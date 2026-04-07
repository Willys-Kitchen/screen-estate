import SwiftUI

@main
struct ScreenEstateApp: App {
    @State private var appState: AppState
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let persistence: PersistenceService
    private let displayService: DisplayService

    var body: some Scene {
        MenuBarExtra("Screen Estate", systemImage: "rectangle.split.3x3") {
            MenuBarView(appState: appState, onOpenEditor: openEditor)
                .onAppear {
                    appDelegate.setAppState(appState)
                }
        }

        Window("Zone Editor", id: "editor") {
            EditorWindow(appState: appState, displayService: displayService, onSave: save)
        }
        .defaultSize(width: 650, height: 550)
    }

    init() {
        let state = AppState()
        let persistence = PersistenceService()
        let displayService = DisplayService()

        if let modes: [Mode] = try? persistence.load(from: "modes.json"), !modes.isEmpty {
            state.modes = modes
        } else {
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
            try? persistence.save(state.modes, to: "modes.json")
        }

        if let settings: AppSettings = try? persistence.load(from: "settings.json") {
            state.settings = settings
        }

        self._appState = State(initialValue: state)
        self.persistence = persistence
        self.displayService = displayService
    }

    private func save() {
        try? persistence.save(appState.modes, to: "modes.json")
        try? persistence.save(appState.settings, to: "settings.json")
    }

    private func openEditor() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { $0.title == "Zone Editor" }) {
            window.makeKeyAndOrderFront(nil)
        }
    }
}
