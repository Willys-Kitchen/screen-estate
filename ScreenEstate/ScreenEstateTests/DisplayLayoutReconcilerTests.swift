import XCTest
@testable import ScreenEstate

final class DisplayLayoutReconcilerTests: XCTestCase {

    private func display(_ identifier: String, name: String = "Display", x: CGFloat = 0) -> DisplayInfo {
        DisplayInfo(
            identifier: identifier,
            name: name,
            frame: CGRect(x: x, y: 0, width: 1920, height: 1080),
            visibleFrame: CGRect(x: x, y: 0, width: 1920, height: 1055)
        )
    }

    private func layout(_ identifier: String, name: String = "Display", zones: Int = 2) -> MonitorLayout {
        MonitorLayout(
            id: UUID(),
            displayIdentifier: identifier,
            displayName: name,
            zones: Array(MonitorLayout.presetsHalves().prefix(zones))
        )
    }

    private func mode(_ layouts: [MonitorLayout]) -> Mode {
        Mode(id: UUID(), name: "Test", layouts: layouts)
    }

    // The reported bug: a monitor reports a different serial after reconnecting,
    // so its saved layout no longer matches and zones stop applying.
    func testMigratesLayoutWhenSameMonitorReturnsWithNewSerial() {
        let saved = mode([layout("v4268-m41458-s809645644", name: "DELL U3423WE")])
        let connected = [display("v4268-m41458-s810043212", name: "DELL U3423WE")]

        let result = DisplayLayoutReconciler.reconcile(modes: [saved], displays: connected)

        XCTAssertEqual(result[0].layouts.count, 1)
        XCTAssertEqual(result[0].layouts[0].displayIdentifier, "v4268-m41458-s810043212",
                       "layout must be re-keyed to the monitor's current identifier")
        XCTAssertEqual(result[0].layouts[0].zones.count, 2, "zones must survive the migration")
    }

    func testExactMatchWinsOverVendorModelMatch() {
        let exact = layout("v4268-m41458-s111", name: "DELL A", zones: 1)
        let orphan = layout("v4268-m41458-s999", name: "DELL B", zones: 2)
        let saved = mode([exact, orphan])
        let connected = [display("v4268-m41458-s111", name: "DELL A")]

        let result = DisplayLayoutReconciler.reconcile(modes: [saved], displays: connected)

        let match = result[0].layouts.first { $0.displayIdentifier == "v4268-m41458-s111" }
        XCTAssertEqual(match?.zones.count, 1, "the exact-identifier layout must keep the slot")
    }

    func testLayoutsForDisconnectedSetupAreLeftAlone() {
        // At home: the work monitors' layouts must survive untouched.
        let homeLayout = layout("v7252-m9995-s7541", name: "G27QC")
        let workLayout = layout("v7789-m30454-s86787", name: "LG ULTRAWIDE")
        let saved = mode([homeLayout, workLayout])
        let connected = [display("v7252-m9995-s7541", name: "G27QC")]

        let result = DisplayLayoutReconciler.reconcile(modes: [saved], displays: connected)

        XCTAssertEqual(result[0].layouts.count, 2)
        XCTAssertTrue(result[0].layouts.contains { $0.displayIdentifier == "v7789-m30454-s86787" },
                      "layouts for monitors in another physical setup must be preserved")
    }

    func testSameModelDisplaysPairLeftToRightInSavedOrder() {
        let left = layout("v4268-m16700-s111", name: "DELL (1)", zones: 1)
        let right = layout("v4268-m16700-s222", name: "DELL (2)", zones: 2)
        let saved = mode([left, right])
        // Both monitors return with new serials; left-most display takes the
        // first saved layout, right-most the second.
        let connected = [
            display("v4268-m16700-s333", name: "DELL", x: 0),
            display("v4268-m16700-s444", name: "DELL", x: 1920),
        ]

        let result = DisplayLayoutReconciler.reconcile(modes: [saved], displays: connected)

        let leftResult = result[0].layouts.first { $0.displayIdentifier == "v4268-m16700-s333" }
        let rightResult = result[0].layouts.first { $0.displayIdentifier == "v4268-m16700-s444" }
        XCTAssertEqual(leftResult?.zones.count, 1)
        XCTAssertEqual(rightResult?.zones.count, 2)
    }

    func testSurplusDuplicateOrphanIsRemoved() {
        // A monitor reconnected under a new serial and the user reconfigured it,
        // so the mode has both the new layout and the stale orphan.
        let current = layout("v4268-m41458-s111", name: "DELL U3423WE", zones: 2)
        let staleOrphan = layout("v4268-m41458-s999", name: "DELL U3423WE", zones: 1)
        let saved = mode([current, staleOrphan])
        let connected = [display("v4268-m41458-s111", name: "DELL U3423WE")]

        let result = DisplayLayoutReconciler.reconcile(modes: [saved], displays: connected)

        XCTAssertEqual(result[0].layouts.count, 1,
                       "stale duplicate of a connected monitor must be garbage-collected")
        XCTAssertEqual(result[0].layouts[0].displayIdentifier, "v4268-m41458-s111")
        XCTAssertEqual(result[0].layouts[0].zones.count, 2, "the live layout must be the one kept")
    }
}
