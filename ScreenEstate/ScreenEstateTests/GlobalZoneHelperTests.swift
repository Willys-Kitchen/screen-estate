import XCTest
@testable import ScreenEstate

final class GlobalZoneHelperTests: XCTestCase {

    // MARK: - Test Fixtures

    /// Two displays side by side: left at x=0, right at x=1920
    private func twoDisplays() -> [DisplayInfo] {
        [
            DisplayInfo(
                identifier: "left-display",
                name: "Left",
                frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
                visibleFrame: CGRect(x: 0, y: 0, width: 1920, height: 1055)
            ),
            DisplayInfo(
                identifier: "right-display",
                name: "Right",
                frame: CGRect(x: 1920, y: 0, width: 1920, height: 1080),
                visibleFrame: CGRect(x: 1920, y: 0, width: 1920, height: 1055)
            ),
        ]
    }

    /// Mode with 2 zones on left display, 2 zones on right display
    private func modeWithFourZones() -> Mode {
        let leftZone1 = Zone(id: UUID(), number: 1, proportionalFrame: CGRect(x: 0, y: 0, width: 0.5, height: 1))
        let leftZone2 = Zone(id: UUID(), number: 2, proportionalFrame: CGRect(x: 0.5, y: 0, width: 0.5, height: 1))
        let rightZone1 = Zone(id: UUID(), number: 1, proportionalFrame: CGRect(x: 0, y: 0, width: 0.5, height: 1))
        let rightZone2 = Zone(id: UUID(), number: 2, proportionalFrame: CGRect(x: 0.5, y: 0, width: 0.5, height: 1))

        return Mode(
            id: UUID(),
            name: "Test",
            layouts: [
                MonitorLayout(id: UUID(), displayIdentifier: "left-display", displayName: "Left", zones: [leftZone1, leftZone2]),
                MonitorLayout(id: UUID(), displayIdentifier: "right-display", displayName: "Right", zones: [rightZone1, rightZone2]),
            ]
        )
    }

    // MARK: - Tests

    func testAutoNumberingAcrossDisplays() {
        // Given: 2 displays (left, right) with 2 zones each
        let displays = twoDisplays()
        let mode = modeWithFourZones()

        // When: computing global zones
        let globalZones = GlobalZoneHelper.computeGlobalZones(displays: displays, mode: mode)

        // Then: zones are numbered 1-4 left-to-right across displays
        XCTAssertEqual(globalZones.count, 4)

        // Left display zones get 1, 2
        let leftZones = globalZones.filter { $0.displayIdentifier == "left-display" }
        XCTAssertEqual(leftZones.map { $0.globalNumber }, [1, 2])

        // Right display zones get 3, 4
        let rightZones = globalZones.filter { $0.displayIdentifier == "right-display" }
        XCTAssertEqual(rightZones.map { $0.globalNumber }, [3, 4])

        // And: findZoneByGlobalNumber returns correct zone
        let result = GlobalZoneHelper.findZoneByGlobalNumber(3, displays: displays, mode: mode)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.display.identifier, "right-display")
        XCTAssertEqual(result?.zone.number, 1) // First zone on right display
    }

    func testManualAssignmentsOverrideAutoNumbering() {
        // Given: 2 displays with 2 zones each, and manual assignments
        let displays = twoDisplays()
        var mode = modeWithFourZones()

        // Get zone IDs to create manual assignments
        let leftZones = mode.layouts.first { $0.displayIdentifier == "left-display" }!.zones
        let rightZones = mode.layouts.first { $0.displayIdentifier == "right-display" }!.zones

        // Assign: right display zone 1 = hotkey 1, left display zone 2 = hotkey 2
        // (reversed from auto-numbering)
        mode.globalZoneAssignments = [
            rightZones[0].id.uuidString: 1,  // Right zone 1 → hotkey 1
            leftZones[1].id.uuidString: 2,   // Left zone 2 → hotkey 2
        ]

        // When: computing global zones
        let globalZones = GlobalZoneHelper.computeGlobalZones(displays: displays, mode: mode)

        // Then: manual assignments are used
        let rightZone1 = globalZones.first { $0.zone.id == rightZones[0].id }
        XCTAssertEqual(rightZone1?.globalNumber, 1)

        let leftZone2 = globalZones.first { $0.zone.id == leftZones[1].id }
        XCTAssertEqual(leftZone2?.globalNumber, 2)

        // Unassigned zones have nil globalNumber
        let leftZone1 = globalZones.first { $0.zone.id == leftZones[0].id }
        XCTAssertNil(leftZone1?.globalNumber)

        // And: findZoneByGlobalNumber respects manual assignment
        let result = GlobalZoneHelper.findZoneByGlobalNumber(1, displays: displays, mode: mode)
        XCTAssertEqual(result?.display.identifier, "right-display") // Not left!
    }

    // MARK: - Mutation Tests

    func testAssignNumberToZone() {
        // Given: a mode with auto-numbering (no manual assignments)
        var mode = modeWithFourZones()
        XCTAssertNil(mode.globalZoneAssignments) // starts in auto mode

        let leftZones = mode.layouts.first { $0.displayIdentifier == "left-display" }!.zones
        let zoneToAssign = leftZones[0]

        // When: assigning number 5 to that zone
        mode = GlobalZoneHelper.assign(number: 5, to: zoneToAssign.id, in: mode)

        // Then: mode switches to manual mode with that assignment
        XCTAssertNotNil(mode.globalZoneAssignments)
        XCTAssertEqual(mode.globalZoneAssignments?[zoneToAssign.id.uuidString], 5)
    }

    func testAssignNumberRemovesDuplicates() {
        // Given: a mode where zone A has number 3
        var mode = modeWithFourZones()
        let leftZones = mode.layouts.first { $0.displayIdentifier == "left-display" }!.zones
        let zoneA = leftZones[0]
        let zoneB = leftZones[1]

        mode.globalZoneAssignments = [zoneA.id.uuidString: 3]

        // When: assigning number 3 to zone B
        mode = GlobalZoneHelper.assign(number: 3, to: zoneB.id, in: mode)

        // Then: zone A no longer has number 3, zone B has it
        XCTAssertNil(mode.globalZoneAssignments?[zoneA.id.uuidString])
        XCTAssertEqual(mode.globalZoneAssignments?[zoneB.id.uuidString], 3)
    }

    func testAssignNilClearsZoneNumber() {
        // Given: a mode where zone A has number 3
        var mode = modeWithFourZones()
        let leftZones = mode.layouts.first { $0.displayIdentifier == "left-display" }!.zones
        let zoneA = leftZones[0]

        mode.globalZoneAssignments = [zoneA.id.uuidString: 3]

        // When: assigning nil to zone A
        mode = GlobalZoneHelper.assign(number: nil, to: zoneA.id, in: mode)

        // Then: zone A has no assignment
        XCTAssertNil(mode.globalZoneAssignments?[zoneA.id.uuidString])
    }

    func testClearAssignmentsSwitchesToAutoMode() {
        // Given: a mode with manual assignments
        var mode = modeWithFourZones()
        mode.globalZoneAssignments = ["some-zone": 1]

        // When: clearing assignments
        mode = GlobalZoneHelper.clearAssignments(in: mode)

        // Then: back to auto mode (nil)
        XCTAssertNil(mode.globalZoneAssignments)
    }
}
