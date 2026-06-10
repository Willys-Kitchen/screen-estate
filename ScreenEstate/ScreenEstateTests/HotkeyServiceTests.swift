import XCTest
import AppKit
@testable import ScreenEstate

@MainActor
final class HotkeyServiceTests: XCTestCase {

    /// Builds a HotkeyService with a controllable trust check and a fake monitor
    /// installer, so the trust-gated lifecycle can be tested without real event
    /// taps or Accessibility permission.
    private func makeService(
        trusted: @escaping () -> Bool
    ) -> (service: HotkeyService, installCount: () -> Int, removeCount: () -> Int) {
        let appState = AppState()
        let engine = SnappingEngine(appState: appState)
        let service = HotkeyService(
            appState: appState,
            snappingEngine: engine,
            overlayManager: OverlayManager()
        )
        service.isAccessibilityTrusted = trusted

        var installs = 0
        var removes = 0
        service.installKeyDownMonitor = { _ in
            installs += 1
            return NSObject() // opaque token
        }
        service.removeKeyDownMonitor = { _ in removes += 1 }

        return (service, { installs }, { removes })
    }

    // MARK: - Trusted at start

    func testInstallsMonitorImmediatelyWhenTrusted() {
        let (service, installCount, _) = makeService(trusted: { true })

        service.start()

        XCTAssertTrue(service.isMonitoring)
        XCTAssertFalse(service.isWaitingForTrust)
        XCTAssertEqual(installCount(), 1)
    }

    // MARK: - Untrusted at start, granted later

    func testDefersMonitorUntilTrustedThenInstallsWithoutRelaunch() {
        var trusted = false
        let (service, installCount, _) = makeService(trusted: { trusted })

        service.start()
        XCTAssertFalse(service.isMonitoring, "must not install a dead monitor while untrusted")
        XCTAssertTrue(service.isWaitingForTrust, "should watch for the grant")
        XCTAssertEqual(installCount(), 0)

        // User grants Accessibility; a poll tick fires.
        trusted = true
        service.pollTrustForTesting()

        XCTAssertTrue(service.isMonitoring)
        XCTAssertFalse(service.isWaitingForTrust, "should stop watching once installed")
        XCTAssertEqual(installCount(), 1)
    }

    func testPollingWhileStillUntrustedDoesNotInstall() {
        let (service, installCount, _) = makeService(trusted: { false })

        service.start()
        service.pollTrustForTesting()
        service.pollTrustForTesting()

        XCTAssertFalse(service.isMonitoring)
        XCTAssertTrue(service.isWaitingForTrust)
        XCTAssertEqual(installCount(), 0)
    }

    // MARK: - Idempotency

    func testDoesNotInstallTwiceWhenAlreadyMonitoring() {
        var trusted = false
        let (service, installCount, _) = makeService(trusted: { trusted })

        service.start()
        trusted = true
        service.pollTrustForTesting()
        service.pollTrustForTesting() // extra tick after install
        service.start()               // redundant start

        XCTAssertEqual(installCount(), 1)
    }

    // MARK: - Stop

    func testStopRemovesMonitorAndStopsWatching() {
        let (service, _, removeCount) = makeService(trusted: { true })
        service.start()

        service.stop()

        XCTAssertFalse(service.isMonitoring)
        XCTAssertFalse(service.isWaitingForTrust)
        XCTAssertEqual(removeCount(), 1)
    }

    func testStopWhileWaitingForTrustStopsWatching() {
        let (service, _, _) = makeService(trusted: { false })
        service.start()
        XCTAssertTrue(service.isWaitingForTrust)

        service.stop()

        XCTAssertFalse(service.isWaitingForTrust)
    }
}
