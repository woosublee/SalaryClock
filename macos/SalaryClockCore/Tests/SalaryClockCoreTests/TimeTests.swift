import Testing
import Foundation
@testable import SalaryClockCore

@Test("appCalendar는 기기의 달력 설정과 무관하게 그레고리력이고, 시간대는 기기를 따른다")
func appCalendarIsGregorianWithCurrentTimeZone() {
    #expect(appCalendar.identifier == .gregorian)
    #expect(appCalendar.timeZone == TimeZone.current)
}

/// 달력을 캐시하되 시간대 변화는 따라가야 한다 — 비행기에서 내려 시간대가
/// 바뀐 뒤에도 낡은 시간대로 계산하면 하루 경계가 통째로 어긋난다.
@Test("CalendarCache는 시간대가 바뀌면 달력을 다시 만든다")
func calendarCacheFollowsTimeZone() throws {
    let seoul = try #require(TimeZone(identifier: "Asia/Seoul"))
    let utc = try #require(TimeZone(identifier: "UTC"))
    let cache = CalendarCache(seoul)

    #expect(cache.calendar(for: seoul).timeZone == seoul)
    #expect(cache.calendar(for: utc).timeZone == utc)
    // 되돌아와도 그 시간대로 다시 만든다 — 한 번 바뀐 뒤 굳지 않는다.
    #expect(cache.calendar(for: seoul).timeZone == seoul)
    // 캐시를 거쳐도 그레고리력 고정은 그대로다.
    #expect(cache.calendar(for: utc).identifier == .gregorian)
}
