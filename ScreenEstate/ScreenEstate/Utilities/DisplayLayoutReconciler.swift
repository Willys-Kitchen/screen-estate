import Foundation
import CoreGraphics

/// Re-keys saved monitor layouts to the identifiers of the currently connected
/// displays. Some monitors report a different serial number after reconnecting
/// (dock/EDID quirk), so the identifier embedded in a saved layout can stop
/// matching the physical monitor it was made for. Without reconciliation those
/// layouts silently orphan and the user has to reconfigure their zones.
///
/// Matching ladder, per mode:
/// 1. Exact identifier match — layout untouched.
/// 2. Same vendor+model orphan layout — re-keyed to the display's current
///    identifier. With several same-model displays, displays are taken
///    left-to-right and orphans in saved order.
/// 3. Layouts for monitors that aren't connected at all are left alone — they
///    belong to another physical setup (e.g. work vs home).
enum DisplayLayoutReconciler {

    /// Returns the modes with layouts migrated to current display identifiers.
    static func reconcile(modes: [Mode], displays: [DisplayInfo]) -> [Mode] {
        modes.map { reconcile(mode: $0, displays: displays) }
    }

    private static func reconcile(mode: Mode, displays: [DisplayInfo]) -> Mode {
        var mode = mode
        let connectedIdentifiers = Set(displays.map(\.identifier))

        // Displays with no exact-identifier layout, left-to-right so that
        // same-model pairing is deterministic and follows physical arrangement.
        let unmatchedDisplays = displays
            .filter { display in !mode.layouts.contains { $0.displayIdentifier == display.identifier } }
            .sorted { a, b in
                a.frame.origin.x != b.frame.origin.x
                    ? a.frame.origin.x < b.frame.origin.x
                    : a.frame.origin.y < b.frame.origin.y
            }

        // Layout indices that no connected display claims exactly.
        var orphanIndices = mode.layouts.indices.filter {
            !connectedIdentifiers.contains(mode.layouts[$0].displayIdentifier)
        }

        for display in unmatchedDisplays {
            let key = vendorModelKey(display.identifier)
            guard let claim = orphanIndices.firstIndex(where: {
                vendorModelKey(mode.layouts[$0].displayIdentifier) == key
            }) else { continue }
            let layoutIndex = orphanIndices.remove(at: claim)
            mode.layouts[layoutIndex].displayIdentifier = display.identifier
            mode.layouts[layoutIndex].displayName = display.name
        }

        // Remaining orphans of a *connected* monitor model are stale duplicates
        // left behind by earlier serial changes — garbage-collect them. Orphans
        // of models that aren't connected belong to another setup and stay.
        let connectedKeys = Set(displays.map { vendorModelKey($0.identifier) })
        let staleIndices = Set(orphanIndices.filter {
            connectedKeys.contains(vendorModelKey(mode.layouts[$0].displayIdentifier))
        })
        if !staleIndices.isEmpty {
            mode.layouts = mode.layouts.indices
                .filter { !staleIndices.contains($0) }
                .map { mode.layouts[$0] }
        }

        return mode
    }

    /// "v4268-m41458-s810043212" → "v4268-m41458". The serial (or displayID
    /// fallback) segment is the unstable part; vendor+model identify the
    /// monitor's make.
    static func vendorModelKey(_ identifier: String) -> String {
        identifier.split(separator: "-").prefix(2).joined(separator: "-")
    }
}
