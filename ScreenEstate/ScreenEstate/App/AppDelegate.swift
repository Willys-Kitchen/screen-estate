import AppKit

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var snappingEngine: SnappingEngine?
    var hotkeyService: HotkeyService?
    var appState: AppState?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if !WindowManipulationService.checkAccessibility(prompt: true) {
            NSLog("Screen Estate: Accessibility permission not granted.")
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
            startServices(appState: state)
        }
    }

    private func startServices(appState: AppState) {
        guard snappingEngine == nil else { return } // Already started

        let engine = SnappingEngine(appState: appState)
        let overlayManager = OverlayManager()
        let hotkeys = HotkeyService(appState: appState, snappingEngine: engine, overlayManager: overlayManager)

        engine.start()
        hotkeys.start()

        self.snappingEngine = engine
        self.hotkeyService = hotkeys

        NSLog("Screen Estate: Services started. Snapping engine and hotkeys active.")
    }

    func stopServices() {
        snappingEngine?.stop()
        hotkeyService?.stop()
        snappingEngine = nil
        hotkeyService = nil
    }
}
