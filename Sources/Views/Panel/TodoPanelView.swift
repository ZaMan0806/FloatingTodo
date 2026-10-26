// 할 일 패널 전체 (머리줄, 할 일 목록, 완료 수)

import SwiftUI

struct TodoPanelView: View {
    @ObservedObject var store: TodoStore
    @ObservedObject var settings: AppSettings
    @ObservedObject var updater: Updater
    @State private var focus: Field?
    @State private var showSettings = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("할 일").font(.headline)
                Spacer()
                Text(Date(), format: .dateTime.month().day().weekday(.wide))
                    .font(.caption)
                    .foregroundColor(.secondary)
                Button {
                    let id = store.addTodo()
                    focusSoon(.todo(id))
                } label: {
                    Image(systemName: "plus")
                        .font(.body.weight(.semibold))
                        .frame(width: 22, height: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("새 할 일")
                Button {
                    withAnimation(.easeOut(duration: 0.15)) { showSettings.toggle() }
                } label: {
                    Image(systemName: showSettings ? "gearshape.fill" : "gearshape")
                        .frame(width: 22, height: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("설정")
            }
            if showSettings {
                ColorSettingsView(settings: settings)
            }
            UpdateBanner(updater: updater)
            Divider()

            if let err = store.loadError {
                Text(err).foregroundColor(.red).font(.callout)
            } else if store.items.isEmpty {
                Text("+ 버튼으로 할 일을 추가하세요")
                    .foregroundColor(.secondary).font(.callout)
            } else {
                ScrollView {
                    ReorderableStack(items: $store.items, onDragStart: { focus = nil }) { todo, handle in
                        let id = todo.wrappedValue.id
                        TodoCard(todo: todo,
                                 focus: $focus,
                                 handle: handle,
                                 onDelete: { store.deleteTodo(id) },
                                 onAddCheckpoint: {
                                     if let cid = store.addCheckpoint(to: id) {
                                         focusSoon(.checkpoint(cid))
                                     }
                                 })
                    }
                }
            }

            Spacer(minLength: 0)
            let doneCount = store.items.filter(\.isDone).count
            Text("\(doneCount)/\(store.items.count) 완료")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity)   // 가운데 정렬 (모서리 손잡이와 겹치지 않게)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .modifier(GlassBackground(shape: RoundedRectangle(cornerRadius: 22, style: .continuous)))
        .environment(\.personalColor, settings.color)
        .tint(settings.color)   // 커서·선택 영역 등도 같은 색으로
    }

    /// 새로 만든 칸이 화면에 생긴 다음 커서를 넣기
    private func focusSoon(_ field: Field) {
        Task { @MainActor in
            await Task.yield()
            focus = field
        }
    }
}
