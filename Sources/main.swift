// FloatingTodo — 화면 위에 떠 있는 버튼 + 할 일 패널 (개인용)
// 빌드: run.command 더블클릭 (swiftc 로 컴파일 후 실행)

import AppKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - 데이터

struct Checkpoint: Codable, Identifiable, Equatable {
    /// 할 일 아래로 몇 단계까지 체크포인트를 만들 수 있는지 (패널 폭을 생각해서 제한)
    static let maxDepth = 3

    var id: UUID
    var title: String
    var done: Bool              // 하위 체크포인트가 없을 때만 사용
    var collapsed: Bool
    var children: [Checkpoint]

    init(_ title: String = "", done: Bool = false, children: [Checkpoint] = []) {
        id = UUID(); self.title = title; self.done = done
        collapsed = false; self.children = children
    }

    enum CodingKeys: String, CodingKey { case id, title, done, collapsed, children }

    // 하위 체크포인트가 없던 예전 todos.json 도 읽히도록
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(UUID.self, forKey: .id)) ?? UUID()
        title = (try? c.decode(String.self, forKey: .title)) ?? ""
        done = (try? c.decode(Bool.self, forKey: .done)) ?? false
        collapsed = (try? c.decode(Bool.self, forKey: .collapsed)) ?? false
        children = (try? c.decode([Checkpoint].self, forKey: .children)) ?? []
    }

    /// 하위 체크포인트가 있으면 전부 끝났을 때 완료
    var isDone: Bool { children.isEmpty ? done : children.allSatisfy(\.isDone) }

    var progressText: String? {
        children.isEmpty ? nil : "\(children.filter(\.isDone).count)/\(children.count)"
    }

    /// 하위 체크포인트까지 모두 같은 상태로
    mutating func setDone(_ value: Bool) {
        if children.isEmpty {
            done = value
        } else {
            for i in children.indices { children[i].setDone(value) }
        }
    }

    mutating func toggleDone() { setDone(!isDone) }
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
    var isDone: Bool { checkpoints.isEmpty ? done : checkpoints.allSatisfy(\.isDone) }

    var progressText: String? {
        checkpoints.isEmpty ? nil : "\(checkpoints.filter(\.isDone).count)/\(checkpoints.count)"
    }

    /// 메인 체크 클릭: 체크포인트가 있으면 (하위까지) 전부 체크/해제
    mutating func toggleDone() {
        if checkpoints.isEmpty {
            done.toggle()
        } else {
            let target = !isDone
            for i in checkpoints.indices { checkpoints[i].setDone(target) }
        }
    }
}

@MainActor
final class TodoStore: ObservableObject {
    @Published var items: [Todo] = [] { didSet { scheduleSave() } }
    @Published var loadError: String?
    let fileURL: URL
    private var saveTask: Task<Void, Never>?

    // ~/Library/Application Support/FloatingTodo (실행 파일·할 일·버전 정보가 모두 여기에)
    // (자동 실행 시 문서 폴더 접근 권한 문제를 피하기 위해 Application Support 사용)
    nonisolated static let directory = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/FloatingTodo", isDirectory: true)

