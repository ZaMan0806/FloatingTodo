// 할 일과 체크포인트 데이터 (todos.json 에 그대로 저장됨)

import Foundation

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
