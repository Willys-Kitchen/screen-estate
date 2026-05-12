import AppKit
import Carbon.HIToolbox

@MainActor
class HotkeyService {
    private var appState: AppState
    private var snappingEngine: SnappingEngine
    private var overlayManager: OverlayManager
    private var monitor: Any?

    init(appState: AppState, snappingEngine: SnappingEngine, overlayManager: OverlayManager) {
        self.appState = appState
        self.snappingEngine = snappingEngine
        self.overlayManager = overlayManager
    }

    func start() {
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            Task { @MainActor in
                self?.handleKeyDown(event)
            }
        }
    }

    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }

    // Key codes for 0–9 on the number row (layout-independent)
    private static let digitKeyCodes: [Int: Int] = [
        kVK_ANSI_1: 1, kVK_ANSI_2: 2, kVK_ANSI_3: 3, kVK_ANSI_4: 4, kVK_ANSI_5: 5,
        kVK_ANSI_6: 6, kVK_ANSI_7: 7, kVK_ANSI_8: 8, kVK_ANSI_9: 9, kVK_ANSI_0: 0,
    ]

    private func handleKeyDown(_ event: NSEvent) {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard modifiers.contains(appState.modifierKey.eventFlags) else { return }

        if let digit = Self.digitKeyCodes[Int(event.keyCode)] {
            if digit >= 1 && digit <= 9 {
                snappingEngine.snapFocusedWindowToZone(number: digit)
            } else if digit == 0 {
                appState.cycleMode()
                if let screen = NSScreen.main {
                    overlayManager.flashModeName(appState.activeMode?.name ?? "", on: screen)
                }
            }
        }
    }
}
