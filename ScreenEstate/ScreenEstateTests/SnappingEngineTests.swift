import XCTest
import SwiftUI
@testable import ScreenEstate

@MainActor
final class SnappingEngineTests: XCTestCase {

    // MARK: - Mocks

    class MockWindowService: WindowManipulating {
        var focusedWindow: AXUIElement?
        var callLog: [String] = []
        var setFrameResult = true
        var raiseResult = true
        var activateResult = true

        var fullscreenResults: [Bool] = [false]
        private var fullscreenCallCount = 0

        var frameOverride: CGRect?
        private var lastSetFrame: CGRect?

        func getFocusedWindow() -> AXUIElement? {
            callLog.append("getFocusedWindow")
            return focusedWindow
        }

        func isWindowValid(_ window: AXUIElement) -> Bool {
            callLog.append("isWindowValid")
            return true
        }

        func getWindowFrame(_ window: AXUIElement) -> CGRect? {
            callLog.append("getWindowFrame")
            return frameOverride ?? lastSetFrame
        }

        func isFullscreen(_ window: AXUIElement) -> Bool {
            callLog.append("isFullscreen")
            let index = min(fullscreenCallCount, fullscreenResults.count - 1)
            fullscreenCallCount += 1
            return fullscreenResults[index]
        }

        func exitFullscreen(_ window: AXUIElement) -> Bool {
            callLog.append("exitFullscreen")
            return true
        }

        @discardableResult
        func setWindowFrame(_ window: AXUIElement, frame: CGRect) -> Bool {
            callLog.append("setWindowFrame")
            lastSetFrame = frame
            return setFrameResult
        }

        @discardableResult
        func raiseWindow(_ window: AXUIElement) -> Bool {
            callLog.append("raiseWindow")
            return raiseResult
        }

        @discardableResult
        func activateOwningApp(_ window: AXUIElement) -> Bool {
            callLog.append("activateOwningApp")
            return activateResult
        }
    }

    class MockDisplayService: DisplayQuerying {
        var displays: [DisplayInfo] = []

        func connectedDisplays() -> [DisplayInfo] {
            return displays
        }
    }

    class MockOverlayManager: OverlayPresenting {
        func showOverlays(zones: [Zone], for displays: [DisplayInfo], activeZoneID: UUID?, accentColor: Color, globalNumbers: [UUID: Int]?) {}
        func hideOverlays() {}
        func showCurtain(message: String, on display: DisplayInfo, accentColor: Color) {}
        func fadeOutCurtain(duration: TimeInterval) {}
        func flashModeName(_ name: String, on screen: NSScreen) {}
    }

    // MARK: - Tests

    func testHotkeySnapCallsRaiseAndActivateAfterMove() {
        // Arrange
        let mockWindow = MockWindowService()
        let mockDisplay = MockDisplayService()
        let mockOverlay = MockOverlayManager()

        // Create a dummy AXUIElement (we'll use the app's own element for testing)
        let dummyWindow = AXUIElementCreateSystemWide()
        mockWindow.focusedWindow = dummyWindow

        // Set up a display and zone
        let display = DisplayInfo(
            identifier: "test-display",
            name: "Test",
            frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            visibleFrame: CGRect(x: 0, y: 25, width: 1920, height: 1055)
        )
        mockDisplay.displays = [display]

        let zone = Zone(
            id: UUID(),
            number: 1,
            proportionalFrame: CGRect(x: 0, y: 0, width: 1, height: 1)
        )
        let layout = MonitorLayout(
            id: UUID(),
            displayIdentifier: "test-display",
            displayName: "Test Display",
            zones: [zone]
        )
        let mode = Mode(id: UUID(), name: "Test", layouts: [layout])

        let appState = AppState()
        appState.modes = [mode]
        appState.activeModeIndex = 0

        let engine = SnappingEngine(
            appState: appState,
            windowService: mockWindow,
            displayService: mockDisplay,
            overlayManager: mockOverlay
        )

        // Act
        engine.snapFocusedWindowToZone(number: 1)

        // Assert - verify order: setWindowFrame -> raiseWindow -> activateOwningApp
        let relevantCalls = mockWindow.callLog.filter {
            ["setWindowFrame", "raiseWindow", "activateOwningApp"].contains($0)
        }
        XCTAssertEqual(relevantCalls, ["setWindowFrame", "raiseWindow", "activateOwningApp"])
    }

