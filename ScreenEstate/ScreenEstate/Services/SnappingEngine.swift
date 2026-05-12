import AppKit
import SwiftUI

@MainActor
class SnappingEngine {
    enum State {
        case idle
        case tracking(window: AXUIElement)
    }

    private var state: State = .idle
    private let windowService = WindowManipulationService()
    private let displayService = DisplayService()
    private let overlayManager = OverlayManager()
    private var appState: AppState
    private var activeZone: Zone?
    private var cachedWindow: AXUIElement? // Captured when Shift is pressed
    private var cachedGlobalZones: [GlobalZoneHelper.GlobalZone]? // Cached during tracking

    private var monitors: [Any] = []
    var onSnapFailed: (() -> Void)?

    init(appState: AppState, onSnapFailed: (() -> Void)? = nil) {
        self.appState = appState
        self.onSnapFailed = onSnapFailed
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
            if windowService.exitFullscreen(window) {
                // Wait for fullscreen exit animation (~0.5s), then snap
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    self?.performSnap(window: window, toZoneNumber: number)
                }
                return
            }
            // If exit failed, try snapping anyway (might fail)
        }

        // Not fullscreen — snap immediately
        performSnap(window: window, toZoneNumber: number)
    }

    private func performSnap(window: AXUIElement, toZoneNumber number: Int) {
        guard let mode = appState.activeMode else {
            NSLog("Screen Estate: No active mode")
            return
        }

        let displays = displayService.connectedDisplays()
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 1080

        // Find zone by global number across all monitors
        #if DEBUG
        NSLog("Screen Estate: Snapping to global zone \(number)")
        #endif
        guard let result = GlobalZoneHelper.findZoneByGlobalNumber(number, displays: displays, mode: mode) else {
            NSLog("Screen Estate: No global zone with number \(number)")
            return
        }

        let axFrame = result.zone.accessibilityFrame(for: result.display.visibleFrame, primaryScreenHeight: primaryHeight)
        #if DEBUG
        NSLog("Screen Estate: Snapping to \(axFrame) on \(result.display.name)")
        #endif
        if !windowService.setWindowFrame(window, frame: axFrame) {
            onSnapFailed?()
        }

        // Show overlay with global zone numbers
        let globalZones = GlobalZoneHelper.computeGlobalZones(displays: displays, mode: mode)
        let zonesOnDisplay = globalZones.filter { $0.displayIdentifier == result.display.identifier }
        overlayManager.showOverlays(
            zones: zonesOnDisplay.map { $0.zone },
            for: [result.display],
            activeZoneID: result.zone.id,
            accentColor: accentColor,
            globalNumbers: Dictionary(uniqueKeysWithValues: zonesOnDisplay.compactMap { gz in
                gz.globalNumber.map { (gz.zone.id, $0) }
            })
        )
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.overlayManager.hideOverlays()
        }
    }
}
