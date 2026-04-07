import CoreGraphics

enum CoordinateConverter {
    /// Convert from NSScreen coordinates (bottom-left origin) to Accessibility coordinates (top-left origin).
    static func toAccessibility(_ rect: CGRect, primaryScreenHeight: CGFloat) -> CGRect {
        CGRect(
            x: rect.origin.x,
            y: primaryScreenHeight - rect.origin.y - rect.height,
            width: rect.width,
            height: rect.height
        )
    }

    /// Convert from Accessibility coordinates (top-left origin) to NSScreen coordinates (bottom-left origin).
    static func fromAccessibility(_ rect: CGRect, primaryScreenHeight: CGFloat) -> CGRect {
        CGRect(
            x: rect.origin.x,
            y: primaryScreenHeight - rect.origin.y - rect.height,
            width: rect.width,
            height: rect.height
        )
    }
}

enum ZoneHitTester {
    /// Find which zone contains the given point. Point and screenFrame are in the same coordinate system.
    static func hitTest(point: CGPoint, zones: [Zone], screenFrame: CGRect) -> Zone? {
        for zone in zones {
            let absoluteFrame = zone.absoluteFrame(for: screenFrame)
            if absoluteFrame.contains(point) {
                return zone
            }
        }
        return nil
    }
}
