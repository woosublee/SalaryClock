import Foundation

public let MS_PER_MINUTE = 60_000
public let MS_PER_HOUR = 3_600_000
public let MS_PER_DAY = 86_400_000

/// "HH:mm" 형식인지. 24시간제, 00:00~23:59만 통과한다.
public func isValidHHmm(_ v: String) -> Bool {
    guard v.count == 5 else { return false }
    let parts = v.split(separator: ":", omittingEmptySubsequences: false)
    guard parts.count == 2, parts[0].count == 2, parts[1].count == 2,
          let h = Int(parts[0]), let m = Int(parts[1]),
          parts[0].allSatisfy(\.isNumber), parts[1].allSatisfy(\.isNumber)
    else { return false }
    return (0...23).contains(h) && (0...59).contains(m)
}

/// "HH:mm" → 자정 이후 분. 형식이 깨졌으면 nil.
public func parseHHmm(_ v: String) -> Int? {
    guard isValidHHmm(v) else { return nil }
    let parts = v.split(separator: ":")
    return Int(parts[0])! * 60 + Int(parts[1])!
}

public func formatHHmm(_ minutes: Int) -> String {
    let m = ((minutes % 1440) + 1440) % 1440
    return String(format: "%02d:%02d", m / 60, m % 60)
}

/// 자정을 넘는 구간에도 항상 0 이상. 시작과 끝이 같으면 0.
public func durationMinutes(_ startMin: Int, _ endMin: Int) -> Int {
    (((endMin - startMin) % 1440) + 1440) % 1440
}

/// 그 시각이 속한 로컬 날짜의 자정. epoch ms.
public func startOfLocalDay(_ now: Int) -> Int {
    let date = Date(timeIntervalSince1970: Double(now) / 1000)
    let start = Calendar.current.startOfDay(for: date)
    return Int((start.timeIntervalSince1970 * 1000).rounded())
}
