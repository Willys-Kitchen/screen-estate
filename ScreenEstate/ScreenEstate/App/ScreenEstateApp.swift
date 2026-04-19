import SwiftUI
import ServiceManagement

@MainActor
class AutoSaveController {
    private let appState: AppState
    private let persistence: PersistenceService
    private var pendingSave: DispatchWorkItem?

    init(appState: AppState, persistence: PersistenceService) {
        self.appState = appState
        self.persistence = persistence
        startObserving()
    }

    private func startObserving() {
        withObservationTracking {
            _ = appState.modes
            _ = appState.settings
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.scheduleSave()
                self?.startObserving()
            }
        }
    }

    private func scheduleSave() {
        pendingSave?.cancel()
        let work = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                self?.performSave()
            }
        }
        pendingSave = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: work)
    }

    private func performSave() {
        do {
            try persistence.save(appState.modes, to: .modes)
        } catch {
            NSLog("Screen Estate: Failed to save modes: \(error)")
        }
        do {
            try persistence.save(appState.settings, to: .settings)
        } catch {
            NSLog("Screen Estate: Failed to save settings: \(error)")
        }
    }
}

@main
struct ScreenEstateApp: App {
    @State private var appState: AppState
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let persistence: PersistenceService
    private let displayService: DisplayService
    private let autoSaveController: AutoSaveController

    var body: some Scene {
        MenuBarExtra("Screen Estate", image: "MenuBarIcon") {
            MenuBarView(appState: appState, onOpenEditor: openEditor)
                .onAppear {
                    appDelegate.setAppState(appState)
                }
        }

        Window("Zone Editor", id: "editor") {
            EditorWindow(appState: appState, displayService: displayService, persistence: persistence)
        }
        .defaultSize(width: 650, height: 550)
    }

    init() {
        let state = AppState()
        let persistence = PersistenceService()
        let displayService = DisplayService()

        do {
            let modes: [Mode] = try persistence.load(from: .modes)
            if !modes.isEmpty {
                state.modes = modes
            } else {
                throw NSError(domain: "ScreenEstate", code: 0, userInfo: [NSLocalizedDescriptionKey: "Empty modes file"])
            }
        } catch {
            NSLog("Screen Estate: Failed to load modes, using defaults: \(error)")
            let displays = displayService.connectedDisplays()
            let layouts = displays.map { display in
                MonitorLayout(
                    id: UUID(),
                    displayIdentifier: display.identifier,
                    displayName: display.name,
                    zones: MonitorLayout.presetsHalves()
                )
            }
            let defaultMode = Mode(id: UUID(), name: "Default", layouts: layouts)
            state.modes = [defaultMode]
            do {
                try persistence.save(state.modes, to: .modes)
            } catch {
                NSLog("Screen Estate: Failed to save default modes: \(error)")
            }
        }

        do {
            let settings: AppSettings = try persistence.load(from: .settings)
            state.settings = settings
        } catch {
            NSLog("Screen Estate: Failed to load settings, using defaults: \(error)")
        }

        // Sync login item state
        if state.settings.launchAtLogin {
            try? SMAppService.mainApp.register()
        }

        self._appState = State(initialValue: state)
        self.persistence = persistence
        self.displayService = displayService
        self.autoSaveController = AutoSaveController(appState: state, persistence: persistence)
    }

    private func openEditor() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { $0.title == "Zone Editor" }) {
            window.makeKeyAndOrderFront(nil)
        }
    }
}
