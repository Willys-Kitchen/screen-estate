import AppKit

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var appState: AppState?

    /// Factory for the runtime services. Overridable in tests; defaults to the
    /// real implementation.
    var makeServices: ((AppState) -> AppServiceController)?

    private var services: AppServiceController?
    private var didFinishLaunching = false
    private var lastAccessibilityAlertDate: Date?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if !WindowManipulationService.checkAccessibility(prompt: true) {
            NSLog("Screen Estate: Accessibility permission not granted. Prompting user.")
        }
        adoptSharedState()
        markLaunched()
    }

    /// Pulls in the live app state published by `ScreenEstateApp.init()`. This
    /// is the launch path that starts services even when the app is launched in
    /// the background and the menu is never opened. No-op if state was already
    /// wired in (e.g. via the menu's onAppear backstop).
    func adoptSharedState() {
        guard appState == nil, let shared = AppState.shared else { return }
        setAppState(shared)
    }

    /// Records that the app has launched and starts services if everything is
    /// ready. Separated from `applicationDidFinishLaunching` so it can be driven
    /// in tests without triggering the accessibility prompt.
    func markLaunched() {
        didFinishLaunching = true
        startServicesIfReady()
    }

    func setAppState(_ state: AppState) {
        // Idempotent: App.init() wires this in at launch, and the menu's
        // onAppear may call it again as a backstop.
        guard appState == nil else { return }
        self.appState = state
        observeIsEnabled(state)
        startServicesIfReady()
    }

    private func observeIsEnabled(_ state: AppState) {
        withObservationTracking {
            _ = state.isEnabled
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self, let appState = self.appState else { return }
                if appState.isEnabled {
                    self.startServicesIfReady()
                } else {
                    NSLog("Screen Estate: Disabled by user, stopping services.")
                    self.stopServices()
                }
                self.observeIsEnabled(appState)
            }
        }
    }

    /// Starts services exactly once, when the app has launched and an enabled
    /// app state is available — regardless of which signal arrives last.
    private func startServicesIfReady() {
        guard didFinishLaunching,
              services == nil,
              let appState,
              appState.settings.isEnabled else { return }

        let make = makeServices ?? { [weak self] state in
            DefaultAppServiceController(appState: state) { self?.handleSnapFailed() }
        }
        let svc = make(appState)
        svc.start()
        services = svc

        NSLog("Screen Estate: Services started. Snapping engine and hotkeys active.")
    }

    func stopServices() {
        services?.stop()
        services = nil
    }

    /// Whether the process currently has Accessibility. Injectable for tests.
    var isAccessibilityTrusted: () -> Bool = {
        WindowManipulationService.checkAccessibility(prompt: false)
    }

    /// Presents the Accessibility alert. Injectable for tests; defaults to the
    /// real NSAlert.
    lazy var presentAccessibilityAlert: () -> Void = { [weak self] in
        self?.showAccessibilityAlert()
    }

    func handleSnapFailed() {
        // Only blame permissions when permission is actually the problem; a
        // snap can also fail because the window closed, is non-resizable, or
        // its app is unresponsive.
        guard !isAccessibilityTrusted() else {
            NSLog("Screen Estate: Snap failed but accessibility is granted (window closed, non-resizable, or app unresponsive)")
            return
        }
        // Debounce: only show once per 30 seconds
        if let last = lastAccessibilityAlertDate, Date().timeIntervalSince(last) < 30 {
            return
        }
        lastAccessibilityAlertDate = Date()
        presentAccessibilityAlert()
    }

    private func showAccessibilityAlert() {
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
