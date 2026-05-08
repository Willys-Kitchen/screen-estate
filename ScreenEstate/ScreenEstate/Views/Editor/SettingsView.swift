import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @Bindable var appState: AppState

    private var accentColor: Color {
        let rgba = appState.settings.accentColorRGBA
        return Color(red: rgba.red, green: rgba.green, blue: rgba.blue, opacity: rgba.alpha)
    }

    private var accentColorBinding: Binding<Color> {
        Binding(
            get: {
                let rgba = appState.settings.accentColorRGBA
                return Color(red: rgba.red, green: rgba.green, blue: rgba.blue, opacity: rgba.alpha)
            },
            set: { newColor in
                guard let nsColor = NSColor(newColor).usingColorSpace(.sRGB) else { return }
                appState.settings.accentColorRGBA = RGBA(
                    red: Double(nsColor.redComponent),
                    green: Double(nsColor.greenComponent),
                    blue: Double(nsColor.blueComponent),
                    alpha: Double(nsColor.alphaComponent)
                )
            }
        )
    }

    @ViewBuilder
    private func modifierToggle(_ label: String, isOn: Bool, flag: NSEvent.ModifierFlags) -> some View {
        Toggle(label, isOn: Binding(
            get: { isOn },
            set: { enabled in
                var current = appState.settings.modifierKey.eventFlags
                if enabled {
                    current.insert(flag)
                } else {
                    current.remove(flag)
                }
                // Require at least one modifier
                if !current.isEmpty {
                    appState.settings.modifierKey = CustomModifierKey(flags: current.rawValue)
                }
            }
        ))
    }

    var body: some View {
        Form {
            Section("General") {
                Toggle("Launch at Login", isOn: $appState.settings.launchAtLogin)
                    .onChange(of: appState.settings.launchAtLogin) { _, enabled in
                        do {
                            if enabled {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                        } catch {
                            NSLog("Screen Estate: Failed to update login item: \(error)")
                        }
                    }
            }

            Section("Appearance") {
                ColorPicker("Accent Color", selection: accentColorBinding)
            }

            Section("Modifier Key") {
                modifierToggle("⌃  Control",
                    isOn: appState.settings.modifierKey.control,
                    flag: .control)
                modifierToggle("⌥  Option",
                    isOn: appState.settings.modifierKey.option,
                    flag: .option)
                modifierToggle("⇧  Shift",
                    isOn: appState.settings.modifierKey.shift,
                    flag: .shift)
                modifierToggle("⌘  Command",
                    isOn: appState.settings.modifierKey.command,
                    flag: .command)
                Text("At least one modifier must be selected")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Shortcuts") {
                LabeledContent("Snap to zone") {
                    Text("\(appState.settings.modifierKey.displayString) + 1 … 9")
                        .foregroundColor(.secondary)
                }
                LabeledContent("Cycle mode") {
                    Text("\(appState.settings.modifierKey.displayString) + 0")
                        .foregroundColor(.secondary)
                }
            }

            Section("Drag to Snap") {
                Toggle("Enable Shift + drag to snap", isOn: $appState.settings.isDragSnapEnabled)
                Text("Hold Shift while dragging a window to snap it to the highlighted zone")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 400)
        .tint(accentColor)
    }
}