    init() {
        let dir = Self.directory
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

// MARK: - 업데이트 (GitHub main 브랜치의 최신 커밋과 설치된 버전 비교)

@MainActor
final class Updater: ObservableObject {
    enum Status: Equatable {
        case idle               // 확인 전이거나 최신 버전
        case available          // 새 버전 있음
        case updating           // 설치 중 (성공하면 앱이 새 버전으로 다시 켜짐)
        case failed(String)
    }

    enum CheckResult { case upToDate, available, unknownVersion, failed }

    @Published var status: Status = .idle

    static let repo = "ZaMan0806/FloatingTodo"
    static let branch = "main"
    private let jobLabel = "com.zaman.floatingtodo.updater"   // install.sh 가 등록하는 업데이트 작업
    private let versionURL = TodoStore.directory.appendingPathComponent("version")
    private let failedURL = TodoStore.directory.appendingPathComponent("update-failed")
    let logURL = TodoStore.directory.appendingPathComponent("update.log")
    private var timer: Timer?
    private var watchTimer: Timer?
    private var lastChecked: Date?   // 마지막으로 확인에 성공한 때

    var needsAttention: Bool {
        switch status {
        case .available, .failed: return true
        default: return false
        }
    }

    /// 설치 명령어로 설치했을 때만 기록됨 (직접 빌드한 개발용은 없음)
    var installedVersion: String? {
        guard let s = try? String(contentsOf: versionURL, encoding: .utf8) else { return nil }
        let v = s.trimmingCharacters(in: .whitespacesAndNewlines)
        return v.isEmpty ? nil : v
    }

    /// 켜고 잠시 뒤, 그 뒤로 한 시간마다, 잠자기에서 깨어난 뒤에 확인
    /// (로그인 직후엔 인터넷이 아직 안 붙어 있을 수 있어서 실패해도 다음 확인 때 다시 시도)
    func start() {
        try? FileManager.default.removeItem(at: failedURL)
        checkLater(seconds: 5)
        timer = Timer.scheduledTimer(withTimeInterval: 60 * 60, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.check() }
        }
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkLater(seconds: 10) }   // 와이파이가 다시 붙을 때까지 잠깐 기다림
        }
    }

    /// 패널을 열 때: 최근 10분 안에 확인했으면 건너뜀
    func checkIfStale() {
        if let lastChecked, Date().timeIntervalSince(lastChecked) < 10 * 60 { return }
        Task { await check() }
    }

    private func checkLater(seconds: UInt64) {
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: seconds * 1_000_000_000)
            await self?.check()
        }
    }

    @discardableResult
    func check() async -> CheckResult {
        guard let installed = installedVersion else { return .unknownVersion }
        guard let latest = await Self.fetchLatestCommit() else { return .failed }
        lastChecked = Date()
        let isNew = latest != installed
        // 설치 중이거나 실패 표시가 떠 있으면 그대로 두기
        if status == .idle || status == .available { status = isNew ? .available : .idle }
        return isNew ? .available : .upToDate
    }

    /// GitHub 의 main 브랜치 최신 커밋 (`git ls-remote` 와 같은 방식)
    /// GitHub API 는 로그인 없이 IP 하나당 한 시간에 60번까지라 학교처럼 IP 를 같이 쓰면 금방 막힘
    private static func fetchLatestCommit() async -> String? {
        var req = URLRequest(url: URL(string: "https://github.com/\(repo).git/info/refs?service=git-upload-pack")!)
        req.cachePolicy = .reloadIgnoringLocalCacheData
        req.timeoutInterval = 15
        guard let res = try? await URLSession.shared.data(for: req),
              (res.1 as? HTTPURLResponse)?.statusCode == 200,
              let body = String(data: res.0, encoding: .utf8),
              let regex = try? NSRegularExpression(pattern: "([0-9a-f]{40}) refs/heads/\(branch)[\\x00\\n]"),
              let match = regex.firstMatch(in: body, range: NSRange(body.startIndex..., in: body)),
              let range = Range(match.range(at: 1), in: body)
        else { return nil }
        return String(body[range])
    }

    /// 업데이트 작업을 launchd 로 실행. 앱과 따로 돌아야 install.sh 가 앱을 끌 때 같이 꺼지지 않음
    func install() {
        try? FileManager.default.removeItem(at: failedURL)
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        p.arguments = ["kickstart", "gui/\(getuid())/\(jobLabel)"]
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        guard (try? p.run()) != nil else {
            status = .failed("업데이트를 시작하지 못했어요.")
            return
        }
        p.waitUntilExit()
        guard p.terminationStatus == 0 else {
            status = .failed("업데이트를 시작하지 못했어요. 설치 명령어로 한 번 다시 설치해 주세요.")
            return
        }
        status = .updating
        // 성공하면 이 앱은 install.sh 가 끄므로, 살아 있는 동안은 실패 표시 파일만 지켜보면 됨
        let started = Date()
        watchTimer?.invalidate()
        watchTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.watchUpdate(since: started) }
        }
    }

    private func watchUpdate(since start: Date) {
        if FileManager.default.fileExists(atPath: failedURL.path) {
            stopWatching(.failed("업데이트에 실패했어요."))
        } else if Date().timeIntervalSince(start) > 10 * 60 {
            stopWatching(.failed("업데이트가 끝나지 않았어요."))
        }
    }

    private func stopWatching(_ s: Status) {
        watchTimer?.invalidate()
        watchTimer = nil
        status = s
    }

    func openLog() {
        NSWorkspace.shared.open(logURL)
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

// MARK: - 여러 줄 입력칸
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

/// 여러 줄 입력칸 + 빈 칸일 때 안내 글씨
struct EditableText: View {
    let placeholder: String
    @Binding var text: String
    let style: EditorStyle
    let done: Bool
    let field: Field
    @Binding var focus: Field?
    @Environment(\.personalColor) private var personalColor

    var body: some View {
        WrappingTextView(text: $text, style: style, done: done, tint: NSColor(personalColor),
                         field: field, focus: $focus)
            .overlay(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder)
                        .font(Font(style.font as CTFont))
                        .foregroundColor(Color(nsColor: .placeholderTextColor))
                        .allowsHitTesting(false)
                }
            }
            .alignmentGuide(.firstTextBaseline) { _ in style.baseline }
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

/// 패널 위쪽 업데이트 안내 (새 버전 / 설치 중 / 실패)
struct UpdateBanner: View {
    @ObservedObject var updater: Updater
    @Environment(\.personalColor) private var personalColor

    var body: some View {
        switch updater.status {
        case .idle:
            EmptyView()
        case .available:
            row(icon: "arrow.down.circle.fill", text: "새 버전이 있어요") {
                Button("업데이트") { updater.install() }
            }
        case .updating:
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("업데이트 중… 끝나면 다시 켜져요").font(.callout)
                Spacer(minLength: 0)
            }
            .modifier(BannerBackground())
        case .failed(let message):
            row(icon: "exclamationmark.triangle.fill", text: message) {
                if FileManager.default.fileExists(atPath: updater.logURL.path) {
                    Button("기록") { updater.openLog() }
                }
                Button("다시 시도") { updater.install() }
            }
        }
    }

    private func row<Buttons: View>(icon: String, text: String,
                                    @ViewBuilder buttons: () -> Buttons) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundColor(personalColor)
            Text(text).font(.callout)
            Spacer(minLength: 0)
            buttons().controlSize(.small)
        }
        .modifier(BannerBackground())
    }
}

