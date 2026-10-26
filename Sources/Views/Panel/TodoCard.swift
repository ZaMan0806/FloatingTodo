// 할 일 카드와 체크포인트 줄

import AppKit
import SwiftUI

/// 각 할 일 카드의 위치(목록 기준 좌표)를 모아서 순서 바꾸기 계산에 사용
struct CardFramesKey: PreferenceKey {
    static let defaultValue: [UUID: CGRect] = [:]
    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

/// 체크포인트 한 줄 + 그 아래 하위 체크포인트들 (단계마다 들여쓰기)
struct CheckpointRow: View {
    @Binding var checkpoint: Checkpoint
    let depth: Int              // 할 일 바로 아래가 1
    @Binding var focus: Field?
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                CheckButton(done: checkpoint.isDone, small: true) { checkpoint.toggleDone() }
                EditableText(placeholder: "체크포인트", text: $checkpoint.title, style: .checkpoint,
                             done: checkpoint.isDone, field: .checkpoint(checkpoint.id), focus: $focus)
                if let p = checkpoint.progressText {
                    Text(p).font(.caption).monospacedDigit().foregroundColor(.secondary)
                }
                if !checkpoint.children.isEmpty {
                    IconButton(checkpoint.collapsed ? "chevron.right" : "chevron.down",
                               help: checkpoint.collapsed ? "펼치기" : "접기") {
                        checkpoint.collapsed.toggle()
                    }
                }
                if depth < Checkpoint.maxDepth {
                    IconButton("plus.circle", help: "하위 체크포인트 추가") {
                        let child = Checkpoint()
                        checkpoint.children.append(child)
                        checkpoint.collapsed = false
                        focus = .checkpoint(child.id)   // 새 칸이 화면에 붙으면 커서가 들어감
                    }
                }
                IconButton("xmark", help: "체크포인트 삭제", action: onDelete)
            }

            if !checkpoint.collapsed {
                ForEach($checkpoint.children) { $child in
                    CheckpointRow(checkpoint: $child, depth: depth + 1, focus: $focus) {
                        let id = child.id
                        checkpoint.children.removeAll { $0.id == id }
                    }
                }
                .padding(.leading, 20)
            }
        }
    }
}

struct TodoCard: View {
    @Binding var todo: Todo
    @Binding var focus: Field?
    let onDelete: () -> Void
    let onAddCheckpoint: () -> Void
    let onDragChanged: (CGFloat) -> Void
    let onDragEnded: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // 메인 할 일
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                // 순서 바꾸기 손잡이
                Image(systemName: "line.3.horizontal")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 14, height: 18)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 2, coordinateSpace: .named("todoList"))
                            .onChanged { onDragChanged($0.translation.height) }
                            .onEnded { _ in onDragEnded() }
                    )
                    .onHover { inside in inside ? NSCursor.openHand.push() : NSCursor.pop() }
                    .help("끌어서 순서 바꾸기")
                CheckButton(done: todo.isDone) { todo.toggleDone() }
                EditableText(placeholder: "할 일 제목", text: $todo.title, style: .title,
                             done: todo.isDone, field: .todo(todo.id), focus: $focus)
                if let p = todo.progressText {
                    Text(p).font(.caption).monospacedDigit().foregroundColor(.secondary)
                }
                if !todo.checkpoints.isEmpty {
                    IconButton(todo.collapsed ? "chevron.right" : "chevron.down",
                               help: todo.collapsed ? "펼치기" : "접기") {
                        todo.collapsed.toggle()
                    }
                }
                IconButton("plus.circle", help: "체크포인트 추가", action: onAddCheckpoint)
                IconButton("trash", help: "할 일 삭제", action: onDelete)
            }

            // 체크포인트
            if !todo.collapsed {
                ForEach($todo.checkpoints) { $cp in
                    CheckpointRow(checkpoint: $cp, depth: 1, focus: $focus) {
                        let id = cp.id
                        todo.checkpoints.removeAll { $0.id == id }
                    }
                }
                .padding(.leading, 42)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
