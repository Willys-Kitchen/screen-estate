import Foundation
import CoreGraphics

struct MonitorLayout: Identifiable, Codable, Equatable {
    let id: UUID
    var displayIdentifier: String
    var displayName: String
    var zones: [Zone]

    // MARK: - Presets

    static func presetsHalves() -> [Zone] {
        [
            Zone(id: UUID(), number: 1, proportionalFrame: CGRect(x: 0, y: 0, width: 0.5, height: 1)),
            Zone(id: UUID(), number: 2, proportionalFrame: CGRect(x: 0.5, y: 0, width: 0.5, height: 1)),
        ]
    }

    static func presetsThirds() -> [Zone] {
        (0..<3).map { i in
            Zone(
                id: UUID(),
                number: i + 1,
                proportionalFrame: CGRect(x: CGFloat(i) / 3.0, y: 0, width: 1.0 / 3.0, height: 1)
            )
        }
    }

    static func presetsTwoThirdsOneThird() -> [Zone] {
        [
            Zone(id: UUID(), number: 1, proportionalFrame: CGRect(x: 0, y: 0, width: 2.0 / 3.0, height: 1)),
            Zone(id: UUID(), number: 2, proportionalFrame: CGRect(x: 2.0 / 3.0, y: 0, width: 1.0 / 3.0, height: 1)),
        ]
    }

    static func presetsOneThirdTwoThirds() -> [Zone] {
        [
            Zone(id: UUID(), number: 1, proportionalFrame: CGRect(x: 0, y: 0, width: 1.0 / 3.0, height: 1)),
            Zone(id: UUID(), number: 2, proportionalFrame: CGRect(x: 1.0 / 3.0, y: 0, width: 2.0 / 3.0, height: 1)),
        ]
    }

    static func presetsQuadrants() -> [Zone] {
        [
            Zone(id: UUID(), number: 1, proportionalFrame: CGRect(x: 0, y: 0, width: 0.5, height: 0.5)),
            Zone(id: UUID(), number: 2, proportionalFrame: CGRect(x: 0.5, y: 0, width: 0.5, height: 0.5)),
            Zone(id: UUID(), number: 3, proportionalFrame: CGRect(x: 0, y: 0.5, width: 0.5, height: 0.5)),
            Zone(id: UUID(), number: 4, proportionalFrame: CGRect(x: 0.5, y: 0.5, width: 0.5, height: 0.5)),
        ]
    }

    // MARK: - Portrait presets (vertical monitor)

    static func presetsPortraitHalves() -> [Zone] {
        [
            Zone(id: UUID(), number: 1, proportionalFrame: CGRect(x: 0, y: 0, width: 1, height: 0.5)),
            Zone(id: UUID(), number: 2, proportionalFrame: CGRect(x: 0, y: 0.5, width: 1, height: 0.5)),
        ]
    }

    static func presetsPortraitThirds() -> [Zone] {
        (0..<3).map { i in
            Zone(
                id: UUID(),
                number: i + 1,
                proportionalFrame: CGRect(x: 0, y: CGFloat(i) / 3.0, width: 1, height: 1.0 / 3.0)
            )
        }
    }

    static func presetsPortraitTwoThirdsOneThird() -> [Zone] {
        [
            Zone(id: UUID(), number: 1, proportionalFrame: CGRect(x: 0, y: 0, width: 1, height: 2.0 / 3.0)),
            Zone(id: UUID(), number: 2, proportionalFrame: CGRect(x: 0, y: 2.0 / 3.0, width: 1, height: 1.0 / 3.0)),
        ]
    }

    static func presetsPortraitOneThirdTwoThirds() -> [Zone] {
        [
            Zone(id: UUID(), number: 1, proportionalFrame: CGRect(x: 0, y: 0, width: 1, height: 1.0 / 3.0)),
            Zone(id: UUID(), number: 2, proportionalFrame: CGRect(x: 0, y: 1.0 / 3.0, width: 1, height: 2.0 / 3.0)),
        ]
    }
}
