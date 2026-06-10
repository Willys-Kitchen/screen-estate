import Foundation
import AppKit
import Carbon.HIToolbox

struct RGBA: Codable, Hashable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double

    static let defaultBlue = RGBA(red: 0.0, green: 0.478, blue: 1.0, alpha: 0.3)
}

struct CustomModifierKey: Codable, Hashable {
    var flags: UInt

    init(flags: UInt) {
        self.flags = flags
    }

    init(from decoder: Decoder) throws {
        if let raw = try? decoder.singleValueContainer().decode(UInt.self) {
            self.flags = raw
        } else if let legacy = try? decoder.singleValueContainer().decode(String.self) {
            self = CustomModifierKey.fromLegacy(legacy)
        } else {
            // Handle old keyed format with triggerKeyCode fields — just read flags
            let c = try decoder.container(keyedBy: CodingKeys.self)
            self.flags = (try? c.decode(UInt.self, forKey: .flags)) ?? CustomModifierKey.controlOption.flags
        }
    }

    private enum CodingKeys: String, CodingKey { case flags }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(flags)
    }

    var eventFlags: NSEvent.ModifierFlags {
        NSEvent.ModifierFlags(rawValue: flags).intersection(.deviceIndependentFlagsMask)
    }

    var control: Bool { eventFlags.contains(.control) }
    var option:  Bool { eventFlags.contains(.option) }
    var shift:   Bool { eventFlags.contains(.shift) }
    var command: Bool { eventFlags.contains(.command) }

    /// The same modifiers expressed as Carbon hotkey flags, for RegisterEventHotKey.
    var carbonFlags: UInt32 {
        var flags: UInt32 = 0
        if control { flags |= UInt32(controlKey) }
        if option  { flags |= UInt32(optionKey) }
        if shift   { flags |= UInt32(shiftKey) }
        if command { flags |= UInt32(cmdKey) }
        return flags
    }

    var displayString: String {
        var parts: [String] = []
        if control { parts.append("⌃") }
        if option  { parts.append("⌥") }
        if shift   { parts.append("⇧") }
        if command { parts.append("⌘") }
        return parts.isEmpty ? "—" : parts.joined()
    }

    static let controlOption = CustomModifierKey(
        flags: NSEvent.ModifierFlags([.control, .option]).rawValue
    )

    private static func fromLegacy(_ string: String) -> CustomModifierKey {
        switch string {
        case "control":        return .init(flags: NSEvent.ModifierFlags.control.rawValue)
        case "option":         return .init(flags: NSEvent.ModifierFlags.option.rawValue)
        case "command":        return .init(flags: NSEvent.ModifierFlags.command.rawValue)
        case "controlOption":  return .init(flags: NSEvent.ModifierFlags([.control, .option]).rawValue)
        case "controlCommand": return .init(flags: NSEvent.ModifierFlags([.control, .command]).rawValue)
        case "optionCommand":  return .init(flags: NSEvent.ModifierFlags([.option, .command]).rawValue)
        default:               return .controlOption
        }
    }
}

enum ThemeMode: String, Codable, CaseIterable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
}

struct AppSettings: Codable, Equatable {
    var accentColorRGBA: RGBA
    var modifierKey: CustomModifierKey
    var launchAtLogin: Bool
    var isEnabled: Bool
    var isDragSnapEnabled: Bool
    var themeMode: ThemeMode
    var hasSeenOnboarding: Bool

    static let defaultSettings = AppSettings(
        accentColorRGBA: .defaultBlue,
        modifierKey: .controlOption,
        launchAtLogin: false,
        isEnabled: true,
        isDragSnapEnabled: true,
        themeMode: .system,
        hasSeenOnboarding: false
    )

    // Custom decoding to handle missing fields in existing configs
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        accentColorRGBA = try container.decode(RGBA.self, forKey: .accentColorRGBA)
        modifierKey = try container.decode(CustomModifierKey.self, forKey: .modifierKey)
        launchAtLogin = try container.decode(Bool.self, forKey: .launchAtLogin)
        isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
        isDragSnapEnabled = try container.decode(Bool.self, forKey: .isDragSnapEnabled)
        themeMode = try container.decodeIfPresent(ThemeMode.self, forKey: .themeMode) ?? .system
        hasSeenOnboarding = try container.decodeIfPresent(Bool.self, forKey: .hasSeenOnboarding) ?? false
    }

    init(accentColorRGBA: RGBA, modifierKey: CustomModifierKey, launchAtLogin: Bool, isEnabled: Bool, isDragSnapEnabled: Bool, themeMode: ThemeMode = .system, hasSeenOnboarding: Bool = false) {
        self.accentColorRGBA = accentColorRGBA
        self.modifierKey = modifierKey
        self.launchAtLogin = launchAtLogin
        self.isEnabled = isEnabled
        self.isDragSnapEnabled = isDragSnapEnabled
        self.themeMode = themeMode
        self.hasSeenOnboarding = hasSeenOnboarding
    }
}
