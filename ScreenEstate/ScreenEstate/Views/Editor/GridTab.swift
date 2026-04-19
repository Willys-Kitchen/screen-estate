import SwiftUI

struct GridTab: View {
    @Binding var zones: [Zone]
    let accentColor: Color
    var aspectRatio: CGFloat = 16.0 / 9.0

    @State private var grid: GridEditor
    @State private var history: [GridEditor] = []
    @State private var selectionStart: (row: Int, col: Int)?
    @State private var selectionEnd: (row: Int, col: Int)?
    @State private var mergeErrorMessage: String?
    @State private var mergeErrorFlash: Bool = false
    @State private var dimensionErrorMessage: String?

    init(zones: Binding<[Zone]>, accentColor: Color, aspectRatio: CGFloat = 16.0 / 9.0, rows: Int = 2, columns: Int = 3) {
        self._zones = zones
        self.accentColor = accentColor
        self.aspectRatio = aspectRatio
        self._grid = State(initialValue: GridEditor(rows: rows, columns: columns))
    }

    // MARK: - Selection

    private var selectedRange: (minRow: Int, maxRow: Int, minCol: Int, maxCol: Int)? {
        guard let start = selectionStart, let end = selectionEnd else { return nil }
        // Expand to cover full group bounding boxes for both endpoints
        let startGroup = grid.cells[start.row][start.col]
        let endGroup = grid.cells[end.row][end.col]
        let sb = bounds(ofGroup: startGroup)
        let eb = bounds(ofGroup: endGroup)
        return (min(sb.minRow, eb.minRow), max(sb.maxRow, eb.maxRow),
                min(sb.minCol, eb.minCol), max(sb.maxCol, eb.maxCol))
    }

    private var selectionIsInvalid: Bool {
        guard let r = selectedRange else { return false }
        return !grid.wouldMergeSucceed(fromRow: r.minRow, fromCol: r.minCol,
                                       toRow: r.maxRow, toCol: r.maxCol)
    }

    // MARK: - Zone helpers

    private var orderedGroups: [Int] {
        var seen = Set<Int>()
        var result: [Int] = []
        for r in 0..<grid.rows {
            for c in 0..<grid.columns {
                let g = grid.cells[r][c]
                if seen.insert(g).inserted { result.append(g) }
            }
        }
        return result
    }

    private func zoneNumber(forGroup groupID: Int) -> Int {
        guard let idx = orderedGroups.firstIndex(of: groupID) else { return 0 }
        return idx < 9 ? idx + 1 : 0
    }

    private func bounds(ofGroup groupID: Int) -> (minRow: Int, maxRow: Int, minCol: Int, maxCol: Int) {
        var minR = grid.rows, maxR = 0, minC = grid.columns, maxC = 0
        for r in 0..<grid.rows {
            for c in 0..<grid.columns {
                if grid.cells[r][c] == groupID {
                    minR = min(minR, r); maxR = max(maxR, r)
                    minC = min(minC, c); maxC = max(maxC, c)
                }
            }
        }
        return (minR, maxR, minC, maxC)
    }

    // MARK: - Actions

    private func pushHistory() {
        history.append(grid)
    }

    private func handleTap(row: Int, col: Int, isCtrlClick: Bool = false) {
        mergeErrorMessage = nil

        if isCtrlClick {
            // Ctrl+click: split vertically (horizontal line)
            let groupID = grid.cells[row][col]
            pushHistory()
            grid.splitVertically(groupID: groupID)
            zones = grid.toZones()
            clearSelection()
            return
        }

        if selectionStart == nil {
            selectionStart = (row, col)
            selectionEnd = nil
        } else if selectionEnd == nil {
            let start = selectionStart!
            if start.row == row && start.col == col {
                // Tapped same cell with no modifier — deselect
                selectionStart = nil
            } else {
                selectionEnd = (row, col)
            }
        } else {
            // Start fresh selection
            selectionStart = (row, col)
            selectionEnd = nil
        }
    }

    private func handleDoubleTap(row: Int, col: Int) {
        // Double-click: split horizontally (vertical line)
        let groupID = grid.cells[row][col]
        pushHistory()
        grid.splitHorizontally(groupID: groupID)
        zones = grid.toZones()
        clearSelection()
    }

