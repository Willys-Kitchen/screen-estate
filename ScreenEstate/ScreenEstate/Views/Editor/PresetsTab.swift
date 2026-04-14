import SwiftUI

struct PresetOption: Identifiable {
    let id = UUID()
    let name: String
    let zones: [Zone]
}

struct PresetsTab: View {
    @Binding var zones: [Zone]
    let accentColor: Color
    var aspectRatio: CGFloat = 16.0 / 9.0

    private var isPortrait: Bool { aspectRatio < 1.0 }

    private var presets: [PresetOption] {
        if isPortrait {
            [
                PresetOption(name: "Halves", zones: MonitorLayout.presetsPortraitHalves()),
                PresetOption(name: "Thirds", zones: MonitorLayout.presetsPortraitThirds()),
                PresetOption(name: "⅔ + ⅓", zones: MonitorLayout.presetsPortraitTwoThirdsOneThird()),
                PresetOption(name: "⅓ + ⅔", zones: MonitorLayout.presetsPortraitOneThirdTwoThirds()),
                PresetOption(name: "Quadrants", zones: MonitorLayout.presetsQuadrants()),
            ]
        } else {
            [
                PresetOption(name: "Halves", zones: MonitorLayout.presetsHalves()),
                PresetOption(name: "Thirds", zones: MonitorLayout.presetsThirds()),
                PresetOption(name: "⅔ + ⅓", zones: MonitorLayout.presetsTwoThirdsOneThird()),
                PresetOption(name: "⅓ + ⅔", zones: MonitorLayout.presetsOneThirdTwoThirds()),
                PresetOption(name: "Quadrants", zones: MonitorLayout.presetsQuadrants()),
            ]
        }
    }

    var body: some View {
        GeometryReader { geo in
            presetsGrid(in: geo.size)
        }
    }

    private func presetsGrid(in size: CGSize) -> some View {
        let outerPad: CGFloat = 32          // 16 top + 16 bottom
        let headlineH: CGFloat = 28         // headline row
        let cardSpacing: CGFloat = 12
        let numCols = max(1, Int(size.width / 130))
        let numRows = max(1, Int(ceil(Double(presets.count) / Double(numCols))))
        let availableH = size.height - outerPad - headlineH - cardSpacing
        let cardH = (availableH - cardSpacing * CGFloat(numRows - 1)) / CGFloat(numRows)
        // card internals: 8 top pad + ZonePreview + 8 spacing + caption (~16) + 8 bottom pad
        let previewH = max(30, cardH - 16 - 8 - 16)

        return VStack(alignment: .leading, spacing: cardSpacing) {
            Text("Choose a preset layout")
                .font(.headline)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: cardSpacing), count: numCols),
                spacing: cardSpacing
            ) {
                ForEach(presets) { preset in
                    Button {
                        zones = preset.zones
                    } label: {
                        VStack(spacing: 8) {
                            ZonePreview(zones: preset.zones, accentColor: accentColor, aspectRatio: aspectRatio)
                                .frame(height: previewH)
                            Text(preset.name)
                                .font(.caption)
                        }
                        .padding(8)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.1))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
    }
}
