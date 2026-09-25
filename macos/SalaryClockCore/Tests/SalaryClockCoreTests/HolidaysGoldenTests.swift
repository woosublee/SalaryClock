import Foundation
import Testing
@testable import SalaryClockCore

/// Holidays.swift는 lib/holidays.ts를 손으로 옮긴 표다. 다른 골든은 몇몇
/// 날짜만 건드리므로, 여기서 표 전체를 날마다 웹과 비교한다.
private struct HolidaysGolden: Decodable {
    struct Year: Decodable {
        let year: Int
        let hasHolidayData: Bool
        let dates: [String]
    }
    let range: [Int]
    let years: [Year]
}

@Test("골든 — holidays: 표 전체가 웹과 날마다 같다")
func goldenHolidays() throws {
    let g = try Golden.decode("holidays.json", as: HolidaysGolden.self)
    #expect(g.years.count == g.range[1] - g.range[0] + 1)

    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!

    for y in g.years {
        #expect(hasHolidayData(y.year) == y.hasHolidayData, "\(y.year) hasHolidayData")

        var actual: [String] = []
        for month in 0..<12 {
            let first = calendar.date(from: DateComponents(year: y.year, month: month + 1, day: 1))!
            let days = calendar.range(of: .day, in: .month, for: first)!.count
            for day in 1...days where isHoliday(y.year, month, day) {
                actual.append(dateKey(y.year, month, day))
            }
        }
        #expect(actual == y.dates, "\(y.year)년 공휴일")
    }
}
