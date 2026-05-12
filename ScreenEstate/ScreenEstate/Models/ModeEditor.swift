import Foundation
import Observation

/// Encapsulates mode editing logic: dirty tracking, zone mutations, persistence.
/// Extracted from EditorWindow to improve testability and locality.
@Observable
class ModeEditor {
    private let appState: AppState
    private let persistence: PersistenceService
    private let getDisplays: () -> [DisplayInfo]

    // Dirty tracking — snapshot taken when editing begins
    private(set) var savedModes: [Mode] = []
    private(set) var savedSettings: AppSettings = .defaultSettings

    init(appState: AppState, persistence: PersistenceService, displays: @escaping () -> [DisplayInfo]) {
        self.appState = appState
        self.persistence = persistence
        self.getDisplays = displays
    }

    // MARK: - Dirty Tracking

    var hasChanges: Bool {
        appState.modes != savedModes || appState.settings != savedSettings
    }

    /// Call when the editor appears to snapshot current state.
    func snapshotCurrent() {
        savedModes = appState.modes
        savedSettings = appState.settings
    }

    // MARK: - Zone Access

    /// Get zones for a display in the active mode.
    func zones(for displayID: String) -> [Zone] {
        appState.activeMode?.layouts.first { $0.displayIdentifier == displayID }?.zones ?? []
    }

    /// Set zones for a display, handling auto-layout creation and numbering reset.
    func setZones(_ newZones: [Zone], for display: DisplayInfo) {
        ensureLayoutExists(for: display)

        guard let layoutIndex = appState.modes[appState.activeModeIndex].layouts
            .firstIndex(where: { $0.displayIdentifier == display.identifier }) else { return }

        let oldZones = appState.modes[appState.activeModeIndex].layouts[layoutIndex].zones
        appState.modes[appState.activeModeIndex].layouts[layoutIndex].zones = newZones

        // Check if the zone set has changed (not just reordered)
        let oldZoneIDs = Set(oldZones.map { $0.id })
        let newZoneIDs = Set(newZones.map { $0.id })
        let zonesChanged = oldZoneIDs != newZoneIDs

        if zonesChanged {
            // Zones have changed (preset selected or grid modified) - reset to auto-numbering
            appState.modes[appState.activeModeIndex].globalZoneAssignments = nil
        }
    }

    /// Ensure a layout exists for the given display, creating a default if needed.
    private func ensureLayoutExists(for display: DisplayInfo) {
        let layouts = appState.modes[appState.activeModeIndex].layouts
        if !layouts.contains(where: { $0.displayIdentifier == display.identifier }) {
            let newLayout = MonitorLayout(
                id: UUID(),
                displayIdentifier: display.identifier,
                displayName: display.name,
                zones: MonitorLayout.presetsHalves()
            )
            appState.modes[appState.activeModeIndex].layouts.append(newLayout)
        }
    }

    // MARK: - Persistence

    /// Save current state to disk and update snapshot.
    func save() throws {
        try persistence.save(appState.modes, to: .modes)
        try persistence.save(appState.settings, to: .settings)
        savedModes = appState.modes
        savedSettings = appState.settings
    }

    /// Reset to last saved state.
    func reset() {
        appState.modes = savedModes
        appState.settings = savedSettings
    }
}
