import Testing
import Foundation
@testable import SalaryClockCore

struct CalendarCase: Decodable {
    struct Cell: Decodable {
        let date: String; let day: Int; let dow: Int; let kind: String; let isWorkday: Bool
    }
    struct Expected: Decodable { let workdays: Int; let cells: [Cell] }
    let label: String
    let year: Int
    let month: Int
    let overrides: [String]
    let expected: Expected
}

@Test("골든 — calendar")
func goldenCalendar() throws {
    let cases: [CalendarCase] = try Golden.decode("calendar.json", as: [CalendarCase].self)
    #expect(cases.count > 0)

    for c in cases {
        #expect(workdaysFromCalendar(c.year, c.month, c.overrides) == c.expected.workdays, "\(c.label) workdays")
        let cells = monthCells(c.year, c.month, c.overrides)
        #expect(cells.count == c.expected.cells.count, "\(c.label) 칸 수")
        for (i, want) in c.expected.cells.enumerated() {
            let got = cells[i]
            #expect(got.date == want.date, "\(c.label) [\(i)] date")
            #expect(got.day == want.day, "\(c.label) [\(i)] day")
            #expect(got.dow == want.dow, "\(c.label) [\(i)] dow")
            #expect(got.kind.rawValue == want.kind, "\(c.label) [\(i)] kind")
            #expect(got.isWorkday == want.isWorkday, "\(c.label) [\(i)] isWorkday")
        }
    }
}

@Test("override는 기본값을 뒤집는다")
func overrideFlips() {
    let plain = monthCells(2026, 8, [])
    let flipped = monthCells(2026, 8, ["2026-09-22", "2026-09-26"])
    #expect(plain[21].kind == .work && flipped[21].kind == .customOff)
    #expect(plain[25].kind == .weekend && flipped[25].kind == .customWork)
}

@Test("toggleOverride는 넣고 빼고 정렬한다")
func toggles() {
    let once = toggleOverride([], "2026-09-22")
    #expect(once == ["2026-09-22"])
    #expect(toggleOverride(once, "2026-09-22").isEmpty)
    #expect(toggleOverride(["2026-09-24"], "2026-09-22") == ["2026-09-22", "2026-09-24"])
}

@Test("clearMonthOverrides는 그 달만 지운다")
func clearsOneMonth() {
    let all = ["2026-08-15", "2026-09-22", "2026-09-26", "2026-10-03"]
    #expect(clearMonthOverrides(all, 2026, 8) == ["2026-08-15", "2026-10-03"])
}