    func testDragSnapCallsRaiseAndActivateAfterMove() {
        // Arrange
        let mockWindow = MockWindowService()
        let mockDisplay = MockDisplayService()
        let mockOverlay = MockOverlayManager()

        let dummyWindow = AXUIElementCreateSystemWide()

        let display = DisplayInfo(
            identifier: "test-display",
            name: "Test",
            frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            visibleFrame: CGRect(x: 0, y: 25, width: 1920, height: 1055)
        )
        mockDisplay.displays = [display]

        let zone = Zone(
            id: UUID(),
            number: 1,
            proportionalFrame: CGRect(x: 0, y: 0, width: 1, height: 1)
        )
        let layout = MonitorLayout(
            id: UUID(),
            displayIdentifier: "test-display",
            displayName: "Test Display",
            zones: [zone]
        )
        let mode = Mode(id: UUID(), name: "Test", layouts: [layout])

        let appState = AppState()
        appState.modes = [mode]
        appState.activeModeIndex = 0

        let engine = SnappingEngine(
            appState: appState,
            windowService: mockWindow,
            displayService: mockDisplay,
            overlayManager: mockOverlay
        )

        // Act - call snapWindow directly (simulates drag-snap path)
        engine.snapWindow(dummyWindow, to: zone)

        // Assert - verify order: setWindowFrame -> raiseWindow -> activateOwningApp
        let relevantCalls = mockWindow.callLog.filter {
            ["setWindowFrame", "raiseWindow", "activateOwningApp"].contains($0)
        }
        XCTAssertEqual(relevantCalls, ["setWindowFrame", "raiseWindow", "activateOwningApp"])
    }

    func testRaiseAndActivateFailuresDoNotTriggerSnapFailed() {
        // Arrange
        let mockWindow = MockWindowService()
        let mockDisplay = MockDisplayService()
        let mockOverlay = MockOverlayManager()

        // Configure mock to fail raise and activate
        mockWindow.raiseResult = false
        mockWindow.activateResult = false

        let dummyWindow = AXUIElementCreateSystemWide()
        mockWindow.focusedWindow = dummyWindow

        let display = DisplayInfo(
            identifier: "test-display",
            name: "Test",
            frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            visibleFrame: CGRect(x: 0, y: 25, width: 1920, height: 1055)
        )
        mockDisplay.displays = [display]

        let zone = Zone(
            id: UUID(),
            number: 1,
            proportionalFrame: CGRect(x: 0, y: 0, width: 1, height: 1)
        )
        let layout = MonitorLayout(
            id: UUID(),
            displayIdentifier: "test-display",
            displayName: "Test Display",
            zones: [zone]
        )
        let mode = Mode(id: UUID(), name: "Test", layouts: [layout])

        let appState = AppState()
        appState.modes = [mode]
        appState.activeModeIndex = 0

        var snapFailedCalled = false
        let engine = SnappingEngine(
            appState: appState,
            windowService: mockWindow,
            displayService: mockDisplay,
            overlayManager: mockOverlay,
            onSnapFailed: { snapFailedCalled = true }
        )

        // Act
        engine.snapFocusedWindowToZone(number: 1)

        // Assert - onSnapFailed should NOT be called even though raise/activate failed
        XCTAssertFalse(snapFailedCalled, "onSnapFailed should not be called when raise/activate fail")
    }

    func testMoveFailureTriggersSnapFailed() {
        // Arrange
        let mockWindow = MockWindowService()
        let mockDisplay = MockDisplayService()
        let mockOverlay = MockOverlayManager()

        // Configure mock to fail setWindowFrame
        mockWindow.setFrameResult = false

        let dummyWindow = AXUIElementCreateSystemWide()
        mockWindow.focusedWindow = dummyWindow

        let display = DisplayInfo(
            identifier: "test-display",
            name: "Test",
            frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            visibleFrame: CGRect(x: 0, y: 25, width: 1920, height: 1055)
        )
        mockDisplay.displays = [display]

        let zone = Zone(
            id: UUID(),
            number: 1,
            proportionalFrame: CGRect(x: 0, y: 0, width: 1, height: 1)
        )
        let layout = MonitorLayout(
            id: UUID(),
            displayIdentifier: "test-display",
            displayName: "Test Display",
            zones: [zone]
        )
        let mode = Mode(id: UUID(), name: "Test", layouts: [layout])

        let appState = AppState()
        appState.modes = [mode]
        appState.activeModeIndex = 0

        var snapFailedCalled = false
        let engine = SnappingEngine(
            appState: appState,
            windowService: mockWindow,
            displayService: mockDisplay,
            overlayManager: mockOverlay,
            onSnapFailed: { snapFailedCalled = true }
        )

        // Act
        engine.snapFocusedWindowToZone(number: 1)

        // Assert - onSnapFailed SHOULD be called when move fails
        XCTAssertTrue(snapFailedCalled, "onSnapFailed should be called when move fails")
    }

