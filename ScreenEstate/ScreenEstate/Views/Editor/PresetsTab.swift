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

    /// For landscape: derive card height from width. For portrait: derive card width from height.
    private func computeGridLayout(availableW: CGFloat, availableH: CGFloat, spacing: CGFloat) -> (cols: Int, cardW: CGFloat, cardH: CGFloat) {
        let count = presets.count

        if isPortrait {
            // Portrait: start from height constraint, derive width
            // Try increasing row counts until the cards fit horizontally
            for rows in 1...count {
                let cols = Int(ceil(Double(count) / Double(rows)))
                let cardH = (availableH - spacing * CGFloat(rows - 1)) / CGFloat(rows)
                let cardW = cardH * aspectRatio
                let totalW = CGFloat(cols) * cardW + CGFloat(cols - 1) * spacing
                if totalW <= availableW {
                    return (cols, cardW, cardH)
                }
            }
            // Fallback: fit all in one row, constrained by width
            let cardW = (availableW - spacing * CGFloat(count - 1)) / CGFloat(count)
            let cardH = cardW / aspectRatio
            return (count, cardW, cardH)
        } else {
            // Landscape: start from width constraint, derive height
            for cols in 1...count {
                let rows = Int(ceil(Double(count) / Double(cols)))
                let cardW = (availableW - spacing * CGFloat(cols - 1)) / CGFloat(cols)
                let cardH = cardW / aspectRatio
                let totalH = CGFloat(rows) * cardH + CGFloat(rows - 1) * spacing
                if totalH <= availableH {
                    return (cols, cardW, cardH)
                }
            }
            // Fallback
            let cardW = (availableW - spacing * CGFloat(count - 1)) / CGFloat(count)
            let cardH = cardW / aspectRatio
            return (count, cardW, cardH)
        }
    }

    private func presetsGrid(in size: CGSize) -> some View {
        let pad: CGFloat = DesignTokens.space4
        let spacing: CGFloat = DesignTokens.space3
        let headlineH: CGFloat = 28 + spacing
        let availableW = size.width - pad * 2
        let availableH = size.height - pad * 2 - headlineH
        let layout = computeGridLayout(availableW: availableW, availableH: availableH, spacing: spacing)

        return VStack(alignment: .leading, spacing: DesignTokens.space4) {
            SectionHeader("Choose a preset layout")

            LazyVGrid(
                columns: Array(repeating: GridItem(.fixed(layout.cardW), spacing: spacing), count: layout.cols),
                spacing: spacing
            ) {
                ForEach(presets) { preset in
                    presetCard(preset, cardSize: CGSize(width: layout.cardW, height: layout.cardH))
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(pad)
    }

    private func presetCard(_ preset: PresetOption, cardSize: CGSize) -> some View {
        let selected = isSelected(preset)
        // Reserve space for label below preview
        let labelHeight: CGFloat = 20
        let previewHeight = max(cardSize.height - labelHeight - DesignTokens.space2, 20)

        return Button {
            zones = preset.zones
        } label: {
            VStack(spacing: DesignTokens.space2) {
                // Zone preview with fixed size
                ZonePreview(zones: preset.zones, accentColor: accentColor, aspectRatio: aspectRatio)
                    .frame(width: cardSize.width, height: previewHeight)
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
                .frame(height: labelHeight)
            }
        }
        .buttonStyle(.plain)
    }
}
