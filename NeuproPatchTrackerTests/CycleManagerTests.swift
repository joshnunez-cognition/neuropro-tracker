import Foundation
import Testing
@testable import NeuproPatchTracker

struct CycleManagerTests {
    let calendar = Calendar(identifier: .gregorian)
    var start: Date { calendar.date(from: DateComponents(year: 2026, month: 3, day: 1))! }
    var manager: CycleManager { CycleManager(startDate: start, calendar: calendar) }

    private func day(_ offset: Int) -> Date { calendar.date(byAdding: .day, value: offset, to: start)! }

    @Test func startDateIsDayOne() {
        #expect(manager.cycleDay(for: start) == 1)
        #expect(manager.cycleNumber(for: start) == 1)
    }

    @Test func dayFourteenThenRollsToDayOne() {
        #expect(manager.cycleDay(for: day(13)) == 14)
        #expect(manager.cycleNumber(for: day(13)) == 1)
        #expect(manager.cycleDay(for: day(14)) == 1)
        #expect(manager.cycleNumber(for: day(14)) == 2)
        #expect(manager.cycleID(for: day(13)) != manager.cycleID(for: day(14)))
    }

    @Test func timeOfDayDoesNotAffectCycleDay() {
        let evening = calendar.date(bySettingHour: 23, minute: 59, second: 0, of: day(13))!
        #expect(manager.cycleDay(for: evening) == 14)
    }

    @Test func datesBeforeStartWrapConsistently() {
        #expect(manager.cycleDay(for: day(-1)) == 14)
        #expect(manager.cycleNumber(for: day(-1)) == 0)
    }

    @Test func dateForCycleDayRoundTrips() {
        let d = manager.date(forCycleDay: 7, inCycleContaining: day(20))
        #expect(manager.cycleDay(for: d) == 7)
        #expect(manager.cycleID(for: d) == manager.cycleID(for: day(20)))
    }

    @Test func daysBetweenIgnoresTime() {
        let a = calendar.date(bySettingHour: 22, minute: 0, second: 0, of: start)!
        let b = calendar.date(bySettingHour: 1, minute: 0, second: 0, of: day(1))!
        #expect(CycleManager.daysBetween(a, b, calendar: calendar) == 1)
    }
}