struct BannerBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
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
                            .onChanged { onDragChanged($0.location.y) }
                            .onEnded { _ in onDragEnded() }
                    )
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

struct TodoPanelView: View {
    @ObservedObject var store: TodoStore
    @ObservedObject var settings: AppSettings
    @ObservedObject var updater: Updater
    @State private var focus: Field?
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
            UpdateBanner(updater: updater)
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

// MARK: - 앱

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    let store = TodoStore()
    let bubbleState = BubbleState()
    let settings = AppSettings()
    let updater = Updater()
    let updateItem = NSMenuItem(title: "업데이트 확인…", action: nil, keyEquivalent: "")
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
                              state: bubbleState, settings: settings, updater: updater)
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
        updateItem.target = self
        menu.addItem(updateItem)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "종료", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "")
        quit.target = NSApp
        menu.addItem(quit)
        menu.autoenablesItems = false
        menu.delegate = self   // 열 때마다 업데이트 항목을 상태에 맞게 바꾸기
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
        let host = FirstMouseHostingView(rootView: TodoPanelView(store: store, settings: settings, updater: updater))
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

        updater.start()
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
            popup.makeFirstResponder(nil)   // 입력 중이던 글자(한글 조합 포함)를 확정한 뒤 저장
            store.save()
            popup.orderOut(nil)
            bubbleState.open = false
        } else {
            positionPopup()
            popup.orderFrontRegardless()
            bubbleState.open = true
            updater.checkIfStale()
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

    func menuNeedsUpdate(_ menu: NSMenu) {
        updateItem.isEnabled = true
        switch updater.status {
        case .available:
            updateItem.title = "업데이트 설치"
            updateItem.action = #selector(installUpdate)
        case .updating:
            updateItem.title = "업데이트 중…"
            updateItem.isEnabled = false
        case .idle, .failed:
            updateItem.title = "업데이트 확인…"
            updateItem.action = #selector(checkForUpdates)
        }
    }

    @objc func installUpdate() { updater.install() }

    @objc func checkForUpdates() {
        Task {
            let result = await updater.check()
            let alert = NSAlert()
            switch result {
            case .upToDate:
                alert.messageText = "최신 버전이에요."
            case .available:
                alert.messageText = "새 버전이 있어요."
                alert.informativeText = "업데이트하면 잠깐 꺼졌다가 다시 켜져요. 할 일은 그대로 남아 있어요."
                alert.addButton(withTitle: "업데이트")
                alert.addButton(withTitle: "나중에")
            case .unknownVersion:
                alert.messageText = "설치된 버전을 알 수 없어요."
                alert.informativeText = "설치 명령어(curl …)로 설치한 경우에만 업데이트를 확인할 수 있어요."
            case .failed:
                alert.messageText = "업데이트를 확인하지 못했어요."
                alert.informativeText = "인터넷 연결을 확인하고 잠시 뒤 다시 시도해 주세요."
            }
            if alert.buttons.isEmpty { alert.addButton(withTitle: "확인") }
            NSApp.activate(ignoringOtherApps: true)   // Dock 없는 앱이라 앞으로 가져와야 창이 보임
            if alert.runModal() == .alertFirstButtonReturn && result == .available {
                updater.install()
            }
        }
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
