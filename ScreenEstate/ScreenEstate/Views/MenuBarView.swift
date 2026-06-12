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

        Group {
            Button("Copy Debug Info") {
                copyDebugInfo()
            }
            Text("Screen Estate v\(appVersion)\(WindowManipulationService.checkAccessibility() ? "" : " — Accessibility not granted")")
                .font(.caption)
                .foregroundColor(.secondary)

            Divider()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }

    /// Everything support needs for a "hotkeys don't work" report, one click.
    private func copyDebugInfo() {
        let displays = NSScreen.screens
            .map { "\($0.localizedName): frame \($0.frame), visible \($0.visibleFrame)" }
            .joined(separator: "\n  ")
        let info = """
        Screen Estate \(appVersion)
        macOS \(ProcessInfo.processInfo.operatingSystemVersionString)
        Accessibility granted: \(WindowManipulationService.checkAccessibility())
        Enabled: \(appState.settings.isEnabled), drag snap: \(appState.settings.isDragSnapEnabled)
        Modifier: \(appState.settings.modifierKey.displayString)
        Active mode: \(appState.activeMode?.name ?? "none") of \(appState.modes.count) mode(s)
        Displays:
          \(displays)
        """
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(info, forType: .string)
    }
}
