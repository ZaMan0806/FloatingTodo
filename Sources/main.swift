// FloatingTodo — 화면 위에 떠 있는 버튼 + 할 일 패널 (개인용)
// 빌드: run.command 더블클릭 (swiftc 로 컴파일 후 실행)

import AppKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - 데이터

struct Checkpoint: Codable, Identifiable, Equatable {
    var id: UUID
    var title: String
    var done: Bool

    init(_ title: String = "", done: Bool = false) {
        id = UUID(); self.title = title; self.done = done
    }

    enum CodingKeys: String, CodingKey { case id, title, done }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(UUID.self, forKey: .id)) ?? UUID()
        title = (try? c.decode(String.self, forKey: .title)) ?? ""
        done = (try? c.decode(Bool.self, forKey: .done)) ?? false
    }
}

struct Todo: Codable, Identifiable, Equatable {
    var id: UUID
    var title: String
    var done: Bool              // 체크포인트가 없을 때만 사용
    var collapsed: Bool
    var checkpoints: [Checkpoint]

    init(_ title: String = "", done: Bool = false, checkpoints: [Checkpoint] = []) {
        id = UUID(); self.title = title; self.done = done
        collapsed = false; self.checkpoints = checkpoints
    }

    enum CodingKeys: String, CodingKey { case id, title, done, collapsed, checkpoints }

    // 예전 todos.json(체크포인트 없음)이나 손으로 쓴 JSON도 읽히도록 너그럽게 디코딩
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(UUID.self, forKey: .id)) ?? UUID()
        title = (try? c.decode(String.self, forKey: .title)) ?? ""
        done = (try? c.decode(Bool.self, forKey: .done)) ?? false
        collapsed = (try? c.decode(Bool.self, forKey: .collapsed)) ?? false
        checkpoints = (try? c.decode([Checkpoint].self, forKey: .checkpoints)) ?? []
    }

    /// 체크포인트가 있으면 전부 끝났을 때 완료
    var isDone: Bool { checkpoints.isEmpty ? done : checkpoints.allSatisfy(\.done) }

    var progressText: String? {
        checkpoints.isEmpty ? nil : "\(checkpoints.filter(\.done).count)/\(checkpoints.count)"
    }

    /// 메인 체크 클릭: 체크포인트가 있으면 전부 체크/해제
    mutating func toggleDone() {
        if checkpoints.isEmpty {
            done.toggle()
        } else {
            let target = !isDone
            for i in checkpoints.indices { checkpoints[i].done = target }
        }
    }
}

@MainActor
final class TodoStore: ObservableObject {
    @Published var items: [Todo] = [] { didSet { scheduleSave() } }
    @Published var loadError: String?
    let fileURL: URL
    private var saveTask: Task<Void, Never>?

    init() {
        // ~/Library/Application Support/FloatingTodo/todos.json 에 저장
        // (자동 실행 시 문서 폴더 접근 권한 문제를 피하기 위해 Application Support 사용)
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/FloatingTodo", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("todos.json")
        load()
    }

    func load() {
        loadError = nil
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            items = [
                Todo("FloatingTodo 다듬기", checkpoints: [
                    Checkpoint("할 일 추가해 보기", done: true),
                    Checkpoint("체크포인트 추가해 보기"),
                    Checkpoint("텍스트 눌러서 수정해 보기"),
                ]),
                Todo("체크포인트 없는 할 일"),
            ]
            save()
            return
        }
        do {
            let data = try Data(contentsOf: fileURL)
            items = try JSONDecoder().decode([Todo].self, from: data)
        } catch {
            items = []
            loadError = "todos.json 을 읽지 못했어요. 파일을 확인해 주세요."
        }
    }

    /// 편집할 때마다 바로 쓰지 않고 잠깐 모아서 저장
    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }
            self?.save()
        }
    }

    func save() {
        guard loadError == nil else { return }   // 깨진 파일을 빈 목록으로 덮어쓰지 않기
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
        if let data = try? enc.encode(items) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    func addTodo() -> UUID {
        let t = Todo()
        items.append(t)
        return t.id
    }

    func deleteTodo(_ id: UUID) {
        items.removeAll { $0.id == id }
    }

    func addCheckpoint(to todoID: UUID) -> UUID? {
        guard let i = items.firstIndex(where: { $0.id == todoID }) else { return nil }
        let c = Checkpoint()
        items[i].checkpoints.append(c)
        items[i].collapsed = false
        return c.id
    }
}

