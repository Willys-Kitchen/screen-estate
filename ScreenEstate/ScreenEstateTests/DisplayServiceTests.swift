import XCTest
@testable import ScreenEstate

final class DisplayServiceTests: XCTestCase {

    // MARK: - Display Identifier

    func testDisplayIdentifierFromComponents() {
        let id = DisplayService.makeIdentifier(vendor: 1234, model: 5678, serial: 9012)
        XCTAssertEqual(id, "v1234-m5678-s9012")
    }

    func testDisplayIdentifierWithZeroSerialUsesDisplayID() {
        // Some displays report serial as 0; fall back to displayID as tiebreaker
        let id = DisplayService.makeIdentifier(vendor: 1234, model: 5678, serial: 0, displayID: 42)
        XCTAssertEqual(id, "v1234-m5678-d42")
    }

    func testDisplayIdentifierWithZeroSerialAndNoDisplayID() {
        let id = DisplayService.makeIdentifier(vendor: 1234, model: 5678, serial: 0)
        XCTAssertEqual(id, "v1234-m5678-s0")
    }

    func testDifferentDisplaysGetDifferentIdentifiers() {
        let id1 = DisplayService.makeIdentifier(vendor: 1234, model: 5678, serial: 1)
        let id2 = DisplayService.makeIdentifier(vendor: 1234, model: 5678, serial: 2)
        XCTAssertNotEqual(id1, id2)
    }

    func testIdenticalDisplaysWithZeroSerialDifferByDisplayID() {
        let id1 = DisplayService.makeIdentifier(vendor: 1234, model: 5678, serial: 0, displayID: 1)
        let id2 = DisplayService.makeIdentifier(vendor: 1234, model: 5678, serial: 0, displayID: 2)
        XCTAssertNotEqual(id1, id2)
    }

    func testSameDisplayGetsSameIdentifier() {
        let id1 = DisplayService.makeIdentifier(vendor: 1234, model: 5678, serial: 9012)
        let id2 = DisplayService.makeIdentifier(vendor: 1234, model: 5678, serial: 9012)
        XCTAssertEqual(id1, id2)
    }

    // MARK: - DisplayInfo

    func testDisplayInfoStruct() {
        let info = DisplayInfo(
            identifier: "v1234-m5678-s9012",
            name: "Test Display",
            frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            visibleFrame: CGRect(x: 0, y: 25, width: 1920, height: 1055)
        )
        XCTAssertEqual(info.identifier, "v1234-m5678-s9012")
        XCTAssertEqual(info.name, "Test Display")
        XCTAssertEqual(info.frame.width, 1920)
        XCTAssertEqual(info.visibleFrame.height, 1055)
    }
}
