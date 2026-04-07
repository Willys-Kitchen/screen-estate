import AppKit
import CoreGraphics

struct DisplayInfo {
    let identifier: String
    let name: String
    let frame: CGRect
    let visibleFrame: CGRect
}

class DisplayService {
    static func makeIdentifier(vendor: UInt32, model: UInt32, serial: UInt32) -> String {
        "v\(vendor)-m\(model)-s\(serial)"
    }

    func connectedDisplays() -> [DisplayInfo] {
        NSScreen.screens.compactMap { screen in
            guard let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else {
                return nil
            }
            let vendor = CGDisplayVendorNumber(screenNumber)
            let model = CGDisplayModelNumber(screenNumber)
            let serial = CGDisplaySerialNumber(screenNumber)
            let identifier = Self.makeIdentifier(vendor: vendor, model: model, serial: serial)
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
