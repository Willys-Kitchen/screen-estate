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

    init(appState: AppState, onSnapFailed: @escaping () -> Void) {
        let engine = SnappingEngine(appState: appState, onSnapFailed: onSnapFailed)
        let overlayManager = OverlayManager()
        self.engine = engine
        self.overlayManager = overlayManager
        self.hotkeys = HotkeyService(appState: appState, snappingEngine: engine, overlayManager: overlayManager)
        self.displayService = DisplayService()
    }

    func start() {
        engine.start()
        hotkeys.start()
        displayService.startMonitoring { }
    }

    func stop() {
        displayService.stopMonitoring()
        engine.stop()
        hotkeys.stop()
    }
}
