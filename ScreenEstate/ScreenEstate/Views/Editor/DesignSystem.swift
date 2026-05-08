import SwiftUI

// MARK: - Design Tokens

enum DesignTokens {
    // Spacing scale (4px base unit)
    static let space1: CGFloat = 4
    static let space2: CGFloat = 8
    static let space3: CGFloat = 12
    static let space4: CGFloat = 16
    static let space5: CGFloat = 20
    static let space6: CGFloat = 24
    static let space7: CGFloat = 32
    static let space8: CGFloat = 40

    // Corner radii
    static let radiusSmall: CGFloat = 4
    static let radiusMedium: CGFloat = 8
    static let radiusLarge: CGFloat = 12

    // Border widths
    static let borderThin: CGFloat = 0.5
    static let borderMedium: CGFloat = 1
    static let borderThick: CGFloat = 2

    // Shadows
    static let shadowSubtle = ShadowStyle(color: .black.opacity(0.08), radius: 2, y: 1)
    static let shadowMedium = ShadowStyle(color: .black.opacity(0.12), radius: 8, y: 2)
    static let shadowElevated = ShadowStyle(color: .black.opacity(0.18), radius: 16, y: 4)

    // Animation durations
    static let durationFast: Double = 0.12
    static let durationNormal: Double = 0.2
    static let durationSlow: Double = 0.35
}

struct ShadowStyle {
    let color: Color
    let radius: CGFloat
    let y: CGFloat

    func apply(to view: some View) -> some View {
        view.shadow(color: color, radius: radius, x: 0, y: y)
    }
}

// MARK: - Color Palette

struct AppColors {
    let accentColor: Color

    // Semantic colors derived from accent
    var accentSubtle: Color { accentColor.opacity(0.08) }
    var accentLight: Color { accentColor.opacity(0.15) }
    var accentMedium: Color { accentColor.opacity(0.35) }
    var accentStrong: Color { accentColor.opacity(0.7) }

    // Background layers (for depth) - using system colors for native feel
    static let backgroundDeep = Color(nsColor: .windowBackgroundColor)
    static let backgroundBase = Color(nsColor: .controlBackgroundColor)
    static let backgroundElevated = Color(nsColor: .controlBackgroundColor).opacity(0.8)
    static let backgroundSurface = Color(nsColor: .unemphasizedSelectedContentBackgroundColor)

    // Borders
    static let borderSubtle = Color.white.opacity(0.06)
    static let borderMedium = Color.white.opacity(0.12)
    static let borderStrong = Color.white.opacity(0.20)

    // Text
    static let textPrimary = Color.white.opacity(0.95)
    static let textSecondary = Color.white.opacity(0.55)
    static let textTertiary = Color.white.opacity(0.35)
}

// MARK: - Typography

enum Typography {
    static func title(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundColor(AppColors.textPrimary)
    }

    static func label(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(AppColors.textSecondary)
            .textCase(.uppercase)
            .tracking(0.5)
    }

    static func caption(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .regular))
            .foregroundColor(AppColors.textSecondary)
    }

    static func zoneNumber(_ number: Int, size: CGFloat, color: Color) -> some View {
        Text("\(number)")
            .font(.system(size: size, weight: .bold, design: .rounded))
            .foregroundColor(color)
    }
}

// MARK: - Refined Button Styles

struct PillButtonStyle: ButtonStyle {
    enum Variant {
        case primary
        case secondary
        case ghost
    }

    let variant: Variant
    let accentColor: Color
    let isDisabled: Bool

    init(variant: Variant = .secondary, accentColor: Color = .accentColor, isDisabled: Bool = false) {
        self.variant = variant
        self.accentColor = accentColor
        self.isDisabled = isDisabled
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .medium))
            .padding(.horizontal, DesignTokens.space3)
            .padding(.vertical, DesignTokens.space2 - 2)
            .background(background(isPressed: configuration.isPressed))
            .foregroundColor(foregroundColor)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(borderColor, lineWidth: DesignTokens.borderThin)
            )
            .opacity(isDisabled ? 0.4 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: DesignTokens.durationFast), value: configuration.isPressed)
    }

    private func background(isPressed: Bool) -> some View {
        Group {
            switch variant {
            case .primary:
                accentColor.opacity(isPressed ? 0.9 : 1)
            case .secondary:
                Color.white.opacity(isPressed ? 0.12 : 0.08)
            case .ghost:
                Color.clear
            }
        }
    }

    private var foregroundColor: Color {
        switch variant {
        case .primary:
            return .white
        case .secondary, .ghost:
            return AppColors.textPrimary
        }
    }

    private var borderColor: Color {
        switch variant {
        case .primary:
            return .clear
        case .secondary:
            return AppColors.borderMedium
        case .ghost:
            return .clear
        }
    }
}

