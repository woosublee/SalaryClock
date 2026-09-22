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

private func daysInMonth(_ year: Int, _ month: Int) -> Int {
    var c = DateComponents()
    c.year = year; c.month = month + 1
    let date = appCalendar.date(from: c)!
    return appCalendar.range(of: .day, in: .month, for: date)!.count
}

/// 그 시각이 속한 달의 평일(월~금) 수
public func weekdaysInMonth(_ now: Int) -> Int {
    let date = Date(timeIntervalSince1970: Double(now) / 1000)
    let cal = appCalendar
    let year = cal.component(.year, from: date)
    let month = cal.component(.month, from: date) - 1

    return (1...daysInMonth(year, month)).count { day in
        let dow = weekday(year, month, day)
        return dow != 0 && dow != 6
    }
}

public func workdayInfo(_ now: Int) -> WorkdayInfo {
    let date = Date(timeIntervalSince1970: Double(now) / 1000)
    let cal = appCalendar
    let year = cal.component(.year, from: date)
    let month = cal.component(.month, from: date) - 1

    let weekdays = weekdaysInMonth(now)
    let holidays = weekdayHolidaysInMonth(year, month).count

    return WorkdayInfo(
        weekdays: weekdays,
        holidays: holidays,
        workdays: weekdays - holidays,
        hasHolidayData: hasHolidayData(year)
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
