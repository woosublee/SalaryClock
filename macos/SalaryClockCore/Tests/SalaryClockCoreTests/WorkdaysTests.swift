import Testing
import Foundation
@testable import SalaryClockCore

struct WorkdaysGolden: Decodable {
    struct Case: Decodable {
        struct Expected: Decodable {
            let autoWorkDays: Double
            let isDayOff: Bool
            let isDayOffWithOverride: Bool
        }
        let at: [Int]
        let expected: Expected
    }
    let overrides: [String]
    let cases: [Case]
}

@Test("골든 — workdays")
func goldenWorkdays() throws {
    let g: WorkdaysGolden = try Golden.decode("workdays.json", as: WorkdaysGolden.self)
    #expect(g.cases.count > 0)

    for c in g.cases {
        let now = Golden.ms(c.at)
        let what = c.at.map(String.init).joined(separator: ",")

        expectClose(effectiveWorkDays(.default, now), c.expected.autoWorkDays, "\(what) autoWorkDays")
        #expect(isDayOff([], now) == c.expected.isDayOff, "\(what) isDayOff")
        #expect(
            isDayOff(g.overrides, now) == c.expected.isDayOffWithOverride,
            "\(what) isDayOffWithOverride"
        )
    }
}

@Test("공휴일 표가 없는 해는 주말만 뺀다")
func noHolidayTable() {
    #expect(hasHolidayData(2026))
    #expect(hasHolidayData(2027))
    #expect(!hasHolidayData(2028))
    let info = workdayInfo(Golden.ms([2028, 8, 22, 12, 0, 0]))
    #expect(info.holidays == 0)
    #expect(info.workdays == info.weekdays)
}

@Test("2026년 9월은 근무일 20일 — 평일 22일에서 추석 평일 2일을 뺀다")
func september2026() {
    let info = workdayInfo(Golden.ms([2026, 8, 22, 12, 0, 0]))
    #expect(info.weekdays == 22)
    #expect(info.holidays == 2)
    #expect(info.workdays == 20)
}

@Test("dateKey는 웹과 같은 문자열을 만든다")
func dateKeyFormat() {
    #expect(dateKey(2026, 8, 22) == "2026-09-22")
    #expect(dateKey(2026, 0, 1) == "2026-01-01")
}
