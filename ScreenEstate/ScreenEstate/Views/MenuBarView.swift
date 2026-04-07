import SwiftUI

struct MenuBarView: View {
    @Bindable var appState: AppState
    var onOpenEditor: () -> Void

    @Environment(\.openWindow) private var openWindow

    var body: some View {
        if let mode = appState.activeMode {
            Text("Mode: \(mode.name)")
                .font(.headline)
        } else {
            Text("No modes configured")
        }

        Divider()

        if appState.modes.count > 1 {
            ForEach(Array(appState.modes.enumerated()), id: \.element.id) { index, mode in
                Button {
                    appState.activeModeIndex = index
                } label: {
                    if index == appState.activeModeIndex {
                        Text("✓ \(mode.name)")
                    } else {
                        Text("  \(mode.name)")
                    }
                }
            }
            Divider()
        }

        Toggle("Enabled", isOn: $appState.settings.isEnabled)

        Button("Edit Zones...") {
            NSApp.activate(ignoringOtherApps: true)
            openWindow(id: "editor")
            onOpenEditor()
        }

        Button("Test Accessibility...") {
            let service = WindowManipulationService()
            let trusted = WindowManipulationService.checkAccessibility(prompt: false)
            let window = service.getFocusedWindow()
            let alert = NSAlert()
            alert.messageText = "Accessibility Test"
            alert.informativeText = """
            AX Trusted: \(trusted)
            Focused window: \(window != nil ? "FOUND ✓" : "nil ✗")
            """
            alert.runModal()
        }

        Divider()

        Button("Quit") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
