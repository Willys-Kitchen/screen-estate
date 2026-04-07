import SwiftUI

struct GridCell: View {
    let row: Int
    let col: Int
    let groupID: Int
    let isSelected: Bool
    let zoneNumber: Int

    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(isSelected ? Color.accentColor.opacity(0.3) : Color.gray.opacity(0.1))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(isSelected ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: isSelected ? 2 : 1)
            )
            .overlay(
                Text(zoneNumber > 0 ? "\(zoneNumber)" : "")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
            )
    }
}
