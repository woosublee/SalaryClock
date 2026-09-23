import Testing
import Foundation
@testable import SalaryClockAppLib
import SalaryClockCore

private func at(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int, _ s: Int) -> Int {
    var c = DateComponents()
    c.year = y; c.month = mo + 1; c.day = d; c.hour = h; c.minute = mi; c.second = s
    return Int((Calendar.current.date(from: c)!.timeIntervalSince1970 * 1000).rounded())
}

@Test("근무 중에는 정수 금액을 보여준다")
func titleWhileWorking() {
    let e = computeEarnings(.default, at(2026, 8, 22, 14, 0, 0))
    let title = menuBarTitle(e, hideAmount: false)
    #expect(title == formatWon(e.earned))
    #expect(title?.contains(".") == false, "메뉴바는 소수를 쓰지 않는다")
}

@Test("휴무일에는 금액을 내린다")
func titleOnDayOff() {
    let e = computeEarnings(.default, at(2026, 8, 26, 14, 0, 0))
    #expect(e.phase == .dayoff)
    #expect(menuBarTitle(e, hideAmount: false) == nil)
}

@Test("가리기를 켜면 금액을 내린다")
func titleWhenHidden() {
    let e = computeEarnings(.default, at(2026, 8, 22, 14, 0, 0))
    #expect(menuBarTitle(e, hideAmount: true) == nil)
}

@Test("출근 전에는 0원을 보여준다")
func titleBeforeWork() {
    let e = computeEarnings(.default, at(2026, 8, 22, 0, 30, 0))
    #expect(e.phase == .before)
    #expect(menuBarTitle(e, hideAmount: false) == formatWon(0))
}

/// 휴무일 아이콘에 바늘이 들어가는지.
///
/// 그림을 눈으로 볼 수 없으니 "빈 링과 다른 그림이 나온다"까지만 본다. 바늘을
/// 그리는 코드가 통째로 빠지거나 시각이 전달되지 않으면 두 그림이 같아진다.
@Test("휴무일 아이콘은 빈 링과 다르다 — 바늘이 그려진다")
func dayOffIconDrawsHands() {
    let t = at(2026, 8, 26, 10, 10, 0)
    let empty = ringImage(progress: 0).tiffRepresentation
    let clock = ringImage(progress: 0, clockAt: t).tiffRepresentation
    #expect(empty != nil && clock != nil)
    #expect(empty != clock)
}

@Test("바늘은 시각에 따라 달라진다")
func handsFollowTime() {
    let a = ringImage(progress: 0, clockAt: at(2026, 8, 26, 3, 0, 0)).tiffRepresentation
    let b = ringImage(progress: 0, clockAt: at(2026, 8, 26, 9, 0, 0)).tiffRepresentation
    #expect(a != b)
}
