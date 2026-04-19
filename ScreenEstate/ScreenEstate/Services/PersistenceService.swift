import Foundation

enum ConfigFile: String {
    case modes = "modes.json"
    case settings = "settings.json"
}

class PersistenceService {
    let baseDirectory: URL

    init(baseDirectory: URL? = nil) {
        if let baseDirectory {
            self.baseDirectory = baseDirectory
        } else {
            self.baseDirectory = FileManager.default
                .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("ScreenEstate")
        }
    }

    func save<T: Encodable>(_ value: T, to file: ConfigFile) throws {
        try FileManager.default.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(value)
        try data.write(to: baseDirectory.appendingPathComponent(file.rawValue), options: .atomic)
    }

    func load<T: Decodable>(from file: ConfigFile) throws -> T {
        let url = baseDirectory.appendingPathComponent(file.rawValue)
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(T.self, from: data)
    }
}
