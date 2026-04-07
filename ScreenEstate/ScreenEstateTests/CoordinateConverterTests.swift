import XCTest
@testable import ScreenEstate

final class CoordinateConverterTests: XCTestCase {

    // NSScreen: bottom-left origin, Y increases upward
    // Accessibility: top-left origin, Y increases downward
    // Formula: ax_y = primaryScreenHeight - ns_y - windowHeight

    func testConvertOriginWindow() {
        // Window at bottom-left of a 1080p primary screen
        let nsRect = CGRect(x: 0, y: 0, width: 800, height: 600)
        let ax = CoordinateConverter.toAccessibility(nsRect, primaryScreenHeight: 1080)
        // ax_y = 1080 - 0 - 600 = 480
        XCTAssertEqual(ax, CGRect(x: 0, y: 480, width: 800, height: 600))
    }

    func testConvertTopLeftWindow() {
        // Window at top-left in NSScreen coords means y = 1080 - 600 = 480
        let nsRect = CGRect(x: 0, y: 480, width: 800, height: 600)
        let ax = CoordinateConverter.toAccessibility(nsRect, primaryScreenHeight: 1080)
        // ax_y = 1080 - 480 - 600 = 0
        XCTAssertEqual(ax, CGRect(x: 0, y: 0, width: 800, height: 600))
    }

    func testConvertFullScreen() {
        let nsRect = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let ax = CoordinateConverter.toAccessibility(nsRect, primaryScreenHeight: 1080)
        XCTAssertEqual(ax, CGRect(x: 0, y: 0, width: 1920, height: 1080))
    }

    func testConvertWithNonZeroX() {
        // Window on a secondary monitor offset to the right
        let nsRect = CGRect(x: 1920, y: 200, width: 500, height: 400)
        let ax = CoordinateConverter.toAccessibility(nsRect, primaryScreenHeight: 1080)
        // ax_y = 1080 - 200 - 400 = 480
        XCTAssertEqual(ax, CGRect(x: 1920, y: 480, width: 500, height: 400))
    }

    func testRoundTripConversion() {
        let original = CGRect(x: 100, y: 300, width: 600, height: 400)
        let primaryHeight: CGFloat = 1440
        let ax = CoordinateConverter.toAccessibility(original, primaryScreenHeight: primaryHeight)
        let backToNS = CoordinateConverter.fromAccessibility(ax, primaryScreenHeight: primaryHeight)
        XCTAssertEqual(original.origin.x, backToNS.origin.x, accuracy: 0.001)
        XCTAssertEqual(original.origin.y, backToNS.origin.y, accuracy: 0.001)
        XCTAssertEqual(original.size.width, backToNS.size.width, accuracy: 0.001)
        XCTAssertEqual(original.size.height, backToNS.size.height, accuracy: 0.001)
    }
}

final class ZoneHitTestTests: XCTestCase {

    func testHitTestFindsCorrectZone() {
        let zones = [
            Zone(id: UUID(), number: 1, proportionalFrame: CGRect(x: 0, y: 0, width: 0.5, height: 1)),
            Zone(id: UUID(), number: 2, proportionalFrame: CGRect(x: 0.5, y: 0, width: 0.5, height: 1)),
        ]
        let screen = CGRect(x: 0, y: 0, width: 1920, height: 1080)

        // Point in left half
        let hit1 = ZoneHitTester.hitTest(point: CGPoint(x: 400, y: 500), zones: zones, screenFrame: screen)
        XCTAssertEqual(hit1?.number, 1)

        // Point in right half
        let hit2 = ZoneHitTester.hitTest(point: CGPoint(x: 1200, y: 500), zones: zones, screenFrame: screen)
        XCTAssertEqual(hit2?.number, 2)
    }

    func testHitTestReturnsNilOutsideScreen() {
        let zones = [
            Zone(id: UUID(), number: 1, proportionalFrame: CGRect(x: 0, y: 0, width: 1, height: 1)),
        ]
        let screen = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let hit = ZoneHitTester.hitTest(point: CGPoint(x: 2000, y: 500), zones: zones, screenFrame: screen)
        XCTAssertNil(hit)
    }

    func testHitTestWithQuadrants() {
        let zones = MonitorLayout.presetsQuadrants()
        let screen = CGRect(x: 0, y: 0, width: 2000, height: 1000)

        let topLeft = ZoneHitTester.hitTest(point: CGPoint(x: 400, y: 200), zones: zones, screenFrame: screen)
        XCTAssertEqual(topLeft?.number, 1)

        let topRight = ZoneHitTester.hitTest(point: CGPoint(x: 1200, y: 200), zones: zones, screenFrame: screen)
        XCTAssertEqual(topRight?.number, 2)

        let bottomLeft = ZoneHitTester.hitTest(point: CGPoint(x: 400, y: 700), zones: zones, screenFrame: screen)
        XCTAssertEqual(bottomLeft?.number, 3)

        let bottomRight = ZoneHitTester.hitTest(point: CGPoint(x: 1200, y: 700), zones: zones, screenFrame: screen)
        XCTAssertEqual(bottomRight?.number, 4)
    }

    func testHitTestWithScreenOffset() {
        let zones = [
            Zone(id: UUID(), number: 1, proportionalFrame: CGRect(x: 0, y: 0, width: 0.5, height: 1)),
            Zone(id: UUID(), number: 2, proportionalFrame: CGRect(x: 0.5, y: 0, width: 0.5, height: 1)),
        ]
        // External monitor offset to the right
        let screen = CGRect(x: 1920, y: 0, width: 2560, height: 1440)

        let hit = ZoneHitTester.hitTest(point: CGPoint(x: 2000, y: 500), zones: zones, screenFrame: screen)
        XCTAssertEqual(hit?.number, 1)

        let hit2 = ZoneHitTester.hitTest(point: CGPoint(x: 3500, y: 500), zones: zones, screenFrame: screen)
        XCTAssertEqual(hit2?.number, 2)
    }
}
