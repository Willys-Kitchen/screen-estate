import SwiftUI

struct MonitorSelector: View {
    let displays: [DisplayInfo]
    @Binding var selectedDisplayIndex: Int

    var body: some View {
        Picker("Monitor", selection: $selectedDisplayIndex) {
            ForEach(Array(displays.enumerated()), id: \.offset) { index, display in
                Text(display.name).tag(index)
            }
        }
        .pickerStyle(.segmented)
    }
}
