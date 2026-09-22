import Foundation

public enum DayKind: String, Sendable {
    case work
    case weekend
    case holiday
    case customOff = "custom-off"
    case customWork = "custom-work"
}

public struct DayCell: Sendable {
    /// "YYYY-MM-DD"
    public let date: String
    public let day: Int
    /// 0=일 … 6=토
    public let dow: Int
    public let kind: DayKind
    /// 근무일로 세는 날인지
    public let isWorkday: Bool
}

/// 그 달의 날짜별 상태. month는 0-based.
///
/// overrides는 "기본값을 뒤집은 날"의 목록이다. 연차를 더하는 것과 공휴일에
/// 출근한 것을 같은 방식으로 담을 수 있다.
public func monthCells(_ year: Int, _ month: Int, _ overrides: [String]) -> [DayCell] {
    let flipped = Set(overrides)
    var cells: [DayCell] = []

    for day in 1...daysInMonth(year, month) {
        let date = dateKey(year, month, day)
        let dow = weekday(year, month, day)
        let defaultOff = isDefaultOff(year, month, day)
        let isFlipped = flipped.contains(date)
        let off = isFlipped ? !defaultOff : defaultOff

        let kind: DayKind
        if isFlipped {
            kind = off ? .customOff : .customWork
        } else if dow == 0 || dow == 6 {
            kind = .weekend
        } else if defaultOff {
            kind = .holiday
        } else {
            kind = .work
        }

        cells.append(DayCell(date: date, day: day, dow: dow, kind: kind, isWorkday: !off))
    }
    return cells
}

/// 한 날짜의 기본값 뒤집기를 켜고 끈다. 결과는 항상 정렬돼 있다.
public func toggleOverride(_ overrides: [String], _ date: String) -> [String] {
    overrides.contains(date)
        ? overrides.filter { $0 != date }
        : (overrides + [date]).sorted()
}

/// 그 달의 override를 모두 지운다. month는 0-based.
public func clearMonthOverrides(_ overrides: [String], _ year: Int, _ month: Int) -> [String] {
    let prefix = String(format: "%04d-%02d-", year, month + 1)
    return overrides.filter { !$0.hasPrefix(prefix) }
}
