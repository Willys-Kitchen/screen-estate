import SwiftUI

struct GridTab: View {
    @Binding var zones: [Zone]
    let accentColor: Color
    var aspectRatio: CGFloat = 16.0 / 9.0

    @State private var grid: GridEditor
    @State private var selectionStart: (row: Int, col: Int)?
    @State private var selectionEnd: (row: Int, col: Int)?
    @State private var mergeErrorMessage: String?
    @State private var mergeErrorFlash: Bool = false

    init(zones: Binding<[Zone]>, accentColor: Color, aspectRatio: CGFloat = 16.0 / 9.0, rows: Int = 2, columns: Int = 3) {
        self._zones = zones
        self.accentColor = accentColor
        self.aspectRatio = aspectRatio
        self._grid = State(initialValue: GridEditor(rows: rows, columns: columns))
    }

    // MARK: - Selection state

    private var selectedRange: (minRow: Int, maxRow: Int, minCol: Int, maxCol: Int)? {
        guard let start = selectionStart, let end = selectionEnd else { return nil }
        return (
            min(start.row, end.row),
            max(start.row, end.row),
            min(start.col, end.col),
            max(start.col, end.col)
        )
    }

    /// Whether the current rectangular selection would cut across an existing merged zone.
    private var selectionIsInvalid: Bool {
        guard let range = selectedRange else { return false }
        return !grid.wouldMergeSucceed(
            fromRow: range.minRow, fromCol: range.minCol,
            toRow: range.maxRow, toCol: range.maxCol
        )
    }

    private func cellState(row: Int, col: Int) -> GridCellState {
        // If both endpoints are set, show rectangular selection
        if let range = selectedRange {
            let inRect = row >= range.minRow && row <= range.maxRow
                && col >= range.minCol && col <= range.maxCol
            if inRect {
                return selectionIsInvalid ? .mergeError : .inSelection
            }
            return .idle
        }
        // If only start is set, highlight that single cell
        if let start = selectionStart, start.row == row, start.col == col {
            return .selectionStart
        }
        return .idle
    }

