import AppKit

/// Owns the lifecycle of the runtime services (snapping, hotkeys, display
/// monitoring). Abstracted behind a protocol so the launch/enable logic in
/// `AppDelegate` can be tested without standing up real event taps.
@MainActor
protocol AppServiceController: AnyObject {
    func start()
    func stop()
}

/// Production implementation that wires together the real services.
@MainActor
final class DefaultAppServiceController: AppServiceController {
    private let engine: SnappingEngine
    private let hotkeys: HotkeyService
    private let overlayManager: OverlayManager
    private let displayService: DisplayService
    private let appState: AppState

    init(appState: AppState, onSnapFailed: @escaping () -> Void) {
        let engine = SnappingEngine(appState: appState, onSnapFailed: onSnapFailed)
        let overlayManager = OverlayManager()
        self.engine = engine
        self.overlayManager = overlayManager
        self.hotkeys = HotkeyService(appState: appState, snappingEngine: engine, overlayManager: overlayManager)
        self.displayService = DisplayService()
        self.appState = appState
    }

    func start() {
        engine.start()
        hotkeys.start()
        displayService.startMonitoring { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                // Stale overlays/tracking reference the old display geometry.
                self.engine.displayConfigurationChanged()
                // A monitor may have reconnected under a new identifier —
                // re-key saved layouts so zones keep applying (see
                // DisplayLayoutReconciler).
                let displays = self.displayService.connectedDisplays()
                let reconciled = DisplayLayoutReconciler.reconcile(modes: self.appState.modes, displays: displays)
                if reconciled != self.appState.modes {
                    self.appState.modes = reconciled
                }
            }
        }
    }

    func stop() {
        displayService.stopMonitoring()
        engine.stop()
        hotkeys.stop()
    }
}