// MARK: - Liquid Glass (macOS 26+), 이전 버전은 반투명 재질로 대체

struct GlassBackground<S: Shape>: ViewModifier {
    let shape: S
    var tint: Color? = nil

    @ViewBuilder
    func body(content: Content) -> some View {
        #if compiler(>=6.2)   // Xcode 26(macOS 26 SDK) 이상에서만 Liquid Glass 코드를 컴파일
        if #available(macOS 26.0, *) {
            content.glassEffect(tint.map { Glass.regular.tint($0) } ?? Glass.regular, in: shape)
        } else {
            fallback(content)
        }
        #else
        fallback(content)
        #endif
    }

    @ViewBuilder
    private func fallback(_ content: Content) -> some View {
        if let tint {
            content.background(tint, in: shape)
        } else {
            content.background(.regularMaterial, in: shape)
        }
    }
}

// MARK: - 퍼스널 컬러

extension Color {
    init?(hex: String) {
        var h = hex.trimmingCharacters(in: .whitespaces)
        if h.hasPrefix("#") { h.removeFirst() }
        guard h.count == 6, let v = UInt32(h, radix: 16) else { return nil }
        self.init(red: Double((v >> 16) & 0xFF) / 255,
                  green: Double((v >> 8) & 0xFF) / 255,
                  blue: Double(v & 0xFF) / 255)
    }

    var hexString: String {
        let c = NSColor(self).usingColorSpace(.sRGB)
            ?? NSColor(srgbRed: 0.04, green: 0.52, blue: 1, alpha: 1)
        return String(format: "#%02X%02X%02X",
                      Int((c.redComponent * 255).rounded()),
                      Int((c.greenComponent * 255).rounded()),
                      Int((c.blueComponent * 255).rounded()))
    }
}

@MainActor
final class AppSettings: ObservableObject {
    static let presets = ["#0A84FF", "#5E5CE6", "#BF5AF2", "#FF375F", "#FF9F0A", "#30D158", "#40C8E0"]
    private let colorKey = "personalColor"

    @Published var colorHex: String {
        didSet { UserDefaults.standard.set(colorHex, forKey: colorKey) }
    }

    init() {
        colorHex = UserDefaults.standard.string(forKey: colorKey) ?? "#0A84FF"
    }

    var color: Color { Color(hex: colorHex) ?? .blue }
}

private struct PersonalColorKey: EnvironmentKey {
    static let defaultValue: Color = .blue
}

extension EnvironmentValues {
    var personalColor: Color {
        get { self[PersonalColorKey.self] }
        set { self[PersonalColorKey.self] = newValue }
    }
}

/// 입력칸을 눌렀을 때 생기는 파란 포커스 테두리 없애기
struct NoFocusRing: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 14.0, *) {
            content.focusEffectDisabled()
        } else {
            content
        }
    }
}

