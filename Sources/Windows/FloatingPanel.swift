// 항상 위에 떠 있는 창

import AppKit
import SwiftUI

// 비활성 상태에서도 첫 클릭이 바로 먹도록
final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

// MARK: - 항상 위에 떠 있는 창

final class FloatingPanel: NSPanel {
    convenience init(rect: NSRect) {
        self.init(contentRect: rect,
                  styleMask: [.borderless, .nonactivatingPanel],
                  backing: .buffered,
                  defer: false)
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        hidesOnDeactivate = false
        isMovable = false
    }
    // 키 입력(텍스트 편집)을 받을 수 있게. nonactivating 이라 다른 앱 포커스는 그대로
    /// 버튼 창은 키 창이 될 필요가 없음 (활성/비활성에 따라 모양이 바뀌지 않도록)
    var allowsKey = true
    override var canBecomeKey: Bool { allowsKey }

    // Dock 없는 앱이라 메뉴바(편집 메뉴)가 없어서 ⌘A·⌘C 같은 단축키가 전달되지 않음
    // → 패널이 직접 받아서 입력칸에 넘겨줌. 한글 자판에서도 되도록 글자 대신 키 위치(keyCode)로 판단
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            .subtracting([.capsLock, .numericPad, .function])
        let action: String?
        switch (event.keyCode, flags) {
        case (0, .command):            action = "selectAll:"   // ⌘A
        case (8, .command):            action = "copy:"        // ⌘C
        case (9, .command):            action = "paste:"       // ⌘V
        case (7, .command):            action = "cut:"         // ⌘X
        case (6, .command):            action = "undo:"        // ⌘Z
        case (6, [.command, .shift]):  action = "redo:"        // ⇧⌘Z
        default:                       action = nil
        }
        if let action, NSApp.sendAction(Selector(action), to: nil, from: self) {
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}
