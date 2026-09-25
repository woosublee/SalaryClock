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
/// 만들어 둔 것을 재사용하되, 시간대가 바뀌면 버리고 다시 만든다.
///
/// 한 번 만들고 굳히면 안 된다. 메뉴바 앱은 오래 떠 있는 프로세스라, 실행 중
/// 시스템 시간대가 바뀌면(비행기 도착, 시스템 설정 변경) 초기화 시점의
/// `TimeZone.current`를 계속 물게 된다. 그렇다고 접근할 때마다 새로 만들면
/// 틱마다 수십 개가 생긴다 — `weekday()` 하나가 두 번 만지고,
/// `weekdaysInMonth`는 그걸 그 달의 날 수만큼 부른다.
///
/// 그래서 "무엇으로 만들었는지"를 같이 들고 있다가 `TimeZone.current`가
/// 달라진 순간에만 다시 만든다. 시간대를 매번 읽는 것은 그대로이므로 계산
/// 프로퍼티였을 때의 성질(시간대 변화를 따라간다)이 그대로 남는다 —
/// 알림(`NSSystemTimeZoneDidChange`)을 구독하지 않으므로 런루프가 돌지 않는
/// 테스트·스크립트에서도 같게 동작한다. 측정하면 접근당 약 166ns → 35ns다.
///
/// 다만 `TimeZone.current` 자체도 프로세스가 캐시한다. 앱은 그 알림을 받아
/// `NSTimeZone.resetSystemTimeZone()`을 부른다(AppDelegate) — 그래야 여기서
/// 읽는 값이 바뀐다.
///
/// 캐시는 공유 가변 상태다. 이 모듈의 함수는 어느 스레드에서 불려도 안전해야
/// 하므로 잠금으로 감싼다. 밖에서 보이는 답은 달라지지 않는다.
final class CalendarCache: @unchecked Sendable {
    static let shared = CalendarCache()

    private let lock = NSLock()
    private var cached: Calendar
    private var cachedZone: TimeZone

    init(_ zone: TimeZone = TimeZone.current) {
        cachedZone = zone
        cached = Self.make(zone)
    }

    private static func make(_ zone: TimeZone) -> Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = zone
        return c
    }

    /// 그 시간대의 달력. 직전과 같은 시간대면 만들어 둔 것을 그대로 준다.
    func calendar(for zone: TimeZone) -> Calendar {
        lock.withLock {
            if cachedZone != zone {
                cachedZone = zone
                cached = Self.make(zone)
            }
            return cached
        }
    }

    var current: Calendar { calendar(for: TimeZone.current) }
}

var appCalendar: Calendar { CalendarCache.shared.current }

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
