import Foundation
import Testing
@testable import SalaryClockAppLib
import SalaryClockCore

/// 2026-09-22(화)의 로컬 시각 → epoch ms. computeEarnings도 로컬 시간대로 푼다.
private func at(_ h: Int, _ m: Int, _ s: Int, ms: Int = 0) -> Int {
    let d = Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 22, hour: h, minute: m, second: s))!
    return Int(d.timeIntervalSince1970 * 1000) + ms
}

private func delay(_ now: Int, hide: Bool = false, popover: Bool = false) -> TimeInterval {
    nextTickDelay(computeEarnings(.default, now), hideAmount: hide, popoverShown: popover, interval: 1, now: now)
}

@Test("근무 중이면 사용자가 고른 주기로 돈다")
func workingUsesInterval() {
    #expect(delay(at(10, 0, 30)) == 1)
}

@Test("팝오버가 열려 있으면 근무 여부와 상관없이 다음 0.1초 눈금까지")
func popoverIsFast() {
    #expect(abs(delay(at(10, 0, 30), popover: true) - 0.101) < 1e-9)
    #expect(abs(delay(at(20, 0, 30), popover: true) - 0.101) < 1e-9)
}

@Test("팝오버 tick은 처리가 늦어져도 0.1초 눈금으로 돌아온다 — 간격이 밀리지 않는다")
func popoverSnapsToGrid() {
    // 눈금에서 37ms 늦게 깨어났어도 다음 깨어남은 다음 눈금(+1ms)이다.
    let late = at(10, 0, 30, ms: 137)
    let wake = late + Int((delay(late, popover: true) * 1000).rounded())
    #expect(wake % 100 == 1)
    #expect(wake - late == 64)
}

@Test("퇴근 후에는 다음 분의 경계까지 한 번만 기다린다")
func afterWorkWaitsForNextMinute() {
    #expect(abs(delay(at(20, 0, 30, ms: 250)) - 29.751) < 1e-9)
}

@Test("출근 전에도 분 경계에 깨어나므로 출근 시각(정각)을 놓치지 않는다")
func beforeWorkHitsStartBoundary() {
    let now = at(8, 59, 59, ms: 500)
    let wake = now + Int(delay(now) * 1000)
    #expect(wake > at(9, 0, 0))
    #expect(computeEarnings(.default, wake).phase == .working)
}

@Test("점심과 금액 가리기는 금액이 바뀌지 않으므로 분 단위")
func lunchAndHiddenAreMinutely() {
    #expect(delay(at(12, 30, 0)) > 59)
    #expect(delay(at(10, 0, 0), hide: true) > 59)
}
