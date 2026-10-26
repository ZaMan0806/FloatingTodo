// 할 일 패널 전체 (목록, 순서 바꾸기)

import AppKit
import SwiftUI

struct TodoPanelView: View {
    @ObservedObject var store: TodoStore
    @ObservedObject var settings: AppSettings
    @ObservedObject var updater: Updater
    @State private var focus: Field?
    @State private var showSettings = false
    @State private var cardFrames: [UUID: CGRect] = [:]
    // 순서 바꾸기: 끄는 동안엔 목록 순서는 그대로 두고 화면에서만 움직였다가, 놓을 때 한 번에 반영
    @State private var dragging: UUID?
    @State private var dragOffset: CGFloat = 0         // 끄는 카드가 마우스를 따라 움직인 거리
    @State private var dragTarget: Int?                // 놓으면 들어갈 자리
    @State private var dragFrames: [UUID: CGRect] = [:] // 끌기 시작할 때의 카드 위치 (기준이 흔들리지 않게)
    @State private var settling: UUID?                 // 놓은 뒤 제자리로 가는 동안 다른 카드 위에 보이게

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
                    VStack(spacing: cardSpacing) {
                        ForEach($store.items) { $todo in
                            let id = todo.id
                            TodoCard(todo: $todo,
                                     focus: $focus,
                                     onDelete: { store.deleteTodo(id) },
                                     onAddCheckpoint: {
                                         if let cid = store.addCheckpoint(to: id) {
                                             focusSoon(.checkpoint(cid))
                                         }
                                     },
                                     onDragChanged: { dy in dragChanged(id, translation: dy) },
                                     onDragEnded: { dragEnded(id) })
                            .background(GeometryReader { g in
                                Color.clear.preference(key: CardFramesKey.self,
                                                       value: [id: g.frame(in: .named("todoList"))])
                            })
                            // 끄는 중: 들어 올린 것처럼 불투명한 바탕 + 그림자 (뒤 카드 글씨가 비치지 않게)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(settings.color, lineWidth: dragging == id ? 1.5 : 0)
                            )
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(settings.color.opacity(dragging == id ? 0.12 : 0))
                            )
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color(nsColor: .windowBackgroundColor))
                                    .shadow(color: .black.opacity(0.2), radius: 8, y: 3)
                                    .opacity(dragging == id ? 1 : 0)
                            )
                            .scaleEffect(dragging == id ? 1.02 : 1)
                            .offset(y: dragging == id ? dragOffset : dragShift(for: id))
                            .zIndex(dragging == id || settling == id ? 1 : 0)
                        }
                    }
                    .coordinateSpace(name: "todoList")
                    .onPreferenceChange(CardFramesKey.self) { frames in
                        MainActor.assumeIsolated { cardFrames = frames }   // 항상 메인 스레드에서 호출됨
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

    private let cardSpacing: CGFloat = 8

    private func dragChanged(_ id: UUID, translation: CGFloat) {
        if dragging != id {
            focus = nil
            dragFrames = cardFrames
            dragTarget = store.items.firstIndex { $0.id == id }
            withAnimation(.easeOut(duration: 0.15)) { dragging = id }
        }
        guard let start = dragFrames[id] else { return }

        // 목록 맨 위·맨 아래 밖으로는 못 나가게
        let top = dragFrames.values.map(\.minY).min() ?? start.minY
        let bottom = dragFrames.values.map(\.maxY).max() ?? start.maxY
        dragOffset = min(max(translation, top - start.minY), bottom - start.maxY)   // 마우스를 바로 따라감

        // 끄는 카드의 가운데가 다른 카드의 가운데를 지나면 자리 바꾸기
        let center = start.midY + dragOffset
        let target = store.items.filter { $0.id != id && (dragFrames[$0.id]?.midY ?? .infinity) < center }.count
        if target != dragTarget {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) { dragTarget = target }
        }
    }

    /// 끄는 카드가 지나간 카드들은 그 카드 높이만큼 비켜 줌
    private func dragShift(for id: UUID) -> CGFloat {
        guard let dragged = dragging, let target = dragTarget, let h = dragFrames[dragged]?.height,
              let from = store.items.firstIndex(where: { $0.id == dragged }),
              let i = store.items.firstIndex(where: { $0.id == id }) else { return 0 }
        if from < target && i > from && i <= target { return -(h + cardSpacing) }
        if target < from && i >= target && i < from { return h + cardSpacing }
        return 0
    }

    /// 놓으면 순서를 반영하고, 카드가 지금 위치에서 제자리로 미끄러지듯 들어감
    private func dragEnded(_ id: UUID) {
        guard dragging == id else { return }
        settling = id
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            if let from = store.items.firstIndex(where: { $0.id == id }), let to = dragTarget, to != from {
                store.items.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
            }
            dragging = nil
            dragTarget = nil
            dragOffset = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            if settling == id { settling = nil }
        }
    }

    /// 새로 만든 칸이 화면에 생긴 다음 커서를 넣기
    private func focusSoon(_ field: Field) {
        Task { @MainActor in
            await Task.yield()
            focus = field
        }
    }
}
