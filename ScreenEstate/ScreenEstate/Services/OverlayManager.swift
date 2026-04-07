import AppKit
import SwiftUI

@MainActor
class OverlayManager {
    private struct OverlayEntry {
        let window: OverlayWindow
        let state: OverlayState
    }

    private var overlayEntries: [String: OverlayEntry] = [:]
    private var flashWindow: OverlayWindow?

    func showOverlays(zones: [Zone], for displays: [DisplayInfo], activeZoneID: UUID?, accentColor: Color) {
        for display in displays {
            let screen = NSScreen.screens.first { screen in
                guard let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else { return false }
                let id = DisplayService.makeIdentifier(
                    vendor: CGDisplayVendorNumber(screenNumber),
                    model: CGDisplayModelNumber(screenNumber),
                    serial: CGDisplaySerialNumber(screenNumber)
                )
                return id == display.identifier
            }
            guard let screen else { continue }

            let displayZones = zones

            if let entry = overlayEntries[display.identifier] {
                // Reuse existing window — just update state
                entry.state.zones = displayZones
                entry.state.activeZoneID = activeZoneID
                entry.state.accentColor = accentColor
                entry.window.setFrame(screen.frame, display: true)
                entry.window.orderFront(nil)
            } else {
                // Create new window with hosting view
                let window = OverlayWindow(for: screen)
                let state = OverlayState()
                state.zones = displayZones
                state.activeZoneID = activeZoneID
                state.accentColor = accentColor

                let contentView = NSHostingView(rootView: OverlayContentView(state: state))
                window.contentView = contentView
                window.setFrame(screen.frame, display: true)
                window.orderFront(nil)

                overlayEntries[display.identifier] = OverlayEntry(window: window, state: state)
            }
        }
    }

    func updateActiveZone(_ zoneID: UUID?, zones: [Zone], accentColor: Color) {
        for (_, entry) in overlayEntries {
            entry.state.activeZoneID = zoneID
            entry.state.zones = zones
            entry.state.accentColor = accentColor
        }
    }

    func hideOverlays() {
        for (_, entry) in overlayEntries {
            entry.window.orderOut(nil)
        }
        overlayEntries.removeAll()
    }

    func flashModeName(_ name: String, on screen: NSScreen) {
        let window = OverlayWindow(for: screen)
        window.contentView = NSHostingView(rootView: ModeFlashView(modeName: name))
        window.setFrame(screen.frame, display: true)
        window.orderFront(nil)
        flashWindow = window

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.flashWindow?.orderOut(nil)
            self?.flashWindow = nil
        }
    }
}
