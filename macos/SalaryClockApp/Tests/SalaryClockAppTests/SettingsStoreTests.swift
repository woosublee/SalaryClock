import Testing
@testable import SalaryClockAppLib
import SalaryClockCore

@Test("기본 설정은 유효하다")
func defaultIsValid() {
    #expect(SettingsStore.isValid(.default))
}

@Test("급여가 0 이하면 무효다")
func rejectsNonPositivePay() {
    var s = Settings.default
    s.payAmount = 0
    #expect(!SettingsStore.isValid(s))
}

@Test("출근과 퇴근이 같으면 무효다")
func rejectsZeroShift() {
    var s = Settings.default
    s.workEnd = s.workStart
    #expect(!SettingsStore.isValid(s))
}

@Test("무급 시간이 근무시간 전체를 덮으면 무효다")
func rejectsLunchCoveringShift() {
    var s = Settings.default
    s.lunchMinutes = 9 * 60
    #expect(!SettingsStore.isValid(s))
}

@Test("점심이 퇴근 시각을 넘어가면 무효다")
func rejectsLunchPastEnd() {
    var s = Settings.default
    s.lunchStart = "17:30"
    s.lunchMinutes = 60
    #expect(!SettingsStore.isValid(s))
}

@Test("야간근무는 유효하다")
func acceptsNightShift() {
    var s = Settings.default
    s.workStart = "22:00"
    s.workEnd = "06:00"
    s.lunchStart = "01:00"
    #expect(SettingsStore.isValid(s))
}

@Test("시각 형식이 깨지면 무효다")
func rejectsBadTime() {
    var s = Settings.default
    s.workStart = "9:00"
    #expect(!SettingsStore.isValid(s))
    s.workStart = "24:00"
    #expect(!SettingsStore.isValid(s))
}
