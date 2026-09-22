import Foundation

public struct WorkdayInfo: Sendable {
    /// 그 달의 평일(월~금) 수
    public let weekdays: Int
    /// 평일에 걸린 공휴일 수. 주말과 겹친 공휴일은 세지 않는다
    public let holidays: Int
    /// 실제 근무일수 = 평일 − 평일 공휴일
    public let workdays: Int
    /// 그 해 공휴일 표가 있는지
    public let hasHolidayData: Bool
}

func daysInMonth(_ year: Int, _ month: Int) -> Int {
    var c = DateComponents()
    c.year = year; c.month = month + 1
    let date = appCalendar.date(from: c)!
    return appCalendar.range(of: .day, in: .month, for: date)!.count
}

/// 그 시각이 속한 달의 평일(월~금) 수. 세는 일은 workdayInfo의 캐시가 한다.
public func weekdaysInMonth(_ now: Int) -> Int {
    workdayInfo(now).weekdays
}

/// 달마다 결과가 고정이므로 캐시해 둔다. 원본은 lib/workdays.ts —
/// "초당 수천 개를 만들 이유가 없다".
///
/// 한 달치를 세려면 그 달의 날 수만큼 `weekday()`를 부르고, 그 하나가
/// `appCalendar`를 두 번 만진다. `computeEarnings`는 틱마다 `effectiveWorkDays`를
/// 두 번 부르고, 팝오버가 열려 있으면 틱은 0.1초마다다.
///
/// (연, 월)만 키로 쓴다. 답은 그레고리력의 날짜와 공휴일 표에서만 나오고
/// 시간대에 의존하지 않는다 — `weekday()`는 그 시간대의 정오를 만들어 같은
/// 시간대에서 요일을 읽으므로 어느 시간대에서든 같은 달력 날짜를 본다.
/// `now`가 어느 달에 속하는지는 매번 새로 판정하므로 시간대 변화도 따라간다.
///
/// 캐시는 공유 가변 상태다. 이 모듈의 함수는 어느 스레드에서 불려도 안전해야
/// 하므로 잠금으로 감싼다. 순수성은 그대로다 — 같은 (연, 월)은 늘 같은 답이고
/// 관측 가능한 동작이 호출 순서에 따라 달라지지 않는다.
private final class WorkdayInfoCache: @unchecked Sendable {
    static let shared = WorkdayInfoCache()

    private let lock = NSLock()
    private var entries: [Int: WorkdayInfo] = [:]

    func info(_ year: Int, _ month: Int) -> WorkdayInfo {
        let key = year * 12 + month
        if let hit = lock.withLock({ entries[key] }) { return hit }

        let info = Self.compute(year, month)
        // 잠금 밖에서 계산하고 여기서 담는다. 같은 달을 두 스레드가 동시에
        // 계산하면 같은 값을 두 번 만들 뿐이라 덮어써도 안전하다.
        lock.withLock { entries[key] = info }
        return info
    }

    private static func compute(_ year: Int, _ month: Int) -> WorkdayInfo {
        let weekdays = (1...daysInMonth(year, month)).count { day in
            let dow = weekday(year, month, day)
            return dow != 0 && dow != 6
        }
        let holidays = weekdayHolidaysInMonth(year, month).count
        return WorkdayInfo(
            weekdays: weekdays,
            holidays: holidays,
            workdays: weekdays - holidays,
            hasHolidayData: hasHolidayData(year)
        )
    }
}

public func workdayInfo(_ now: Int) -> WorkdayInfo {
    let date = Date(timeIntervalSince1970: Double(now) / 1000)
    let cal = appCalendar
    return WorkdayInfoCache.shared.info(
        cal.component(.year, from: date),
        cal.component(.month, from: date) - 1
    )
}

public func workdaysInMonth(_ now: Int) -> Int {
    workdayInfo(now).workdays
}

/// 달력 기준 그 달의 근무일수 (calendar 모드)
public func workdaysFromCalendar(_ year: Int, _ month: Int, _ overrides: [String]) -> Int {
    (1...daysInMonth(year, month)).count { day in
        let key = dateKey(year, month, day)
        let defaultOff = isDefaultOff(year, month, day)
        let off = overrides.contains(key) ? !defaultOff : defaultOff
        return !off
    }
}

/// 설정에 따른 이번 달 근무일수.
///
/// auto     — 평일 − 공휴일
/// calendar — 달력에서 고른 것
/// manual   — 사용자가 넣은 숫자 그대로
public func effectiveWorkDays(_ s: Settings, _ now: Int) -> Double {
    switch s.workDaysMode {
    case .manual:
        return s.workDaysPerMonth
    case .calendar:
        let date = Date(timeIntervalSince1970: Double(now) / 1000)
        let cal = appCalendar
        return Double(
            workdaysFromCalendar(
                cal.component(.year, from: date),
                cal.component(.month, from: date) - 1,
                s.dayOverrides
            )
        )
    case .auto:
        return Double(workdaysInMonth(now))
    }
}
