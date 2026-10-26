// 여러 줄 입력칸 (NSTextView)

import AppKit
import SwiftUI

// SwiftUI 의 TextField(axis: .vertical) 는 입력 중에 패널 폭이 바뀌면 글자가 사라지고,
// 입력할 때와 아닐 때 줄바꿈 위치가 달라짐 → 보여 주기와 편집을 NSTextView 하나로 처리

enum EditorStyle {
    case title, checkpoint

    var font: NSFont {
        switch self {
        case .title: return .systemFont(ofSize: NSFont.preferredFont(forTextStyle: .body).pointSize, weight: .semibold)
        case .checkpoint: return .preferredFont(forTextStyle: .callout)
        }
    }

    /// 첫 줄 글자 기준선 (체크 버튼과 높이를 맞추는 데 사용)
    var baseline: CGFloat { NSLayoutManager().defaultBaselineOffset(for: font) }

    func attributes(done: Bool) -> [NSAttributedString.Key: Any] {
        let para = NSMutableParagraphStyle()
        para.lineBreakMode = .byWordWrapping
        para.lineBreakStrategy = .standard   // 한글도 단어 단위로 줄바꿈 (일반 글씨와 같은 규칙)
        return [
            .font: font,
            .foregroundColor: done ? NSColor.secondaryLabelColor : NSColor.labelColor,
            .strikethroughStyle: done ? NSUnderlineStyle.single.rawValue : 0,
            .paragraphStyle: para,
        ]
    }
}

final class EditorTextView: NSTextView {
    var storage: NSTextStorage?          // 직접 만든 텍스트 시스템은 저장소를 붙잡고 있어야 함
    var onFocusChange: ((Bool) -> Void)?
    var wantsFocus = false

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func becomeFirstResponder() -> Bool {
        let ok = super.becomeFirstResponder()
        if ok { onFocusChange?(true) }
        return ok
    }

    override func resignFirstResponder() -> Bool {
        let ok = super.resignFirstResponder()
        if ok { onFocusChange?(false) }
        return ok
    }

    // 새로 만든 칸은 창에 붙은 다음에야 커서를 넣을 수 있음
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if wantsFocus { DispatchQueue.main.async { [weak self] in self?.takeFocus() } }
    }

    // 줄이 늘어날 때 SwiftUI 가 칸을 키우기 전에 스크롤부터 움직여 화면이 튀지 않도록 한 박자 뒤에
    override func scrollRangeToVisible(_ range: NSRange) {
        DispatchQueue.main.async { [weak self] in self?.scrollToCaret() }
    }

    private func scrollToCaret() {
        super.scrollRangeToVisible(selectedRange())
    }

    func takeFocus() {
        guard let window, window.firstResponder !== self else { return }
        if !window.isKeyWindow { window.makeKey() }
        if window.makeFirstResponder(self) {
            setSelectedRange(NSRange(location: (string as NSString).length, length: 0))
        }
    }
}

struct WrappingTextView: NSViewRepresentable {
    @Binding var text: String
    let style: EditorStyle
    let done: Bool
    let tint: NSColor
    let field: Field
    @Binding var focus: Field?

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> EditorTextView {
        // 크기 계산(measure)과 같은 TextKit 1 구성이어야 줄바꿈이 정확히 일치함
        let storage = NSTextStorage()
        let layout = NSLayoutManager()
        storage.addLayoutManager(layout)
        let container = NSTextContainer(size: NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude))
        container.widthTracksTextView = true
        container.lineFragmentPadding = 0
        layout.addTextContainer(container)

