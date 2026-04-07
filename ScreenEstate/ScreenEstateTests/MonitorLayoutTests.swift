import XCTest
@testable import ScreenEstate

final class MonitorLayoutTests: XCTestCase {

    // MARK: - Codable Round-Trip

    func testMonitorLayoutCodableRoundTrip() throws {
        let layout = MonitorLayout(
            id: UUID(),
            displayIdentifier: "vendor-1234-model-5678-serial-9012",
            displayName: "LG Ultrafine",
            zones: [
                Zone(id: UUID(), number: 1, proportionalFrame: CGRect(x: 0, y: 0, width: 0.5, height: 1)),
                Zone(id: UUID(), number: 2, proportionalFrame: CGRect(x: 0.5, y: 0, width: 0.5, height: 1)),
            ]
        )
        let data = try JSONEncoder().encode(layout)
        let decoded = try JSONDecoder().decode(MonitorLayout.self, from: data)
        XCTAssertEqual(decoded.id, layout.id)
        XCTAssertEqual(decoded.displayIdentifier, layout.displayIdentifier)
        XCTAssertEqual(decoded.displayName, layout.displayName)
        XCTAssertEqual(decoded.zones.count, 2)
    }

    // MARK: - Preset Layouts

    func testHalvesPreset() {
        let zones = MonitorLayout.presetsHalves()
        XCTAssertEqual(zones.count, 2)
        XCTAssertEqual(zones[0].number, 1)
        XCTAssertEqual(zones[1].number, 2)
        XCTAssertEqual(zones[0].proportionalFrame, CGRect(x: 0, y: 0, width: 0.5, height: 1))
        XCTAssertEqual(zones[1].proportionalFrame, CGRect(x: 0.5, y: 0, width: 0.5, height: 1))
    }

    func testThirdsPreset() {
        let zones = MonitorLayout.presetsThirds()
        XCTAssertEqual(zones.count, 3)
        for (i, zone) in zones.enumerated() {
            XCTAssertEqual(zone.number, i + 1)
            let expectedX = CGFloat(i) / 3.0
            XCTAssertEqual(zone.proportionalFrame.origin.x, expectedX, accuracy: 0.0001)
            XCTAssertEqual(zone.proportionalFrame.width, 1.0 / 3.0, accuracy: 0.0001)
            XCTAssertEqual(zone.proportionalFrame.origin.y, 0)
            XCTAssertEqual(zone.proportionalFrame.height, 1.0)
        }
    }

    func testTwoThirdsOneThirdPreset() {
        let zones = MonitorLayout.presetsTwoThirdsOneThird()
        XCTAssertEqual(zones.count, 2)
        XCTAssertEqual(zones[0].number, 1)
        XCTAssertEqual(zones[0].proportionalFrame.width, 2.0 / 3.0, accuracy: 0.0001)
        XCTAssertEqual(zones[1].number, 2)
        XCTAssertEqual(zones[1].proportionalFrame.origin.x, 2.0 / 3.0, accuracy: 0.0001)
        XCTAssertEqual(zones[1].proportionalFrame.width, 1.0 / 3.0, accuracy: 0.0001)
    }

    func testQuadrantsPreset() {
        let zones = MonitorLayout.presetsQuadrants()
        XCTAssertEqual(zones.count, 4)
        // Top-left
        XCTAssertEqual(zones[0].number, 1)
        XCTAssertEqual(zones[0].proportionalFrame, CGRect(x: 0, y: 0, width: 0.5, height: 0.5))
        // Top-right
        XCTAssertEqual(zones[1].number, 2)
        XCTAssertEqual(zones[1].proportionalFrame, CGRect(x: 0.5, y: 0, width: 0.5, height: 0.5))
        // Bottom-left
        XCTAssertEqual(zones[2].number, 3)
        XCTAssertEqual(zones[2].proportionalFrame, CGRect(x: 0, y: 0.5, width: 0.5, height: 0.5))
        // Bottom-right
        XCTAssertEqual(zones[3].number, 4)
        XCTAssertEqual(zones[3].proportionalFrame, CGRect(x: 0.5, y: 0.5, width: 0.5, height: 0.5))
    }

    // MARK: - Presets: zones cover the full screen without gaps or overlaps

    func testPresetsFullCoverage() {
        let presets: [[Zone]] = [
            MonitorLayout.presetsHalves(),
            MonitorLayout.presetsThirds(),
            MonitorLayout.presetsTwoThirdsOneThird(),
            MonitorLayout.presetsQuadrants(),
        ]
        for zones in presets {
            let totalArea = zones.reduce(0.0) { sum, zone in
                sum + zone.proportionalFrame.width * zone.proportionalFrame.height
            }
            XCTAssertEqual(totalArea, 1.0, accuracy: 0.0001, "Preset zones should cover exactly 100% of screen area")
        }
    }
}