struct ColorSettingsView: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("퍼스널 컬러").font(.caption).foregroundColor(.secondary)
            HStack(spacing: 8) {
                ForEach(AppSettings.presets, id: \.self) { hex in
                    Button { settings.colorHex = hex } label: {
                        Circle()
                            .fill(Color(hex: hex) ?? .blue)
                            .frame(width: 16, height: 16)
                            .overlay(
                                Circle()
                                    .strokeBorder(Color.primary.opacity(settings.colorHex == hex ? 0.85 : 0),
                                                  lineWidth: 1.5)
                                    .padding(-3)
                            )
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
                ColorPicker("", selection: Binding(get: { settings.color },
                                                   set: { settings.colorHex = $0.hexString }),
                            supportsOpacity: false)
                    .labelsHidden()
                    .help("직접 고르기")
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

// MARK: - 할 일 패널 (SwiftUI)

enum Field: Hashable {
    case todo(UUID)
    case checkpoint(UUID)
}

struct CheckButton: View {
    let done: Bool
    var small = false
    let action: () -> Void
    @Environment(\.personalColor) private var personalColor

    var body: some View {
        Button(action: action) {
            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                .font(small ? .callout : .body)
                .foregroundColor(done ? personalColor : Color.secondary)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct IconButton: View {
    let systemName: String
    let help: String
    let action: () -> Void

    init(_ systemName: String, help: String, action: @escaping () -> Void) {
        self.systemName = systemName; self.help = help; self.action = action
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 18, height: 18)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

/// 각 할 일 카드의 위치(목록 기준 좌표)를 모아서 순서 바꾸기 계산에 사용
struct CardFramesKey: PreferenceKey {
    static let defaultValue: [UUID: CGRect] = [:]
    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

struct TodoCard: View {
    @Binding var todo: Todo
    var focus: FocusState<Field?>.Binding
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
                            .onChanged { onDragChanged($0.location.y) }
                            .onEnded { _ in onDragEnded() }
                    )
                    .help("끌어서 순서 바꾸기")
                CheckButton(done: todo.isDone) { todo.toggleDone() }
                TextField("할 일 제목", text: $todo.title, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.body.weight(.semibold))
                    .strikethrough(todo.isDone)
                    .foregroundColor(todo.isDone ? Color.secondary : Color.primary)
                    .focused(focus, equals: .todo(todo.id))
                    .modifier(NoFocusRing())
                    .onSubmit { focus.wrappedValue = nil }
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
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        CheckButton(done: cp.done, small: true) { cp.done.toggle() }
                        TextField("체크포인트", text: $cp.title, axis: .vertical)
                            .textFieldStyle(.plain)
                            .font(.callout)
                            .strikethrough(cp.done)
                            .foregroundColor(cp.done ? Color.secondary : Color.primary)
                            .focused(focus, equals: .checkpoint(cp.id))
                            .modifier(NoFocusRing())
                            .onSubmit { focus.wrappedValue = nil }
                        IconButton("xmark", help: "체크포인트 삭제") {
                            let id = cp.id
                            todo.checkpoints.removeAll { $0.id == id }
                        }
                    }
                    .padding(.leading, 42)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

struct TodoPanelView: View {
    @ObservedObject var store: TodoStore
    @ObservedObject var settings: AppSettings
    @FocusState private var focus: Field?
    @State private var showSettings = false
    @State private var dragging: UUID?
    @State private var cardFrames: [UUID: CGRect] = [:]

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
            Divider()

            if let err = store.loadError {
                Text(err).foregroundColor(.red).font(.callout)
            } else if store.items.isEmpty {
                Text("+ 버튼으로 할 일을 추가하세요")
                    .foregroundColor(.secondary).font(.callout)
            } else {
                ScrollView {
                    VStack(spacing: 8) {
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
                                     onDragChanged: { y in dragMoved(id, to: y) },
                                     onDragEnded: { withAnimation(.easeOut(duration: 0.15)) { dragging = nil } })
                            // 끄는 중: 크기는 그대로 두고, 테두리는 카드 안쪽에 그려서 잘리지 않게
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(settings.color, lineWidth: dragging == id ? 1.5 : 0)
                            )
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(settings.color.opacity(dragging == id ? 0.12 : 0))
                            )
                            .zIndex(dragging == id ? 1 : 0)
                            .background(GeometryReader { g in
                                Color.clear.preference(key: CardFramesKey.self,
                                                       value: [id: g.frame(in: .named("todoList"))])
                            })
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

    /// 마우스 위치(y)보다 위에 있는 다른 카드 수 = 끌고 있는 카드가 들어갈 자리
    private func dragMoved(_ id: UUID, to y: CGFloat) {
        if dragging != id { dragging = id; focus = nil }
        guard let from = store.items.firstIndex(where: { $0.id == id }) else { return }
        let target = store.items.filter { $0.id != id && (cardFrames[$0.id]?.midY ?? .infinity) < y }.count
        guard target != from else { return }
        withAnimation(.easeInOut(duration: 0.15)) {
            let item = store.items.remove(at: from)
            store.items.insert(item, at: target)
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

// MARK: - 크기 조절 손잡이 (패널 아래쪽 바깥 모서리)

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

// MARK: - 동그란 버튼 (클릭 = 패널 열기/닫기, 드래그 = 이동, 우클릭 = 메뉴)

@MainActor
final class BubbleState: ObservableObject {
    @Published var pressed = false
    @Published var open = false
}

struct BubbleContent: View {
    @ObservedObject var state: BubbleState
    @ObservedObject var settings: AppSettings

    var body: some View {
        Image(systemName: state.open ? "xmark" : "checklist")
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 52, height: 52)
            // 유리 틴트는 창이 활성일 때만 진하게 보여서, 색은 직접 칠하고 유리는 그 위 질감으로만 사용
            .background(settings.color.opacity(0.85), in: Circle())
            .modifier(GlassBackground(shape: Circle()))
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

    init(frame: NSRect, state: BubbleState, settings: AppSettings) {
        self.state = state
        super.init(frame: frame)
        let host = NSHostingView(rootView: BubbleContent(state: state, settings: settings))
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

// MARK: - 앱

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = TodoStore()
    let bubbleState = BubbleState()
    let settings = AppSettings()
    var bubble: FloatingPanel!
    var popup: FloatingPanel!
    private var termSource: DispatchSourceSignal?

    let bubbleSize: CGFloat = 60
    var popupSize = NSSize(width: 300, height: 440)
    let minPopupSize = NSSize(width: 240, height: 200)
    let sizeKey = "popupSize"
    let grip = ResizeGripView(frame: NSRect(x: 0, y: 0, width: ResizeGripView.size, height: ResizeGripView.size))
    let gap: CGFloat = 6
    let originKey = "bubbleOrigin"

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 색 고르기 창이 다른 앱을 쓰는 중에도 숨지 않고 위에 뜨도록
        NSColorPanel.shared.hidesOnDeactivate = false
        NSColorPanel.shared.level = .floating

        // 종료 신호(재시작/종료/stop.command)를 받으면 저장하고 끝내기
        signal(SIGTERM, SIG_IGN)
        let src = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
        src.setEventHandler { [weak self] in
            MainActor.assumeIsolated { self?.store.save() }
            exit(0)
        }
        src.resume()
        termSource = src
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willPowerOffNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.store.save() }
        }
        // 버튼
        bubble = FloatingPanel(rect: NSRect(origin: initialOrigin(),
                                            size: NSSize(width: bubbleSize, height: bubbleSize)))
        let view = BubbleView(frame: NSRect(x: 0, y: 0, width: bubbleSize, height: bubbleSize),
                              state: bubbleState, settings: settings)
        view.onClick = { [weak self] in self?.togglePopup() }
        view.onMove = { [weak self] in self?.positionPopup() }
        view.onDragEnd = { [weak self] in
            guard let self else { return }
            UserDefaults.standard.set(NSStringFromPoint(self.bubble.frame.origin), forKey: self.originKey)
        }
        let menu = NSMenu()
        let reload = NSMenuItem(title: "todos.json 다시 읽기", action: #selector(reloadTodos), keyEquivalent: "")
        reload.target = self
        menu.addItem(reload)
        let openFile = NSMenuItem(title: "todos.json 열기", action: #selector(openTodoFile), keyEquivalent: "")
        openFile.target = self
        menu.addItem(openFile)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "종료", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "")
        quit.target = NSApp
        menu.addItem(quit)
        view.menu = menu
        bubble.allowsKey = false
        bubble.contentView = view
        bubble.orderFrontRegardless()

        // 할 일 패널
        if let s = UserDefaults.standard.string(forKey: sizeKey) {
            let saved = NSSizeFromString(s)
            if saved.width >= minPopupSize.width && saved.height >= minPopupSize.height { popupSize = saved }
        }
        popup = FloatingPanel(rect: NSRect(origin: .zero, size: popupSize))
        let container = NSView(frame: NSRect(origin: .zero, size: popupSize))
        let host = FirstMouseHostingView(rootView: TodoPanelView(store: store, settings: settings))
        if #available(macOS 13.0, *) { host.sizingOptions = [] }   // SwiftUI 가 창 크기를 고정하지 않도록
        host.frame = container.bounds
        host.autoresizingMask = [.width, .height]
        container.addSubview(host)
        grip.onResize = { [weak self] size in self?.resizePopup(to: size) }
        grip.onResizeEnd = { [weak self] in
            guard let self else { return }
            UserDefaults.standard.set(NSStringFromSize(self.popupSize), forKey: self.sizeKey)
        }
        container.addSubview(grip)
        popup.contentView = container
    }

    func applicationWillTerminate(_ notification: Notification) {
        store.save()
    }

    private func initialOrigin() -> NSPoint {
        if let s = UserDefaults.standard.string(forKey: originKey) {
            let p = NSPointFromString(s)
            if NSScreen.screens.contains(where: { $0.visibleFrame.insetBy(dx: -10, dy: -10).contains(p) }) {
                return p
            }
        }
        let f = (NSScreen.main ?? NSScreen.screens[0]).visibleFrame
        return NSPoint(x: f.minX + 24, y: f.midY)
    }

    func togglePopup() {
        if popup.isVisible {
            store.save()
            popup.orderOut(nil)
            bubbleState.open = false
        } else {
            positionPopup()
            popup.orderFrontRegardless()
            bubbleState.open = true
        }
    }

    private var currentScreen: NSRect {
        (bubble.screen ?? NSScreen.main ?? NSScreen.screens[0]).visibleFrame
    }

    func resizePopup(to size: NSSize) {
        let screen = currentScreen
        popupSize = NSSize(width: min(max(size.width, minPopupSize.width), screen.width - bubbleSize - gap),
                           height: min(max(size.height, minPopupSize.height), screen.height))
        positionPopup()
    }

    // 버튼 오른쪽에 붙이고, 오른쪽 공간이 없으면 왼쪽에 표시
    func positionPopup() {
        guard let popup else { return }
        let b = bubble.frame
        let screen = currentScreen
        var x = b.maxX + gap
        let onLeft = x + popupSize.width > screen.maxX
        if onLeft { x = b.minX - gap - popupSize.width }
        var y = b.maxY - popupSize.height
        y = min(max(y, screen.minY), screen.maxY - popupSize.height)
        popup.setFrame(NSRect(x: x, y: y, width: popupSize.width, height: popupSize.height), display: true)

        // 손잡이는 패널의 바깥쪽 아래 모서리에
        grip.isLeft = onLeft
        let g = ResizeGripView.size
        grip.frame = NSRect(x: onLeft ? 4 : popupSize.width - g - 4, y: 4, width: g, height: g)
    }

    @objc func reloadTodos() { store.load() }

    @objc func openTodoFile() {
        store.save()
        NSWorkspace.shared.open(store.fileURL)
    }
}

// 최상위 코드는 메인 스레드에서 돌지만 컴파일러가 모르므로 명시해 줌
MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)   // Dock 아이콘 없이 실행
    app.run()                             // 여기서 계속 실행되므로 delegate 도 유지됨
}
