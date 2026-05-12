import Foundation
import Observation
import SwiftUI

@Observable
class AppState {
    var modes: [Mode] = []
    var activeModeIndex: Int = 0
    var settings: AppSettings = .defaultSettings

    // MARK: - Active Mode

    var activeMode: Mode? {
        guard !modes.isEmpty, activeModeIndex >= 0, activeModeIndex < modes.count else { return nil }
        return modes[activeModeIndex]
    }

    func cycleMode() {
        guard modes.count > 1 else { return }
        activeModeIndex = (activeModeIndex + 1) % modes.count
    }

    // MARK: - Convenience Accessors

    /// Zones for a display in the active mode, or empty if none configured.
    func zonesFor(displayID: String) -> [Zone] {
        activeMode?.layouts.first { $0.displayIdentifier == displayID }?.zones ?? []
    }

    /// Accent color as SwiftUI Color.
    var accentColor: Color {
        let rgba = settings.accentColorRGBA
        return Color(red: rgba.red, green: rgba.green, blue: rgba.blue, opacity: rgba.alpha)
    }

    /// Shortcut to modifier key setting.
    var modifierKey: CustomModifierKey { settings.modifierKey }

    /// Shortcut to drag snap enabled setting.
    var isDragSnapEnabled: Bool { settings.isDragSnapEnabled }

    /// Shortcut to global enabled setting.
    var isEnabled: Bool { settings.isEnabled }
}
