import Foundation

struct Mode: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var layouts: [MonitorLayout]
    /// Custom zone number assignments for global zones mode. Maps zone UUID string to number 1-9.
    /// When nil, uses automatic left-to-right numbering. When set (even if empty), uses manual mode.
    var globalZoneAssignments: [String: Int]?

    init(id: UUID, name: String, layouts: [MonitorLayout], globalZoneAssignments: [String: Int]? = nil) {
        self.id = id
        self.name = name
        self.layouts = layouts
        self.globalZoneAssignments = globalZoneAssignments
    }
}
