import Foundation

/// "YYYY-MM-DD". month는 0-based.
public func dateKey(_ year: Int, _ month: Int, _ day: Int) -> String {
    String(format: "%04d-%02d-%02d", year, month + 1, day)
}

/// 0=일 … 6=토. month는 0-based.
func weekday(_ year: Int, _ month: Int, _ day: Int) -> Int {
    var c = DateComponents()
    c.year = year; c.month = month + 1; c.day = day; c.hour = 12
    let date = Calendar.current.date(from: c)!
    return Calendar.current.component(.weekday, from: date) - 1
}

/// 아무것도 지정하지 않았을 때 쉬는 날인가 — 주말이거나 공휴일.
public func isDefaultOff(_ year: Int, _ month: Int, _ day: Int) -> Bool {
    let dow = weekday(year, month, day)
    if dow == 0 || dow == 6 { return true }
    return isHoliday(year, month, day)
}

/// 그 날짜가 쉬는 날인가.
///
/// 기본값은 주말·공휴일이고, overrides에 든 날짜는 기본값을 뒤집는다.
/// workDaysMode와 무관하게 반영한다 — 달력에서 "이날은 쉰다"고 찍은 건
/// 근무일수를 어떤 방식으로 세는지와 별개로 참인 사실이다.
public func isDayOff(_ overrides: [String], _ dateMs: Int) -> Bool {
    let date = Date(timeIntervalSince1970: Double(dateMs) / 1000)
    let cal = Calendar.current
    let year = cal.component(.year, from: date)
    let month = cal.component(.month, from: date) - 1
    let day = cal.component(.day, from: date)

    let defaultOff = isDefaultOff(year, month, day)
    return overrides.contains(dateKey(year, month, day)) ? !defaultOff : defaultOff
}
