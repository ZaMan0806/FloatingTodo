// 작은 버튼들 (체크, 아이콘)

import SwiftUI

struct CheckButton: View {
    let done: Bool
    var small = false
    let action: () -> Void
    @Environment(\.personalColor) private var personalColor

    var body: some View {
        Button(action: action) {
            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                .font(small ? .callout : .body)
                .foregroundColor(done ? personalColor : Color.secondary)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct IconButton: View {
    let systemName: String
    let help: String
    let action: () -> Void

    init(_ systemName: String, help: String, action: @escaping () -> Void) {
        self.systemName = systemName; self.help = help; self.action = action
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 18, height: 18)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }
}
