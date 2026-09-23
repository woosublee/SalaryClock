import Foundation
import SalaryClockCore

/// SettingsView의 바인딩 안에 숨어 있던 순수 계산을 뽑아낸 것들.
/// SalaryClockCore는 웹과 공유하는 도메인 계층이라 여기(앱 전용 화면 로직)에 둔다.

/// 점심 시작 시각과 무급 분으로 종료 시각 문자열을 만든다. 시작 시각 형식이
/// 깨졌으면(입력 중이라 아직 "HH:mm"이 아닐 때) "13:00"을 기본값으로 보여준다 —
/// 웹 SettingsPanel의 `lunchEndValue`와 같다.
func lunchEndTime(start: String, minutes: Int) -> String {
    guard let s = parseHHmm(start) else { return "13:00" }
    return formatHHmm(s + minutes)
}

/// 종료 시각 입력으로 새 무급 분을 계산한다. 시작·종료 중 하나라도 "HH:mm" 형식이
/// 아니면 nil을 돌려줘 호출자가 이전 값을 그대로 두게 한다 — 웹 `setLunchEnd`와 같다.
///
/// 자정을 넘는 구간(예: 23:00 시작 → 01:00 종료)도 `durationMinutes`가 항상
/// 0 이상으로 감아 계산하므로 그대로 반영된다. 종료가 시작과 같으면 0분이 나온다
/// (그 경우 저장은 SettingsStore.isValid가 막는다 — 여기서는 값만 계산한다).
func lunchMinutesFromEnd(start: String, end: String) -> Int? {
    guard isValidHHmm(end), let s = parseHHmm(start), let e = parseHHmm(end) else { return nil }
    return durationMinutes(s, e)
}

/// 공제율 입력 텍스트를 해석한 결과. 문자열 하나로는 "빈 칸(추정치로)"과
/// "숫자로 못 읽음(무시)"을 구분할 수 없어 따로 케이스를 둔다.
enum DeductionRateInput: Equatable {
    /// 빈 칸 — deductionRate를 nil로 되돌려 추정치를 쓰게 한다.
    case useEstimate
    /// 숫자로 읽은 값 — 0..1 분수로 변환된 상태(범위 검사는 SettingsStore.isValid가 한다).
    case rate(Double)
    /// 숫자로 읽을 수 없는 입력 — 아무것도 바꾸지 않는다(이전 값 유지).
    case ignore
}

/// 공제율 입력칸에 보여줄 문자열. nil(추정치 사용)이면 빈 문자열 — 웹의
/// `draft.deductionRate === null ? '' : (draft.deductionRate * 100).toFixed(1)`와 같다.
func deductionRateText(_ rate: Double?) -> String {
    guard let r = rate else { return "" }
    return String(format: "%.1f", r * 100)
}

/// 공제율 입력 텍스트를 해석한다.
///
/// 빈 문자열은 `.useEstimate`, 숫자면 퍼센트를 0..1 분수로 바꿔 `.rate`, 그 외
/// (숫자로 읽을 수 없는 입력)는 `.ignore`를 돌려준다. "1."처럼 Swift의 `Double`이
/// 그대로 받아들이는 중간 입력 상태는 걸러지지 않고 값으로 통과한다
/// (`Double("1.") == 1.0`) — 사용자가 "1.5"를 마저 입력하려는 도중에도 0.01로
/// 저장되는 순간이 있다는 뜻이다. 의도한 동작은 아니지만 지금 실제로 그렇게
/// 동작하므로 있는 그대로 둔다(테스트가 이 동작을 고정한다).
func parseDeductionRateInput(_ text: String) -> DeductionRateInput {
    let trimmed = text.trimmingCharacters(in: .whitespaces)
    if trimmed.isEmpty { return .useEstimate }
    guard let pct = Double(trimmed) else { return .ignore }
    return .rate(pct / 100)
}

/// 메뉴바 갱신 주기의 위아래 버튼이 내놓을 값.
///
/// 0.1씩 더하고 빼는 것을 그대로 두면 부동소수점 찌꺼기가 쌓여
/// 1.2000000000000002 같은 값이 입력칸에 찍힌다. 소수 한 자리로 끊고 범위
/// 안으로 넣는다 — 범위는 AppPreferences가 저장을 허용하는 것과 같은 값이라,
/// 버튼으로는 넣을 수 있는데 저장은 거부되는 값이 생기지 않는다.
func steppedInterval(_ value: Double) -> Double {
    let rounded = (value * 10).rounded() / 10
    return min(max(rounded, AppPreferences.range.lowerBound), AppPreferences.range.upperBound)
}
