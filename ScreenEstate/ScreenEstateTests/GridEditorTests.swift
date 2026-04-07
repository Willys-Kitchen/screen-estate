import XCTest
@testable import ScreenEstate

final class GridEditorTests: XCTestCase {

    // MARK: - Initialization

    func testInitialGridHasUniqueCellsPerGroup() {
        let grid = GridEditor(rows: 3, columns: 3)
        var allGroupIDs = Set<Int>()
        for row in 0..<3 {
            for col in 0..<3 {
                allGroupIDs.insert(grid.cells[row][col])
            }
        }
        XCTAssertEqual(allGroupIDs.count, 9, "Each cell should have a unique group ID")
    }

    func testInitialGridDimensions() {
        let grid = GridEditor(rows: 2, columns: 4)
        XCTAssertEqual(grid.rows, 2)
        XCTAssertEqual(grid.columns, 4)
        XCTAssertEqual(grid.cells.count, 2)
        XCTAssertEqual(grid.cells[0].count, 4)
    }

    // MARK: - Merging

    func testMergeRectangularSelection() {
        var grid = GridEditor(rows: 2, columns: 3)
        // Merge top-left 2x2
        let success = grid.merge(fromRow: 0, fromCol: 0, toRow: 1, toCol: 1)
        XCTAssertTrue(success)
        // All 4 cells in the 2x2 block should share the same group ID
        let groupID = grid.cells[0][0]
        XCTAssertEqual(grid.cells[0][1], groupID)
        XCTAssertEqual(grid.cells[1][0], groupID)
        XCTAssertEqual(grid.cells[1][1], groupID)
        // The remaining cells should be different
        XCTAssertNotEqual(grid.cells[0][2], groupID)
        XCTAssertNotEqual(grid.cells[1][2], groupID)
    }

    func testMergeSingleCellIsNoOp() {
        var grid = GridEditor(rows: 2, columns: 2)
        let originalCells = grid.cells
        let success = grid.merge(fromRow: 0, fromCol: 0, toRow: 0, toCol: 0)
        XCTAssertTrue(success)
        XCTAssertEqual(grid.cells, originalCells)
    }

    func testMergeOutOfBoundsReturnsFalse() {
        var grid = GridEditor(rows: 2, columns: 2)
        let success = grid.merge(fromRow: 0, fromCol: 0, toRow: 2, toCol: 1)
        XCTAssertFalse(success)
    }

    func testMergeReversedCoordsNormalized() {
        var grid = GridEditor(rows: 3, columns: 3)
        // Pass bottom-right first, then top-left — should still work
        let success = grid.merge(fromRow: 1, fromCol: 1, toRow: 0, toCol: 0)
        XCTAssertTrue(success)
        let groupID = grid.cells[0][0]
        XCTAssertEqual(grid.cells[0][1], groupID)
        XCTAssertEqual(grid.cells[1][0], groupID)
        XCTAssertEqual(grid.cells[1][1], groupID)
    }

    // MARK: - Splitting

    func testSplitZoneRestoresIndividualCells() {
        var grid = GridEditor(rows: 2, columns: 2)
        _ = grid.merge(fromRow: 0, fromCol: 0, toRow: 1, toCol: 1)
        // All 4 cells have same group
        let groupID = grid.cells[0][0]
        XCTAssertEqual(grid.cells[1][1], groupID)

        grid.split(groupID: groupID)
        // Now all should be unique again
        var allGroupIDs = Set<Int>()
        for row in 0..<2 {
            for col in 0..<2 {
                allGroupIDs.insert(grid.cells[row][col])
            }
        }
        XCTAssertEqual(allGroupIDs.count, 4)
    }

    // MARK: - Zone Generation

    func testZonesFromUnmergedGrid() {
        let grid = GridEditor(rows: 2, columns: 2)
        let zones = grid.toZones()
        XCTAssertEqual(zones.count, 4)
        // Zones should be numbered 1-4 in reading order
        XCTAssertEqual(zones.map(\.number), [1, 2, 3, 4])
    }

    func testZonesFromMergedGrid() {
        var grid = GridEditor(rows: 2, columns: 3)
        // Merge left 2x2
        _ = grid.merge(fromRow: 0, fromCol: 0, toRow: 1, toCol: 1)
        let zones = grid.toZones()
        // Should have 3 zones: the merged 2x2, top-right, bottom-right
        XCTAssertEqual(zones.count, 3)
    }

    func testZoneProportionalFramesFromMergedGrid() {
        var grid = GridEditor(rows: 2, columns: 2)
        // Merge top row
        _ = grid.merge(fromRow: 0, fromCol: 0, toRow: 0, toCol: 1)
        let zones = grid.toZones()
        XCTAssertEqual(zones.count, 3)

        // Zone 1 should be the full top row
        let topZone = zones[0]
        XCTAssertEqual(topZone.proportionalFrame.origin.x, 0, accuracy: 0.0001)
        XCTAssertEqual(topZone.proportionalFrame.origin.y, 0, accuracy: 0.0001)
        XCTAssertEqual(topZone.proportionalFrame.width, 1.0, accuracy: 0.0001)
        XCTAssertEqual(topZone.proportionalFrame.height, 0.5, accuracy: 0.0001)
    }

    func testZonesCoverFullScreen() {
        var grid = GridEditor(rows: 3, columns: 3)
        // Merge top-left 2x2
        _ = grid.merge(fromRow: 0, fromCol: 0, toRow: 1, toCol: 1)
        let zones = grid.toZones()

        let totalArea = zones.reduce(0.0) { sum, zone in
            sum + zone.proportionalFrame.width * zone.proportionalFrame.height
        }
        XCTAssertEqual(totalArea, 1.0, accuracy: 0.0001)
    }

    func testZonesNumberedUpToNine() {
        let grid = GridEditor(rows: 4, columns: 3)
        let zones = grid.toZones()
        XCTAssertEqual(zones.count, 12)
        // First 9 get numbers 1-9
        for i in 0..<9 {
            XCTAssertEqual(zones[i].number, i + 1)
        }
        // Beyond 9 get number 0 (drag-only)
        for i in 9..<12 {
            XCTAssertEqual(zones[i].number, 0)
        }
    }

    // MARK: - Merge overlap prevention

    func testCannotMergeAcrossExistingMergedZone() {
        var grid = GridEditor(rows: 2, columns: 3)
        // Merge left 2 cells in top row
        _ = grid.merge(fromRow: 0, fromCol: 0, toRow: 0, toCol: 1)
        // Now try to merge a region that partially overlaps: top-right 2x1 including col 1 and 2
        // This should fail because col 1 row 0 is already part of a merged zone
        // that extends beyond the selection
        let success = grid.merge(fromRow: 0, fromCol: 1, toRow: 0, toCol: 2)
        XCTAssertFalse(success, "Should not allow merging across an existing merged zone boundary")
    }
}
