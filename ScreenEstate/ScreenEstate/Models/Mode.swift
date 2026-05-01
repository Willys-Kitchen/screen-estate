import Foundation

struct Mode: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var layouts: [MonitorLayout]
    var globalZones: Bool
    /// Custom zone number assignments for global zones mode. Maps zone UUID string to number 1-9.
    /// When nil, uses automatic left-to-right numbering. When set (even if empty), uses manual mode.
    var globalZoneAssignments: [String: Int]?

    init(id: UUID, name: String, layouts: [MonitorLayout], globalZones: Bool = false, globalZoneAssignments: [String: Int]? = nil) {
        self.id = id
        self.name = name
        self.layouts = layouts
        self.globalZones = globalZones
        self.globalZoneAssignments = globalZoneAssignments
    }

    // Backward compatibility: default globalZones to false if not present in saved data
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        layouts = try container.decode([MonitorLayout].self, forKey: .layouts)
        globalZones = try container.decodeIfPresent(Bool.self, forKey: .globalZones) ?? false
        globalZoneAssignments = try container.decodeIfPresent([String: Int].self, forKey: .globalZoneAssignments)
    }
}
