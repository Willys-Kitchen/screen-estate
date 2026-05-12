import Foundation
import CoreGraphics

struct Zone: Identifiable, Codable, Hashable {
    let id: UUID
    var number: Int
    var proportionalFrame: CGRect

    /// Converts proportional frame (y=0 at top) to absolute NSScreen coordinates (y=0 at bottom).
    func absoluteFrame(for screenFrame: CGRect) -> CGRect {
        CGRect(
            x: screenFrame.origin.x + proportionalFrame.origin.x * screenFrame.width,
            y: screenFrame.origin.y + (1.0 - proportionalFrame.origin.y - proportionalFrame.height) * screenFrame.height,
            width: proportionalFrame.width * screenFrame.width,
            height: proportionalFrame.height * screenFrame.height
        )
    }

    /// Converts proportional frame to Accessibility API coordinates (y=0 at top of primary screen).
    /// Use this when setting window frames via AXUIElement.
    func accessibilityFrame(for screenFrame: CGRect, primaryScreenHeight: CGFloat) -> CGRect {
        let absolute = absoluteFrame(for: screenFrame)
        return CGRect(
            x: absolute.origin.x,
            y: primaryScreenHeight - absolute.origin.y - absolute.height,
            width: absolute.width,
            height: absolute.height
        )
    }
}
