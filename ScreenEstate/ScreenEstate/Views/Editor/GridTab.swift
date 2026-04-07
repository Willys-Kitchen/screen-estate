import SwiftUI

struct GridTab: View {
    @Binding var zones: [Zone]
    let accentColor: Color
    var aspectRatio: CGFloat = 16.0 / 9.0

    @State private var grid: GridEditor
    @State private var selectionStart: (row: Int, col: Int)?
    @State private var selectionEnd: (row: Int, col: Int)?

    init(zones: Binding<[Zone]>, accentColor: Color, aspectRatio: CGFloat = 16.0 / 9.0, rows: Int = 2, columns: Int = 3) {
        self._zones = zones
        self.accentColor = accentColor
        self.aspectRatio = aspectRatio
        self._grid = State(initialValue: GridEditor(rows: rows, columns: columns))
    }

    private var selectedRange: (minRow: Int, maxRow: Int, minCol: Int, maxCol: Int)? {
        guard let start = selectionStart, let end = selectionEnd else { return nil }
        return (
            min(start.row, end.row),
            max(start.row, end.row),
            min(start.col, end.col),
            max(start.col, end.col)
        )
    }

    private func isCellSelected(row: Int, col: Int) -> Bool {
        guard let range = selectedRange else { return false }
        return row >= range.minRow && row <= range.maxRow && col >= range.minCol && col <= range.maxCol
    }

    private func zoneNumberForCell(row: Int, col: Int) -> Int {
        let zones = grid.toZones()
        let groupID = grid.cells[row][col]
        // Find which zone this group maps to
        var seenGroups = Set<Int>()
        var orderedGroups: [Int] = []
        for r in 0..<grid.rows {
            for c in 0..<grid.columns {
                let g = grid.cells[r][c]
                if !seenGroups.contains(g) {
                    seenGroups.insert(g)
                    orderedGroups.append(g)
                }
            }
        }
        guard let index = orderedGroups.firstIndex(of: groupID) else { return 0 }
        return index < 9 ? index + 1 : 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Custom grid layout")
                .font(.headline)

            HStack(spacing: 20) {
                HStack {
                    Text("Rows:")
                    Stepper("\(grid.rows)", value: Binding(
                        get: { grid.rows },
                        set: { newValue in
                            let clamped = max(1, min(6, newValue))
                            grid = GridEditor(rows: clamped, columns: grid.columns)
                            selectionStart = nil
                            selectionEnd = nil
                            zones = grid.toZones()
                        }
                    ), in: 1...6)
                }
                HStack {
                    Text("Columns:")
                    Stepper("\(grid.columns)", value: Binding(
                        get: { grid.columns },
                        set: { newValue in
                            let clamped = max(1, min(6, newValue))
                            grid = GridEditor(rows: grid.rows, columns: clamped)
                            selectionStart = nil
                            selectionEnd = nil
                            zones = grid.toZones()
                        }
                    ), in: 1...6)
                }
            }

            // Grid
            VStack(spacing: 2) {
                ForEach(0..<grid.rows, id: \.self) { row in
                    HStack(spacing: 2) {
                        ForEach(0..<grid.columns, id: \.self) { col in
                            GridCell(
                                row: row,
                                col: col,
                                groupID: grid.cells[row][col],
                                isSelected: isCellSelected(row: row, col: col),
                                zoneNumber: zoneNumberForCell(row: row, col: col)
                            )
                            .onTapGesture {
                                if let start = selectionStart, selectionEnd == nil {
                                    selectionEnd = (row, col)
                                } else {
                                    selectionStart = (row, col)
                                    selectionEnd = nil
                                }
                            }
                            .onTapGesture(count: 2) {
                                // Double-click to split a merged zone
                                let groupID = grid.cells[row][col]
                                grid.split(groupID: groupID)
                                selectionStart = nil
                                selectionEnd = nil
                                zones = grid.toZones()
                            }
                        }
                    }
                }
            }
            .aspectRatio(aspectRatio, contentMode: .fit)

            HStack {
                Button("Merge") {
                    guard let range = selectedRange else { return }
                    if grid.merge(fromRow: range.minRow, fromCol: range.minCol,
                                  toRow: range.maxRow, toCol: range.maxCol) {
                        zones = grid.toZones()
                    }
                    selectionStart = nil
                    selectionEnd = nil
                }
                .disabled(selectedRange == nil)

                Button("Reset Grid") {
                    grid = GridEditor(rows: grid.rows, columns: grid.columns)
                    selectionStart = nil
                    selectionEnd = nil
                    zones = grid.toZones()
                }

                Spacer()

                Text("Click a cell to start selection, click another to end. Then press Merge.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .onAppear {
            zones = grid.toZones()
        }
    }
}
