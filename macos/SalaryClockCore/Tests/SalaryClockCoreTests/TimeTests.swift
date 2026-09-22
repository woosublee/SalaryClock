import Testing
import Foundation
@testable import SalaryClockCore

@Test("appCalendar는 기기의 달력 설정과 무관하게 그레고리력이고, 시간대는 기기를 따른다")
func appCalendarIsGregorianWithCurrentTimeZone() {
    #expect(appCalendar.identifier == .gregorian)
    #expect(appCalendar.timeZone == TimeZone.current)
}
