import Testing
import Foundation
@testable import SalaryClockCore

struct ShiftCase: Decodable {
    struct Expected: Decodable {
        let start: [Int]
        let end: [Int]
        let lunchStart: [Int]?
        let lunchEnd: [Int]?
        let paidMs: Int
    }
    let label: String
    let settings: String
    let at: [Int]
    let expected: Expected
}

@Test("골든 — shift")
func goldenShift() throws {
    let settings: [String: Settings] = try Golden.decode("settings.json", as: [String: Settings].self)
    let cases: [ShiftCase] = try Golden.decode("shift.json", as: [ShiftCase].self)
    #expect(cases.count > 0)

    for c in cases {
        let s = try #require(settings[c.settings], "알 수 없는 설정: \(c.settings)")
        let got = resolveShift(s, Golden.ms(c.at))
        let what = "\(c.label) (\(c.settings))"

        #expect(got.startMs == Golden.ms(c.expected.start), "\(what) startMs")
        #expect(got.endMs == Golden.ms(c.expected.end), "\(what) endMs")
        #expect(got.lunchStartMs == Golden.msOrNull(c.expected.lunchStart), "\(what) lunchStartMs")
        #expect(got.lunchEndMs == Golden.msOrNull(c.expected.lunchEnd), "\(what) lunchEndMs")
        #expect(got.paidMs == c.expected.paidMs, "\(what) paidMs")
    }
}

@Test("paidMsBetween — 점심을 가로지르면 점심만큼 뺀다")
func paidMsAcrossLunch() {
    let shift = resolveShift(.default, Golden.ms([2026, 8, 22, 14, 0, 0]))
    let from = Golden.ms([2026, 8, 22, 11, 0, 0])
    let to = Golden.ms([2026, 8, 22, 14, 0, 0])
    #expect(paidMsBetween(shift, from, to) == 2 * MS_PER_HOUR)
}

@Test("paidMsBetween — 시프트 밖은 잘라낸다")
func paidMsClamps() {
    let shift = resolveShift(.default, Golden.ms([2026, 8, 22, 14, 0, 0]))
    #expect(paidMsBetween(shift, shift.startMs - MS_PER_HOUR, shift.startMs) == 0)
    #expect(paidMsBetween(shift, shift.endMs, shift.endMs + MS_PER_HOUR) == 0)
    #expect(paidMsBetween(shift, shift.startMs, shift.endMs) == shift.paidMs)
}

/// 야간근무(22:00–06:00). 점심은 골든의 night 설정과 같이 01:00부터 60분.
private let night: Settings = {
    var s = Settings.default
    s.workStart = "22:00"
    s.workEnd = "06:00"
    s.lunchEnabled = true
    s.lunchStart = "01:00"
    s.lunchMinutes = 60
    return s
}()

/// 2026-09-22(화) 그날의 시각 → epoch ms
private func at(_ h: Int, _ m: Int = 0, _ s: Int = 0) -> Int {
    Golden.ms([2026, 8, 22, h, m, s])
}

/// 어제 시프트는 오늘 06:00에 끝나므로 "오늘 안에 끝났는가"만 보면 21:00에도
/// 그게 걸려, 출근 1시간 전에 어제 총액이 남는다. 06:00과 22:00의 중간점인
/// 14:00을 지나면 오늘 출근 쪽으로 넘어가야 한다.
@Test("야간근무 — 저녁 21:00에는 오늘 출근할 시프트를 고른다")
func nightBeforeWork() {
    let shift = resolveShift(night, at(21))
    #expect(shift.startMs == at(22))
    #expect(shift.endMs == at(6) + MS_PER_DAY)
}

@Test("야간근무 — 중간점 정각(14:00)까지는 방금 끝난 어제 시프트를 유지한다")
func nightKeepsEndedUntilMidpoint() {
    #expect(resolveShift(night, at(14)).startMs == at(22) - MS_PER_DAY)
    #expect(resolveShift(night, at(12)).startMs == at(22) - MS_PER_DAY)
}

@Test("야간근무 — 중간점을 1ms라도 지나면 오늘 시프트로 넘어간다")
func nightSwitchesPastMidpoint() {
    #expect(resolveShift(night, at(14) + 1).startMs == at(22))
}

@Test("야간근무 — 아침 07:00에는 방금 끝난 시프트를 유지한다")
func nightJustFinished() {
    #expect(resolveShift(night, at(7)).startMs == at(22) - MS_PER_DAY)
}

@Test("주간근무 — 자정 직후에는 어제 총액을 버리고 오늘 시프트를 고른다")
func dayShiftResetsAtMidnight() {
    #expect(resolveShift(.default, at(0, 30)).startMs == at(9))
    #expect(resolveShift(.default, at(20)).startMs == at(9))
}

@Test("야간근무 — 출근 1시간 전 21:00의 phase는 before다")
func nightPhaseBeforeAt21() {
    let e = computeEarnings(night, at(21))
    #expect(e.phase == .before)
    #expect(e.msUntilStart == MS_PER_HOUR)
    #expect(e.earned == 0)
}
