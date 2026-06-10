import AppKit
import SwiftUI

@MainActor
class SnappingEngine {
    enum State {
        case idle
        case tracking(window: AXUIElement)
    }

    private var state: State = .idle
    private let windowService: WindowManipulating
    private let displayService: DisplayQuerying
    private let overlayManager: OverlayPresenting
    private var appState: AppState
    private var activeZone: Zone?
    private var cachedWindow: AXUIElement? // Captured when Shift is pressed
    private var cachedGlobalZones: [GlobalZoneHelper.GlobalZone]? // Cached during tracking

    private var monitors: [Any] = []
    var onSnapFailed: (() -> Void)?

    private let fullscreenQuietWait: TimeInterval
    private let fullscreenVerifyDelay: TimeInterval
    private let curtainFadeDuration: TimeInterval

    private let curtainMessages = [
        "shuffling some shtuff",
        "movin your tingz",
        "thanks for using screen estate :)",
        "Willy says hi",
        "Sorry if this wait is a bit awkward",
        "Can you tell this app was heavily vibecoded?",
        "blame apple for the wait, not me",
        "if you want, press esc and then move the screen. or don't. you do you",
        "looking good :)",
        "Hope you liked your accent colour",
        "sliding your content over",
        "this took way too many attempts to get working",
        "an AI wrote most of this, be nice",
        "held together with hopes and dispatch timers",
        "shipping > perfect, apparently",
        "macOS won't let me do this any faster, sorry",
        "fighting the window manager on your behalf",
        "waiting for apple's fullscreen mode to finish chucking a sook",
        "made with love-ish",
        "you're one of like 3 people using this :)",
        "checkout Willys-Kitchen on github to see if he's cooked up anything new",
        "almost there…",
        "worth the wait, probably",
        "can't believe this kind of app isn't free on mac btw"
    ]

    private var curtainMessage: String {
        curtainMessages.randomElement() ?? "Arranging your screen estate…"
    }

    init(
        appState: AppState,
        windowService: WindowManipulating = WindowManipulationService(),
        displayService: DisplayQuerying = DisplayService(),
        overlayManager: OverlayPresenting = OverlayManager(),
        onSnapFailed: (() -> Void)? = nil,
        fullscreenQuietWait: TimeInterval = 0.8,
        fullscreenVerifyDelay: TimeInterval = 0.1,
        curtainFadeDuration: TimeInterval = 0.5
    ) {
        self.appState = appState
        self.windowService = windowService
        self.displayService = displayService
        self.overlayManager = overlayManager
        self.onSnapFailed = onSnapFailed
        self.fullscreenQuietWait = fullscreenQuietWait
        self.fullscreenVerifyDelay = fullscreenVerifyDelay
        self.curtainFadeDuration = curtainFadeDuration
    }

