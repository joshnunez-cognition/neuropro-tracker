import Foundation

/// Rolling fixed-length cycles anchored at a start date.
///
/// Day numbering is purely date based: the day after Day 14 is Day 1 of the
/// next cycle regardless of whether every day was logged.
struct CycleManager: Sendable {
    var startDate: Date
    var cycleLength: Int
    var calendar: Calendar

    init(
        startDate: Date,
        cycleLength: Int = PlacementConfiguration.rotationWindowDays,
        calendar: Calendar = .current
    ) {
        self.startDate = calendar.startOfDay(for: startDate)
        self.cycleLength = cycleLength
        self.calendar = calendar
    }

    /// Whole days since the cycle start (negative before the start).
    func dayOffset(for date: Date) -> Int {
        let day = calendar.startOfDay(for: date)
        return calendar.dateComponents([.day], from: startDate, to: day).day ?? 0
    }

    /// Zero-based index of the cycle containing `date`.
    func cycleIndex(for date: Date) -> Int {
        let offset = dayOffset(for: date)
        return offset >= 0 ? offset / cycleLength : Int((Double(offset) / Double(cycleLength)).rounded(.down))
    }

    /// 1-based day number within the cycle (1...cycleLength).
    func cycleDay(for date: Date) -> Int {
        let offset = dayOffset(for: date)
        let mod = ((offset % cycleLength) + cycleLength) % cycleLength
        return mod + 1
    }

    func cycleID(for date: Date) -> String {
        "cycle-\(cycleIndex(for: date) + 1)"
    }

    /// Human readable cycle number (1-based).
    func cycleNumber(for date: Date) -> Int {
        cycleIndex(for: date) + 1
    }

    func startDate(ofCycleContaining date: Date) -> Date {
        calendar.date(byAdding: .day, value: cycleIndex(for: date) * cycleLength, to: startDate) ?? startDate
    }

    /// Calendar date for a given day of the cycle that contains `reference`.
    func date(forCycleDay day: Int, inCycleContaining reference: Date) -> Date {
        let start = startDate(ofCycleContaining: reference)
        return calendar.date(byAdding: .day, value: day - 1, to: start) ?? start
    }

    static func daysBetween(_ from: Date, _ to: Date, calendar: Calendar = .current) -> Int {
        calendar.dateComponents(
            [.day], from: calendar.startOfDay(for: from), to: calendar.startOfDay(for: to)
        ).day ?? 0
    }
}
