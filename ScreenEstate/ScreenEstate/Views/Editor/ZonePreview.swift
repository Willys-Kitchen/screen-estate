import SwiftUI

struct ZonePreview: View {
    let zones: [Zone]
    let accentColor: Color
    var aspectRatio: CGFloat = 16.0 / 9.0
    var showNumbers: Bool = true
    var compactMode: Bool = false

    private let gap: CGFloat = 3

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Subtle background
                RoundedRectangle(cornerRadius: DesignTokens.radiusSmall)
                    .fill(Color.black.opacity(0.08))

                ForEach(zones) { zone in
                    zoneCell(zone: zone, in: geo.size)
                }
            }
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
    }

    private func zoneCell(zone: Zone, in size: CGSize) -> some View {
        let frame = zone.proportionalFrame
        let cellWidth = frame.width * size.width - gap
        let cellHeight = frame.height * size.height - gap
        let fontSize = min(cellWidth, cellHeight) * (compactMode ? 0.3 : 0.28)

        return RoundedRectangle(cornerRadius: DesignTokens.radiusSmall)
            .fill(
                LinearGradient(
                    colors: [
                        accentColor.opacity(0.18),
                        accentColor.opacity(0.08)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.radiusSmall)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                accentColor.opacity(0.5),
                                accentColor.opacity(0.25)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: DesignTokens.borderThin
                    )
            )
            .overlay(
                Group {
                    if showNumbers && zone.number > 0 {
                        Text("\(zone.number)")
                            .font(.system(size: fontSize, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        accentColor.opacity(0.9),
                                        accentColor.opacity(0.6)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
                }
            )
            .frame(width: cellWidth, height: cellHeight)
            .position(
                x: (frame.origin.x + frame.width / 2) * size.width,
                y: (frame.origin.y + frame.height / 2) * size.height
            )
    }
}
