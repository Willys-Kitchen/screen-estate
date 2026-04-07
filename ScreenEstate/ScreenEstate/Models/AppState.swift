import Foundation
import Observation

@Observable
class AppState {
    var modes: [Mode] = []
    var activeModeIndex: Int = 0
    var settings: AppSettings = .defaultSettings

    var activeMode: Mode? {
        guard !modes.isEmpty, activeModeIndex >= 0, activeModeIndex < modes.count else { return nil }
        return modes[activeModeIndex]
    }

    func cycleMode() {
        guard modes.count > 1 else { return }
        activeModeIndex = (activeModeIndex + 1) % modes.count
    }
}
