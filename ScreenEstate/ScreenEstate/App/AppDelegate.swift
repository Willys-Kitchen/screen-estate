import AppKit

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var snappingEngine: SnappingEngine?
    var hotkeyService: HotkeyService?
    var appState: AppState?
    private let displayService = DisplayService()
    private var lastAccessibilityAlertDate: Date?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if !WindowManipulationService.checkAccessibility(prompt: true) {
            NSLog("Screen Estate: Accessibility permission not granted. Prompting user.")
        }

        // Services will be started once appState is set
        if let appState {
            startServices(appState: appState)
        }
    }

    func setAppState(_ state: AppState) {
        self.appState = state
        // If app already launched, start services now
        if NSApp.isRunning {
            if state.settings.isEnabled {
                startServices(appState: state)
            }
        }
        observeIsEnabled(state)
    }

    private func observeIsEnabled(_ state: AppState) {
        withObservationTracking {
            _ = state.settings.isEnabled
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self, let appState = self.appState else { return }
                if appState.settings.isEnabled {
                    self.startServices(appState: appState)
                } else {
                    NSLog("Screen Estate: Disabled by user, stopping services.")
                    self.stopServices()
                }
                self.observeIsEnabled(appState)
            }
        }
    }

    private func startServices(appState: AppState) {
        guard snappingEngine == nil else { return } // Already started

        let engine = SnappingEngine(appState: appState) { [weak self] in
            self?.handleSnapFailed()
        }
        let overlayManager = OverlayManager()
        let hotkeys = HotkeyService(appState: appState, snappingEngine: engine, overlayManager: overlayManager)

        engine.start()
        hotkeys.start()

        self.snappingEngine = engine
        self.hotkeyService = hotkeys

        displayService.startMonitoring { }

        NSLog("Screen Estate: Services started. Snapping engine and hotkeys active.")
    }

    func stopServices() {
        displayService.stopMonitoring()
        snappingEngine?.stop()
        hotkeyService?.stop()
        snappingEngine = nil
        hotkeyService = nil
    }

    private func handleSnapFailed() {
        // Debounce: only show once per 30 seconds
        if let last = lastAccessibilityAlertDate, Date().timeIntervalSince(last) < 30 {
            return
        }
        showAccessibilityAlert()
    }

    private func showAccessibilityAlert() {
        lastAccessibilityAlertDate = Date()
        let alert = NSAlert()
        alert.messageText = "Accessibility Permission Required"
        alert.informativeText = "Screen Estate needs accessibility access to move and resize windows. Please grant permission in System Settings."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Later")

        if alert.runModal() == .alertFirstButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }
    }
}
