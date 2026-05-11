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
            Text("Cycle modes: \(appState.settings.modifierKey.displayString)+0")
                .font(.caption)
                .foregroundColor(.secondary)
            Divider()
        }

        Button("Settings and Zone Editor") {
            NSApp.activate(ignoringOtherApps: true)
            openWindow(id: "editor")
            onOpenEditor()
        }

        Divider()

        Toggle("Enabled", isOn: $appState.settings.isEnabled)

        Divider()

        Button("Quit") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
