import Testing
import Foundation
@testable import SalaryClockCore

struct ShiftCase: Decodable {
    struct Expected: Decodable {
        let start: [Int]
        let end: [Int]
        let lunchStart: [Int]?
        let lunchEnd: [Int]?
        let paidMs: Int
    }
    let label: String
    let settings: String
    let at: [Int]
    let expected: Expected
}

@Test("골든 — shift")
func goldenShift() throws {
    let settings: [String: Settings] = try Golden.decode("settings.json", as: [String: Settings].self)
    let cases: [ShiftCase] = try Golden.decode("shift.json", as: [ShiftCase].self)
    #expect(cases.count > 0)

    for c in cases {
        let s = try #require(settings[c.settings], "알 수 없는 설정: \(c.settings)")
        let got = resolveShift(s, Golden.ms(c.at))
        let what = "\(c.label) (\(c.settings))"

        #expect(got.startMs == Golden.ms(c.expected.start), "\(what) startMs")
        #expect(got.endMs == Golden.ms(c.expected.end), "\(what) endMs")
        #expect(got.lunchStartMs == Golden.msOrNull(c.expected.lunchStart), "\(what) lunchStartMs")
        #expect(got.lunchEndMs == Golden.msOrNull(c.expected.lunchEnd), "\(what) lunchEndMs")
        #expect(got.paidMs == c.expected.paidMs, "\(what) paidMs")
    }
}

@Test("paidMsBetween — 점심을 가로지르면 점심만큼 뺀다")
func paidMsAcrossLunch() {
    let shift = resolveShift(.default, Golden.ms([2026, 8, 22, 14, 0, 0]))
    let from = Golden.ms([2026, 8, 22, 11, 0, 0])
    let to = Golden.ms([2026, 8, 22, 14, 0, 0])
    #expect(paidMsBetween(shift, from, to) == 2 * MS_PER_HOUR)
}

@Test("paidMsBetween — 시프트 밖은 잘라낸다")
func paidMsClamps() {
    let shift = resolveShift(.default, Golden.ms([2026, 8, 22, 14, 0, 0]))
    #expect(paidMsBetween(shift, shift.startMs - MS_PER_HOUR, shift.startMs) == 0)
    #expect(paidMsBetween(shift, shift.endMs, shift.endMs + MS_PER_HOUR) == 0)
    #expect(paidMsBetween(shift, shift.startMs, shift.endMs) == shift.paidMs)
}
