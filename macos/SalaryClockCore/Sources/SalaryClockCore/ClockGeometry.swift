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
private func msIntoDay(_ now: Int) -> Int {
    now - startOfLocalDay(now)
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
