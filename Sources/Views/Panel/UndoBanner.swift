// 지운 직후 잠깐 보이는 '되돌리기' 안내

import SwiftUI

struct UndoBanner: View {
    let message: String
    let onUndo: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "trash").foregroundColor(.secondary)
            Text(message).font(.callout)
            Spacer(minLength: 0)
            Button("되돌리기", action: onUndo).controlSize(.small)
        }
        .modifier(BannerBackground())
    }
}

/// 체크포인트처럼 목록 안쪽에서 지울 때도 TodoStore 가 지우기 직전 상태를 기억하도록 넘겨주는 동작
private struct RecordDeletionKey: EnvironmentKey {
    static let defaultValue: (String) -> Void = { _ in }
}

extension EnvironmentValues {
    var recordDeletion: (String) -> Void {
        get { self[RecordDeletionKey.self] }
        set { self[RecordDeletionKey.self] = newValue }
    }
}