    private func performMerge() {
        guard let r = selectedRange else { return }
        pushHistory()
        let success = grid.merge(fromRow: r.minRow, fromCol: r.minCol,
                                 toRow: r.maxRow, toCol: r.maxCol)
        if success {
            zones = grid.toZones()
            clearSelection()
        } else {
            history.removeLast()
            mergeErrorMessage = "Selection cuts across an existing merged zone."
            withAnimation(.easeInOut(duration: 0.08).repeatCount(3, autoreverses: true)) {
                mergeErrorFlash = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { mergeErrorFlash = false }
        }
    }

    private func clearSelection() {
        selectionStart = nil
        selectionEnd = nil
        mergeErrorMessage = nil
    }

    private func undo() {
        guard !history.isEmpty else { return }
        grid = history.removeLast()
        zones = grid.toZones()
        clearSelection()
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .center, spacing: 14) {
            // Dimension controls
            HStack(spacing: 20) {
                Text("Custom grid layout")
                    .font(.headline)
                Spacer()
                HStack(spacing: 12) {
                    dimensionStepper(label: "Rows", value: Binding(
                        get: { grid.rows },
                        set: { v in
                            let newRows = max(1, min(6, v))
                            if newRows * grid.columns > 9 {
                                dimensionErrorMessage = "What do you need so many zones for bruh"
                                return
                            }
                            dimensionErrorMessage = nil
                            pushHistory()
                            grid = GridEditor(rows: newRows, columns: grid.columns)
                            clearSelection(); zones = grid.toZones()
                        }
                    ))
                    dimensionStepper(label: "Columns", value: Binding(
                        get: { grid.columns },
                        set: { v in
                            let newCols = max(1, min(6, v))
                            if grid.rows * newCols > 9 {
                                dimensionErrorMessage = "What do you need so many zones for bruh"
                                return
                            }
                            dimensionErrorMessage = nil
                            pushHistory()
                            grid = GridEditor(rows: grid.rows, columns: newCols)
                            clearSelection(); zones = grid.toZones()
                        }
                    ))
                }
            }

            // Grid
            gridEditorView

            // Error banner
            if let errorMsg = mergeErrorMessage {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red).font(.caption)
                    Text(errorMsg).font(.caption).foregroundColor(.red)
                }
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(Color.red.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // Dimension limit error banner
            if let dimError = dimensionErrorMessage {
                HStack(spacing: 6) {
                    Image(systemName: "hand.raised.fill")
                        .foregroundColor(.orange).font(.caption)
                    Text(dimError).font(.caption).foregroundColor(.orange)
                }
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(Color.orange.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // Action bar
            HStack(spacing: 8) {
                Button(action: performMerge) {
                    Label("Merge Cells", systemImage: "square.grid.2x2")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(MergeButtonStyle(isActive: selectedRange != nil,
                                              isError: selectionIsInvalid,
                                              flash: mergeErrorFlash))
                .disabled(selectedRange == nil)

                if selectionStart != nil {
                    Button("Cancel") { clearSelection() }
                        .buttonStyle(.plain).font(.caption).foregroundColor(.secondary)
                }

                Spacer()

                Button(action: undo) {
                    Label("Revert", systemImage: "arrow.uturn.backward").font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundColor(history.isEmpty ? Color.secondary.opacity(0.4) : .secondary)
                .disabled(history.isEmpty)

                Button("Reset Grid") {
                    pushHistory()
                    grid = GridEditor(rows: grid.rows, columns: grid.columns)
                    clearSelection(); zones = grid.toZones()
                }
                .buttonStyle(.plain).font(.caption).foregroundColor(.secondary)
            }

            selectionHint
        }
        .padding()
        .animation(.easeInOut(duration: 0.18), value: mergeErrorMessage != nil)
        .animation(.easeInOut(duration: 0.18), value: dimensionErrorMessage != nil)
        .animation(.easeInOut(duration: 0.12), value: selectionStart != nil)
        .onAppear {
            // Only initialize zones from the grid if no zones exist yet.
            // All grid mutations (merge, split, undo, reset, dimension changes)
            // already sync zones via grid.toZones(), so this is only needed as
            // a fallback for an empty initial state.
            if zones.isEmpty {
                zones = grid.toZones()
            }
        }
    }

    // MARK: - Grid editor

    private var gridEditorView: some View {
        GeometryReader { geo in
            gridCanvas(width: geo.size.width, height: geo.size.height)
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.2), lineWidth: 1))
    }

    @ViewBuilder
    private func gridCanvas(width W: CGFloat, height H: CGFloat) -> some View {
        let cellW = W / CGFloat(grid.columns)
        let cellH = H / CGFloat(grid.rows)
        let gap: CGFloat = 3

        ZStack(alignment: .topLeading) {
            groupFills(cellW: cellW, cellH: cellH, gap: gap)
            selectionOverlay(cellW: cellW, cellH: cellH, gap: gap)
            anchorOverlay(cellW: cellW, cellH: cellH, gap: gap)
            tapTargets(cellW: cellW, cellH: cellH)
        }
    }

    @ViewBuilder
    private func groupFills(cellW: CGFloat, cellH: CGFloat, gap: CGFloat) -> some View {
        ForEach(orderedGroups, id: \.self) { groupID in
            let b = bounds(ofGroup: groupID)
            let x = CGFloat(b.minCol) * cellW + gap / 2
            let y = CGFloat(b.minRow) * cellH + gap / 2
            let w = CGFloat(b.maxCol - b.minCol + 1) * cellW - gap
            let h = CGFloat(b.maxRow - b.minRow + 1) * cellH - gap
            let num = zoneNumber(forGroup: groupID)

            RoundedRectangle(cornerRadius: 5)
                .fill(Color.gray.opacity(0.12))
                .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.gray.opacity(0.4), lineWidth: 1))
                .overlay(
                    Text(num > 0 ? "\(num)" : "")
                        .font(.system(size: min(w, h) * 0.28, weight: .semibold))
                        .foregroundColor(.secondary)
                )
                .frame(width: w, height: h)
                .position(x: x + w / 2, y: y + h / 2)
                .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private func selectionOverlay(cellW: CGFloat, cellH: CGFloat, gap: CGFloat) -> some View {
        if let r = selectedRange {
            let x = CGFloat(r.minCol) * cellW + gap / 2
            let y = CGFloat(r.minRow) * cellH + gap / 2
            let w = CGFloat(r.maxCol - r.minCol + 1) * cellW - gap
            let h = CGFloat(r.maxRow - r.minRow + 1) * cellH - gap

            RoundedRectangle(cornerRadius: 5)
                .fill(selectionIsInvalid ? Color.red.opacity(0.15) : accentColor.opacity(0.2))
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(selectionIsInvalid ? Color.red.opacity(0.8) : accentColor,
                                style: StrokeStyle(lineWidth: 2, dash: [5, 3]))
                )
                .frame(width: w, height: h)
                .position(x: x + w / 2, y: y + h / 2)
                .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private func anchorOverlay(cellW: CGFloat, cellH: CGFloat, gap: CGFloat) -> some View {
        if selectedRange == nil, let s = selectionStart {
            let groupID = grid.cells[s.row][s.col]
            let b = bounds(ofGroup: groupID)
            let x = CGFloat(b.minCol) * cellW + gap / 2
            let y = CGFloat(b.minRow) * cellH + gap / 2
            let w = CGFloat(b.maxCol - b.minCol + 1) * cellW - gap
            let h = CGFloat(b.maxRow - b.minRow + 1) * cellH - gap

            RoundedRectangle(cornerRadius: 5)
                .fill(accentColor.opacity(0.15))
                .overlay(RoundedRectangle(cornerRadius: 5).stroke(accentColor, lineWidth: 2))
                .frame(width: w, height: h)
                .position(x: x + w / 2, y: y + h / 2)
                .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private func tapTargets(cellW: CGFloat, cellH: CGFloat) -> some View {
        ForEach(0..<grid.rows, id: \.self) { row in
            ForEach(0..<grid.columns, id: \.self) { col in
                let x = CGFloat(col) * cellW
                let y = CGFloat(row) * cellH

                Color.clear
                    .frame(width: cellW, height: cellH)
                    .contentShape(Rectangle())
                    .position(x: x + cellW / 2, y: y + cellH / 2)
                    .gesture(TapGesture(count: 2).onEnded { handleDoubleTap(row: row, col: col) })
                    .simultaneousGesture(
                        TapGesture(count: 1).modifiers(.control).onEnded {
                            handleTap(row: row, col: col, isCtrlClick: true)
                        }
                    )
                    .simultaneousGesture(
                        TapGesture(count: 1).onEnded { handleTap(row: row, col: col) }
                    )
            }
        }
    }

    // MARK: - Hint

    private var hintInfo: (text: String, icon: String, color: Color) {
        if selectionStart == nil {
            return ("Click to select · Double-click splits left/right · ⌃-click splits top/bottom", "hand.tap", .secondary)
        } else if selectionEnd == nil {
            return ("Click a second cell to complete selection", "arrow.right.to.line", accentColor)
        } else if selectionIsInvalid {
            return ("Selection cuts across an existing merged zone — adjust selection", "xmark.circle", .red)
        } else {
            let r = selectedRange!
            let count = (r.maxRow - r.minRow + 1) * (r.maxCol - r.minCol + 1)
            return ("\(count) cells selected — press Merge Cells to combine", "checkmark.circle", accentColor)
        }
    }

    private var selectionHint: some View {
        let info = hintInfo
        return HStack(spacing: 6) {
            Image(systemName: info.icon).font(.caption).foregroundColor(info.color)
            Text(info.text).font(.caption).foregroundColor(info.color)
        }
    }

    @ViewBuilder
    private func dimensionStepper(label: String, value: Binding<Int>) -> some View {
        HStack(spacing: 4) {
            Text("\(label):").font(.subheadline)
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
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(background(pressed: configuration.isPressed))
            .foregroundColor(foreground)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(borderColor, lineWidth: 1))
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
