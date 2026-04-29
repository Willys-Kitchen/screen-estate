import Foundation

struct Mode: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var layouts: [MonitorLayout]
    var globalZones: Bool

    init(id: UUID, name: String, layouts: [MonitorLayout], globalZones: Bool = false) {
        self.id = id
        self.name = name
        self.layouts = layouts
        self.globalZones = globalZones
    }

    // Backward compatibility: default globalZones to false if not present in saved data
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        layouts = try container.decode([MonitorLayout].self, forKey: .layouts)
        globalZones = try container.decodeIfPresent(Bool.self, forKey: .globalZones) ?? false
    }
}
