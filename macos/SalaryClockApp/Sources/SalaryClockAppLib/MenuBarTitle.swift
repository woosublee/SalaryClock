import Foundation
import SalaryClockCore

/// 메뉴바에 띄울 금액 문자열. 아이콘만 보여야 하면 nil.
///
/// 소수를 쓰지 않는 이유: 0.1초마다 갱신하면 메뉴바가 끝없이 꿈틀거리고
/// 배터리도 먹는다. 소수 1자리가 흐르는 건 팝오버에서 보여준다.
///
/// hideAmount일 때 현재 시각을 대신 넣지 않는다 — macOS 기본 시계와
/// 나란히 중복되고, 회의 중에 가장 가리고 싶은 게 메뉴바 금액이다.
public func menuBarTitle(_ e: Earnings, hideAmount: Bool) -> String? {
    if hideAmount || e.phase == .dayoff { return nil }
    return formatWon(e.earned)
}
