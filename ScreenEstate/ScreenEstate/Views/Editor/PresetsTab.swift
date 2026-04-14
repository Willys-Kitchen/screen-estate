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

    private func optimalColumnCount(availableW: CGFloat, availableH: CGFloat, spacing: CGFloat) -> Int {
        let count = presets.count
        // Walk from 1 column up; pick the fewest columns (most rows) that still fit.
        // Card height is determined purely by aspect ratio so the preview looks correct.
        for cols in 1...count {
            let rows = Int(ceil(Double(count) / Double(cols)))
            let cardW = (availableW - spacing * CGFloat(cols - 1)) / CGFloat(cols)
            let cardH = cardW / aspectRatio
            let totalH = CGFloat(rows) * cardH + CGFloat(rows - 1) * spacing
            if totalH <= availableH {
                return cols
            }
        }
        return count
    }

    private func presetsGrid(in size: CGSize) -> some View {
        let pad: CGFloat = 16
        let spacing: CGFloat = 12
        let headlineH: CGFloat = 28 + spacing  // headline + gap below it
        let availableW = size.width - pad * 2
        let availableH = size.height - pad * 2 - headlineH
        let numCols = optimalColumnCount(availableW: availableW, availableH: availableH, spacing: spacing)

        return VStack(alignment: .leading, spacing: spacing) {
            Text("Choose a preset layout")
                .font(.headline)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: spacing), count: numCols),
                spacing: spacing
            ) {
                ForEach(presets) { preset in
                    presetCard(preset)
                }
            }
        }
        .padding(pad)
    }

    private func presetCard(_ preset: PresetOption) -> some View {
        Button {
            zones = preset.zones
        } label: {
            ZStack(alignment: .bottom) {
                ZonePreview(zones: preset.zones, accentColor: accentColor, aspectRatio: aspectRatio)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Label overlaid at the bottom
                Text(preset.name)
                    .font(.caption)
                    .foregroundColor(.primary)
                    .padding(.vertical, 5)
                    .frame(maxWidth: .infinity)
                    .background(.ultraThinMaterial)
            }
            .aspectRatio(aspectRatio, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.2), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
