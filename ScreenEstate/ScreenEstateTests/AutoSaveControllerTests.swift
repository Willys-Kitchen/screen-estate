import XCTest
import AppKit
@testable import ScreenEstate

@MainActor
final class AutoSaveControllerTests: XCTestCase {
    var tempDir: URL!
    var persistence: PersistenceService!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ScreenEstateTests-\(UUID().uuidString)")
        persistence = PersistenceService(baseDirectory: tempDir)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testFlushSavesPendingEditsImmediately() throws {
        let state = AppState()
        state.modes = [Mode(id: UUID(), name: "Original", layouts: [])]
        let controller = AutoSaveController(appState: state, persistence: persistence)

        state.modes[0].name = "Edited"
        controller.flush()

        let loaded: [Mode] = try persistence.load(from: .modes)
        XCTAssertEqual(loaded[0].name, "Edited",
                       "flush() must persist edits without waiting for the debounce interval")
    }

    func testSavesPendingEditsWhenAppWillTerminate() throws {
        let state = AppState()
        state.modes = [Mode(id: UUID(), name: "Original", layouts: [])]
        let controller = AutoSaveController(appState: state, persistence: persistence)
        defer { _ = controller } // keep alive through the notification

        state.modes[0].name = "Edited"
        NotificationCenter.default.post(name: NSApplication.willTerminateNotification, object: nil)

        let loaded: [Mode] = try persistence.load(from: .modes)
        XCTAssertEqual(loaded[0].name, "Edited",
                       "app termination must persist edits still inside the debounce window")
    }
}
