import SwiftUI

struct ZonePreview: View {
    let zones: [Zone]
    let accentColor: Color
    var aspectRatio: CGFloat = 16.0 / 9.0

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.black.opacity(0.05))

                ForEach(zones) { zone in
                    let frame = zone.proportionalFrame
                    RoundedRectangle(cornerRadius: 4)
                        .fill(accentColor.opacity(0.15))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(accentColor.opacity(0.5), lineWidth: 1.5)
                        )
                        .overlay(
                            Text(zone.number > 0 ? "\(zone.number)" : "")
                                .font(.title2.bold())
                                .foregroundColor(accentColor)
                        )
                        .frame(
                            width: frame.width * geo.size.width - 4,
                            height: frame.height * geo.size.height - 4
                        )
                        .position(
                            x: (frame.origin.x + frame.width / 2) * geo.size.width,
                            y: (frame.origin.y + frame.height / 2) * geo.size.height
                        )
                }
            }
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
    }
}
