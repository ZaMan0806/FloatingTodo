// 할 일 목록을 읽고 저장

import Foundation
import Combine

@MainActor
final class TodoStore: ObservableObject {
    @Published var items: [Todo] = [] { didSet { scheduleSave(); dropUndoIfEdited() } }
    @Published var loadError: String?
    @Published private(set) var undoMessage: String?   // 있으면 패널 아래에 '되돌리기'가 보임
    let fileURL: URL
    private var saveTask: Task<Void, Never>?
    private var undoSnapshot: [Todo]?
    private var undoTimer: Task<Void, Never>?
    private var deleting = false

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
        recordDeletion("할 일을 삭제했어요")
        items.removeAll { $0.id == id }
    }

    /// 지우기 직전에 호출: 지금 목록을 기억해 두고 잠깐 동안 되돌릴 수 있게 함
    func recordDeletion(_ message: String) {
        undoSnapshot = items
        undoMessage = message
        deleting = true
        undoTimer?.cancel()
        undoTimer = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 6_000_000_000)
            guard !Task.isCancelled else { return }
            self?.clearUndo()
        }
    }

    func undoDeletion() {
        guard let snapshot = undoSnapshot else { return }
        clearUndo()
        items = snapshot
    }

    /// 지운 뒤에 다른 걸 고치면 되돌리기를 없앰 (예전 목록으로 덮어써서 그 수정이 사라지지 않게)
    private func dropUndoIfEdited() {
        if deleting {
            deleting = false
        } else if undoSnapshot != nil {
            clearUndo()
        }
    }

    private func clearUndo() {
        undoTimer?.cancel()
        undoTimer = nil
        undoSnapshot = nil
        undoMessage = nil
    }

    func addCheckpoint(to todoID: UUID) -> UUID? {
        guard let i = items.firstIndex(where: { $0.id == todoID }) else { return nil }
        let c = Checkpoint()
        items[i].checkpoints.append(c)
        items[i].collapsed = false
        return c.id
    }
}
