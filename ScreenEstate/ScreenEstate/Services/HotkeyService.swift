import AppKit
import Carbon.HIToolbox

@MainActor
class HotkeyService {
    private var appState: AppState
    private var snappingEngine: SnappingEngine
    private var overlayManager: OverlayManager
    private var monitor: Any?
    private var trustPollTimer: Timer?

    /// Whether the process is currently trusted for global key monitoring.
    /// Injectable for tests.
    var isAccessibilityTrusted: () -> Bool = {
        WindowManipulationService.checkAccessibility(prompt: false)
    }

    /// Installs a global key-down monitor and returns an opaque token (or nil).
    /// Injectable so tests can exercise the lifecycle without a real event tap.
    var installKeyDownMonitor: (@escaping (NSEvent) -> Void) -> Any?

    /// Removes a monitor previously returned by `installKeyDownMonitor`.
    var removeKeyDownMonitor: (Any) -> Void

    /// How often to re-check trust while waiting for the user to grant access.
    var trustPollInterval: TimeInterval = 1.0

    init(appState: AppState, snappingEngine: SnappingEngine, overlayManager: OverlayManager) {
        self.appState = appState
        self.snappingEngine = snappingEngine
        self.overlayManager = overlayManager
        self.installKeyDownMonitor = { handler in
            NSEvent.addGlobalMonitorForEvents(matching: .keyDown, handler: handler)
        }
        self.removeKeyDownMonitor = { NSEvent.removeMonitor($0) }
    }

    /// Whether the global key monitor is currently installed.
    var isMonitoring: Bool { monitor != nil }

    /// Whether the service is polling for Accessibility to be granted.
    var isWaitingForTrust: Bool { trustPollTimer != nil }

    func start() {
        installMonitorIfTrusted()
    }

    func stop() {
        stopTrustPolling()
        if let monitor { removeKeyDownMonitor(monitor) }
        monitor = nil
    }

    /// Installs the global key monitor once the process is trusted.
    ///
    /// A global `.keyDown` monitor registered while the app is *untrusted*
    /// silently receives nothing and never recovers — even after the user
    /// grants Accessibility — until it is re-registered. So if we aren't trusted
    /// yet, we defer installation and poll; the monitor comes alive the moment
    /// the user flips the switch, with no app relaunch required.
    func installMonitorIfTrusted() {
        guard monitor == nil else { return }
        guard isAccessibilityTrusted() else {
            startTrustPolling()
            return
        }
        stopTrustPolling()
        monitor = installKeyDownMonitor { [weak self] event in
            Task { @MainActor in
                self?.handleKeyDown(event)
            }
        }
        NSLog("Screen Estate: Hotkey monitor installed (accessibility trusted).")
    }

    /// Re-check trust and install if now ready. Invoked by the poll timer in
    /// production; exposed so tests can drive a tick deterministically.
    func pollTrustForTesting() {
        installMonitorIfTrusted()
    }

    private func startTrustPolling() {
        guard trustPollTimer == nil else { return }
        NSLog("Screen Estate: Accessibility not granted yet; watching to enable hotkeys without relaunch.")
        trustPollTimer = Timer.scheduledTimer(withTimeInterval: trustPollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.installMonitorIfTrusted()
            }
        }
    }

    private func stopTrustPolling() {
        trustPollTimer?.invalidate()
        trustPollTimer = nil
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
