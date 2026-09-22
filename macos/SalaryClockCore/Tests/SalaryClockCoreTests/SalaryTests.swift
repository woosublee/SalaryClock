import Testing
import Foundation
@testable import SalaryClockCore

struct EarningsCase: Decodable {
    struct Expected: Decodable {
        let phase: String
        let earned: Double
        let perSecond: Double
        let progress: Double
        let elapsedPaidMs: Int
        let totalPaidMs: Int
        let msUntilStart: Int
        let msUntilEnd: Int
        let msUntilLunchEnd: Int
        let remainingAmount: Double
        let dailyTotal: Double
        let workDays: Double
        let deductionRate: Double
        let hasShift: Bool
    }
    let label: String
    let settings: String
    let at: [Int]
    let expected: Expected
}

@Test("골든 — earnings")
func goldenEarnings() throws {
    let settings: [String: Settings] = try Golden.decode("settings.json", as: [String: Settings].self)
    let cases: [EarningsCase] = try Golden.decode("earnings.json", as: [EarningsCase].self)
    #expect(cases.count > 0)

    for c in cases {
        let s = try #require(settings[c.settings], "알 수 없는 설정: \(c.settings)")
        let e = computeEarnings(s, Golden.ms(c.at))
        let what = "\(c.label) (\(c.settings))"

        #expect(e.phase.rawValue == c.expected.phase, "\(what) phase")
        expectClose(e.earned, c.expected.earned, "\(what) earned")
        expectClose(e.perSecond, c.expected.perSecond, "\(what) perSecond")
        expectClose(e.progress, c.expected.progress, "\(what) progress")
        #expect(e.elapsedPaidMs == c.expected.elapsedPaidMs, "\(what) elapsedPaidMs")
        #expect(e.totalPaidMs == c.expected.totalPaidMs, "\(what) totalPaidMs")
        #expect(e.msUntilStart == c.expected.msUntilStart, "\(what) msUntilStart")
        #expect(e.msUntilEnd == c.expected.msUntilEnd, "\(what) msUntilEnd")
        #expect(e.msUntilLunchEnd == c.expected.msUntilLunchEnd, "\(what) msUntilLunchEnd")
        expectClose(e.remainingAmount, c.expected.remainingAmount, "\(what) remainingAmount")
        expectClose(e.dailyTotal, c.expected.dailyTotal, "\(what) dailyTotal")
        expectClose(e.workDays, c.expected.workDays, "\(what) workDays")
        expectClose(e.deductionRate, c.expected.deductionRate, "\(what) deductionRate")
        #expect((e.shift != nil) == c.expected.hasShift, "\(what) hasShift")
    }
}

@Test("야간근무가 월 경계를 넘어도 금액이 튀지 않는다")
func noMidnightJump() throws {
    let settings: [String: Settings] = try Golden.decode("settings.json", as: [String: Settings].self)
    let night = try #require(settings["night"])

    let before = computeEarnings(night, Golden.ms([2026, 11, 31, 23, 59, 59]))
    let after = computeEarnings(night, Golden.ms([2027, 0, 1, 0, 0, 1]))

    #expect(before.workDays == after.workDays, "근무일수가 자정에 바뀌면 안 된다")
    expectClose(after.perSecond, before.perSecond, "초당 단가")
    // 2초치 적립분만 늘어야 한다
    let delta = after.earned - before.earned
    expectClose(delta, before.perSecond * 2, "2초 적립분")
}