        let tv = EditorTextView(frame: .zero, textContainer: container)
        tv.storage = storage
        tv.isRichText = false
        tv.importsGraphics = false
        tv.allowsUndo = true
        tv.drawsBackground = false
        tv.focusRingType = .none
        tv.textContainerInset = .zero
        tv.isVerticallyResizable = false     // 크기는 SwiftUI 가 정함
        tv.isHorizontallyResizable = false
        tv.minSize = .zero
        tv.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude)
        tv.isContinuousSpellCheckingEnabled = false
        tv.delegate = context.coordinator
        return tv
    }

    func updateNSView(_ tv: EditorTextView, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self

        // 한글 조합 중에는 건드리지 않기 (글자가 끊기거나 두 번 들어가는 것 방지)
        var restyle = coordinator.styled != done || !coordinator.tint.isEqual(tint)
        if tv.string != text && !tv.hasMarkedText() {
            tv.string = text
            restyle = true
        }
        if restyle && !tv.hasMarkedText() {
            let attrs = style.attributes(done: done)
            tv.textStorage?.setAttributes(attrs, range: NSRange(location: 0, length: tv.textStorage?.length ?? 0))
            tv.typingAttributes = attrs
            tv.insertionPointColor = tint
            tv.selectedTextAttributes = [.backgroundColor: tint.withAlphaComponent(0.3)]
            coordinator.styled = done
            coordinator.tint = tint
        }

        // 클릭으로 들어오고 나간 것을 focus 에 반영, focus 가 바뀌면 커서를 옮김
        // (화면 갱신 도중에 상태를 바꾸지 않도록 한 박자 뒤에, 그때의 값으로 다시 확인)
        let current = $focus, me = field
        tv.onFocusChange = { focused in
            DispatchQueue.main.async {
                if focused {
                    if current.wrappedValue != me { current.wrappedValue = me }
                } else if current.wrappedValue == me {
                    current.wrappedValue = nil
                }
            }
        }
        tv.wantsFocus = current.wrappedValue == me
        if tv.wantsFocus {
            DispatchQueue.main.async { if current.wrappedValue == me { tv.takeFocus() } }
        } else if tv.window?.firstResponder === tv {
            DispatchQueue.main.async {
                if current.wrappedValue != me && tv.window?.firstResponder === tv {
                    tv.window?.makeFirstResponder(nil)
                }
            }
        }
    }

    /// 주어진 폭에서 필요한 높이 (패널 크기를 바꾸면 매번 다시 계산됨)
    func sizeThatFits(_ proposal: ProposedViewSize, nsView: EditorTextView, context: Context) -> CGSize? {
        let width = proposal.width.flatMap { $0.isFinite ? max($0, 0) : nil }
        let content = NSAttributedString(attributedString: nsView.textStorage ?? NSTextStorage())
        let storage = NSTextStorage(attributedString: content)
        let container = NSTextContainer(size: NSSize(width: width ?? .greatestFiniteMagnitude,
                                                     height: .greatestFiniteMagnitude))
        container.lineFragmentPadding = 0
        let layout = NSLayoutManager()
        layout.addTextContainer(container)
        storage.addLayoutManager(layout)
        layout.ensureLayout(for: container)
        let used = layout.usedRect(for: container)
        let height = max(used.maxY, layout.extraLineFragmentRect.maxY, layout.defaultLineHeight(for: style.font))
        return CGSize(width: width ?? ceil(used.width), height: ceil(height))
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: WrappingTextView
        var styled: Bool?
        var tint = NSColor.clear

        init(_ parent: WrappingTextView) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView, parent.text != tv.string else { return }
            parent.text = tv.string
            tv.invalidateIntrinsicContentSize()   // 줄 수가 바뀌었으면 높이를 다시 계산하게
        }

        // Return·Tab·Esc 는 입력 끝내기, ⌥Return 은 줄바꿈
        func textView(_ textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            switch selector {
            case #selector(NSResponder.insertNewline(_:)),
                 #selector(NSResponder.insertTab(_:)),
                 #selector(NSResponder.insertBacktab(_:)),
                 #selector(NSResponder.cancelOperation(_:)):
                textView.window?.makeFirstResponder(nil)
                return true
            default:
                return false
            }
        }
    }
}
