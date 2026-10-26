// 퍼스널 컬러 고르기

import SwiftUI

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
