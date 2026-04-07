import SwiftUI

@Observable
class OverlayState {
    var zones: [Zone] = []
    var activeZoneID: UUID?
    var accentColor: Color = .blue
}

struct OverlayContentView: View {
    var state: OverlayState

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(state.zones) { zone in
                    let isActive = zone.id == state.activeZoneID
                    let frame = zone.proportionalFrame

                    RoundedRectangle(cornerRadius: 8)
                        .fill(isActive ? state.accentColor.opacity(0.3) : Color.gray.opacity(0.15))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isActive ? state.accentColor : Color.gray.opacity(0.4), lineWidth: isActive ? 3 : 1)
                        )
                        .overlay(
                            Text(zone.number > 0 ? "\(zone.number)" : "")
                                .font(.system(size: 48, weight: .bold))
                                .foregroundColor(.white.opacity(0.8))
                                .shadow(color: .black.opacity(0.5), radius: 2)
                        )
                        .frame(
                            width: frame.width * geo.size.width - 8,
                            height: frame.height * geo.size.height - 8
                        )
                        .position(
                            x: (frame.origin.x + frame.width / 2) * geo.size.width,
                            y: (frame.origin.y + frame.height / 2) * geo.size.height
                        )
                }
            }
        }
        .ignoresSafeArea()
    }
}

struct ModeFlashView: View {
    let modeName: String

    var body: some View {
        Text(modeName)
            .font(.system(size: 72, weight: .bold))
            .foregroundColor(.white)
            .shadow(color: .black.opacity(0.6), radius: 4)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()
    }
}
