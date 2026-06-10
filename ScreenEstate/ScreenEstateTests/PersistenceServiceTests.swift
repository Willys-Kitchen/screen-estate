import XCTest
@testable import ScreenEstate

final class PersistenceServiceTests: XCTestCase {
    var service: PersistenceService!
    var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ScreenEstateTests-\(UUID().uuidString)")
        service = PersistenceService(baseDirectory: tempDir)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    // MARK: - Directory Creation

    func testCreatesBaseDirectoryOnSave() throws {
        XCTAssertFalse(FileManager.default.fileExists(atPath: tempDir.path))
        let zone = Zone(id: UUID(), number: 1, proportionalFrame: .zero)
        try service.save([zone], to: .modes)
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempDir.path))
    }

    // MARK: - Save and Load

    func testSaveAndLoadModes() throws {
        let modes = [
            Mode(
                id: UUID(),
                name: "Coding",
                layouts: [
                    MonitorLayout(
                        id: UUID(),
                        displayIdentifier: "display-1",
                        displayName: "Built-in",
                        zones: MonitorLayout.presetsHalves()
                    ),
                ]
            ),
        ]
        try service.save(modes, to: .modes)
        let loaded: [Mode] = try service.load(from: .modes)
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].name, "Coding")
        XCTAssertEqual(loaded[0].layouts[0].zones.count, 2)
    }

    func testSaveAndLoadSettings() throws {
        let commandKey = CustomModifierKey(flags: NSEvent.ModifierFlags.command.rawValue)
        let settings = AppSettings(
            accentColorRGBA: RGBA(red: 1, green: 0, blue: 0, alpha: 1),
            modifierKey: commandKey,
            launchAtLogin: true,
            isEnabled: false,
            isDragSnapEnabled: true
        )
        try service.save(settings, to: .settings)
        let loaded: AppSettings = try service.load(from: .settings)
        XCTAssertEqual(loaded.modifierKey, commandKey)
        XCTAssertTrue(loaded.launchAtLogin)
        XCTAssertFalse(loaded.isEnabled)
    }

    // MARK: - Missing File

    func testLoadMissingFileReturnsNil() {
        let result: [Mode]? = try? service.load(from: .modes)
        XCTAssertNil(result)
    }

    // MARK: - Overwrite

    func testSaveOverwritesExistingFile() throws {
        let modes1 = [Mode(id: UUID(), name: "First", layouts: [])]
        try service.save(modes1, to: .modes)

        let modes2 = [Mode(id: UUID(), name: "Second", layouts: [])]
        try service.save(modes2, to: .modes)

        let loaded: [Mode] = try service.load(from: .modes)
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].name, "Second")
    }

    // MARK: - Corrupt File Recovery

    func testCorruptModesFileIsBackedUpBeforeReset() throws {
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let corruptData = Data("{this is not valid json".utf8)
        try corruptData.write(to: tempDir.appendingPathComponent("modes.json"))

        let defaults = [Mode(id: UUID(), name: "Default", layouts: [])]
        let modes = service.loadModesOrReset(makeDefaults: { defaults })

        XCTAssertEqual(modes.map(\.name), ["Default"], "unreadable file must fall back to defaults")

        let backups = try FileManager.default.contentsOfDirectory(atPath: tempDir.path)
            .filter { $0.hasPrefix("modes.json.corrupt") }
        XCTAssertEqual(backups.count, 1, "the unreadable file must be preserved, not overwritten")
        let backupData = try Data(contentsOf: tempDir.appendingPathComponent(backups[0]))
        XCTAssertEqual(backupData, corruptData, "backup must contain the original bytes")

        let reloaded: [Mode] = try service.load(from: .modes)
        XCTAssertEqual(reloaded.map(\.name), ["Default"], "defaults must be written as the new modes file")
    }

    func testValidModesFileLoadsWithoutResetOrBackup() throws {
        let saved = [Mode(id: UUID(), name: "Mine", layouts: [])]
        try service.save(saved, to: .modes)

        let modes = service.loadModesOrReset(makeDefaults: { XCTFail("defaults must not be built"); return [] })

        XCTAssertEqual(modes.map(\.name), ["Mine"])
        let backups = try FileManager.default.contentsOfDirectory(atPath: tempDir.path)
            .filter { $0.hasPrefix("modes.json.corrupt") }
        XCTAssertTrue(backups.isEmpty)
    }

    func testMissingModesFileResetsToDefaultsWithoutBackup() throws {
        let defaults = [Mode(id: UUID(), name: "Default", layouts: [])]
        let modes = service.loadModesOrReset(makeDefaults: { defaults })

        XCTAssertEqual(modes.map(\.name), ["Default"])
        let backups = try FileManager.default.contentsOfDirectory(atPath: tempDir.path)
            .filter { $0.hasPrefix("modes.json.corrupt") }
        XCTAssertTrue(backups.isEmpty, "no backup should be created when there was no file")
        let reloaded: [Mode] = try service.load(from: .modes)
        XCTAssertEqual(reloaded.map(\.name), ["Default"], "defaults must be persisted")
    }

    func testKeepSafetyCopyPreservesCurrentFileAsBak() throws {
        let original = [Mode(id: UUID(), name: "Original", layouts: [])]
        try service.save(original, to: .modes)

        service.keepSafetyCopy(of: .modes)
        try service.save([Mode(id: UUID(), name: "Rewritten", layouts: [])], to: .modes)

        let bakURL = tempDir.appendingPathComponent("modes.json.bak")
        let bakData = try Data(contentsOf: bakURL)
        let restored = try JSONDecoder().decode([Mode].self, from: bakData)
        XCTAssertEqual(restored.map(\.name), ["Original"],
                       "the .bak must hold the pre-rewrite contents")
    }

    // MARK: - JSON is Human-Readable

    func testSavedJSONIsPrettyPrinted() throws {
        let modes = [Mode(id: UUID(), name: "Test", layouts: [])]
        try service.save(modes, to: .modes)
        let data = try Data(contentsOf: tempDir.appendingPathComponent("modes.json"))
        let jsonString = String(data: data, encoding: .utf8)!
        XCTAssertTrue(jsonString.contains("\n"), "JSON should be pretty-printed with newlines")
    }
}
