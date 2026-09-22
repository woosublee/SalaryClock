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

// 2026년 9월: 30일, 평일 22일, 평일 추석 2일(09-24, 09-25) → auto 20일.
// 09-26도 추석이지만 토요일이라 이미 쉬는 날이라 평일 공휴일 수에 안 들어간다.

@Test("manual 모드는 달력과 무관하게 입력값을 그대로 돌려준다")
func manualIgnoresCalendar() {
    let now = Golden.ms([2026, 8, 22, 12, 0, 0])

    var s = Settings.default
    s.workDaysMode = .manual
    s.workDaysPerMonth = 21
    #expect(effectiveWorkDays(s, now) == 21)

    // auto 값(20)과 우연히 같아서 통과하는 게 아님을 확인하는 값
    s.workDaysPerMonth = 18
    #expect(effectiveWorkDays(s, now) == 18)
}

@Test("calendar 모드는 override가 없으면 auto와 같다")
func calendarMatchesAutoWithNoOverrides() {
    let now = Golden.ms([2026, 8, 22, 12, 0, 0])

    var s = Settings.default
    s.workDaysMode = .calendar
    s.dayOverrides = []
    #expect(effectiveWorkDays(s, now) == 20)
}

@Test("calendar 모드에서 평일을 쉬는 날로 표시하면 하루 준다")
func calendarWeekdayOverrideOff() {
    let now = Golden.ms([2026, 8, 22, 12, 0, 0])

    var s = Settings.default
    s.workDaysMode = .calendar
    s.dayOverrides = ["2026-09-22"]  // 화요일
    #expect(effectiveWorkDays(s, now) == 19)
}

@Test("calendar 모드에서 주말을 근무일로 표시하면 하루 는다")
func calendarWeekendOverrideOn() {
    let now = Golden.ms([2026, 8, 22, 12, 0, 0])

    var s = Settings.default
    s.workDaysMode = .calendar
    s.dayOverrides = ["2026-09-26"]  // 토요일(추석 연휴)
    #expect(effectiveWorkDays(s, now) == 21)
}

@Test("calendar 모드에서 공휴일을 근무일로 표시하면 하루 는다")
func calendarHolidayOverrideOn() {
    let now = Golden.ms([2026, 8, 22, 12, 0, 0])

    var s = Settings.default
    s.workDaysMode = .calendar
    s.dayOverrides = ["2026-09-24"]  // 평일 추석
    #expect(effectiveWorkDays(s, now) == 21)
}

@Test("calendar 모드는 달 밖의 override를 무시한다")
func calendarOverrideOutsideMonthIgnored() {
    let now = Golden.ms([2026, 8, 22, 12, 0, 0])

    var s = Settings.default
    s.workDaysMode = .calendar
    s.dayOverrides = ["2026-08-15"]  // 8월, 계산 대상은 9월
    #expect(effectiveWorkDays(s, now) == 20)
}

/// workdayInfo는 (연, 월)로 캐시한다. 키가 달을 제대로 가르는지, 그리고 같은
/// 달을 여러 번 물어도 답이 흔들리지 않는지 본다.
@Test("workdayInfo 캐시는 달을 가르고 같은 달에는 같은 답을 준다")
func workdayInfoCacheKeysOnMonth() {
    let sepStart = workdayInfo(Golden.ms([2026, 8, 1, 0, 0, 0]))
    let sepEnd = workdayInfo(Golden.ms([2026, 8, 30, 23, 59, 59]))
    #expect(sepStart.weekdays == 22)
    #expect(sepStart.workdays == 20)
    #expect(sepEnd.weekdays == sepStart.weekdays)
    #expect(sepEnd.workdays == sepStart.workdays)

    // 2026년 2월은 평일 20일 · 설 연휴 평일 3일 → 근무 17일. 키가 달을
    // 안 가르면 9월 값이 그대로 나온다.
    let feb = workdayInfo(Golden.ms([2026, 1, 15, 12, 0, 0]))
    #expect(feb.weekdays == 20)
    #expect(feb.workdays == 17)

    // 해가 달라도 갈라져야 한다 — 키를 month만으로 잡으면 여기서 걸린다.
    let sep2028 = workdayInfo(Golden.ms([2028, 8, 15, 12, 0, 0]))
    #expect(sep2028.hasHolidayData == false)
    #expect(sep2028.workdays == sep2028.weekdays)

    // weekdaysInMonth도 같은 캐시를 읽는다.
    #expect(weekdaysInMonth(Golden.ms([2026, 8, 15, 12, 0, 0])) == 22)
}
