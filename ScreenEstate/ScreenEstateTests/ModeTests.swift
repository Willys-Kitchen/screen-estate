import XCTest
@testable import ScreenEstate

final class ModeTests: XCTestCase {

    func testModeCodableRoundTrip() throws {
        let mode = Mode(
            id: UUID(),
            name: "Coding",
            layouts: [
                MonitorLayout(
                    id: UUID(),
                    displayIdentifier: "display-1",
                    displayName: "Built-in",
                    zones: MonitorLayout.presetsHalves()
                ),
                MonitorLayout(
                    id: UUID(),
                    displayIdentifier: "display-2",
                    displayName: "External",
                    zones: MonitorLayout.presetsThirds()
                ),
            ]
        )
        let data = try JSONEncoder().encode(mode)
        let decoded = try JSONDecoder().decode(Mode.self, from: data)
        XCTAssertEqual(decoded.id, mode.id)
        XCTAssertEqual(decoded.name, "Coding")
        XCTAssertEqual(decoded.layouts.count, 2)
        XCTAssertEqual(decoded.layouts[0].zones.count, 2)
        XCTAssertEqual(decoded.layouts[1].zones.count, 3)
    }
}

final class AppSettingsTests: XCTestCase {

    func testAppSettingsCodableRoundTrip() throws {
        let settings = AppSettings(
            accentColorRGBA: RGBA(red: 0.2, green: 0.5, blue: 0.8, alpha: 0.3),
            modifierKey: .controlOption,
            launchAtLogin: false,
            isEnabled: true
        )
        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(AppSettings.self, from: data)
        XCTAssertEqual(decoded.accentColorRGBA.red, 0.2, accuracy: 0.001)
        XCTAssertEqual(decoded.accentColorRGBA.green, 0.5, accuracy: 0.001)
        XCTAssertEqual(decoded.accentColorRGBA.blue, 0.8, accuracy: 0.001)
        XCTAssertEqual(decoded.modifierKey, .controlOption)
        XCTAssertEqual(decoded.launchAtLogin, false)
        XCTAssertEqual(decoded.isEnabled, true)
    }

    func testDefaultSettings() {
        let settings = AppSettings.defaultSettings
        XCTAssertTrue(settings.isEnabled)
        XCTAssertFalse(settings.launchAtLogin)
        XCTAssertEqual(settings.modifierKey, .controlOption)
    }

    func testAllModifierKeyOptionsAreCodable() throws {
        for option in ModifierKeyOption.allCases {
            let settings = AppSettings(
                accentColorRGBA: .defaultBlue,
                modifierKey: option,
                launchAtLogin: false,
                isEnabled: true
            )
            let data = try JSONEncoder().encode(settings)
            let decoded = try JSONDecoder().decode(AppSettings.self, from: data)
            XCTAssertEqual(decoded.modifierKey, option)
        }
    }
}
