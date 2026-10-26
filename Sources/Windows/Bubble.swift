// 동그란 버튼 (클릭 = 패널 열기/닫기, 드래그 = 이동, 우클릭 = 메뉴)

import AppKit
import SwiftUI

@MainActor
final class BubbleState: ObservableObject {
    @Published var pressed = false
    @Published var open = false
}

struct BubbleContent: View {
    @ObservedObject var state: BubbleState
    @ObservedObject var settings: AppSettings
    @ObservedObject var updater: Updater

    var body: some View {
        Image(systemName: state.open ? "xmark" : "checklist")
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 52, height: 52)
            // 유리 틴트는 창이 활성일 때만 진하게 보여서, 색은 직접 칠하고 유리는 그 위 질감으로만 사용
            .background(settings.color.opacity(0.85), in: Circle())
            .modifier(GlassBackground(shape: Circle()))
            // 새 버전이 있거나 업데이트에 실패하면 빨간 점
            .overlay(alignment: .topTrailing) {
                if updater.needsAttention {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 10, height: 10)
                        .overlay(Circle().strokeBorder(Color.white, lineWidth: 1.5))
                        .offset(x: -3, y: 3)
                }
            }
            .scaleEffect(state.pressed ? 0.92 : 1)
            .animation(.easeOut(duration: 0.12), value: state.pressed)
            .frame(width: 60, height: 60)
    }
}

final class BubbleView: NSView {
    var onClick: (() -> Void)?
    var onMove: (() -> Void)?
    var onDragEnd: (() -> Void)?
    let state: BubbleState

    private var mouseStart = NSPoint.zero
    private var windowStart = NSPoint.zero
    private var dragged = false

    init(frame: NSRect, state: BubbleState, settings: AppSettings, updater: Updater) {
        self.state = state
        super.init(frame: frame)
        let host = NSHostingView(rootView: BubbleContent(state: state, settings: settings, updater: updater))
        host.frame = bounds
        host.autoresizingMask = [.width, .height]
        addSubview(host)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    // 마우스 이벤트는 SwiftUI 쪽이 아니라 이 뷰가 받도록
    override func hitTest(_ point: NSPoint) -> NSView? {
        frame.contains(point) ? self : nil
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        mouseStart = NSEvent.mouseLocation
        windowStart = window?.frame.origin ?? .zero
        dragged = false
        state.pressed = true
    }

    override func mouseDragged(with event: NSEvent) {
        let p = NSEvent.mouseLocation
        let dx = p.x - mouseStart.x, dy = p.y - mouseStart.y
        if !dragged && hypot(dx, dy) < 3 { return }   // 살짝 흔들린 건 클릭으로 처리
        dragged = true
        window?.setFrameOrigin(NSPoint(x: windowStart.x + dx, y: windowStart.y + dy))
        onMove?()
    }

    override func mouseUp(with event: NSEvent) {
        state.pressed = false
        if dragged { onDragEnd?() } else { onClick?() }
    }
}
