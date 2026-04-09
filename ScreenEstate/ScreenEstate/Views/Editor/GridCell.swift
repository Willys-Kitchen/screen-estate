import SwiftUI

enum GridCellState {
    case idle
    case selectionStart     // First cell tapped, awaiting second
    case inSelection        // Within the active selection rectangle
    case mergeError         // Selection is invalid for merging
}
