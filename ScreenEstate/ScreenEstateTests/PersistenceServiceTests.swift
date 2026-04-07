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
        try service.save([zone], to: "test.json")
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
        try service.save(modes, to: "modes.json")
        let loaded: [Mode] = try service.load(from: "modes.json")
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
        try service.save(settings, to: "settings.json")
        let loaded: AppSettings = try service.load(from: "settings.json")
        XCTAssertEqual(loaded.modifierKey, commandKey)
        XCTAssertTrue(loaded.launchAtLogin)
        XCTAssertFalse(loaded.isEnabled)
    }

    // MARK: - Missing File

    func testLoadMissingFileReturnsNil() {
        let result: [Mode]? = try? service.load(from: "nonexistent.json")
        XCTAssertNil(result)
    }

    // MARK: - Overwrite

    func testSaveOverwritesExistingFile() throws {
        let modes1 = [Mode(id: UUID(), name: "First", layouts: [])]
        try service.save(modes1, to: "modes.json")

        let modes2 = [Mode(id: UUID(), name: "Second", layouts: [])]
        try service.save(modes2, to: "modes.json")

        let loaded: [Mode] = try service.load(from: "modes.json")
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].name, "Second")
    }

    // MARK: - JSON is Human-Readable

    func testSavedJSONIsPrettyPrinted() throws {
        let modes = [Mode(id: UUID(), name: "Test", layouts: [])]
        try service.save(modes, to: "modes.json")
        let data = try Data(contentsOf: tempDir.appendingPathComponent("modes.json"))
        let jsonString = String(data: data, encoding: .utf8)!
        XCTAssertTrue(jsonString.contains("\n"), "JSON should be pretty-printed with newlines")
    }
}
