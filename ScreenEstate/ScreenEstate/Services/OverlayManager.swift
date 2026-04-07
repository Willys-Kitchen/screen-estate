import AppKit
import SwiftUI

@MainActor
class OverlayManager {
    private var overlayWindows: [String: OverlayWindow] = [:]
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

            let displayZones = zones // caller should pass zones for this display
            let window: OverlayWindow
            if let existing = overlayWindows[display.identifier] {
                window = existing
            } else {
                window = OverlayWindow(for: screen)
                overlayWindows[display.identifier] = window
            }

            let contentView = NSHostingView(rootView: OverlayContentView(
                zones: displayZones,
                activeZoneID: activeZoneID,
                accentColor: accentColor
            ))
            window.contentView = contentView
            window.setFrame(screen.frame, display: true)
            window.orderFront(nil)
        }
    }

    func updateActiveZone(_ zoneID: UUID?, zones: [Zone], accentColor: Color) {
        for (_, window) in overlayWindows {
            let contentView = NSHostingView(rootView: OverlayContentView(
                zones: zones,
                activeZoneID: zoneID,
                accentColor: accentColor
            ))
            window.contentView = contentView
        }
    }

    func hideOverlays() {
        for (_, window) in overlayWindows {
            window.orderOut(nil)
        }
        overlayWindows.removeAll()
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
