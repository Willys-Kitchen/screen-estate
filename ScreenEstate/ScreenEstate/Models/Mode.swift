import Foundation

struct Mode: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var layouts: [MonitorLayout]
}
