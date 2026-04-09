import Foundation
import CoreGraphics

struct GridEditor {
    var rows: Int
    var columns: Int
    var cells: [[Int]] // Each value is a zone group ID
    private var nextGroupID: Int

    init(rows: Int, columns: Int) {
        self.rows = rows
        self.columns = columns
        var id = 0
        self.cells = (0..<rows).map { _ in
            (0..<columns).map { _ in
                defer { id += 1 }
                return id
            }
        }
        self.nextGroupID = id
    }

    /// Returns true if the group occupies more than one cell (i.e. is merged).
    func isGroupMerged(groupID: Int) -> Bool {
        var count = 0
        for r in 0..<rows {
            for c in 0..<columns {
                if cells[r][c] == groupID { count += 1 }
            }
        }
        return count > 1
    }

    /// Returns true if merge would succeed without modifying state.
    func wouldMergeSucceed(fromRow: Int, fromCol: Int, toRow: Int, toCol: Int) -> Bool {
        let minRow = min(fromRow, toRow)
        let maxRow = max(fromRow, toRow)
        let minCol = min(fromCol, toCol)
        let maxCol = max(fromCol, toCol)

        guard minRow >= 0, maxRow < rows, minCol >= 0, maxCol < columns else {
            return false
        }
        if minRow == maxRow && minCol == maxCol { return true }

        var groupIDsInSelection = Set<Int>()
        for r in minRow...maxRow {
            for c in minCol...maxCol {
                groupIDsInSelection.insert(cells[r][c])
            }
        }
        for groupID in groupIDsInSelection {
            for r in 0..<rows {
                for c in 0..<columns {
                    if cells[r][c] == groupID {
                        if r < minRow || r > maxRow || c < minCol || c > maxCol {
                            return false
                        }
                    }
                }
            }
        }
        return true
    }

    /// Merge all cells in the rectangle defined by (fromRow, fromCol) to (toRow, toCol).
    /// Returns false if out of bounds or if the selection would cut across an existing merged zone.
    mutating func merge(fromRow: Int, fromCol: Int, toRow: Int, toCol: Int) -> Bool {
        let minRow = min(fromRow, toRow)
        let maxRow = max(fromRow, toRow)
        let minCol = min(fromCol, toCol)
        let maxCol = max(fromCol, toCol)

        guard minRow >= 0, maxRow < rows, minCol >= 0, maxCol < columns else {
            return false
        }

        // Single cell — no-op
        if minRow == maxRow && minCol == maxCol { return true }

        // Check that we don't cut across an existing merged zone:
        // every group ID that appears in the selection must have ALL its cells within the selection
        var groupIDsInSelection = Set<Int>()
        for r in minRow...maxRow {
            for c in minCol...maxCol {
                groupIDsInSelection.insert(cells[r][c])
            }
        }
        for groupID in groupIDsInSelection {
            for r in 0..<rows {
                for c in 0..<columns {
                    if cells[r][c] == groupID {
                        if r < minRow || r > maxRow || c < minCol || c > maxCol {
                            return false
                        }
                    }
                }
            }
        }

        let newGroupID = nextGroupID
        nextGroupID += 1
        for r in minRow...maxRow {
            for c in minCol...maxCol {
                cells[r][c] = newGroupID
            }
        }
        return true
    }

    /// Split a merged zone back into individual cells.
    mutating func split(groupID: Int) {
        for r in 0..<rows {
            for c in 0..<columns {
                if cells[r][c] == groupID {
                    cells[r][c] = nextGroupID
                    nextGroupID += 1
                }
            }
        }
    }

    /// Convert the current grid state into an array of Zones with proportional frames.
    /// Zones are numbered 1–9 in reading order; beyond 9 get number 0.
    func toZones() -> [Zone] {
        // Find unique groups in reading order (top-left corner)
        var seenGroups = Set<Int>()
        var orderedGroups: [Int] = []
        for r in 0..<rows {
            for c in 0..<columns {
                let group = cells[r][c]
                if !seenGroups.contains(group) {
                    seenGroups.insert(group)
                    orderedGroups.append(group)
                }
            }
        }

        return orderedGroups.enumerated().map { index, groupID in
            // Find bounding box for this group
            var minR = rows, maxR = 0, minC = columns, maxC = 0
            for r in 0..<rows {
                for c in 0..<columns {
                    if cells[r][c] == groupID {
                        minR = min(minR, r)
                        maxR = max(maxR, r)
                        minC = min(minC, c)
                        maxC = max(maxC, c)
                    }
                }
            }

            let x = CGFloat(minC) / CGFloat(columns)
            let y = CGFloat(minR) / CGFloat(rows)
            let width = CGFloat(maxC - minC + 1) / CGFloat(columns)
            let height = CGFloat(maxR - minR + 1) / CGFloat(rows)

            return Zone(
                id: UUID(),
                number: index < 9 ? index + 1 : 0,
                proportionalFrame: CGRect(x: x, y: y, width: width, height: height)
            )
        }
    }
}
