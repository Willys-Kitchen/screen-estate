import SwiftUI

@Observable
class OverlayState {
    var zones: [Zone] = []
    var activeZoneID: UUID?
    var accentColor: Color = .blue
    var globalNumbers: [UUID: Int]? // When set, use these numbers instead of zone.number
}

struct OverlayContentView: View {
    var state: OverlayState

    private func displayNumber(for zone: Zone) -> String {
        if let globalNumbers = state.globalNumbers {
            // Global mode: use global number, blank if not in map (zone 10+)
            if let num = globalNumbers[zone.id] {
                return "\(num)"
            }
            return ""
        }
        // Per-monitor mode: use zone's own number
        return zone.number > 0 ? "\(zone.number)" : ""
    }

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
                            Text(displayNumber(for: zone))
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

struct CurtainView: View {
    let message: String
    let accentColor: Color

    var body: some View {
        ZStack {
            Color(white: 0.12)
            LinearGradient(
                colors: [accentColor.opacity(0.30), accentColor.opacity(0.10)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Text(message)
                .font(.system(size: 38, weight: .semibold))
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.5)
                .lineLimit(3)
                .foregroundColor(.white.opacity(0.9))
                .shadow(color: .black.opacity(0.35), radius: 2)
                .padding(32)
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
