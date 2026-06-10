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

    /// Loads modes, falling back to defaults when the file is missing, empty,
    /// or unreadable. An existing unreadable file is preserved as
    /// `modes.json.corrupt-<timestamp>` before defaults are written over it,
    /// so user configuration is never silently destroyed.
    func loadModesOrReset(makeDefaults: () -> [Mode]) -> [Mode] {
        do {
            let modes: [Mode] = try load(from: .modes)
            if !modes.isEmpty { return modes }
            NSLog("Screen Estate: Modes file is empty, resetting to defaults")
        } catch {
            NSLog("Screen Estate: Failed to load modes, resetting to defaults: \(error)")
        }

        backUpUnreadableFile(.modes)
        let defaults = makeDefaults()
        do {
            try save(defaults, to: .modes)
        } catch {
            NSLog("Screen Estate: Failed to save default modes: \(error)")
        }
        return defaults
    }

    /// Copies the current file to `<name>.bak` (replacing any previous .bak).
    /// Called before an automated rewrite (e.g. layout reconciliation) so the
    /// pre-rewrite state stays recoverable.
    func keepSafetyCopy(of file: ConfigFile) {
        let url = baseDirectory.appendingPathComponent(file.rawValue)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        let bak = baseDirectory.appendingPathComponent("\(file.rawValue).bak")
        do {
            if FileManager.default.fileExists(atPath: bak.path) {
                try FileManager.default.removeItem(at: bak)
            }
            try FileManager.default.copyItem(at: url, to: bak)
        } catch {
            NSLog("Screen Estate: Could not write safety copy of \(file.rawValue): \(error)")
        }
    }

    private func backUpUnreadableFile(_ file: ConfigFile) {
        let url = baseDirectory.appendingPathComponent(file.rawValue)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let destination = baseDirectory
            .appendingPathComponent("\(file.rawValue).corrupt-\(formatter.string(from: Date()))")
        do {
            try FileManager.default.moveItem(at: url, to: destination)
            NSLog("Screen Estate: Preserved unreadable \(file.rawValue) at \(destination.lastPathComponent)")
        } catch {
            NSLog("Screen Estate: Could not back up unreadable \(file.rawValue): \(error)")
        }
    }
}
