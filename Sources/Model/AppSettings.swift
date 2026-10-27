// 퍼스널 컬러 설정과 SwiftUI 환경값

import AppKit
import SwiftUI

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

/// 패널 위쪽 탭
enum PanelTab: String {
    case todo, calendar
}

@MainActor
final class AppSettings: ObservableObject {
    static let presets = ["#0A84FF", "#5E5CE6", "#BF5AF2", "#FF375F", "#FF9F0A", "#30D158", "#40C8E0"]
    private let colorKey = "personalColor"

    @Published var colorHex: String {
        didSet { UserDefaults.standard.set(colorHex, forKey: colorKey) }
    }

    /// 마지막으로 보던 탭 (다음에 열 때도 그대로)
    @Published var tab: PanelTab {
        didSet { UserDefaults.standard.set(tab.rawValue, forKey: tabKey) }
    }
    private let tabKey = "panelTab"

    /// 달력 탭에서 고른 날 (저장하지 않음. 날짜가 바뀐 뒤 패널을 열면 오늘로 돌아감)
    @Published var selectedDay = Day.today

    init() {
        colorHex = UserDefaults.standard.string(forKey: colorKey) ?? "#0A84FF"
        tab = UserDefaults.standard.string(forKey: tabKey).flatMap(PanelTab.init(rawValue:)) ?? .todo
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
