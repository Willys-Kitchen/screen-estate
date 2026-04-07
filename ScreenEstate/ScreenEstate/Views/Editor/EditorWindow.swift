import SwiftUI

struct EditorWindow: View {
    @Bindable var appState: AppState
    let displayService: DisplayService

    @Environment(\.dismiss) private var dismiss

    @State private var selectedDisplayIndex: Int = 0
    @State private var selectedTab: EditorTab = .presets

    enum EditorTab: String, CaseIterable {
        case presets = "Presets"
        case grid = "Grid"
        case settings = "Settings"
    }

    private var displays: [DisplayInfo] {
        displayService.connectedDisplays()
    }

    private var currentZonesBinding: Binding<[Zone]> {
        Binding(
            get: {
                guard let mode = appState.activeMode,
                      selectedDisplayIndex < displays.count else { return [] }
                let displayID = displays[selectedDisplayIndex].identifier
                return mode.layouts.first { $0.displayIdentifier == displayID }?.zones ?? []
            },
            set: { newZones in
                guard selectedDisplayIndex < displays.count else { return }
                let display = displays[selectedDisplayIndex]
                ensureLayoutExists(for: display)
                if let layoutIndex = appState.modes[appState.activeModeIndex].layouts
                    .firstIndex(where: { $0.displayIdentifier == display.identifier }) {
                    appState.modes[appState.activeModeIndex].layouts[layoutIndex].zones = newZones
                }
            }
        )
    }

    private var accentColor: Color {
        let rgba = appState.settings.accentColorRGBA
        return Color(red: rgba.red, green: rgba.green, blue: rgba.blue, opacity: rgba.alpha)
    }

    private var currentDisplayAspectRatio: CGFloat {
        guard selectedDisplayIndex < displays.count else { return 16.0 / 9.0 }
        let frame = displays[selectedDisplayIndex].frame
        guard frame.height > 0 else { return 16.0 / 9.0 }
        return frame.width / frame.height
    }

    var body: some View {
        VStack(spacing: 0) {
            // Mode manager
            ModeManager(appState: appState)
                .padding()

            Divider()

            if selectedTab != .settings {
                // Monitor selector
                if displays.count > 1 {
                    MonitorSelector(displays: displays, selectedDisplayIndex: $selectedDisplayIndex)
                        .padding(.horizontal)
                        .padding(.top, 8)
                }
            }

            // Tab selector
            Picker("", selection: $selectedTab) {
                ForEach(EditorTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 8)

            // Content
            switch selectedTab {
            case .presets:
                PresetsTab(zones: currentZonesBinding, accentColor: accentColor, aspectRatio: currentDisplayAspectRatio)
            case .grid:
                GridTab(zones: currentZonesBinding, accentColor: accentColor, aspectRatio: currentDisplayAspectRatio)
            case .settings:
                SettingsView(appState: appState)
            }

            Divider()

            // Zone preview
            if selectedTab != .settings {
                VStack(alignment: .leading) {
                    Text("Preview")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    ZonePreview(zones: currentZonesBinding.wrappedValue, accentColor: accentColor, aspectRatio: currentDisplayAspectRatio)
                        .frame(height: 120)
                }
                .padding()
            }

            Divider()

            HStack {
                Spacer()
                Button("Done") {
                    NSApp.keyWindow?.close()
                }
                .keyboardShortcut(.return, modifiers: [])
                .buttonStyle(.borderedProminent)
                .padding()
            }
        }
        .frame(minWidth: 600, minHeight: 500)
    }

    private func ensureLayoutExists(for display: DisplayInfo) {
        let layouts = appState.modes[appState.activeModeIndex].layouts
        if !layouts.contains(where: { $0.displayIdentifier == display.identifier }) {
            let newLayout = MonitorLayout(
                id: UUID(),
                displayIdentifier: display.identifier,
                displayName: display.name,
                zones: MonitorLayout.presetsHalves()
            )
            appState.modes[appState.activeModeIndex].layouts.append(newLayout)
        }
    }
}
