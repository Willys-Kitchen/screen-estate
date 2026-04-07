import XCTest
@testable import ScreenEstate

final class ZoneTests: XCTestCase {

    // MARK: - Codable Round-Trip

    func testZoneCodableRoundTrip() throws {
        let zone = Zone(
            id: UUID(),
            number: 1,
            proportionalFrame: CGRect(x: 0, y: 0, width: 0.5, height: 1.0)
        )
        let data = try JSONEncoder().encode(zone)
        let decoded = try JSONDecoder().decode(Zone.self, from: data)
        XCTAssertEqual(zone.id, decoded.id)
        XCTAssertEqual(zone.number, decoded.number)
        XCTAssertEqual(zone.proportionalFrame, decoded.proportionalFrame)
    }

    // MARK: - Absolute Frame Calculation

    func testAbsoluteFrameFullScreen() {
        let zone = Zone(
            id: UUID(),
            number: 1,
            proportionalFrame: CGRect(x: 0, y: 0, width: 1.0, height: 1.0)
        )
        let screen = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let absolute = zone.absoluteFrame(for: screen)
        XCTAssertEqual(absolute, CGRect(x: 0, y: 0, width: 1920, height: 1080))
    }

    func testAbsoluteFrameLeftHalf() {
        let zone = Zone(
            id: UUID(),
            number: 1,
            proportionalFrame: CGRect(x: 0, y: 0, width: 0.5, height: 1.0)
        )
        let screen = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let absolute = zone.absoluteFrame(for: screen)
        XCTAssertEqual(absolute, CGRect(x: 0, y: 0, width: 960, height: 1080))
    }

    func testAbsoluteFrameWithScreenOffset() {
        // External monitor with non-zero origin
        let zone = Zone(
            id: UUID(),
            number: 2,
            proportionalFrame: CGRect(x: 0.5, y: 0, width: 0.5, height: 1.0)
        )
        let screen = CGRect(x: 1920, y: 0, width: 2560, height: 1440)
        let absolute = zone.absoluteFrame(for: screen)
        XCTAssertEqual(absolute, CGRect(x: 1920 + 1280, y: 0, width: 1280, height: 1440))
    }

    func testAbsoluteFrameBottomRightQuadrant() {
        let zone = Zone(
            id: UUID(),
            number: 4,
            proportionalFrame: CGRect(x: 0.5, y: 0.5, width: 0.5, height: 0.5)
        )
        let screen = CGRect(x: 0, y: 0, width: 2000, height: 1000)
        let absolute = zone.absoluteFrame(for: screen)
        XCTAssertEqual(absolute, CGRect(x: 1000, y: 500, width: 1000, height: 500))
    }
}
