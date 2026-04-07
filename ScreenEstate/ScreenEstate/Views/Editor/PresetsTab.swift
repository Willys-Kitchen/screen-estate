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
        VStack(alignment: .leading, spacing: 16) {
            Text("Choose a preset layout")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 12) {
                ForEach(presets) { preset in
                    Button {
                        zones = preset.zones
                    } label: {
                        VStack(spacing: 8) {
                            ZonePreview(zones: preset.zones, accentColor: accentColor, aspectRatio: aspectRatio)
                                .frame(height: 80)
                            Text(preset.name)
                                .font(.caption)
                        }
                        .padding(8)
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
