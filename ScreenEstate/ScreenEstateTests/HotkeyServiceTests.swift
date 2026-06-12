import XCTest
import AppKit
import Carbon.HIToolbox
@testable import ScreenEstate

@MainActor
final class HotkeyServiceTests: XCTestCase {

    private struct Registration: Equatable {
        let keyCode: UInt32
        let modifiers: UInt32
        let id: UInt32
    }

    /// Builds a HotkeyService with fake Carbon registration, so the hotkey
    /// lifecycle can be tested without registering real system hotkeys.
    private func makeService(
        appState: AppState = AppState(),
        failRegistrationFor: Set<UInt32> = []
    ) -> (service: HotkeyService, registrations: () -> [Registration], unregisterCount: () -> Int) {
        let engine = SnappingEngine(appState: appState)
        let service = HotkeyService(
            appState: appState,
            snappingEngine: engine,
            overlayManager: OverlayManager()
        )

        var registrations: [Registration] = []
        var unregisters = 0
        service.registerHotKey = { keyCode, modifiers, id in
            registrations.append(Registration(keyCode: keyCode, modifiers: modifiers, id: id))
            return failRegistrationFor.contains(id) ? nil : OpaquePointer(bitPattern: Int(id) + 1)
        }
        service.unregisterHotKey = { _ in unregisters += 1 }

        return (service, { registrations }, { unregisters })
    }

    // MARK: - Registration

    func testStartRegistersAllTenDigitChordsWithConfiguredModifier() {
        let (service, registrations, _) = makeService()

        service.start()

        let regs = registrations()
        XCTAssertEqual(regs.count, 10, "digits 0-9 must each get a system hotkey")
        XCTAssertEqual(Set(regs.map(\.id)), Set(0...9))
        // Default modifier is ⌃⌥ — registered as Carbon controlKey|optionKey,
        // so the chord is consumed and never reaches the frontmost app.
        let expected = UInt32(controlKey | optionKey)
        XCTAssertTrue(regs.allSatisfy { $0.modifiers == expected },
                      "all chords must use the configured modifier")
        XCTAssertEqual(regs.first { $0.id == 1 }?.keyCode, UInt32(kVK_ANSI_1))
        XCTAssertEqual(regs.first { $0.id == 0 }?.keyCode, UInt32(kVK_ANSI_0))
        XCTAssertTrue(service.isMonitoring)
    }

    func testStopUnregistersEverything() {
        let (service, _, unregisterCount) = makeService()
        service.start()

        service.stop()

        XCTAssertEqual(unregisterCount(), 10)
        XCTAssertFalse(service.isMonitoring)
    }

    func testStartIsIdempotent() {
        let (service, registrations, unregisterCount) = makeService()

        service.start()
        service.start()

        XCTAssertEqual(registrations().count - unregisterCount(), 10,
                       "re-starting must not leave duplicate live registrations")
    }

    func testOneFailedRegistrationDoesNotAbortTheOthers() {
        let (service, registrations, unregisterCount) = makeService(failRegistrationFor: [3])
        service.start()

        XCTAssertEqual(registrations().count, 10, "all ten must be attempted")
        service.stop()
        XCTAssertEqual(unregisterCount(), 9, "only the successful nine are live to unregister")
    }

    // MARK: - Modifier change

    func testChangingModifierReRegistersWithNewFlags() async {
        let appState = AppState()
        let (service, registrations, _) = makeService(appState: appState)
        service.start()
        XCTAssertEqual(registrations().count, 10)

        appState.settings.modifierKey = CustomModifierKey(flags: NSEvent.ModifierFlags.command.rawValue)
        await waitUntil { registrations().count == 20 }

        let newRegs = registrations().suffix(10)
        XCTAssertTrue(newRegs.allSatisfy { $0.modifiers == UInt32(cmdKey) },
                      "chords must follow the recorded modifier")
    }

    // MARK: - Dispatch

    func testHotkeyZeroCyclesTheActiveMode() {
        let appState = AppState()
        appState.modes = [
            Mode(id: UUID(), name: "A", layouts: []),
            Mode(id: UUID(), name: "B", layouts: []),
        ]
        let (service, _, _) = makeService(appState: appState)
        service.start()

        service.handleHotKeyPressed(id: 0)

        XCTAssertEqual(appState.activeModeIndex, 1)
    }

    // MARK: - Helpers

    private func waitUntil(timeout: TimeInterval = 1.0, _ condition: () -> Bool) async {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() && Date() < deadline {
            await Task.yield()
        }
    }
}
