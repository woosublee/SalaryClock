import Foundation

public struct Shift: Equatable, Sendable {
    public let startMs: Int
    public let endMs: Int
    public let lunchStartMs: Int?
    public let lunchEndMs: Int?
    /// 시프트 길이에서 무급 점심을 뺀 시간
    public let paidMs: Int
}

/// "HH:mm"을 분으로 바꾼다. 형식이 깨졌으면 0.
///
/// SettingsStore가 저장 시점에 검증하므로 여기까지 오면 계약이 깨진 것이다.
/// 디버그·테스트에서는 즉시 멈추고, 릴리스에서는 0으로 버티며 앱을 살려둔다.
private func minutesOrZero(_ v: String) -> Int {
    guard let m = parseHHmm(v) else {
        assertionFailure("시각 형식이 올바르지 않습니다: \(v)")
        return 0
    }
    return m
}

private func buildShift(_ s: Settings, _ dayStart: Int) -> Shift {
    let workStartMin = minutesOrZero(s.workStart)
    let shiftMin = durationMinutes(workStartMin, minutesOrZero(s.workEnd))

    let startMs = dayStart + workStartMin * MS_PER_MINUTE
    let endMs = startMs + shiftMin * MS_PER_MINUTE

    var lunchStartMs: Int?
    var lunchEndMs: Int?
    var lunchMs = 0

    if s.lunchEnabled {
        let offsetMin = durationMinutes(workStartMin, minutesOrZero(s.lunchStart))
        let ls = startMs + offsetMin * MS_PER_MINUTE
        lunchStartMs = ls
        lunchEndMs = ls + s.lunchMinutes * MS_PER_MINUTE
        lunchMs = s.lunchMinutes * MS_PER_MINUTE
    }

    return Shift(
        startMs: startMs, endMs: endMs,
        lunchStartMs: lunchStartMs, lunchEndMs: lunchEndMs,
        paidMs: endMs - startMs - lunchMs
    )
}

/// 그 시각을 품고 있으면 true. 시작은 포함, 끝은 제외.
private func contains(_ shift: Shift, _ now: Int) -> Bool {
    now >= shift.startMs && now < shift.endMs
}

/// 화면에 보여줄 시프트.
///
///   1. now를 품는 시프트가 있으면        → 그것        (근무 중 · 점심)
///   2. 없고, 오늘 안에 끝난 것이 있으면  → 그것        (퇴근 후 — 총액 유지)
///   3. 그 외                              → 오늘 시작할 시프트 (출근 전 — 0원)
///
/// 원본은 lib/shift.ts다. 자정을 특별히 다루지 않는데도 초기화가 나오고,
/// 야간근무(22:00–06:00)는 1단계에 걸려 자정에 끊기지 않는다.
public func resolveShift(_ s: Settings, _ now: Int) -> Shift {
    let today = startOfLocalDay(now)
    let yesterday = buildShift(s, today - MS_PER_DAY)
    let todayShift = buildShift(s, today)
    // tomorrow는 고정 오프셋 지역에서는 1단계에 걸리지 않지만, DST fall-back으로
    // 로컬 하루가 25시간인 날에는 now가 today + MS_PER_DAY를 넘을 수 있다.
    let tomorrow = buildShift(s, today + MS_PER_DAY)

    for c in [yesterday, todayShift, tomorrow] where contains(c, now) {
        return c
    }

    // 둘 중 최대 하나만 걸린다. yesterday가 걸리려면 시프트가 자정을 넘어야 하고
    // todayShift가 걸리려면 넘지 않아야 해서, 둘이 동시에 참일 수 없다.
    if let ended = [yesterday, todayShift].first(where: { $0.endMs <= now && $0.endMs > today }) {
        return ended
    }

    return todayShift
}

/// 두 시각 사이의 유급 시간(ms). 시프트 밖은 잘라내고 점심은 뺀다.
public func paidMsBetween(_ shift: Shift, _ from: Int, _ to: Int) -> Int {
    let lo = max(from, shift.startMs)
    let hi = min(to, shift.endMs)
    if hi <= lo { return 0 }

    var paid = hi - lo
    if let ls = shift.lunchStartMs, let le = shift.lunchEndMs {
        let overlap = min(hi, le) - max(lo, ls)
        if overlap > 0 { paid -= overlap }
    }
    return paid
}
