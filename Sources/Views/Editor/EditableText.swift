// 입력칸 + 안내 글씨, 커서가 들어갈 칸 구분

import AppKit
import SwiftUI

enum Field: Hashable {
    case todo(UUID)
    case checkpoint(UUID)
}

/// 여러 줄 입력칸 + 빈 칸일 때 안내 글씨
struct EditableText: View {
    let placeholder: String
    @Binding var text: String
    let style: EditorStyle
    let done: Bool
    let field: Field
    @Binding var focus: Field?
    @Environment(\.personalColor) private var personalColor

    var body: some View {
        WrappingTextView(text: $text, style: style, done: done, tint: NSColor(personalColor),
                         field: field, focus: $focus)
            .overlay(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder)
                        .font(Font(style.font as CTFont))
                        .foregroundColor(Color(nsColor: .placeholderTextColor))
                        .allowsHitTesting(false)
                }
            }
            .alignmentGuide(.firstTextBaseline) { _ in style.baseline }
    }
}
