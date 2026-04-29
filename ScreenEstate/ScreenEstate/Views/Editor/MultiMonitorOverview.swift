import SwiftUI

/// Shows all monitors in their physical arrangement with zones overlaid.
/// Used in the editor when Global Zones mode is enabled.
struct MultiMonitorOverview: View {
    let displays: [DisplayInfo]
    let mode: Mode
    let accentColor: Color
    @Binding var selectedDisplayIndex: Int

    var body: some View {
        GeometryReader { geo in
            let layout = computeLayout(in: geo.size)

            ZStack {
                ForEach(Array(layout.monitors.enumerated()), id: \.offset) { index, monitor in
                    MonitorView(
                        display: monitor.display,
                        zones: monitor.zones,
                        globalNumbers: monitor.globalNumbers,
                        frame: monitor.frame,
                        isSelected: index == selectedDisplayIndex,
                        accentColor: accentColor
                    )
                    .onTapGesture {
                        selectedDisplayIndex = index
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    private struct MonitorLayoutInfo {
        let display: DisplayInfo
        let zones: [Zone]
        let globalNumbers: [UUID: Int]
        let frame: CGRect // Scaled frame within the view
    }

    private struct ComputedLayout {
        let monitors: [MonitorLayoutInfo]
    }

    private func computeLayout(in size: CGSize) -> ComputedLayout {
        guard !displays.isEmpty else {
            return ComputedLayout(monitors: [])
        }

        // Sort displays left-to-right, top-to-bottom (same as GlobalZoneHelper)
        let sortedDisplays = displays.sorted { a, b in
            if a.frame.origin.x != b.frame.origin.x {
                return a.frame.origin.x < b.frame.origin.x
            }
            return a.frame.origin.y < b.frame.origin.y
        }

        // Compute bounding box of all displays
        let minX = sortedDisplays.map { $0.frame.origin.x }.min() ?? 0
        let minY = sortedDisplays.map { $0.frame.origin.y }.min() ?? 0
        let maxX = sortedDisplays.map { $0.frame.maxX }.max() ?? 0
        let maxY = sortedDisplays.map { $0.frame.maxY }.max() ?? 0
        let totalWidth = maxX - minX
        let totalHeight = maxY - minY

        guard totalWidth > 0 && totalHeight > 0 else {
            return ComputedLayout(monitors: [])
        }

        // Scale to fit within view with padding
        let padding: CGFloat = 20
        let availableWidth = size.width - padding * 2
        let availableHeight = size.height - padding * 2
        let scale = min(availableWidth / totalWidth, availableHeight / totalHeight)

        // Center the layout
        let scaledTotalWidth = totalWidth * scale
        let scaledTotalHeight = totalHeight * scale
        let offsetX = padding + (availableWidth - scaledTotalWidth) / 2
        let offsetY = padding + (availableHeight - scaledTotalHeight) / 2

        // Compute global zone numbers
        let globalZones = GlobalZoneHelper.computeGlobalZones(displays: displays, mode: mode)

        var monitors: [MonitorLayoutInfo] = []

        for (index, display) in sortedDisplays.enumerated() {
            // Map display frame to view coordinates
            // Note: macOS Y=0 is at bottom, SwiftUI Y=0 is at top, so we flip Y
            let relativeX = display.frame.origin.x - minX
            let relativeY = maxY - display.frame.maxY  // Flip Y axis
            let scaledFrame = CGRect(
                x: offsetX + relativeX * scale,
                y: offsetY + relativeY * scale,
                width: display.frame.width * scale,
                height: display.frame.height * scale
            )

            let zones = mode.layouts.first { $0.displayIdentifier == display.identifier }?.zones ?? []
            let globalNumbers = Dictionary(uniqueKeysWithValues: globalZones
                .filter { $0.displayIdentifier == display.identifier }
                .compactMap { gz in gz.globalNumber.map { (gz.zone.id, $0) } }
            )

            monitors.append(MonitorLayoutInfo(
                display: display,
                zones: zones,
                globalNumbers: globalNumbers,
                frame: scaledFrame
            ))

            // Update selected index to match sorted order
            if index < displays.count && displays[selectedDisplayIndex].identifier == display.identifier {
                // Keep selection on the same display
            }
        }

        return ComputedLayout(monitors: monitors)
    }
}

private struct MonitorView: View {
    let display: DisplayInfo
    let zones: [Zone]
    let globalNumbers: [UUID: Int]
    let frame: CGRect
    let isSelected: Bool
    let accentColor: Color

    var body: some View {
        ZStack {
            // Monitor background
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(nsColor: .controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isSelected ? accentColor : Color.gray.opacity(0.5), lineWidth: isSelected ? 2 : 1)
                )

            // Zones
            GeometryReader { _ in
                ForEach(zones) { zone in
                    let zoneFrame = CGRect(
                        x: zone.proportionalFrame.origin.x * frame.width,
                        y: zone.proportionalFrame.origin.y * frame.height,
                        width: zone.proportionalFrame.width * frame.width,
                        height: zone.proportionalFrame.height * frame.height
                    )

                    ZStack {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(accentColor.opacity(0.2))
                            .overlay(
                                RoundedRectangle(cornerRadius: 2)
                                    .stroke(accentColor.opacity(0.5), lineWidth: 1)
                            )

                        if let num = globalNumbers[zone.id] {
                            Text("\(num)")
                                .font(.system(size: min(zoneFrame.width, zoneFrame.height) * 0.4, weight: .bold))
                                .foregroundColor(accentColor)
                        }
                    }
                    .frame(width: zoneFrame.width - 2, height: zoneFrame.height - 2)
                    .position(
                        x: zoneFrame.origin.x + zoneFrame.width / 2,
                        y: zoneFrame.origin.y + zoneFrame.height / 2
                    )
                }
            }

            // Monitor name
            VStack {
                Spacer()
                Text(display.name)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 2)
            }
        }
        .frame(width: frame.width, height: frame.height)
        .position(x: frame.midX, y: frame.midY)
    }
}
