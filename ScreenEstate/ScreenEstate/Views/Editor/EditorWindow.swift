import SwiftUI

struct EditorWindow: View {
    @Bindable var appState: AppState
    let displayService: DisplayService
    let persistence: PersistenceService

    @Environment(\.dismiss) private var dismiss

    @State private var selectedDisplayIndex: Int = 0
    @State private var selectedTab: EditorTab = .presets
    @State private var isEditingZoneOrder: Bool = false

    // Dirty tracking — snapshot taken when the window appears
    @State private var savedModes: [Mode] = []
    @State private var savedSettings: AppSettings = .defaultSettings
    @State private var showSavedConfirmation = false

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

    // MARK: - Split Preview Section
    private var currentDisplayName: String {
        guard selectedDisplayIndex < displays.count else { return "Unknown" }
        return displays[selectedDisplayIndex].name
    }

    @ViewBuilder
    private func splitPreviewSection(height: CGFloat) -> some View {
        let previewBoxHeight = max(100, height - 80) // Account for headers and controls
        VStack(spacing: DesignTokens.space2) {
            // Header with unsaved indicator
            HStack(spacing: DesignTokens.space2) {
                Spacer()
                if hasChanges {
                    HStack(spacing: DesignTokens.space1) {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 6, height: 6)
                        Text("Unsaved")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.orange)
                    }
                    .padding(.horizontal, DesignTokens.space2)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(Color.orange.opacity(0.12))
                    )
                }
            }
            .padding(.horizontal, DesignTokens.space4)

            // Split preview: Left = Current Monitor, Right = All Monitors
            HStack(alignment: .top, spacing: DesignTokens.space3) {
                // Left panel: Current monitor detail
                VStack(alignment: .leading, spacing: DesignTokens.space2) {
                    // Header row with label and monitor picker - fixed height
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Typography.label("Current Monitor")
                            // Monitor picker dropdown
                            Menu {
                                ForEach(Array(displays.enumerated()), id: \.element.identifier) { index, display in
                                    Button {
                                        selectedDisplayIndex = index
                                    } label: {
                                        HStack {
                                            Text(display.name)
                                            if index == selectedDisplayIndex {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            } label: {
                                Text(currentDisplayName)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(AppColors.textSecondary)
                            }
                            .menuStyle(.borderlessButton)
                            .fixedSize()
                        }
                        Spacer()
                    }
                    .frame(height: 36) // Fixed header height to match right panel

                    // Zone preview container
                    ZStack {
                        RoundedRectangle(cornerRadius: DesignTokens.radiusMedium)
                            .fill(AppColors.backgroundElevated)
                            .overlay(
                                RoundedRectangle(cornerRadius: DesignTokens.radiusMedium)
                                    .strokeBorder(AppColors.borderSubtle, lineWidth: DesignTokens.borderThin)
                            )

                        ZonePreview(
                            zones: currentZonesBinding.wrappedValue,
                            accentColor: accentColor,
                            aspectRatio: currentDisplayAspectRatio
                        )
                        .padding(DesignTokens.space3)
                    }
                    .frame(height: previewBoxHeight)
                }
                .frame(maxWidth: .infinity)

                // Right panel: All monitors with zone numbers
                VStack(alignment: .leading, spacing: DesignTokens.space2) {
                    // Header row - same fixed height as left panel
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Typography.label("All Monitors")
                            Text(isEditingZoneOrder ? "Click a zone then input a number to assign" : "Click monitor to select")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(AppColors.textSecondary)
                        }
                        Spacer()
                        Button {
                            isEditingZoneOrder.toggle()
                        } label: {
                            HStack(spacing: DesignTokens.space1) {
                                Image(systemName: isEditingZoneOrder ? "checkmark" : "pencil")
                                    .font(.system(size: 10, weight: .medium))
                                Text(isEditingZoneOrder ? "Done" : "Zone Order")
                                    .font(.system(size: 10, weight: .medium))
                            }
                        }
                        .buttonStyle(PillButtonStyle(
                            variant: isEditingZoneOrder ? .primary : .secondary,
                            accentColor: accentColor
                        ))
                        .help(isEditingZoneOrder ? "Done editing zone numbers" : "Edit zone numbers")
                    }
                    .frame(height: 36) // Fixed header height

                    // Multi-monitor overview container
                    ZStack {
                        RoundedRectangle(cornerRadius: DesignTokens.radiusMedium)
                            .fill(AppColors.backgroundElevated)
                            .overlay(
                                RoundedRectangle(cornerRadius: DesignTokens.radiusMedium)
                                    .strokeBorder(
                                        isEditingZoneOrder ? accentColor.opacity(0.4) : AppColors.borderSubtle,
                                        lineWidth: DesignTokens.borderThin
                                    )
                            )

                        MultiMonitorOverview(
                            displays: displays,
                            mode: appState.activeMode!,
                            accentColor: accentColor,
                            selectedDisplayIndex: $selectedDisplayIndex,
                            isEditing: isEditingZoneOrder,
                            onZoneAssignment: { zoneID, number in
                                handleZoneAssignment(zoneID: zoneID, number: number)
                            }
                        )
                    }
                    .frame(height: previewBoxHeight)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, DesignTokens.space4)

            // Zone order editing controls (only when editing)
            if isEditingZoneOrder {
                HStack(spacing: DesignTokens.space2) {
                    Spacer()

                    Button {
                        autoFillZones(order: .leftToRight)
                    } label: {
                        Label("Fill", systemImage: "arrow.right")
                    }
                    .buttonStyle(PillButtonStyle(variant: .secondary, accentColor: accentColor))
                    .help("Auto-fill zones left to right")

                    Button {
                        autoFillZones(order: .topToBottom)
                    } label: {
                        Label("Fill", systemImage: "arrow.down")
                    }
                    .buttonStyle(PillButtonStyle(variant: .secondary, accentColor: accentColor))
                    .help("Auto-fill zones top to bottom")

                    Button("Clear") {
                        clearAllZoneNumbers()
                    }
                    .buttonStyle(PillButtonStyle(variant: .ghost, accentColor: accentColor))
                    .help("Clear all zone numbers")
                }
                .padding(.horizontal, DesignTokens.space4)
            }
        }
        .padding(.vertical, DesignTokens.space2)
    }

    var body: some View {
        GeometryReader { geo in
            let previewHeight = max(200, (geo.size.height - 150) * 0.55) // Preview takes ~55% of available space

            VStack(spacing: 0) {
                // Mode manager
                ModeManager(appState: appState)
                    .padding()

                Divider()

                // Split preview section (always visible except Settings)
                if selectedTab != .settings {
                    splitPreviewSection(height: previewHeight)
                }

                // Tab selector
                RefinedTabBar(selection: $selectedTab, accentColor: accentColor)
                    .padding(.horizontal, DesignTokens.space4)
                    .padding(.top, DesignTokens.space3)

                // Content
                Group {
                    switch selectedTab {
                    case .presets:
                        PresetsTab(zones: currentZonesBinding, accentColor: accentColor, aspectRatio: currentDisplayAspectRatio)
                    case .grid:
                        GridTab(zones: currentZonesBinding, accentColor: accentColor, aspectRatio: currentDisplayAspectRatio, rows: 1, columns: 1)
                    case .settings:
                        SettingsView(appState: appState)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            RefinedDivider()

            HStack(spacing: DesignTokens.space3) {
                Button {
                    resetConfig()
                } label: {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                }
                .keyboardShortcut("z", modifiers: [.command, .shift])
                .buttonStyle(PillButtonStyle(variant: .ghost, accentColor: accentColor, isDisabled: !hasChanges))
                .disabled(!hasChanges)

                Spacer()

                if showSavedConfirmation {
                    HStack(spacing: DesignTokens.space1) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Saved")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.green)
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            withAnimation(.easeOut(duration: DesignTokens.durationNormal)) {
                                showSavedConfirmation = false
                            }
                        }
                    }
                }

                Button("Save") {
                    saveConfig()
                }
                .keyboardShortcut("s", modifiers: .command)
                .buttonStyle(PillButtonStyle(variant: .secondary, accentColor: accentColor, isDisabled: !hasChanges))
                .disabled(!hasChanges)

                Button("Save + Close") {
                    saveConfig()
                    NSApp.keyWindow?.close()
                }
                .keyboardShortcut(.return, modifiers: [])
                .buttonStyle(PillButtonStyle(variant: .primary, accentColor: accentColor, isDisabled: !hasChanges))
                .disabled(!hasChanges)
            }
            .padding(.horizontal, DesignTokens.space4)
            .padding(.vertical, DesignTokens.space3)
            }
        }
        .frame(minWidth: 600, minHeight: 500)
        .onAppear {
            savedModes = appState.modes
            savedSettings = appState.settings
        }
    }

    private func resetConfig() {
        appState.modes = savedModes
        appState.settings = savedSettings
    }

    private func saveConfig() {
        do {
            try persistence.save(appState.modes, to: .modes)
            try persistence.save(appState.settings, to: .settings)
            // Update snapshot so buttons disable again after save
            savedModes = appState.modes
            savedSettings = appState.settings
            withAnimation { showSavedConfirmation = true }
        } catch {
            NSLog("Screen Estate: Failed to save config: \(error)")
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

    private func handleZoneAssignment(zoneID: UUID, number: Int?) {
        // Initialize assignments if nil (switching from auto to manual mode)
        if appState.modes[appState.activeModeIndex].globalZoneAssignments == nil {
            appState.modes[appState.activeModeIndex].globalZoneAssignments = [:]
        }

        let zoneKey = zoneID.uuidString

        if let number = number {
            // Remove this number from any other zone first (no duplicates)
            appState.modes[appState.activeModeIndex].globalZoneAssignments = appState.modes[appState.activeModeIndex].globalZoneAssignments?.filter { $0.value != number }

            // Assign the number to this zone
            appState.modes[appState.activeModeIndex].globalZoneAssignments?[zoneKey] = number
        } else {
            // Clear assignment for this zone
            appState.modes[appState.activeModeIndex].globalZoneAssignments?.removeValue(forKey: zoneKey)
        }
    }

    private func autoFillZones(order: GlobalZoneHelper.FillOrder) {
        let currentAssignments = appState.modes[appState.activeModeIndex].globalZoneAssignments
        let mode = appState.modes[appState.activeModeIndex]
        let filledAssignments = GlobalZoneHelper.autoFillAssignments(
            currentAssignments: currentAssignments,
            displays: displays,
            mode: mode,
            order: order
        )
        appState.modes[appState.activeModeIndex].globalZoneAssignments = filledAssignments
    }

    private func clearZoneAssignments() {
        appState.modes[appState.activeModeIndex].globalZoneAssignments = nil
    }

    private func clearAllZoneNumbers() {
        // Set to empty dictionary - manual mode with no assignments (no numbers shown)
        appState.modes[appState.activeModeIndex].globalZoneAssignments = [:]
    }
}