struct IconButtonStyle: ButtonStyle {
    let isActive: Bool
    let accentColor: Color

    init(isActive: Bool = false, accentColor: Color = .accentColor) {
        self.isActive = isActive
        self.accentColor = accentColor
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .padding(DesignTokens.space2)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.radiusSmall)
                    .fill(isActive ? accentColor.opacity(0.15) : Color.white.opacity(configuration.isPressed ? 0.08 : 0))
            )
            .foregroundColor(isActive ? accentColor : AppColors.textSecondary)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.easeOut(duration: DesignTokens.durationFast), value: configuration.isPressed)
    }
}

// MARK: - Refined Tab Bar

struct RefinedTabBar<Tab: Hashable & CaseIterable & RawRepresentable>: View where Tab.RawValue == String {
    @Binding var selection: Tab
    let accentColor: Color

    var body: some View {
        HStack(spacing: DesignTokens.space1) {
            ForEach(Array(Tab.allCases), id: \.self) { tab in
                tabItem(tab)
            }
        }
        .padding(DesignTokens.space1)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.radiusMedium)
                .fill(AppColors.backgroundElevated)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.radiusMedium)
                        .strokeBorder(AppColors.borderSubtle, lineWidth: DesignTokens.borderThin)
                )
        )
    }

    private func tabItem(_ tab: Tab) -> some View {
        let isSelected = selection == tab

        return Button {
            withAnimation(.easeInOut(duration: DesignTokens.durationNormal)) {
                selection = tab
            }
        } label: {
            Text(tab.rawValue)
                .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                .foregroundColor(isSelected ? AppColors.textPrimary : AppColors.textSecondary)
                .padding(.horizontal, DesignTokens.space4)
                .padding(.vertical, DesignTokens.space2)
                .background(
                    Group {
                        if isSelected {
                            RoundedRectangle(cornerRadius: DesignTokens.radiusSmall + 2)
                                .fill(AppColors.backgroundSurface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: DesignTokens.radiusSmall + 2)
                                        .strokeBorder(AppColors.borderMedium, lineWidth: DesignTokens.borderThin)
                                )
                                .shadow(color: .black.opacity(0.15), radius: 4, y: 1)
                        }
                    }
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Card Styles

struct CardStyle: ViewModifier {
    let isSelected: Bool
    let accentColor: Color

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.radiusMedium)
                    .fill(AppColors.backgroundElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.radiusMedium)
                    .strokeBorder(
                        isSelected ? accentColor.opacity(0.5) : AppColors.borderSubtle,
                        lineWidth: isSelected ? DesignTokens.borderMedium : DesignTokens.borderThin
                    )
            )
            .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
    }
}

extension View {
    func cardStyle(isSelected: Bool = false, accentColor: Color = .accentColor) -> some View {
        modifier(CardStyle(isSelected: isSelected, accentColor: accentColor))
    }
}

// MARK: - Zone Cell Style

struct ZoneCellStyle: ViewModifier {
    let accentColor: Color
    let isHighlighted: Bool
    let showNumber: Bool
    let number: Int

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.radiusSmall)
                    .fill(
                        LinearGradient(
                            colors: [
                                accentColor.opacity(isHighlighted ? 0.25 : 0.12),
                                accentColor.opacity(isHighlighted ? 0.18 : 0.06)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.radiusSmall)
                    .strokeBorder(
                        accentColor.opacity(isHighlighted ? 0.7 : 0.3),
                        lineWidth: isHighlighted ? DesignTokens.borderMedium : DesignTokens.borderThin
                    )
            )
    }
}

// MARK: - Divider

struct RefinedDivider: View {
    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        AppColors.borderSubtle.opacity(0),
                        AppColors.borderMedium,
                        AppColors.borderSubtle.opacity(0)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: 1)
    }
}

// MARK: - Section Header

struct SectionHeader: View {
    let title: String
    let subtitle: String?

    init(_ title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: DesignTokens.space2) {
            Typography.title(title)
            if let subtitle = subtitle {
                Typography.caption(subtitle)
            }
            Spacer()
        }
    }
}
