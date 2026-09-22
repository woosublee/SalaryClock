import Testing
@testable import SalaryClockAppLib
import SalaryClockCore

/// `SettingsStore.isValid`가 웹 `lib/settings.ts`의 `SettingsSchema`와
/// 어긋나지 않는지 확인한다. 이 규칙이 깨지면 Task 9 리뷰에서 지적된 gap이
/// 그대로 되돌아온다.

@Test("clockStyle이 열 가지 목록 밖이면 무효")
func invalidClockStyleRejected() {
    var s = Settings.default
    s.clockStyle = "not-a-real-style"
    #expect(!SettingsStore.isValid(s))
}

@Test("clockStyle 열 가지는 전부 유효")
func allClockStylesAccepted() {
    for style in validClockStyles {
        var s = Settings.default
        s.clockStyle = style
        #expect(SettingsStore.isValid(s), "\(style)은 유효해야 한다")
    }
}

@Test("dayOverrides 형식이 YYYY-MM-DD가 아니면 무효")
func malformedDayOverrideRejected() {
    var s = Settings.default
    s.dayOverrides = ["2026/09/22"]
    #expect(!SettingsStore.isValid(s))
}

@Test("dayOverrides가 732개를 넘으면 무효")
func tooManyDayOverridesRejected() {
    var s = Settings.default
    s.dayOverrides = (0..<733).map { String(format: "2026-01-%02d", ($0 % 28) + 1) }
    #expect(!SettingsStore.isValid(s))
}

@Test("dayOverrides가 732개 이하고 형식이 맞으면 유효")
func validDayOverridesAccepted() {
    var s = Settings.default
    s.dayOverrides = ["2026-01-01", "2026-12-31"]
    #expect(SettingsStore.isValid(s))
}

@Test("lunchEnabled가 꺼져 있어도 lunchMinutes는 0..1440 범위를 벗어나면 무효")
func lunchMinutesBoundsCheckedEvenWhenLunchDisabled() {
    var s = Settings.default
    s.lunchEnabled = false
    s.lunchMinutes = 1441
    #expect(!SettingsStore.isValid(s))

    s.lunchMinutes = -1
    #expect(!SettingsStore.isValid(s))

    s.lunchMinutes = 1440
    #expect(SettingsStore.isValid(s))
}

@Test("lunchEnabled가 꺼져 있어도 lunchStart 형식은 여전히 검사한다")
func lunchStartFormatCheckedEvenWhenLunchDisabled() {
    var s = Settings.default
    s.lunchEnabled = false
    s.lunchStart = "not-hhmm"
    #expect(!SettingsStore.isValid(s))
}
