import Foundation

struct Mode: Identifiable, Codable {
    let id: UUID
    var name: String
    var layouts: [MonitorLayout]
}
