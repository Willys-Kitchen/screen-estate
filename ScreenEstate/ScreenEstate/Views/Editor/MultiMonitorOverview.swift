import SwiftUI

/// Shows all monitors in their physical arrangement with zones overlaid.
/// Used in the editor when Global Zones mode is enabled.
struct MultiMonitorOverview: View {
    let displays: [DisplayInfo]
    let mode: Mode
    let accentColor: Color
    @Binding var selectedDisplayIndex: Int
    let isEditing: Bool
    var onZoneAssignment: ((UUID, Int?) -> Void)?

    @State private var selectedZoneID: UUID?

    var body: some View {
        GeometryReader { geo in
            let layout = computeLayout(in: geo.size)

            ZStack {
                ForEach(Array(layout.monitors.enumerated()), id: \.element.display.identifier) { _, monitor in
                    MonitorView(
                        display: monitor.display,
                        zones: monitor.zones,
                        globalNumbers: monitor.globalNumbers,
                        frame: monitor.frame,
                        isMonitorSelected: monitor.originalIndex == selectedDisplayIndex,
                        selectedZoneID: isEditing ? selectedZoneID : nil,
                        accentColor: accentColor,
                        isEditing: isEditing,
                        onZoneTap: { zoneID in
                            if isEditing {
                                selectedZoneID = zoneID
                            }
                            selectedDisplayIndex = monitor.originalIndex
                        },
                        onMonitorTap: {
                            selectedDisplayIndex = monitor.originalIndex
                            if !isEditing {
                                selectedZoneID = nil
                            }
                        }
                    )
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .focusable(isEditing)
        .onKeyPress { press in
            guard isEditing, let zoneID = selectedZoneID else { return .ignored }

            // Handle number keys 1-9
            if let char = press.characters.first, let num = Int(String(char)), num >= 1 && num <= 9 {
                onZoneAssignment?(zoneID, num)
                return .handled
            }

            // Handle Delete/Backspace to clear assignment
            if press.key == .delete {
                onZoneAssignment?(zoneID, nil)
                return .handled
            }

            return .ignored
        }
        .onChange(of: isEditing) { _, newValue in
            if !newValue {
                selectedZoneID = nil
            }
        }
    }

    private struct MonitorLayoutInfo {
        let display: DisplayInfo
        let zones: [Zone]
        let globalNumbers: [UUID: Int]
        let frame: CGRect // Scaled frame within the view
        let originalIndex: Int // Index in the original unsorted displays array
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

            // Find the original index in the unsorted displays array
            let originalIndex = displays.firstIndex { $0.identifier == display.identifier } ?? 0

            monitors.append(MonitorLayoutInfo(
                display: display,
                zones: zones,
                globalNumbers: globalNumbers,
                frame: scaledFrame,
                originalIndex: originalIndex
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
    let isMonitorSelected: Bool
    let selectedZoneID: UUID?
    let accentColor: Color
    let isEditing: Bool
    let onZoneTap: (UUID) -> Void
    let onMonitorTap: () -> Void

    var body: some View {
        ZStack {
            // Monitor background - tappable to select monitor
            // Button taps on zones take priority over this onTapGesture
            RoundedRectangle(cornerRadius: DesignTokens.radiusMedium)
                .fill(AppColors.backgroundElevated)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.radiusMedium)
                        .strokeBorder(
                            isMonitorSelected ? accentColor.opacity(0.6) : AppColors.borderSubtle,
                            lineWidth: isMonitorSelected ? DesignTokens.borderMedium : DesignTokens.borderThin
                        )
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    onMonitorTap()
                }

            // Zones layer - on top of monitor background
            ZStack {
                ForEach(zones) { zone in
                    ZoneView(
                        zone: zone,
                        globalNumber: globalNumbers[zone.id],
                        containerFrame: frame,
                        isSelected: zone.id == selectedZoneID,
                        accentColor: accentColor,
                        isEditing: isEditing,
                        onTap: {
                            onZoneTap(zone.id)
                        }
                    )
                }
            }
            .frame(width: frame.width, height: frame.height)

            // Monitor name at bottom
            VStack {
                Spacer()
                Text(display.name)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(AppColors.textSecondary)
                    .padding(.horizontal, DesignTokens.space2)
                    .padding(.vertical, 2)
                    .background(AppColors.backgroundElevated.opacity(0.9))
                    .cornerRadius(3)
                    .padding(.bottom, DesignTokens.space2)
            }
            .allowsHitTesting(false)
        }
        .frame(width: frame.width, height: frame.height)
        .position(x: frame.midX, y: frame.midY)
    }
}

private struct ZoneView: View {
    let zone: Zone
    let globalNumber: Int?
    let containerFrame: CGRect
    let isSelected: Bool
    let accentColor: Color
    let isEditing: Bool
    let onTap: () -> Void

    private var zoneFrame: CGRect {
        CGRect(
            x: zone.proportionalFrame.origin.x * containerFrame.width,
            y: zone.proportionalFrame.origin.y * containerFrame.height,
            width: zone.proportionalFrame.width * containerFrame.width,
            height: zone.proportionalFrame.height * containerFrame.height
        )
    }

    private var fontSize: CGFloat {
        min(zoneFrame.width, zoneFrame.height) * 0.35
    }

    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Zone background
                RoundedRectangle(cornerRadius: DesignTokens.radiusSmall)
                    .fill(isSelected ? accentColor.opacity(0.35) : accentColor.opacity(0.15))
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.radiusSmall)
                            .strokeBorder(
                                isSelected ? accentColor : accentColor.opacity(0.4),
                                lineWidth: isSelected ? DesignTokens.borderMedium : DesignTokens.borderThin
                            )
                    )

                // Zone number or placeholder
                if let num = globalNumber {
                    Text("\(num)")
                        .font(.system(size: fontSize, weight: .bold, design: .rounded))
                        .foregroundColor(accentColor)
                } else if isSelected && isEditing {
                    Text("?")
                        .font(.system(size: fontSize, weight: .bold, design: .rounded))
                        .foregroundColor(accentColor.opacity(0.5))
                }
            }
        }
        .buttonStyle(.plain)
        .frame(width: max(zoneFrame.width - 3, 1), height: max(zoneFrame.height - 3, 1))
        .position(
            x: zoneFrame.origin.x + zoneFrame.width / 2,
            y: zoneFrame.origin.y + zoneFrame.height / 2
        )
    }
}
