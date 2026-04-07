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

    private var monitors: [Any] = []

    init(appState: AppState) {
        self.appState = appState
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
        NSLog("Screen Estate: Drag monitors registered")
    }

    func stop() {
        for monitor in monitors {
            NSEvent.removeMonitor(monitor)
        }
        monitors.removeAll()
        cancelTracking()
    }

    private var accentColor: Color {
        let rgba = appState.settings.accentColorRGBA
        return Color(red: rgba.red, green: rgba.green, blue: rgba.blue, opacity: rgba.alpha)
    }

    private func handleMouseDragged(_ event: NSEvent) {
        guard appState.settings.isEnabled, appState.settings.isDragSnapEnabled else { return }
        guard event.modifierFlags.contains(.shift) else {
            if case .tracking = state {
                cancelTracking()
            }
            return
        }

        switch state {
        case .idle:
            // Try to get window now, or use the one cached when Shift was pressed
            let window = windowService.getFocusedWindow() ?? cachedWindow
            guard let window else {
                NSLog("Screen Estate: No focused window found")
                return
            }
            NSLog("Screen Estate: Started tracking drag")
            state = .tracking(window: window)
            showOverlaysForCurrentMode()
            updateHitTest()

        case .tracking:
            updateHitTest()
        }
    }

    private func handleMouseUp(_ event: NSEvent) {
        guard case .tracking(let window) = state else { return }

        if let zone = activeZone {
            NSLog("Screen Estate: Snapping to zone \(zone.number)")
            snapWindow(window, to: zone)
        } else {
            NSLog("Screen Estate: Mouse up but no active zone")
        }
        cancelTracking()
    }

    private func handleFlagsChanged(_ event: NSEvent) {
        guard appState.settings.isDragSnapEnabled else { return }
        if event.modifierFlags.contains(.shift) {
            // Shift pressed — cache the focused window now, before drag starts
            if case .idle = state {
                cachedWindow = windowService.getFocusedWindow()
                if cachedWindow != nil {
                    NSLog("Screen Estate: Cached focused window on Shift press")
                } else {
                    NSLog("Screen Estate: Shift pressed but no focused window to cache")
                }
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
        overlayManager.hideOverlays()
    }

    private func showOverlaysForCurrentMode() {
        guard let mode = appState.activeMode else {
            NSLog("Screen Estate: No active mode")
            return
        }
        let displays = displayService.connectedDisplays()
        NSLog("Screen Estate: Showing overlays for \(displays.count) displays")
        for display in displays {
            let zones = mode.layouts.first { $0.displayIdentifier == display.identifier }?.zones ?? []
            NSLog("Screen Estate: Display \(display.name) has \(zones.count) zones")
            overlayManager.showOverlays(zones: zones, for: [display], activeZoneID: nil, accentColor: accentColor)
        }
    }

    private func updateHitTest() {
        let cursorLocation = NSEvent.mouseLocation
        let displays = displayService.connectedDisplays()
        guard let mode = appState.activeMode else { return }

        for display in displays {
            if display.frame.contains(cursorLocation) {
                let zones = mode.layouts.first { $0.displayIdentifier == display.identifier }?.zones ?? []
                let hit = ZoneHitTester.hitTest(point: cursorLocation, zones: zones, screenFrame: display.frame)
                activeZone = hit

                overlayManager.showOverlays(zones: zones, for: [display], activeZoneID: hit?.id, accentColor: accentColor)
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
                let absoluteFrame = zone.absoluteFrame(for: display.visibleFrame)
                let primaryHeight = NSScreen.screens.first?.frame.height ?? display.frame.height
                let axFrame = CoordinateConverter.toAccessibility(absoluteFrame, primaryScreenHeight: primaryHeight)
                NSLog("Screen Estate: Setting window frame to \(axFrame)")
                windowService.setWindowFrame(window, frame: axFrame)
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
        guard appState.settings.isEnabled else {
            NSLog("Screen Estate: Disabled")
            return
        }
        guard let window = windowService.getFocusedWindow() else {
            NSLog("Screen Estate: No focused window")
            return
        }
        guard let position = windowService.getWindowPosition(window) else {
            NSLog("Screen Estate: Can't get window position")
            return
        }
        guard let mode = appState.activeMode else {
            NSLog("Screen Estate: No active mode")
            return
        }

        NSLog("Screen Estate: Snapping focused window to zone \(number), window at \(position)")

        let primaryHeight = NSScreen.screens.first?.frame.height ?? 1080
        let nsPosition = CoordinateConverter.fromAccessibility(
            CGRect(origin: position, size: .zero), primaryScreenHeight: primaryHeight
        ).origin

        let displays = displayService.connectedDisplays()
        for display in displays {
            if display.frame.contains(nsPosition) {
                let zones = mode.layouts.first { $0.displayIdentifier == display.identifier }?.zones ?? []
                NSLog("Screen Estate: Found display \(display.name) with \(zones.count) zones")
                if let zone = zones.first(where: { $0.number == number }) {
                    let absoluteFrame = zone.absoluteFrame(for: display.visibleFrame)
                    let axFrame = CoordinateConverter.toAccessibility(absoluteFrame, primaryScreenHeight: primaryHeight)
                    NSLog("Screen Estate: Snapping to \(axFrame)")
                    windowService.setWindowFrame(window, frame: axFrame)

                    overlayManager.showOverlays(zones: zones, for: [display], activeZoneID: zone.id, accentColor: accentColor)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                        self?.overlayManager.hideOverlays()
                    }
                } else {
                    NSLog("Screen Estate: No zone with number \(number) on this display")
                }
                return
            }
        }
        NSLog("Screen Estate: Window position \(nsPosition) not on any known display")
    }
}
