// 달력 탭: 위에는 한 달 달력, 아래에는 고른 날의 할 일

import SwiftUI

struct CalendarView: View {
    @ObservedObject var store: TodoStore
    @Binding var selected: Date      // 고른 날 (그날 0시)
    @Binding var focus: Field?

    var body: some View {
        if let err = store.calendarError {
            Text(err).foregroundColor(.red).font(.callout)
        } else {
            // 패널이 작아도 쓸 수 있게 달력과 목록을 함께 스크롤
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    MonthGrid(store: store, selected: $selected)
                    Divider()
                    Text(selected, format: .dateTime.month().day().weekday(.wide))
                        .font(.headline)
                    dayList
                }
            }
            .onAppear {
                store.pruneOldDays()
                if selected < Day.earliest { selected = Day.today }   // 며칠 켜 둔 사이 보관 기간이 지났으면
            }
        }
    }

    @ViewBuilder
    private var dayList: some View {
        let key = Day.key(for: selected)
        let todos = Binding<[Todo]>(
            get: { store.days[key] ?? [] },
            set: { store.days[key] = $0.isEmpty ? nil : $0 }
        )
        if todos.wrappedValue.isEmpty {
            Text("+ 버튼으로 이 날의 할 일을 추가하세요")
                .foregroundColor(.secondary).font(.callout)
        } else {
            ReorderableStack(items: todos, onDragStart: { focus = nil }) { todo, handle in
                let id = todo.wrappedValue.id
                TodoCard(todo: todo,
                         focus: $focus,
                         handle: handle,
                         onDelete: { store.deleteTodo(id, on: key) },
                         onAddCheckpoint: {
                             if let cid = store.addCheckpoint(to: id, on: key) {
                                 focus = .checkpoint(cid)
                             }
                         })
            }
        }
    }
}

/// 한 달 달력. 보관 기간 밖의 날은 흐리게 표시하고 고를 수 없음
struct MonthGrid: View {
    @ObservedObject var store: TodoStore
    @Binding var selected: Date
    @Environment(\.personalColor) private var personalColor
    @ViewState private var month = Day.startOfMonth(Day.today)

    private let weekdaySymbols = ["일", "월", "화", "수", "목", "금", "토"]

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                IconButton("chevron.left", help: "이전 달") { moveMonth(-1) }
                    .disabled(month <= Day.earliest)   // 이전 달은 전부 보관 기간 밖
                    .opacity(month <= Day.earliest ? 0.3 : 1)
                Spacer()
                Text(month, format: .dateTime.year().month(.wide))
                    .font(.callout.weight(.semibold))
                Spacer()
                Button("오늘") {
                    selected = Day.today
                    month = Day.startOfMonth(Day.today)
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundColor(.secondary)
                IconButton("chevron.right", help: "다음 달") { moveMonth(1) }
            }

            let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(0..<7, id: \.self) { i in
                    Text(weekdaySymbols[(i + Calendar.current.firstWeekday - 1) % 7])
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                ForEach(Array(cells.enumerated()), id: \.offset) { _, date in
                    if let date {
                        dayCell(date)
                    } else {
                        Color.clear.frame(height: 30)
                    }
                }
            }
        }
        .onAppear { month = Day.startOfMonth(selected) }
        .onChange(of: selected) { day in month = Day.startOfMonth(day) }   // '오늘'·날짜 바뀜 등으로 고른 날이 바뀌면 그 달로
    }

    /// 달력 칸: 앞쪽 빈칸(nil) + 그 달의 날짜들
    private var cells: [Date?] {
        let cal = Calendar.current
        let count = cal.range(of: .day, in: .month, for: month)?.count ?? 30
        let leading = (cal.component(.weekday, from: month) - cal.firstWeekday + 7) % 7
        let dates: [Date?] = (0..<count).map { cal.date(byAdding: .day, value: $0, to: month) }
        return Array(repeating: nil, count: leading) + dates
    }

    private func moveMonth(_ delta: Int) {
        if let m = Calendar.current.date(byAdding: .month, value: delta, to: month) { month = m }
    }

    private func dayCell(_ date: Date) -> some View {
        let cal = Calendar.current
        let available = date >= Day.earliest
        let isSelected = cal.isDate(date, inSameDayAs: selected)
        let isToday = cal.isDateInToday(date)
        let todos = store.days[Day.key(for: date)] ?? []
        let remaining = todos.filter { !$0.isDone }.count

        return Button { selected = date } label: {
            VStack(spacing: 1) {
                Text("\(cal.component(.day, from: date))")
                    .font(.callout.weight(isToday ? .bold : .regular))
                    .monospacedDigit()
                    .foregroundColor(isSelected ? .white : (available ? .primary : .secondary))
                    .frame(width: 24, height: 22)
                    .background(Circle().fill(isSelected ? personalColor : Color.clear))
                    .overlay(Circle().strokeBorder(personalColor, lineWidth: isToday && !isSelected ? 1.2 : 0))
                // 할 일이 남았으면 점, 다 했으면 체크
                ZStack {
                    if !todos.isEmpty && remaining == 0 {
                        Image(systemName: "checkmark")
                            .font(.system(size: 6, weight: .heavy))
                            .foregroundColor(personalColor)
                    } else if remaining > 0 {
                        Circle().fill(personalColor).frame(width: 5, height: 5)
                    }
                }
                .frame(height: 6)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .opacity(available ? 1 : 0.35)
        }
        .buttonStyle(.plain)
        .disabled(!available)
        .help(available ? "" : "\(Day.keepDays)일이 지난 날은 지워져서 볼 수 없어요")
    }
}
