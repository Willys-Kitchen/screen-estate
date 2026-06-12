import XCTest
@testable import ScreenEstate

@MainActor
final class AppDelegateTests: XCTestCase {

    // MARK: - Mocks

    final class MockServiceController: AppServiceController {
        var startCount = 0
        var stopCount = 0
        func start() { startCount += 1 }
        func stop() { stopCount += 1 }
    }

    /// Builds an AppDelegate whose services are mocked, and records every
    /// controller it creates so tests can assert on start/stop counts.
    private func makeDelegate() -> (AppDelegate, () -> [MockServiceController]) {
        let delegate = AppDelegate()
        var created: [MockServiceController] = []
        delegate.makeServices = { _ in
            let controller = MockServiceController()
            created.append(controller)
            return controller
        }
        return (delegate, { created })
    }

    private func enabledState() -> AppState {
        let state = AppState()
        state.settings.isEnabled = true
        return state
    }

    override func tearDown() {
        AppState.shared = nil
        super.tearDown()
    }

    // MARK: - Tracer

    func testServicesStartOnLaunchWhenEnabled() {
        let (delegate, created) = makeDelegate()

        delegate.setAppState(enabledState())
        delegate.markLaunched()

        XCTAssertEqual(created().count, 1)
        XCTAssertEqual(created().first?.startCount, 1)
    }

    /// The real launch path: `App.init()` publishes the configured state to
    /// `AppState.shared`, and the delegate pulls it in at launch without ever
    /// touching the `@NSApplicationDelegateAdaptor` from `App.init()`.
    func testServicesStartFromSharedStateAtLaunch() {
        let (delegate, created) = makeDelegate()
        AppState.shared = enabledState()

        delegate.adoptSharedState()
        delegate.markLaunched()

        XCTAssertEqual(created().count, 1)
        XCTAssertEqual(created().first?.startCount, 1)
    }

    /// If state was already wired in (e.g. via the menu's onAppear backstop),
    /// adopting the shared state must not start a second controller.
    func testAdoptingSharedStateIsIgnoredWhenStateAlreadySet() {
        let (delegate, created) = makeDelegate()
        delegate.setAppState(enabledState())
        delegate.markLaunched()
        XCTAssertEqual(created().count, 1)

        AppState.shared = enabledState()
        delegate.adoptSharedState()

        XCTAssertEqual(created().count, 1)
    }

    // MARK: - Launch gate

    func testServicesDoNotStartWhenDisabled() {
        let (delegate, created) = makeDelegate()
        let state = AppState()
        state.settings.isEnabled = false

        delegate.setAppState(state)
        delegate.markLaunched()

        XCTAssertTrue(created().isEmpty)
    }

    func testServicesDoNotStartBeforeLaunch() {
        let (delegate, created) = makeDelegate()

        delegate.setAppState(enabledState())

        // Wired in but the app hasn't finished launching yet.
        XCTAssertTrue(created().isEmpty)
    }

    /// The original bug: the menu's onAppear (setAppState) can arrive *after*
    /// the app has already launched. Services must still start.
    func testServicesStartWhenStateArrivesAfterLaunch() {
        let (delegate, created) = makeDelegate()

        delegate.markLaunched()
        XCTAssertTrue(created().isEmpty)

        delegate.setAppState(enabledState())

        XCTAssertEqual(created().count, 1)
        XCTAssertEqual(created().first?.startCount, 1)
    }

    // MARK: - Idempotency

    func testServicesStartOnlyOnceAcrossRepeatedSignals() {
        let (delegate, created) = makeDelegate()
        let state = enabledState()

        delegate.setAppState(state)
        delegate.setAppState(enabledState()) // backstop onAppear, ignored
        delegate.markLaunched()
        delegate.markLaunched()

        XCTAssertEqual(created().count, 1)
        XCTAssertEqual(created().first?.startCount, 1)
    }

    // MARK: - Enable toggle

    func testTogglingDisabledStopsAndReenablingRestarts() async {
        let (delegate, created) = makeDelegate()
        let state = enabledState()
        delegate.setAppState(state)
        delegate.markLaunched()
        XCTAssertEqual(created().count, 1)

        state.settings.isEnabled = false
        await waitUntil { created().first?.stopCount == 1 }
        XCTAssertEqual(created().first?.stopCount, 1)

        state.settings.isEnabled = true
        await waitUntil { created().count == 2 }
        XCTAssertEqual(created().count, 2)
        XCTAssertEqual(created().last?.startCount, 1)
    }

    // MARK: - Snap failure alert

    func testSnapFailureWithAccessibilityGrantedShowsNoPermissionAlert() {
        let delegate = AppDelegate()
        delegate.isAccessibilityTrusted = { true }
        var alerts = 0
        delegate.presentAccessibilityAlert = { alerts += 1 }

        delegate.handleSnapFailed()

        XCTAssertEqual(alerts, 0,
                       "a snap can fail for non-permission reasons; don't tell the user to grant a permission they have")
    }

    func testSnapFailureWithoutAccessibilityAlertsOnceWithinDebounceWindow() {
        let delegate = AppDelegate()
        delegate.isAccessibilityTrusted = { false }
        var alerts = 0
        delegate.presentAccessibilityAlert = { alerts += 1 }

        delegate.handleSnapFailed()
        delegate.handleSnapFailed()

        XCTAssertEqual(alerts, 1, "repeat failures inside the debounce window must not stack alerts")
    }

    // MARK: - Helpers

    private func waitUntil(timeout: TimeInterval = 1.0, _ condition: () -> Bool) async {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() && Date() < deadline {
            await Task.yield()
        }
    }
}
