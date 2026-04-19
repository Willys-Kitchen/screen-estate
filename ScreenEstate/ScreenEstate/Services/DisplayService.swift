import AppKit
import CoreGraphics

struct DisplayInfo {
    let identifier: String
    let name: String
    let frame: CGRect
    let visibleFrame: CGRect
}

class DisplayService {
    private var screenChangeObserver: NSObjectProtocol?

    static func makeIdentifier(vendor: UInt32, model: UInt32, serial: UInt32, displayID: CGDirectDisplayID? = nil) -> String {
        if serial != 0 {
            return "v\(vendor)-m\(model)-s\(serial)"
        }
        if let displayID {
            return "v\(vendor)-m\(model)-d\(displayID)"
        }
        return "v\(vendor)-m\(model)-s\(serial)"
    }

    func startMonitoring(onChange: @escaping @Sendable () -> Void) {
        screenChangeObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { _ in
            let displays = NSScreen.screens.map { $0.localizedName }
            NSLog("Screen Estate: Display configuration changed. Connected: \(displays)")
            onChange()
        }
    }

    func stopMonitoring() {
        if let observer = screenChangeObserver {
            NotificationCenter.default.removeObserver(observer)
            screenChangeObserver = nil
        }
    }

    func connectedDisplays() -> [DisplayInfo] {
        NSScreen.screens.compactMap { screen in
            guard let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else {
                return nil
            }
            let vendor = CGDisplayVendorNumber(screenNumber)
            let model = CGDisplayModelNumber(screenNumber)
            let serial = CGDisplaySerialNumber(screenNumber)
            let identifier = Self.makeIdentifier(vendor: vendor, model: model, serial: serial, displayID: screenNumber)
            let name = screen.localizedName
            return DisplayInfo(
                identifier: identifier,
                name: name,
                frame: screen.frame,
                visibleFrame: screen.visibleFrame
            )
        }
    }
}
