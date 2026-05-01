import Foundation
import CoreGraphics

/// Helper for computing global zone numbers across all monitors.
/// Monitors are ordered left-to-right (by frame.origin.x), with top-to-bottom as tiebreaker.
/// Zones within each monitor are ordered by their existing number (reading order).
struct GlobalZoneHelper {

    /// A zone with its global number and display info.
    struct GlobalZone {
        let zone: Zone
        let displayIdentifier: String
        let displayFrame: CGRect
        let globalNumber: Int? // nil if > 9
    }

    /// Computes all zones across displays with global numbering.
    /// - Parameters:
    ///   - displays: Connected displays from DisplayService
    ///   - mode: The current mode containing layouts
    /// - Returns: Array of GlobalZone sorted by global number
    static func computeGlobalZones(displays: [DisplayInfo], mode: Mode) -> [GlobalZone] {
        // Sort displays left-to-right, top-to-bottom as tiebreaker
        let sortedDisplays = displays.sorted { a, b in
            if a.frame.origin.x != b.frame.origin.x {
                return a.frame.origin.x < b.frame.origin.x
            }
            return a.frame.origin.y < b.frame.origin.y
        }

        var globalZones: [GlobalZone] = []

        // Check if we have custom assignments
        if let assignments = mode.globalZoneAssignments {
            // Manual mode: use custom assignments, unassigned zones get nil
            for display in sortedDisplays {
                let layout = mode.layouts.first { $0.displayIdentifier == display.identifier }
                let zones = layout?.zones ?? []
                let sortedZones = zones.sorted { $0.number < $1.number }

                for zone in sortedZones {
                    let globalNumber = assignments[zone.id.uuidString]
                    globalZones.append(GlobalZone(
                        zone: zone,
                        displayIdentifier: display.identifier,
                        displayFrame: display.frame,
                        globalNumber: globalNumber
                    ))
                }
            }
        } else {
            // Automatic mode: left-to-right numbering
            var globalIndex = 1
            for display in sortedDisplays {
                let layout = mode.layouts.first { $0.displayIdentifier == display.identifier }
                let zones = layout?.zones ?? []
                let sortedZones = zones.sorted { $0.number < $1.number }

                for zone in sortedZones {
                    let globalNumber: Int? = globalIndex <= 9 ? globalIndex : nil
                    globalZones.append(GlobalZone(
                        zone: zone,
                        displayIdentifier: display.identifier,
                        displayFrame: display.frame,
                        globalNumber: globalNumber
                    ))
                    globalIndex += 1
                }
            }
        }

        return globalZones
    }

    /// Finds the zone and display for a given global zone number (1-9).
    /// - Parameters:
    ///   - number: Global zone number (1-9)
    ///   - displays: Connected displays
    ///   - mode: Current mode
    /// - Returns: Tuple of (zone, displayInfo) or nil if not found
    static func findZoneByGlobalNumber(_ number: Int, displays: [DisplayInfo], mode: Mode) -> (zone: Zone, display: DisplayInfo)? {
        guard number >= 1 && number <= 9 else { return nil }

        let globalZones = computeGlobalZones(displays: displays, mode: mode)
        guard let globalZone = globalZones.first(where: { $0.globalNumber == number }) else {
            return nil
        }

        guard let display = displays.first(where: { $0.identifier == globalZone.displayIdentifier }) else {
            return nil
        }

        return (globalZone.zone, display)
    }

    /// Returns the global number for a specific zone on a specific display.
    /// - Parameters:
    ///   - zoneID: The zone's UUID
    ///   - displayIdentifier: The display's identifier
    ///   - displays: Connected displays
    ///   - mode: Current mode
    /// - Returns: Global number (1-9) or nil if zone is beyond 9 or not found
    static func globalNumber(for zoneID: UUID, displayIdentifier: String, displays: [DisplayInfo], mode: Mode) -> Int? {
        let globalZones = computeGlobalZones(displays: displays, mode: mode)
        return globalZones.first { $0.zone.id == zoneID && $0.displayIdentifier == displayIdentifier }?.globalNumber
    }

    enum FillOrder {
        case leftToRight
        case topToBottom
    }

    /// Auto-fills unassigned zones with remaining numbers (1-9) in specified order.
    /// - Parameters:
    ///   - currentAssignments: Current manual assignments (may be nil or partial)
    ///   - displays: Connected displays
    ///   - mode: Current mode
    ///   - order: Fill order - leftToRight or topToBottom
    /// - Returns: Updated assignments with unassigned zones filled in
    static func autoFillAssignments(currentAssignments: [String: Int]?, displays: [DisplayInfo], mode: Mode, order: FillOrder = .leftToRight) -> [String: Int] {
        var assignments = currentAssignments ?? [:]

        // Find which numbers are already used
        let usedNumbers = Set(assignments.values)

        // Find available numbers 1-9
        var availableNumbers = (1...9).filter { !usedNumbers.contains($0) }

        // Sort displays based on order
        let sortedDisplays: [DisplayInfo]
        switch order {
        case .leftToRight:
            sortedDisplays = displays.sorted { a, b in
                if a.frame.origin.x != b.frame.origin.x {
                    return a.frame.origin.x < b.frame.origin.x
                }
                return a.frame.origin.y > b.frame.origin.y // Higher Y = higher on screen in macOS
            }
        case .topToBottom:
            sortedDisplays = displays.sorted { a, b in
                if a.frame.origin.y != b.frame.origin.y {
                    return a.frame.origin.y > b.frame.origin.y // Higher Y = higher on screen in macOS
                }
                return a.frame.origin.x < b.frame.origin.x
            }
        }

        // Go through zones in order and assign available numbers to unassigned zones
        for display in sortedDisplays {
            let layout = mode.layouts.first { $0.displayIdentifier == display.identifier }
            let zones = layout?.zones ?? []
            let sortedZones = zones.sorted { $0.number < $1.number }

            for zone in sortedZones {
                let zoneKey = zone.id.uuidString
                if assignments[zoneKey] == nil && !availableNumbers.isEmpty {
                    assignments[zoneKey] = availableNumbers.removeFirst()
                }
            }
        }

        return assignments
    }
}
