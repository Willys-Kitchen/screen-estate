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
                PresetOption(name: "Full", zones: MonitorLayout.presetsFull()),
                PresetOption(name: "Halves", zones: MonitorLayout.presetsPortraitHalves()),
                PresetOption(name: "Thirds", zones: MonitorLayout.presetsPortraitThirds()),
                PresetOption(name: "⅔ + ⅓", zones: MonitorLayout.presetsPortraitTwoThirdsOneThird()),
                PresetOption(name: "⅓ + ⅔", zones: MonitorLayout.presetsPortraitOneThirdTwoThirds()),
                PresetOption(name: "Quadrants", zones: MonitorLayout.presetsQuadrants()),
            ]
        } else {
            [
                PresetOption(name: "Full", zones: MonitorLayout.presetsFull()),
                PresetOption(name: "Halves", zones: MonitorLayout.presetsHalves()),
                PresetOption(name: "Thirds", zones: MonitorLayout.presetsThirds()),
                PresetOption(name: "⅔ + ⅓", zones: MonitorLayout.presetsTwoThirdsOneThird()),
                PresetOption(name: "⅓ + ⅔", zones: MonitorLayout.presetsOneThirdTwoThirds()),
                PresetOption(name: "Quadrants", zones: MonitorLayout.presetsQuadrants()),
            ]
        }
    }

    private func isSelected(_ preset: PresetOption) -> Bool {
        // Check if current zones match this preset
        guard zones.count == preset.zones.count else { return false }
        for (z1, z2) in zip(zones.sorted(by: { $0.number < $1.number }),
                           preset.zones.sorted(by: { $0.number < $1.number })) {
            if abs(z1.proportionalFrame.origin.x - z2.proportionalFrame.origin.x) > 0.01 ||
               abs(z1.proportionalFrame.origin.y - z2.proportionalFrame.origin.y) > 0.01 ||
               abs(z1.proportionalFrame.width - z2.proportionalFrame.width) > 0.01 ||
               abs(z1.proportionalFrame.height - z2.proportionalFrame.height) > 0.01 {
                return false
            }
        }
        return true
    }

    var body: some View {
        GeometryReader { geo in
            presetsGrid(in: geo.size)
        }
    }

    private func optimalColumnCount(availableW: CGFloat, availableH: CGFloat, spacing: CGFloat) -> Int {
        let count = presets.count
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
        let pad: CGFloat = DesignTokens.space4
        let spacing: CGFloat = DesignTokens.space3
        let headlineH: CGFloat = 28 + spacing
        let availableW = size.width - pad * 2
        let availableH = size.height - pad * 2 - headlineH
        let numCols = optimalColumnCount(availableW: availableW, availableH: availableH, spacing: spacing)

        return VStack(alignment: .leading, spacing: DesignTokens.space4) {
            SectionHeader("Choose a preset layout")

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
        let selected = isSelected(preset)

        return Button {
            zones = preset.zones
        } label: {
            VStack(spacing: DesignTokens.space2) {
                // Zone preview
                ZonePreview(zones: preset.zones, accentColor: accentColor, aspectRatio: aspectRatio)
                    .aspectRatio(aspectRatio, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.radiusMedium))
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.radiusMedium)
                            .strokeBorder(
                                selected ? accentColor.opacity(0.6) : AppColors.borderSubtle,
                                lineWidth: selected ? DesignTokens.borderMedium : DesignTokens.borderThin
                            )
                    )

                // Label below the preview
                HStack(spacing: DesignTokens.space1) {
                    Text(preset.name)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(selected ? accentColor : AppColors.textSecondary)

                    if selected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(accentColor)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }
}
