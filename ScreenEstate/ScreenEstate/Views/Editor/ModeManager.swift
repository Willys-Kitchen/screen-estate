import SwiftUI

struct ModeManager: View {
    @Bindable var appState: AppState
    @State private var editingModeID: UUID?
    @State private var editingName: String = ""
    @FocusState private var isNameFieldFocused: Bool

    var body: some View {
        HStack {
            if editingModeID != nil {
                // In-place editable text field replaces the picker while renaming
                HStack(spacing: 4) {
                    Text("Mode")
                        .foregroundColor(.secondary)
                    TextField("Mode name", text: $editingName)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 200)
                        .focused($isNameFieldFocused)
                        .onSubmit { commitRename() }
                        .onChange(of: isNameFieldFocused) { _, focused in
                            if !focused { commitRename() }
                        }
                }
            } else {
                Picker("Mode", selection: $appState.activeModeIndex) {
                    ForEach(Array(appState.modes.enumerated()), id: \.element.id) { index, mode in
                        Text(mode.name).tag(index)
                    }
                }
                .frame(maxWidth: 200)
            }

            Button("Add Mode") {
                let newMode = Mode(id: UUID(), name: "New Mode", layouts: [])
                appState.modes.append(newMode)
                appState.activeModeIndex = appState.modes.count - 1
            }

            if let mode = appState.activeMode {
                if editingModeID == mode.id {
                    Button("Done") { commitRename() }
                } else {
                    Button("Rename") {
                        editingModeID = mode.id
                        editingName = mode.name
                        isNameFieldFocused = true
                    }
                }
            }

            Button("Delete") {
                guard appState.modes.count > 1 else { return }
                appState.modes.remove(at: appState.activeModeIndex)
                appState.activeModeIndex = max(0, appState.activeModeIndex - 1)
            }
            .disabled(appState.modes.count <= 1)
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
