import Foundation

public let MS_PER_MINUTE = 60_000
public let MS_PER_HOUR = 3_600_000
public let MS_PER_DAY = 86_400_000

/// 그레고리력 고정, 시간대는 기기 설정을 그대로 따르는 달력.
///
/// 기기의 달력 설정(일본력·불기·이슬람력)을 따라가지 않도록 그레고리력으로
/// 고정한다. 웹의 Date는 정의상 그레고리력이라, `Calendar.current`를 쓰면
/// 연도·월·요일 계산이 기기 설정에 따라 조용히 달라진다.
///
/// `let`으로 한 번 캐시하지 않고 접근할 때마다 새로 만드는 이유는 시간대
/// 때문이다. 메뉴바 앱은 오래 떠 있는 프로세스라, 실행 중 시스템 시간대가
/// 바뀌면(비행기 도착, 시스템 설정 변경) 초기화 시점에 캐시한 `TimeZone.current`는
/// 그 변화를 못 따라가고 낡은 시간대를 계속 물게 된다. 계산 프로퍼티로 두면
/// 매번 그 시점의 시간대를 읽는다.
var appCalendar: Calendar {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone.current
    return c
}

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
    let start = appCalendar.startOfDay(for: date)
    return Int((start.timeIntervalSince1970 * 1000).rounded())
}
