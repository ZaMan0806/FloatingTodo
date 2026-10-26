// 할 일 카드와 체크포인트 줄

import SwiftUI

/// 체크포인트 한 줄 + 그 아래 하위 체크포인트들 (단계마다 들여쓰기)
struct CheckpointRow: View {
    @Binding var checkpoint: Checkpoint
    let depth: Int              // 할 일 바로 아래가 1
    @Binding var focus: Field?
    let handle: ReorderHandle
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                handle
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
                CheckpointList(checkpoints: $checkpoint.children, depth: depth + 1, focus: $focus)
                    .padding(.leading, 20)   // 하위 줄의 손잡이가 이 줄의 체크 버튼 아래에 오게
            }
        }
    }
}

/// 같은 부모 아래의 체크포인트들 (끌어서 순서 바꾸기, 하위 체크포인트는 같이 움직임)
struct CheckpointList: View {
    @Binding var checkpoints: [Checkpoint]
    let depth: Int
    @Binding var focus: Field?

    var body: some View {
        ReorderableStack(items: $checkpoints, spacing: 6, liftInset: 4, cornerRadius: 8,
                         onDragStart: { focus = nil }) { cp, handle in
            CheckpointRow(checkpoint: cp, depth: depth, focus: $focus, handle: handle) {
                let id = cp.wrappedValue.id
                checkpoints.removeAll { $0.id == id }
            }
        }
    }
}

struct TodoCard: View {
    @Binding var todo: Todo
    @Binding var focus: Field?
    let handle: ReorderHandle
    let onDelete: () -> Void
    let onAddCheckpoint: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // 메인 할 일
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                handle
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
                CheckpointList(checkpoints: $todo.checkpoints, depth: 1, focus: $focus)
                    .padding(.leading, 22)   // 체크포인트 손잡이가 할 일 체크 버튼 아래에 오게
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
