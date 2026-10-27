// 달력 할 일의 날짜 규칙 (날짜 키, 보관 기간)

import Foundation

enum Day {
    /// 오늘을 포함해 최근 며칠까지 보관할지. 그보다 오래된 날은 지우고 달력에서도 고를 수 없음
    static let keepDays = 7

    /// 날짜마다 할 일을 나눠 저장하는 키 ("2026-10-27"). 글자 순서가 곧 날짜 순서
    static func key(for date: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    static var today: Date { Calendar.current.startOfDay(for: Date()) }

    /// 고를 수 있는 가장 이른 날 (이 날보다 앞은 지워짐)
    static var earliest: Date {
        Calendar.current.date(byAdding: .day, value: -(keepDays - 1), to: today) ?? today
    }

    static func startOfMonth(_ date: Date) -> Date {
        Calendar.current.dateInterval(of: .month, for: date)?.start ?? today
    }
}
