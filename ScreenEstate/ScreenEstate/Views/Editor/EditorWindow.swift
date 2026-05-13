import SwiftUI

struct EditorWindow: View {
    @Bindable var appState: AppState
    let displayService: DisplayService
    let persistence: PersistenceService
    @State private var editor: ModeEditor?

    @Environment(\.dismiss) private var dismiss

    @State private var selectedDisplayIndex: Int = 0
    @State private var selectedTab: EditorTab = .presets
    @State private var isEditingZoneOrder: Bool = false

    @State private var showSavedConfirmation = false
    @State private var showOnboardingBanner = false

    enum EditorTab: String, CaseIterable {
        case presets = "Presets"
        case grid = "Grid"
        case settings = "Settings"
    }

    private var displays: [DisplayInfo] {
        displayService.connectedDisplays()
    }

    private var hasChanges: Bool {
        editor?.hasChanges ?? false
    }

    private var currentZonesBinding: Binding<[Zone]> {
        Binding(
            get: {
                guard selectedDisplayIndex < displays.count else { return [] }
                let displayID = displays[selectedDisplayIndex].identifier
                return editor?.zones(for: displayID) ?? []
            },
            set: { newZones in
                guard selectedDisplayIndex < displays.count else { return }
                let display = displays[selectedDisplayIndex]
                editor?.setZones(newZones, for: display)
            }
        )
    }

    private var accentColor: Color { appState.accentColor }

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
                    VStack(alignment: .leading, spacing: 2) {
                        Typography.label("Current Monitor")
                        // Monitor picker dropdown - offset to align with label (compensate for menu's intrinsic leading padding)
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
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 8, weight: .semibold))
                                    .foregroundColor(AppColors.textTertiary)
                                Text(currentDisplayName)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(AppColors.textSecondary)
                            }
                        }
                        .menuStyle(.borderlessButton)
                        .menuIndicator(.hidden)
                        .fixedSize()
                        .offset(x: -4) // Align with label above
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 36) // Fixed header height to match right panel

                    // Zone preview container - centered with correct aspect ratio
                    HStack {
                        Spacer()
                        ZStack {
                            RoundedRectangle(cornerRadius: DesignTokens.radiusMedium)
                                .fill(AppColors.backgroundElevated)
                                .overlay(
                                    RoundedRectangle(cornerRadius: DesignTokens.radiusMedium)
                                        .strokeBorder(AppColors.borderSubtle, lineWidth: DesignTokens.borderThin)
                                )

                            if currentZonesBinding.wrappedValue.isEmpty {
                                // Empty mode guidance
                                VStack(spacing: DesignTokens.space2) {
                                    Image(systemName: "rectangle.3.group")
                                        .font(.system(size: 28))
                                        .foregroundColor(AppColors.textTertiary)
                                    Text("No zones configured")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(AppColors.textSecondary)
                                    Text("Choose a preset below or draw a custom grid")
                                        .font(.system(size: 11))
                                        .foregroundColor(AppColors.textTertiary)
                                }
                            } else {
                                ZonePreview(
                                    zones: currentZonesBinding.wrappedValue,
                                    accentColor: accentColor,
                                    aspectRatio: currentDisplayAspectRatio,
                                    showNumbers: true
                                )
                                .padding(DesignTokens.space3)
                            }
                        }
                        .aspectRatio(currentDisplayAspectRatio, contentMode: .fit)
                        .frame(maxHeight: previewBoxHeight)
                        Spacer()
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
                            if isEditingZoneOrder {
                                saveConfig()
                                isEditingZoneOrder = false
                            } else {
                                isEditingZoneOrder = true
                            }
                        } label: {
                            HStack(spacing: DesignTokens.space1) {
                                Image(systemName: isEditingZoneOrder ? "checkmark" : "pencil")
                                    .font(.system(size: 10, weight: .medium))
                                Text(isEditingZoneOrder ? "Save" : "Zone Order")
                                    .font(.system(size: 10, weight: .medium))
                            }
                        }
                        .buttonStyle(PillButtonStyle(
                            variant: isEditingZoneOrder ? .primary : .secondary,
                            accentColor: accentColor
                        ))
                        .help(isEditingZoneOrder ? "Save and exit zone editing" : "Edit zone numbers")
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
                // First-run onboarding banner
                if showOnboardingBanner {
                    HStack(spacing: DesignTokens.space2) {
                        Image(systemName: "sparkles")
                            .foregroundColor(accentColor)
                        Text("Quick tip: Press \(appState.settings.modifierKey.displayString)+1-9 to snap windows to zones. Create multiple modes for different workflows, then \(appState.settings.modifierKey.displayString)+0 to cycle.")
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.textSecondary)
                        Spacer()
                        Button {
                            withAnimation(.easeOut(duration: DesignTokens.durationNormal)) {
                                showOnboardingBanner = false
                                appState.settings.hasSeenOnboarding = true
                            }
                        } label: {
                            Text("Got it")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .buttonStyle(PillButtonStyle(variant: .secondary, accentColor: accentColor))
                    }
                    .padding(.horizontal, DesignTokens.space4)
                    .padding(.vertical, DesignTokens.space3)
                    .background(accentColor.opacity(0.08))
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

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
                    isEditingZoneOrder = false
                }
                .keyboardShortcut("s", modifiers: .command)
                .buttonStyle(PillButtonStyle(variant: .secondary, accentColor: accentColor, isDisabled: !hasChanges))
                .disabled(!hasChanges)

                Button("Save + Close") {
                    saveConfig()
                    isEditingZoneOrder = false
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
            // Initialize editor and snapshot current state
            if editor == nil {
                editor = ModeEditor(
                    appState: appState,
                    persistence: persistence,
                    displays: { [displayService] in displayService.connectedDisplays() }
                )
            }
            editor?.snapshotCurrent()
            // Show onboarding banner for first-time users
            if !appState.settings.hasSeenOnboarding {
                showOnboardingBanner = true
            }
        }
    }

    private func resetConfig() {
        editor?.reset()
    }

    private func saveConfig() {
        do {
            try editor?.save()
            withAnimation { showSavedConfirmation = true }
        } catch {
            NSLog("Screen Estate: Failed to save config: \(error)")
        }
    }

    private func handleZoneAssignment(zoneID: UUID, number: Int?) {
        appState.modes[appState.activeModeIndex] = GlobalZoneHelper.assign(
            number: number,
            to: zoneID,
            in: appState.modes[appState.activeModeIndex]
        )
    }

    private func autoFillZones(order: GlobalZoneHelper.FillOrder) {
        let mode = appState.modes[appState.activeModeIndex]
        let filledAssignments = GlobalZoneHelper.autoFillAssignments(
            currentAssignments: mode.globalZoneAssignments,
            displays: displays,
            mode: mode,
            order: order
        )
        appState.modes[appState.activeModeIndex].globalZoneAssignments = filledAssignments
    }

    private func clearZoneAssignments() {
        appState.modes[appState.activeModeIndex] = GlobalZoneHelper.clearAssignments(
            in: appState.modes[appState.activeModeIndex]
        )
    }

    private func clearAllZoneNumbers() {
        appState.modes[appState.activeModeIndex] = GlobalZoneHelper.clearToManualEmpty(
            in: appState.modes[appState.activeModeIndex]
        )
    }
}
