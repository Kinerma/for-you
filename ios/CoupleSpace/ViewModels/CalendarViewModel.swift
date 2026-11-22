import SwiftUI
import Observation

@Observable
final class CalendarViewModel {
    var month: Date
    var selectedDate: Date

    init() {
        let today = Calendar.current.startOfDay(for: Date())
        selectedDate = today
        month = Calendar.current.dateInterval(of: .month, for: today)?.start ?? today
    }

    func shiftMonth(_ delta: Int, calendar: Calendar) {
        if let m = calendar.date(byAdding: .month, value: delta, to: month) {
            month = m
        }
    }

    func goToToday(calendar: Calendar) {
        let today = calendar.startOfDay(for: Date())
        selectedDate = today
        month = calendar.dateInterval(of: .month, for: today)?.start ?? today
    }

    /// Ячейки месячной сетки: nil — пустая ячейка до первого числа.
    func gridDays(calendar: Calendar) -> [Date?] {
        guard let interval = calendar.dateInterval(of: .month, for: month),
              let range = calendar.range(of: .day, in: .month, for: month) else { return [] }
        let firstWeekday = calendar.component(.weekday, from: interval.start)
        let leading = (firstWeekday - calendar.firstWeekday + 7) % 7
        var cells: [Date?] = Array(repeating: nil, count: leading)
        for day in range {
            cells.append(calendar.date(byAdding: .day, value: day - 1, to: interval.start))
        }
        return cells
    }

    func weekdaySymbols(calendar: Calendar) -> [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let shift = calendar.firstWeekday - 1
        return Array(symbols[shift...] + symbols[..<shift])
    }
}
