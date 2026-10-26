// 손잡이(≡)로 끌어서 순서를 바꾸는 목록 (할 일 카드, 체크포인트 공용)

import AppKit
import SwiftUI

/// 각 줄의 위치(목록 기준 좌표)를 모아서 순서 바꾸기 계산에 사용
struct RowFramesKey: PreferenceKey {
    static let defaultValue: [UUID: CGRect] = [:]
    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

/// 줄 안에 넣는 순서 바꾸기 손잡이
struct ReorderHandle: View {
    let onChanged: (CGFloat) -> Void
    let onEnded: () -> Void

    var body: some View {
        Image(systemName: "line.3.horizontal")
            .font(.caption)
            .foregroundColor(.secondary)
            .frame(width: 14, height: 18)
            .contentShape(Rectangle())
            .gesture(
                // 줄이 마우스를 따라 움직이므로, 움직이지 않는 화면 좌표 기준으로 거리를 잼
                DragGesture(minimumDistance: 2, coordinateSpace: .global)
                    .onChanged { onChanged($0.translation.height) }
                    .onEnded { _ in onEnded() }
            )
            .onHover { inside in inside ? NSCursor.openHand.push() : NSCursor.pop() }
            .help("끌어서 순서 바꾸기")
    }
}

/// 끄는 동안엔 목록 순서는 그대로 두고 화면에서만 움직였다가, 놓을 때 한 번에 반영
struct ReorderableStack<Item: Identifiable, Row: View>: View where Item.ID == UUID {
    @Binding var items: [Item]
    var spacing: CGFloat = 8
    var liftInset: CGFloat = 0          // 들어 올린 바탕을 줄 바깥으로 얼마나 넓힐지
    var cornerRadius: CGFloat = 10
    var onDragStart: () -> Void = {}
    @ViewBuilder let row: (Binding<Item>, ReorderHandle) -> Row

    @Environment(\.personalColor) private var personalColor
    @State private var space = UUID()                  // 목록마다 따로 쓰는 좌표 공간
    @State private var frames: [UUID: CGRect] = [:]
    @State private var dragging: UUID?
    @State private var dragOffset: CGFloat = 0         // 끄는 줄이 마우스를 따라 움직인 거리
    @State private var dragTarget: Int?                // 놓으면 들어갈 자리
    @State private var dragFrames: [UUID: CGRect] = [:] // 끌기 시작할 때의 위치 (기준이 흔들리지 않게)
    @State private var settling: UUID?                 // 놓은 뒤 제자리로 가는 동안 다른 줄 위에 보이게

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            ForEach($items) { item in
                let id = item.wrappedValue.id
                let lifted = dragging == id
                row(item, ReorderHandle(onChanged: { dragChanged(id, translation: $0) },
                                        onEnded: { dragEnded(id) }))
                    .background(GeometryReader { g in
                        Color.clear.preference(key: RowFramesKey.self, value: [id: g.frame(in: .named(space))])
                    })
                    // 끄는 중: 들어 올린 것처럼 불투명한 바탕 + 그림자 (뒤 줄 글씨가 비치지 않게)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(personalColor, lineWidth: lifted ? 1.5 : 0)
                            .padding(-liftInset)
                    )
                    .background(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(personalColor.opacity(lifted ? 0.12 : 0))
                            .padding(-liftInset)
                    )
                    .background(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(Color(nsColor: .windowBackgroundColor))
                            .shadow(color: .black.opacity(0.2), radius: 8, y: 3)
                            .padding(-liftInset)
                            .opacity(lifted ? 1 : 0)
                    )
                    .scaleEffect(lifted ? 1.02 : 1)
                    .offset(y: lifted ? dragOffset : dragShift(for: id))
                    .zIndex(lifted || settling == id ? 1 : 0)
            }
        }
        .coordinateSpace(name: space)
        .onPreferenceChange(RowFramesKey.self) { all in
            // 안쪽 목록(하위 체크포인트)의 위치도 섞여 올라오므로 이 목록의 줄만 골라 씀
            MainActor.assumeIsolated {
                let ids = Set(items.map(\.id))
                frames = all.filter { ids.contains($0.key) }
            }
        }
        .transformPreference(RowFramesKey.self) { $0 = [:] }   // 바깥 목록으로는 올려 보내지 않기
    }

    private func dragChanged(_ id: UUID, translation: CGFloat) {
        if dragging != id {
            onDragStart()
            dragFrames = frames
            dragTarget = items.firstIndex { $0.id == id }
            withAnimation(.easeOut(duration: 0.15)) { dragging = id }
        }
        guard let start = dragFrames[id] else { return }

        // 목록 맨 위·맨 아래 밖으로는 못 나가게
        let top = dragFrames.values.map(\.minY).min() ?? start.minY
        let bottom = dragFrames.values.map(\.maxY).max() ?? start.maxY
        dragOffset = min(max(translation, top - start.minY), bottom - start.maxY)   // 마우스를 바로 따라감

        // 끄는 줄의 가운데가 다른 줄의 가운데를 지나면 자리 바꾸기
        let center = start.midY + dragOffset
        let target = items.filter { $0.id != id && (dragFrames[$0.id]?.midY ?? .infinity) < center }.count
        if target != dragTarget {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) { dragTarget = target }
        }
    }

    /// 끄는 줄이 지나간 줄들은 그 줄 높이만큼 비켜 줌
    private func dragShift(for id: UUID) -> CGFloat {
        guard let dragged = dragging, let target = dragTarget, let h = dragFrames[dragged]?.height,
              let from = items.firstIndex(where: { $0.id == dragged }),
              let i = items.firstIndex(where: { $0.id == id }) else { return 0 }
        if from < target && i > from && i <= target { return -(h + spacing) }
        if target < from && i >= target && i < from { return h + spacing }
        return 0
    }

    /// 놓으면 순서를 반영하고, 줄이 지금 위치에서 제자리로 미끄러지듯 들어감
    private func dragEnded(_ id: UUID) {
        guard dragging == id else { return }
        settling = id
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            if let from = items.firstIndex(where: { $0.id == id }), let to = dragTarget, to != from {
                items.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
            }
            dragging = nil
            dragTarget = nil
            dragOffset = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            if settling == id { settling = nil }
        }
    }
}
