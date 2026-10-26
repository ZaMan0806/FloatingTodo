// 업데이트 확인·설치 (GitHub main 브랜치의 최신 커밋과 설치된 버전 비교)

import AppKit
import Combine

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
