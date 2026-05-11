import SwiftUI

struct ModeManager: View {
    @Bindable var appState: AppState
    @State private var editingModeID: UUID?
    @State private var editingName: String = ""
    @State private var showingModeHelp: Bool = false
    @FocusState private var isNameFieldFocused: Bool

    private var accentColor: Color {
        let rgba = appState.settings.accentColorRGBA
        return Color(red: rgba.red, green: rgba.green, blue: rgba.blue, opacity: rgba.alpha)
    }

    var body: some View {
        HStack(spacing: DesignTokens.space3) {
            // Mode selector group
            HStack(spacing: DesignTokens.space2) {
                if editingModeID != nil {
                    TextField("Mode name", text: $editingName)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, DesignTokens.space2)
                        .padding(.vertical, DesignTokens.space1 + 2)
                        .background(
                            RoundedRectangle(cornerRadius: DesignTokens.radiusSmall)
                                .fill(AppColors.backgroundBase)
                                .overlay(
                                    RoundedRectangle(cornerRadius: DesignTokens.radiusSmall)
                                        .strokeBorder(accentColor.opacity(0.5), lineWidth: DesignTokens.borderMedium)
                                )
                        )
                        .frame(maxWidth: 160)
                        .focused($isNameFieldFocused)
                        .onSubmit { commitRename() }
                        .onChange(of: isNameFieldFocused) { _, focused in
                            if !focused { commitRename() }
                        }
                } else {
                    Menu {
                        ForEach(Array(appState.modes.enumerated()), id: \.element.id) { index, mode in
                            Button {
                                appState.activeModeIndex = index
                            } label: {
                                HStack {
                                    Text(mode.name)
                                    if index == appState.activeModeIndex {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        Text(appState.activeMode?.name ?? "Global")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(AppColors.textPrimary)
                            .padding(.horizontal, DesignTokens.space3)
                            .padding(.vertical, DesignTokens.space2)
                            .background(
                                RoundedRectangle(cornerRadius: DesignTokens.radiusSmall)
                                    .fill(AppColors.backgroundElevated)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: DesignTokens.radiusSmall)
                                            .strokeBorder(AppColors.borderSubtle, lineWidth: DesignTokens.borderThin)
                                    )
                            )
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }
            }

            // Info button (first, for visibility)
            Button {
                showingModeHelp.toggle()
            } label: {
                Image(systemName: "questionmark.circle")
            }
            .buttonStyle(IconButtonStyle(accentColor: accentColor))
            .popover(isPresented: $showingModeHelp, arrowEdge: .bottom) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("About Modes")
                        .font(.headline)
                    Text("Modes let you save different zone layouts for different workflows—one for coding, another for design, etc.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Divider()
                    HStack(spacing: 4) {
                        Text("\(appState.settings.modifierKey.displayString)+0")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.2))
                            .cornerRadius(4)
                        Text("to cycle between modes")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .frame(width: 260)
            }

            // Action buttons
            HStack(spacing: DesignTokens.space1) {
                Button {
                    let newMode = Mode(id: UUID(), name: "New Mode", layouts: [])
                    appState.modes.append(newMode)
                    appState.activeModeIndex = appState.modes.count - 1
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(IconButtonStyle(accentColor: accentColor))
                .help("Add new mode")

                if let mode = appState.activeMode {
                    if editingModeID == mode.id {
                        Button {
                            commitRename()
                        } label: {
                            Image(systemName: "checkmark")
                        }
                        .buttonStyle(IconButtonStyle(isActive: true, accentColor: accentColor))
                    } else {
                        Button {
                            editingModeID = mode.id
                            editingName = mode.name
                            isNameFieldFocused = true
                        } label: {
                            Image(systemName: "pencil")
                        }
                        .buttonStyle(IconButtonStyle(accentColor: accentColor))
                        .help("Rename mode")
                    }
                }

                Button {
                    guard appState.modes.count > 1 else { return }
                    appState.modes.remove(at: appState.activeModeIndex)
                    appState.activeModeIndex = max(0, appState.activeModeIndex - 1)
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(IconButtonStyle(accentColor: accentColor))
                .disabled(appState.modes.count <= 1)
                .opacity(appState.modes.count <= 1 ? 0.4 : 1)
                .help("Delete mode")
            }

            Spacer()
        }
    }

    private func commitRename() {
        guard let id = editingModeID else { return }
        let trimmed = editingName.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty, let index = appState.modes.firstIndex(where: { $0.id == id }) {
            appState.modes[index].name = trimmed
        }
        editingModeID = nil
    }
}
