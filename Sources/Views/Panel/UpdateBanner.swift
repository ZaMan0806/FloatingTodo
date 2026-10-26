// 패널 위쪽 업데이트 안내

import SwiftUI

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
