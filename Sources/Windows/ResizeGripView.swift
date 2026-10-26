// 크기 조절 손잡이 (패널 아래쪽 바깥 모서리)

import AppKit

final class ResizeGripView: NSView {
    static let size: CGFloat = 18
    /// true 면 왼쪽 아래 모서리(패널이 버튼 왼쪽에 있을 때)
    var isLeft = false { didSet { needsDisplay = true } }
    var onResize: ((NSSize) -> Void)?
    var onResizeEnd: (() -> Void)?

    private var mouseStart = NSPoint.zero
    private var sizeStart = NSSize.zero

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        // 대각선 줄 두 개
        let path = NSBezierPath()
        let b = bounds.insetBy(dx: 5, dy: 5)
        for k in [0.0, 0.5] {
            let off = b.width * k
            if isLeft {
                path.move(to: NSPoint(x: b.minX, y: b.maxY - off))
                path.line(to: NSPoint(x: b.maxX - off, y: b.minY))
            } else {
                path.move(to: NSPoint(x: b.minX + off, y: b.minY))
                path.line(to: NSPoint(x: b.maxX, y: b.maxY - off))
            }
        }
        path.lineWidth = 1.5
        path.lineCapStyle = .round
        NSColor.secondaryLabelColor.setStroke()
        path.stroke()
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }

    override func mouseDown(with event: NSEvent) {
        mouseStart = NSEvent.mouseLocation
        sizeStart = window?.frame.size ?? .zero
    }

    override func mouseDragged(with event: NSEvent) {
        let p = NSEvent.mouseLocation
        let dx = p.x - mouseStart.x, dy = p.y - mouseStart.y
        // 바깥쪽으로 끌면 넓어지고, 아래로 끌면 길어짐
        let w = sizeStart.width + (isLeft ? -dx : dx)
        let h = sizeStart.height - dy
        onResize?(NSSize(width: w, height: h))
    }

    override func mouseUp(with event: NSEvent) {
        onResizeEnd?()
    }
}
