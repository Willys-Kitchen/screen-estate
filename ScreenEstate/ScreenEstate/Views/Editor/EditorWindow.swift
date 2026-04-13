import SwiftUI
import UserNotifications

struct EditorWindow: View {
    @Bindable var appState: AppState
    let displayService: DisplayService

    @Environment(\.dismiss) private var dismiss

    @State private var selectedDisplayIndex: Int = 0
    @State private var selectedTab: EditorTab = .presets

    // Dirty tracking — snapshot taken when the window appears
    @State private var savedModes: [Mode] = []
    @State private var savedSettings: AppSettings = .defaultSettings

    enum EditorTab: String, CaseIterable {
        case presets = "Presets"
        case grid = "Grid"
        case settings = "Settings"
    }

    private var displays: [DisplayInfo] {
        displayService.connectedDisplays()
    }

    private var hasChanges: Bool {
        appState.modes != savedModes || appState.settings != savedSettings
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

            // Content — wrapped in a ScrollView so tall tab content never
            // pushes the button row off the bottom of the window.
            ScrollView {
                Group {
                    switch selectedTab {
                    case .presets:
                        PresetsTab(zones: currentZonesBinding, accentColor: accentColor, aspectRatio: currentDisplayAspectRatio)
                    case .grid:
                        GridTab(zones: currentZonesBinding, accentColor: accentColor, aspectRatio: currentDisplayAspectRatio, rows: 2, columns: 2)
                    case .settings:
                        SettingsView(appState: appState)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Current layout preview
            if selectedTab != .settings {
                Divider()
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Current Screen Estate")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        if hasChanges {
                            Text("· Unsaved changes")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                    ZonePreview(
                        zones: currentZonesBinding.wrappedValue,
                        accentColor: accentColor,
                        aspectRatio: currentDisplayAspectRatio
                    )
                    .frame(height: 100)
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
            }

            Divider()

            HStack {
                Spacer()
                Button("Save") {
                    saveConfig()
                }
                .keyboardShortcut("s", modifiers: .command)
                .buttonStyle(.bordered)
                .disabled(!hasChanges)
                .padding(.vertical)

                Button("Save + Close") {
                    saveConfig()
                    NSApp.keyWindow?.close()
                }
                .keyboardShortcut(.return, modifiers: [])
                .buttonStyle(.borderedProminent)
                .disabled(!hasChanges)
                .padding(.vertical)
                .padding(.trailing)
            }
        }
        .frame(minWidth: 600, minHeight: 500)
        .onAppear {
            savedModes = appState.modes
            savedSettings = appState.settings
        }
    }

    private func saveConfig() {
        let persistence = PersistenceService()
        do {
            try persistence.save(appState.modes, to: "modes.json")
            try persistence.save(appState.settings, to: "settings.json")
            // Update snapshot so buttons disable again after save
            savedModes = appState.modes
            savedSettings = appState.settings
            sendSaveNotification()
        } catch {
            NSLog("Screen Estate: Failed to save config: \(error)")
        }
    }

    private func sendSaveNotification() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "Screen Estate"
            content.body = "Configuration saved."
            content.sound = .default
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
            center.add(request)
        }
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
