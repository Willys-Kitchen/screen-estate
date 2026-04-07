import AppKit

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
    private static let digitKeyCodes: [UInt16: Int] = [
        18: 1, 19: 2, 20: 3, 21: 4, 23: 5,
        22: 6, 26: 7, 28: 8, 25: 9, 29: 0,
    ]

    private func handleKeyDown(_ event: NSEvent) {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard modifiers.contains(appState.settings.modifierKey.eventFlags) else { return }

        if let digit = Self.digitKeyCodes[event.keyCode] {
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
