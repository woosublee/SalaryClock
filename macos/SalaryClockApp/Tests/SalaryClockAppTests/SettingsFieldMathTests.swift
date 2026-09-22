import Testing
@testable import SalaryClockAppLib

/// SettingsView의 바인딩 안에 있던 순수 계산(SettingsFieldMath.swift)을 검증한다.
/// `SettingsStore.isValid`는 이 태스크에서 건드리지 않았으므로 여기서는 다시
/// 테스트하지 않는다 — 그 쪽은 SettingsStoreValidationTests.swift가 이미 덮는다.

// MARK: - 점심 종료 시각 ↔ 무급 분

@Test("시작 12:00 + 무급 60분이면 종료는 13:00")
func lunchEndTimeNormal() {
    #expect(lunchEndTime(start: "12:00", minutes: 60) == "13:00")
}

@Test("시작 시각 형식이 깨지면 13:00을 기본값으로 보여준다")
func lunchEndTimeFallsBackWhenStartInvalid() {
    #expect(lunchEndTime(start: "9:00", minutes: 60) == "13:00")
}

@Test("시작을 옮기면 무급 길이는 그대로, 종료만 따라간다")
func lunchEndTimeFollowsStartAndBack() {
    // 12:00 + 60분 = 13:00에서 시작을 10:00으로 옮기면 60분 길이를 유지한 채 11:00으로.
    #expect(lunchEndTime(start: "10:00", minutes: 60) == "11:00")
    // 다시 12:00으로 돌아오면 원래 13:00으로 돌아온다.
    #expect(lunchEndTime(start: "12:00", minutes: 60) == "13:00")
}

@Test("종료를 시작 이후로 넣으면 그 차이만큼 무급 분이 된다")
func lunchMinutesFromEndNormal() {
    #expect(lunchMinutesFromEnd(start: "12:00", end: "13:00") == 60)
}

@Test("자정을 넘는 야간근무 점심은 durationMinutes처럼 감아서 계산된다")
func lunchMinutesFromEndWrapsPastMidnight() {
    // 23:30 시작 → 00:30 종료 = 60분 (자정을 넘는다).
    #expect(lunchMinutesFromEnd(start: "23:30", end: "00:30") == 60)
}

@Test("종료가 시작과 같으면 무급 0분이 나온다")
func lunchMinutesFromEndZeroWhenEqual() {
    #expect(lunchMinutesFromEnd(start: "12:00", end: "12:00") == 0)
}

@Test("시작·종료 중 하나라도 형식이 깨지면 nil — 이전 값을 그대로 둔다")
func lunchMinutesFromEndNilOnBadFormat() {
    #expect(lunchMinutesFromEnd(start: "12:00", end: "9:00") == nil)
    #expect(lunchMinutesFromEnd(start: "9:00", end: "13:00") == nil)
}

// MARK: - 공제율 입력

@Test("nil은 빈 문자열로 보여준다")
func deductionRateTextEmptyForNil() {
    #expect(deductionRateText(nil) == "")
}

@Test("0.3은 30.0으로 보여준다")
func deductionRateTextFormatsFraction() {
    #expect(deductionRateText(0.3) == "30.0")
}

@Test("빈 문자열은 추정치를 쓰라는 뜻이다")
func parseDeductionRateInputEmptyMeansEstimate() {
    #expect(parseDeductionRateInput("") == .useEstimate)
    #expect(parseDeductionRateInput("   ") == .useEstimate)
}

@Test("숫자 30은 0.3 분수로 해석된다")
func parseDeductionRateInputNumber() {
    #expect(parseDeductionRateInput("30") == .rate(0.3))
}

@Test("표시 문자열을 다시 해석하면 원래 값으로 돌아온다")
func deductionRateRoundTrips() {
    let text = deductionRateText(0.3)
    #expect(parseDeductionRateInput(text) == .rate(0.3))
}

@Test("숫자로 읽을 수 없는 입력은 무시된다 — 이전 값을 지우지 않는다")
func parseDeductionRateInputIgnoresJunk() {
    #expect(parseDeductionRateInput("abc") == .ignore)
    #expect(parseDeductionRateInput("12%") == .ignore)
    #expect(parseDeductionRateInput("--") == .ignore)
}

@Test("현재 동작 고정: \"1.\"처럼 소수점만 붙은 중간 입력은 Double이 그대로 받아들여 값으로 통과한다")
func parseDeductionRateInputAcceptsTrailingDot() {
    // Double("1.") == 1.0이라 Swift 표준 라이브러리 수준에서 이미 유효한 숫자로
    // 취급된다. "1.5"를 마저 입력하는 중이라도 그 순간 1%로 반영된다는 뜻이다 —
    // 의도한 사용성은 아니지만 지금 실제 동작이 그렇다는 것을 여기서 고정해 둔다.
    #expect(parseDeductionRateInput("1.") == .rate(0.01))
}

@Test("현재 동작 고정: 범위를 벗어난 숫자도 그대로 분수로 바뀐다 — 범위 검사는 SettingsStore.isValid의 몫이다")
func parseDeductionRateInputDoesNotClamp() {
    #expect(parseDeductionRateInput("150") == .rate(1.5))
    #expect(parseDeductionRateInput("-5") == .rate(-0.05))
}
