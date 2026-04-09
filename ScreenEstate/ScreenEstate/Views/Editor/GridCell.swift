import SwiftUI

enum GridCellState {
    case idle
    case selectionStart     // First cell tapped, awaiting second
    case inSelection        // Within the active selection rectangle
    case mergeError         // Selection is invalid for merging
}

struct GridCell: View {
    let row: Int
    let col: Int
    let groupID: Int
    let cellState: GridCellState
    let zoneNumber: Int

    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(fillColor)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(strokeColor, lineWidth: strokeWidth)
            )
            .overlay(
                Text(zoneNumber > 0 ? "\(zoneNumber)" : "")
                    .font(.caption.bold())
                    .foregroundColor(labelColor)
            )
            .animation(.easeInOut(duration: 0.12), value: cellState == .idle)
    }

    private var fillColor: Color {
        switch cellState {
        case .idle:
            return Color.gray.opacity(0.1)
        case .selectionStart:
            return Color.accentColor.opacity(0.45)
        case .inSelection:
            return Color.accentColor.opacity(0.25)
        case .mergeError:
            return Color.red.opacity(0.18)
        }
    }

    private var strokeColor: Color {
        switch cellState {
        case .idle:
            return Color.gray.opacity(0.3)
        case .selectionStart:
            return Color.accentColor
        case .inSelection:
            return Color.accentColor.opacity(0.7)
        case .mergeError:
            return Color.red.opacity(0.7)
        }
    }

    private var strokeWidth: CGFloat {
        switch cellState {
        case .idle: return 1
        case .selectionStart: return 2
        case .inSelection: return 1.5
        case .mergeError: return 1.5
        }
    }

    private var labelColor: Color {
        switch cellState {
        case .idle: return .secondary
        case .selectionStart, .inSelection: return Color.accentColor
        case .mergeError: return Color.red
        }
    }
}