    private func zoneNumberForCell(row: Int, col: Int) -> Int {
        let groupID = grid.cells[row][col]
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

    // MARK: - Actions

    private func handleTap(row: Int, col: Int) {
        mergeErrorMessage = nil
        if selectionStart == nil {
            // Start a new selection
            selectionStart = (row, col)
            selectionEnd = nil
        } else if selectionEnd == nil {
            let start = selectionStart!
            if start.row == row && start.col == col {
                // Tapped same cell — split if merged, otherwise deselect
                let groupID = grid.cells[row][col]
                if grid.isGroupMerged(groupID: groupID) {
                    grid.split(groupID: groupID)
                    zones = grid.toZones()
                }
                selectionStart = nil
            } else {
                selectionEnd = (row, col)
            }
        } else {
            // Already have a full selection — start fresh
            selectionStart = (row, col)
            selectionEnd = nil
        }
    }

    private func performMerge() {
        guard let range = selectedRange else { return }
        let success = grid.merge(
            fromRow: range.minRow, fromCol: range.minCol,
            toRow: range.maxRow, toCol: range.maxCol
        )
        if success {
            zones = grid.toZones()
            selectionStart = nil
            selectionEnd = nil
            mergeErrorMessage = nil
        } else {
            mergeErrorMessage = "Can't merge: selection cuts across an existing merged zone."
            withAnimation(.easeInOut(duration: 0.08).repeatCount(3, autoreverses: true)) {
                mergeErrorFlash = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                mergeErrorFlash = false
            }
        }
    }

    private func clearSelection() {
        selectionStart = nil
        selectionEnd = nil
        mergeErrorMessage = nil
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header row
            HStack(spacing: 20) {
                Text("Custom grid layout")
                    .font(.headline)
                Spacer()
                HStack(spacing: 12) {
                    dimensionStepper(label: "Rows", value: Binding(
                        get: { grid.rows },
                        set: { newValue in
                            let clamped = max(1, min(6, newValue))
                            grid = GridEditor(rows: clamped, columns: grid.columns)
                            clearSelection()
                            zones = grid.toZones()
                        }
                    ))
                    dimensionStepper(label: "Columns", value: Binding(
                        get: { grid.columns },
                        set: { newValue in
                            let clamped = max(1, min(6, newValue))
                            grid = GridEditor(rows: grid.rows, columns: clamped)
                            clearSelection()
                            zones = grid.toZones()
                        }
                    ))
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
                                cellState: cellState(row: row, col: col),
                                zoneNumber: zoneNumberForCell(row: row, col: col)
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                handleTap(row: row, col: col)
                            }
                        }
                    }
                }
            }
            .aspectRatio(aspectRatio, contentMode: .fit)

            // Error message
            if let errorMsg = mergeErrorMessage {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                        .font(.caption)
                    Text(errorMsg)
                        .font(.caption)
                        .foregroundColor(.red)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.red.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // Action bar
            HStack(spacing: 8) {
                // Merge button — primary CTA when a selection is active
                Button(action: performMerge) {
                    Label("Merge Cells", systemImage: "square.grid.2x2")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(MergeButtonStyle(
                    isActive: selectedRange != nil,
                    isError: selectionIsInvalid,
                    flash: mergeErrorFlash
                ))
                .disabled(selectedRange == nil)

                if selectionStart != nil {
                    Button("Cancel") {
                        clearSelection()
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundColor(.secondary)
                }

                Spacer()

                Button("Reset Grid") {
                    grid = GridEditor(rows: grid.rows, columns: grid.columns)
                    clearSelection()
                    zones = grid.toZones()
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundColor(.secondary)
            }

            // Instruction hint
            selectionHint
        }
        .padding()
        .animation(.easeInOut(duration: 0.18), value: mergeErrorMessage != nil)
        .animation(.easeInOut(duration: 0.12), value: selectionStart != nil)
        .onAppear {
            zones = grid.toZones()
        }
    }

    // MARK: - Subviews

    private var hintInfo: (text: String, icon: String, color: Color) {
        if selectionStart == nil {
            return ("Tap a cell to begin selection", "hand.tap", .secondary)
        } else if selectionEnd == nil {
            return ("Tap a second cell to complete selection, or tap same cell to split", "arrow.right.to.line", accentColor)
        } else if selectionIsInvalid {
            return ("Selection cuts across an existing merged zone — adjust your selection", "xmark.circle", .red)
        } else {
            let range = selectedRange!
            let cellCount = (range.maxRow - range.minRow + 1) * (range.maxCol - range.minCol + 1)
            return ("\(cellCount) cells selected — press Merge Cells to combine", "checkmark.circle", accentColor)
        }
    }

    private var selectionHint: some View {
        let info = hintInfo
        return HStack(spacing: 6) {
            Image(systemName: info.icon)
                .font(.caption)
                .foregroundColor(info.color)
            Text(info.text)
                .font(.caption)
                .foregroundColor(info.color)
        }
    }

    @ViewBuilder
    private func dimensionStepper(label: String, value: Binding<Int>) -> some View {
        HStack(spacing: 4) {
            Text("\(label):")
                .font(.subheadline)
            Stepper("\(value.wrappedValue)", value: value, in: 1...6)
        }
    }
}

// MARK: - Merge Button Style

struct MergeButtonStyle: ButtonStyle {
    let isActive: Bool
    let isError: Bool
    let flash: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(background(pressed: configuration.isPressed))
            .foregroundColor(foreground)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(borderColor, lineWidth: 1)
            )
            .opacity(isActive ? 1 : 0.45)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeInOut(duration: 0.08), value: configuration.isPressed)
    }

    private func background(pressed: Bool) -> Color {
        if !isActive { return Color.gray.opacity(0.12) }
        if isError || flash { return Color.red.opacity(pressed ? 0.3 : 0.15) }
        return Color.accentColor.opacity(pressed ? 0.35 : 0.18)
    }

    private var foreground: Color {
        if !isActive { return .secondary }
        if isError || flash { return .red }
        return .accentColor
    }

    private var borderColor: Color {
        if !isActive { return Color.gray.opacity(0.25) }
        if isError || flash { return Color.red.opacity(0.5) }
        return Color.accentColor.opacity(0.5)
    }
}