    // MARK: - Fullscreen exit

    private func makeFullscreenTestEngine(
        mockWindow: MockWindowService,
        onSnapFailed: (() -> Void)? = nil
    ) -> SnappingEngine {
        let mockDisplay = MockDisplayService()
        let mockOverlay = MockOverlayManager()

        let display = DisplayInfo(
            identifier: "test-display",
            name: "Test",
            frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            visibleFrame: CGRect(x: 0, y: 25, width: 1920, height: 1055)
        )
        mockDisplay.displays = [display]

        let zone = Zone(
            id: UUID(),
            number: 1,
            proportionalFrame: CGRect(x: 0, y: 0, width: 1, height: 1)
        )
        let layout = MonitorLayout(
            id: UUID(),
            displayIdentifier: "test-display",
            displayName: "Test Display",
            zones: [zone]
        )
        let mode = Mode(id: UUID(), name: "Test", layouts: [layout])

        let appState = AppState()
        appState.modes = [mode]
        appState.activeModeIndex = 0

        return SnappingEngine(
            appState: appState,
            windowService: mockWindow,
            displayService: mockDisplay,
            overlayManager: mockOverlay,
            onSnapFailed: onSnapFailed,
            fullscreenQuietWait: 0.05,
            fullscreenVerifyDelay: 0.05,
            curtainFadeDuration: 0.02
        )
    }

    func testFullscreenSnapWaitsQuietlyThenMovesOnceBehindCurtain() {
        // Arrange
        let mockWindow = MockWindowService()
        mockWindow.focusedWindow = AXUIElementCreateSystemWide()
        mockWindow.fullscreenResults = [true, false]

        let engine = makeFullscreenTestEngine(mockWindow: mockWindow)

        // Act
        var movesDuringWait = 0
        let preWait = expectation(description: "mid-wait check")
        engine.snapFocusedWindowToZone(number: 1)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
            movesDuringWait = mockWindow.callLog.filter { $0 == "setWindowFrame" }.count
            preWait.fulfill()
        }
        wait(for: [preWait], timeout: 1.0)

        let done = expectation(description: "snap completes after quiet wait")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { done.fulfill() }
        wait(for: [done], timeout: 1.0)

        // Assert
        XCTAssertEqual(movesDuringWait, 0, "Must NOT move the window during the quiet wait")
        let log = mockWindow.callLog
        guard let exitIdx = log.firstIndex(of: "exitFullscreen"),
              let frameSetIdx = log.firstIndex(of: "setWindowFrame") else {
            return XCTFail("Expected exitFullscreen and setWindowFrame. Log: \(log)")
        }
        XCTAssertLessThan(exitIdx, frameSetIdx, "Must exit fullscreen before snapping")
        XCTAssertEqual(log.filter { $0 == "setWindowFrame" }.count, 1,
                       "Should move exactly once when the window lands. Log: \(log)")
    }

    func testFullscreenVerifyDoesOneCorrectiveMoveWhenNotLanded() {
        // Arrange
        let mockWindow = MockWindowService()
        mockWindow.focusedWindow = AXUIElementCreateSystemWide()
        mockWindow.fullscreenResults = [true, false]
        mockWindow.frameOverride = CGRect(x: -335, y: -1415, width: 1847, height: 1415)

        let engine = makeFullscreenTestEngine(mockWindow: mockWindow)

        // Act
        let done = expectation(description: "snap + verify complete")
        engine.snapFocusedWindowToZone(number: 1)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { done.fulfill() }
        wait(for: [done], timeout: 1.0)

        // Assert
        XCTAssertEqual(mockWindow.callLog.filter { $0 == "setWindowFrame" }.count, 2,
                       "One initial move + one corrective move. Log: \(mockWindow.callLog)")
    }
}
