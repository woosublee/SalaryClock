import Foundation

private let MS_PER_12H = 43_200_000

public struct HandAngles: Sendable {
    public let hour: Double
    public let minute: Double
    public let second: Double
}

public struct Arc: Equatable, Sendable {
    public let startDeg: Double
    public let sweepDeg: Double
}

public struct ShiftArcs: Sendable {
    public let work: Arc
    public let progress: Arc
    public let lunch: Arc?
}

/// 그 시각의 자정 이후 경과 밀리초. 로컬 시각 기준.
///
/// `now - startOfLocalDay(now)`처럼 경과 시간으로 구하지 않고, 벽시계 성분
/// (시·분·초·밀리초)을 그대로 더해서 만든다. DST로 로컬 하루가 23시간 또는
/// 25시간이 되는 날에는 두 계산이 갈린다 — 경과 시간 쪽은 자정 이후 실제로
/// 흐른 시간을 재므로 그 시각의 벽시계가 가리키는 시각과 최대 한 시간까지
/// 어긋난다. 웹(`lib/clock.ts`)은 `Date.getHours()` 등으로 벽시계 성분을 직접
/// 읽으므로, 여기서도 같은 방식으로 맞춘다 — 초 단위까지는 Calendar로,
/// 밀리초는 시간대가 항상 분 단위 오프셋이라는 점을 이용해 epoch에서 직접 뗀다.
private func msIntoDay(_ now: Int) -> Int {
    let date = Date(timeIntervalSince1970: Double(now) / 1000)
    let comps = appCalendar.dateComponents([.hour, .minute, .second], from: date)
    let msOfSecond = ((now % 1000) + 1000) % 1000
    return (comps.hour ?? 0) * MS_PER_HOUR
        + (comps.minute ?? 0) * MS_PER_MINUTE
        + (comps.second ?? 0) * 1000
        + msOfSecond
}

/// 12시 방향 0도, 시계방향 증가.
///
/// 밀리초를 버리지 않고 그대로 각도로 환산하는 것이 스위프 운동의 전부다.
/// 초를 내림하면 1초마다 6도씩 튀는 쿼츠 시계가 된다.
public func handAngles(_ now: Int) -> HandAngles {
    let t = Double(msIntoDay(now))
    return HandAngles(
        hour: (t.truncatingRemainder(dividingBy: Double(MS_PER_12H)) / Double(MS_PER_12H)) * 360,
        minute: (t.truncatingRemainder(dividingBy: 3_600_000) / 3_600_000) * 360,
        second: (t.truncatingRemainder(dividingBy: 60_000) / 60_000) * 360
    )
}

/// 그 시각의 12시간 문자판 위치 (0~360).
public func dialAngle(_ now: Int) -> Double {
    let t = Double(msIntoDay(now))
    return (t.truncatingRemainder(dividingBy: Double(MS_PER_12H)) / Double(MS_PER_12H)) * 360
}

/// 두 시각 사이를 문자판 호로. 12시간을 넘으면 360도로 자른다.
public func arcBetween(_ fromMs: Int, _ toMs: Int) -> Arc {
    let span = Double(max(0, toMs - fromMs))
    return Arc(
        startDeg: dialAngle(fromMs),
        sweepDeg: min(360, (span / Double(MS_PER_12H)) * 360)
    )
}

private let EMPTY_ARC = Arc(startDeg: 0, sweepDeg: 0)

/// 시프트를 문자판 위의 호 셋으로. 휴무일에는 시프트가 없어 빈 호를 돌려준다.
public func shiftArcs(_ shift: Shift?, _ now: Int) -> ShiftArcs {
    guard let shift else {
        return ShiftArcs(work: EMPTY_ARC, progress: EMPTY_ARC, lunch: nil)
    }
    let clampedNow = min(max(now, shift.startMs), shift.endMs)
    return ShiftArcs(
        work: arcBetween(shift.startMs, shift.endMs),
        progress: arcBetween(shift.startMs, clampedNow),
        lunch: shift.lunchStartMs.flatMap { ls in
            shift.lunchEndMs.map { arcBetween(ls, $0) }
        }
    )
}