    func start() {
        let dragMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDragged]) { [weak self] event in
            Task { @MainActor in
                self?.handleMouseDragged(event)
            }
        }
        let mouseUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp]) { [weak self] event in
            Task { @MainActor in
                self?.handleMouseUp(event)
            }
        }
        let flagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged]) { [weak self] event in
            Task { @MainActor in
                self?.handleFlagsChanged(event)
            }
        }
        if let m = dragMonitor { monitors.append(m) }
        if let m = mouseUpMonitor { monitors.append(m) }
        if let m = flagsMonitor { monitors.append(m) }
        #if DEBUG
        NSLog("Screen Estate: Drag monitors registered")
        #endif
    }

    func stop() {
        for monitor in monitors {
            NSEvent.removeMonitor(monitor)
        }
        monitors.removeAll()
        cancelTracking()
    }

    private var accentColor: Color { appState.accentColor }

    private func handleMouseDragged(_ event: NSEvent) {
        guard appState.isDragSnapEnabled else { return }
        guard event.modifierFlags.contains(.shift) else {
            if case .tracking = state {
                cancelTracking()
            }
            return
        }

        switch state {
        case .idle:
            // Prefer a fresh window reference; fall back to the one cached on Shift press.
            // Validate the cached reference is still alive before using it.
            let freshWindow = windowService.getFocusedWindow()
            let validCached = cachedWindow.flatMap { windowService.isWindowValid($0) ? $0 : nil }
            guard let window = freshWindow ?? validCached else {
                NSLog("Screen Estate: No focused window found (fresh and cached both nil/invalid)")
                return
            }
            #if DEBUG
            NSLog("Screen Estate: Started tracking drag (used \(freshWindow != nil ? "fresh" : "cached") window)")
            #endif
            state = .tracking(window: window)
            // Cache global zones once at tracking start
            if let mode = appState.activeMode {
                let displays = displayService.connectedDisplays()
                cachedGlobalZones = GlobalZoneHelper.computeGlobalZones(displays: displays, mode: mode)
            }
            showOverlaysForCurrentMode()
            updateHitTest()

        case .tracking:
            updateHitTest()
        }
    }

    private func handleMouseUp(_ event: NSEvent) {
        guard case .tracking(let window) = state else { return }

        if let zone = activeZone {
            // Re-validate the window reference before snapping — it may have
            // become stale during the drag (e.g. window closed, app quit).
            if windowService.isWindowValid(window) {
                #if DEBUG
                NSLog("Screen Estate: Snapping to zone \(zone.number)")
                #endif
                snapWindow(window, to: zone)
            } else {
                NSLog("Screen Estate: Window became invalid during drag, cannot snap")
                onSnapFailed?()
            }
        } else {
            #if DEBUG
            NSLog("Screen Estate: Mouse up but no active zone")
            #endif
        }
        cancelTracking()
    }

    private func handleFlagsChanged(_ event: NSEvent) {
        guard appState.isDragSnapEnabled else { return }
        if event.modifierFlags.contains(.shift) {
            // Shift pressed — cache the focused window now, before drag starts
            if case .idle = state {
                cachedWindow = windowService.getFocusedWindow()
                #if DEBUG
                if cachedWindow != nil {
                    NSLog("Screen Estate: Cached focused window on Shift press")
                } else {
                    NSLog("Screen Estate: Shift pressed but no focused window to cache")
                }
                #endif
            }
        } else {
            // Shift released
            cachedWindow = nil
            if case .tracking = state {
                cancelTracking()
            }
        }
    }

    private func cancelTracking() {
        state = .idle
        activeZone = nil
        cachedWindow = nil
        cachedGlobalZones = nil
        overlayManager.hideOverlays()
    }

    private func showOverlaysForCurrentMode() {
        guard let mode = appState.activeMode else {
            NSLog("Screen Estate: No active mode")
            return
        }
        let displays = displayService.connectedDisplays()
        #if DEBUG
        NSLog("Screen Estate: Showing overlays for \(displays.count) displays")
        #endif

        // Use cached global zones if available, otherwise compute
        let globalZonesData = cachedGlobalZones ?? GlobalZoneHelper.computeGlobalZones(displays: displays, mode: mode)

        for display in displays {
            let zones = mode.layouts.first { $0.displayIdentifier == display.identifier }?.zones ?? []
            #if DEBUG
            NSLog("Screen Estate: Display \(display.name) has \(zones.count) zones")
            #endif

            let globalNumbers: [UUID: Int] = Dictionary(uniqueKeysWithValues: globalZonesData
                .filter { $0.displayIdentifier == display.identifier }
                .compactMap { gz in gz.globalNumber.map { (gz.zone.id, $0) } }
            )

            overlayManager.showOverlays(zones: zones, for: [display], activeZoneID: nil, accentColor: accentColor, globalNumbers: globalNumbers)
        }
    }

    private func updateHitTest() {
        let cursorLocation = NSEvent.mouseLocation
        let displays = displayService.connectedDisplays()
        guard let mode = appState.activeMode else { return }

        // Use cached global zones if available, otherwise compute
        let globalZonesData = cachedGlobalZones ?? GlobalZoneHelper.computeGlobalZones(displays: displays, mode: mode)

        for display in displays {
            if display.frame.contains(cursorLocation) {
                let zones = mode.layouts.first { $0.displayIdentifier == display.identifier }?.zones ?? []
                let hit = ZoneHitTester.hitTest(point: cursorLocation, zones: zones, screenFrame: display.frame)
                activeZone = hit

                let globalNumbers: [UUID: Int] = Dictionary(uniqueKeysWithValues: globalZonesData
                    .filter { $0.displayIdentifier == display.identifier }
                    .compactMap { gz in gz.globalNumber.map { (gz.zone.id, $0) } }
                )

                overlayManager.showOverlays(zones: zones, for: [display], activeZoneID: hit?.id, accentColor: accentColor, globalNumbers: globalNumbers)
                return
            }
        }
        activeZone = nil
    }

    func snapWindow(_ window: AXUIElement, to zone: Zone) {
        let displays = displayService.connectedDisplays()
        guard let mode = appState.activeMode else { return }

        for display in displays {
            let zones = mode.layouts.first { $0.displayIdentifier == display.identifier }?.zones ?? []
            if zones.contains(where: { $0.id == zone.id }) {
                let primaryHeight = NSScreen.screens.first?.frame.height ?? display.frame.height
                let axFrame = zone.accessibilityFrame(for: display.visibleFrame, primaryScreenHeight: primaryHeight)
                #if DEBUG
                NSLog("Screen Estate: Setting window frame to \(axFrame)")
                #endif
                if !windowService.setWindowFrame(window, frame: axFrame) {
                    onSnapFailed?()
                }
                // Raise window and activate owning app (best-effort, failures are silent)
                windowService.raiseWindow(window)
                windowService.activateOwningApp(window)
                return
            }
        }
    }

    func showKeyboardSnapOverlay() {
        showOverlaysForCurrentMode()
    }

    func hideKeyboardSnapOverlay() {
        overlayManager.hideOverlays()
    }

    func snapFocusedWindowToZone(number: Int) {
        guard let window = windowService.getFocusedWindow() else {
            NSLog("Screen Estate: No focused window")
            return
        }
        guard appState.activeMode != nil else {
            NSLog("Screen Estate: No active mode")
            return
        }

        // Check if window is fullscreen — if so, exit fullscreen first and snap after animation
        if windowService.isFullscreen(window) {
            #if DEBUG
            NSLog("Screen Estate: Window is fullscreen, exiting before snap")
            #endif
            // Capture the owning app before exiting: focus can legitimately
            // move during the quiet wait, and we must never snap a different
            // app's window.
            let originalPID = windowService.owningPID(window)
            if windowService.exitFullscreen(window) {
                if let resolved = resolveGlobalZone(number) {
                    overlayManager.showCurtain(message: curtainMessage, on: resolved.display, accentColor: accentColor)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + fullscreenQuietWait) { [weak self] in
                    guard let self else { return }
                    guard let freshWindow = self.windowService.getFocusedWindow() else {
                        NSLog("Screen Estate: Lost window reference after fullscreen exit")
                        self.overlayManager.fadeOutCurtain(duration: 0.2)
                        return
                    }
                    guard self.windowService.owningPID(freshWindow) == originalPID else {
                        NSLog("Screen Estate: Focus moved to another app during fullscreen exit, aborting snap")
                        self.overlayManager.fadeOutCurtain(duration: 0.2)
                        return
                    }
                    self.performFullscreenSnap(window: freshWindow, toZoneNumber: number)
                }
                return
            }
            // If exit failed, try snapping anyway (might fail)
        }

        // Not fullscreen — snap immediately
        performSnap(window: window, toZoneNumber: number)
    }

    private func framesMatch(_ a: CGRect?, _ b: CGRect?, tolerance: CGFloat) -> Bool {
        guard let a, let b else { return false }
        return abs(a.origin.x - b.origin.x) <= tolerance
            && abs(a.origin.y - b.origin.y) <= tolerance
            && abs(a.width - b.width) <= tolerance
            && abs(a.height - b.height) <= tolerance
    }

    private struct ResolvedZone {
        let display: DisplayInfo
        let zone: Zone
        let axFrame: CGRect
    }

    private func resolveGlobalZone(_ number: Int) -> ResolvedZone? {
        guard let mode = appState.activeMode else { return nil }
        let displays = displayService.connectedDisplays()
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 1080
        guard let result = GlobalZoneHelper.findZoneByGlobalNumber(number, displays: displays, mode: mode) else {
            return nil
        }
        let axFrame = result.zone.accessibilityFrame(for: result.display.visibleFrame, primaryScreenHeight: primaryHeight)
        return ResolvedZone(display: result.display, zone: result.zone, axFrame: axFrame)
    }

    private func showZoneOverlay(for resolved: ResolvedZone, autoHideAfter: TimeInterval?) {
        guard let mode = appState.activeMode else { return }
        let displays = displayService.connectedDisplays()
        let globalZones = GlobalZoneHelper.computeGlobalZones(displays: displays, mode: mode)
        let zonesOnDisplay = globalZones.filter { $0.displayIdentifier == resolved.display.identifier }
        overlayManager.showOverlays(
            zones: zonesOnDisplay.map { $0.zone },
            for: [resolved.display],
            activeZoneID: resolved.zone.id,
            accentColor: accentColor,
            globalNumbers: Dictionary(uniqueKeysWithValues: zonesOnDisplay.compactMap { gz in
                gz.globalNumber.map { (gz.zone.id, $0) }
            })
        )
        if let autoHideAfter {
            DispatchQueue.main.asyncAfter(deadline: .now() + autoHideAfter) { [weak self] in
                self?.overlayManager.hideOverlays()
            }
        }
    }

    private func verifyLandingOnce(window: AXUIElement, frame: CGRect) {
        guard windowService.isWindowValid(window) else { return }
        let current = windowService.getWindowFrame(window)
        if let current, framesMatch(current, frame, tolerance: 8) {
            return
        }
        windowService.setWindowFrame(window, frame: frame)
        windowService.raiseWindow(window)
        windowService.activateOwningApp(window)
    }

    private func performFullscreenSnap(window: AXUIElement, toZoneNumber number: Int) {
        guard let resolved = resolveGlobalZone(number) else {
            NSLog("Screen Estate: No global zone with number \(number)")
            overlayManager.fadeOutCurtain(duration: 0.2)
            return
        }
        let axFrame = resolved.axFrame

        if !windowService.setWindowFrame(window, frame: axFrame) {
            onSnapFailed?()
        }
        if windowService.isWindowValid(window) {
            windowService.raiseWindow(window)
            windowService.activateOwningApp(window)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + fullscreenVerifyDelay) { [weak self] in
            guard let self else { return }
            self.verifyLandingOnce(window: window, frame: axFrame)
            self.overlayManager.fadeOutCurtain(duration: self.curtainFadeDuration)
        }
    }

    private func performSnap(window: AXUIElement, toZoneNumber number: Int) {
        guard let resolved = resolveGlobalZone(number) else {
            NSLog("Screen Estate: No global zone with number \(number)")
            return
        }
        #if DEBUG
        NSLog("Screen Estate: Snapping to \(resolved.axFrame) on \(resolved.display.name)")
        #endif
        if !windowService.setWindowFrame(window, frame: resolved.axFrame) {
            onSnapFailed?()
            return
        }

        // Raise window and activate owning app (best-effort, failures are silent)
        if windowService.isWindowValid(window) {
            windowService.raiseWindow(window)
            windowService.activateOwningApp(window)
        }

        showZoneOverlay(for: resolved, autoHideAfter: 0.3)
    }
}
