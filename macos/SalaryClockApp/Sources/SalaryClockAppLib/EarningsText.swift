import SalaryClockCore

// 맥 팝오버와 iOS 메인 화면이 함께 쓰는 문구. 화면 배치는 플랫폼마다 다르지만
// 무엇을 보여주는지는 같아야 하므로 여기 한 벌만 둔다.

/// 상태 줄의 앞부분 — 웹 components/StatusLine.tsx와 같은 문구.
func statusText(_ e: Earnings, _ s: SalaryClockCore.Settings, _ now: Int) -> String {
    switch e.phase {
    case .before: return "출근까지 \(formatDuration(e.msUntilStart))"
    // "· 재개까지"를 빼서 짧게 줄였다 — 웹 StatusLine도 같은 문구다.
    case .lunch: return "점심시간 \(formatDuration(e.msUntilLunchEnd))"
    // 종류(kind)는 SalaryClockCore가 정하고, 문구는 여기(UI)가 갖는다.
    case .after: return afterWorkText(afterWorkKind(s, now))
    case .working: return "퇴근까지 \(formatDuration(e.msUntilEnd))"
    // 휴무일에는 화면이 상태 줄을 비운다 — switch를 다 채우기 위한 자리만 지킨다.
    case .dayoff: return " "
    }
}

/// 금액을 가렸을 때 시각 아래에 라벨 없이 붙는 남은 시간.
func remainingTime(_ e: Earnings) -> String {
    switch e.phase {
    case .before: return formatDuration(e.msUntilStart)
    case .lunch: return formatDuration(e.msUntilLunchEnd)
    case .working: return formatDuration(e.msUntilEnd)
    case .after, .dayoff: return " "
    }
}

/// "오후 3:04:05"를 오전/오후와 숫자로 나눈다. 24시간제면 meridiem이 nil이다.
func splitClockTime(_ now: Int, hour12: Bool) -> (meridiem: String?, hms: String) {
    let text = formatClockTime(now, hour12: hour12)
    guard let space = text.firstIndex(of: " ") else { return (nil, text) }
    return (String(text[..<space]), String(text[text.index(after: space)...]))
}

/// 금액 뒤에 흐리게 붙는 소수 한 자리(".3"). 정수만 쓰면 초당 5.8원일 때
/// 0.17초마다 한 번씩 또각또각 올라가는데, 한 자리를 더 두면 흐르듯 보인다.
func earnedFraction(_ earned: Double) -> String {
    String(format: ".%d", Int(earned.truncatingRemainder(dividingBy: 1) * 10))
}

/// 퇴근 후 격려 문구. 종류(kind)는 SalaryClockCore.afterWorkKind가 정하고,
/// 실제 한국어 문장은 여기(UI)가 갖는다 — 웹 components/StatusLine.tsx의
/// AFTER_WORK_TEXT와 같은 표를 따른다.
func afterWorkText(_ kind: AfterWorkKind) -> String {
    switch kind {
    case .tomorrow: return "🌙 오늘 하루도 수고하셨어요"
    case .restThisWeek: return "😌 오늘은 여기까지, 편히 쉬세요"
    case .nextWeek: return "🎉 한 주 동안 수고하셨어요"
    case .longBreak: return "🏖️ 즐거운 연휴 보내세요"
    }
}

