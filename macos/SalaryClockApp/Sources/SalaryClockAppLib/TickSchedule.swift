import Foundation
import SalaryClockCore

/// 다음 tick까지 기다릴 시간(초).
///
/// 메뉴바에서 매초 바뀌는 것은 근무 중의 금액뿐이다. 출근 전·점심·퇴근 후·
/// 휴무일에는 금액이 멈춰 있고, 가리기를 켜면 금액 자체가 없다. 그때 바뀌는
/// 것은 분 단위로 다시 그리는 링 아이콘뿐이고, 근무 단계의 경계(출근·점심·
/// 퇴근)도 설정이 HH:mm이라 모두 분의 경계에 떨어진다. 그래서 그 동안은
/// 다음 분의 경계에 한 번만 깨어나면 놓치는 것이 없다 — 퇴근 뒤 다음 날
/// 출근까지 1Hz로 깨어나던 것이 분당 한 번으로 준다.
///
/// - Parameters:
///   - interval: 사용자가 고른 메뉴바 갱신 주기(AppPreferences).
///   - popoverShown: 팝오버가 열려 있으면 소수 1자리가 흐르도록 0.1초.
public func nextTickDelay(
    _ e: Earnings,
    hideAmount: Bool,
    popoverShown: Bool,
    interval: TimeInterval,
    now: Int
) -> TimeInterval {
    if popoverShown { return 0.1 }
    if e.phase == .working && !hideAmount { return interval }
    let msIntoMinute = ((now % 60_000) + 60_000) % 60_000
    // 경계를 막 넘긴 뒤에 깨어나야 분이 바뀐 값을 읽는다. 1ms를 더한다.
    return TimeInterval(60_000 - msIntoMinute + 1) / 1000
}
