import SwiftUI

struct ModeManager: View {
    @Bindable var appState: AppState
    @State private var editingModeID: UUID?
    @State private var editingName: String = ""

    var body: some View {
        HStack {
            Picker("Mode", selection: $appState.activeModeIndex) {
                ForEach(Array(appState.modes.enumerated()), id: \.element.id) { index, mode in
                    Text(mode.name).tag(index)
                }
            }
            .frame(maxWidth: 200)

            Button("Add Mode") {
                let newMode = Mode(id: UUID(), name: "New Mode", layouts: [])
                appState.modes.append(newMode)
                appState.activeModeIndex = appState.modes.count - 1
            }

            if let mode = appState.activeMode {
                if editingModeID == mode.id {
                    TextField("Name", text: $editingName, onCommit: {
                        appState.modes[appState.activeModeIndex].name = editingName
                        editingModeID = nil
                    })
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 150)
                } else {
                    Button("Rename") {
                        editingModeID = mode.id
                        editingName = mode.name
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
}
