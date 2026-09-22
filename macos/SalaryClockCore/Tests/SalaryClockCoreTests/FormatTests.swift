import Testing
import Foundation
@testable import SalaryClockCore

struct FormatGolden: Decodable {
    struct NumCase: Decodable { let n: Double; let expected: String }
    struct MsCase: Decodable { let ms: Int; let expected: String }
    struct AtCase: Decodable { let at: [Int]; let expected: String }
    let won: [NumCase]
    let wonOneDecimal: [NumCase]
    let perSecond: [NumCase]
    let duration: [MsCase]
    let koreanUnits: [NumCase]
    let dateKo: [AtCase]
    let clockTime: [AtCase]
}

@Test("골든 — format")
func goldenFormat() throws {
    let g: FormatGolden = try Golden.decode("format.json", as: FormatGolden.self)
    #expect(g.won.count > 0)

    for c in g.won { #expect(formatWon(c.n) == c.expected, "formatWon(\(c.n))") }
    for c in g.wonOneDecimal {
        #expect(formatWon(c.n, fractionDigits: 1) == c.expected, "formatWon(\(c.n), 1)")
    }
    for c in g.perSecond {
        #expect(formatPerSecond(c.n) == c.expected, "formatPerSecond(\(c.n))")
    }
    for c in g.duration {
        #expect(formatDuration(c.ms) == c.expected, "formatDuration(\(c.ms))")
    }
    for c in g.koreanUnits {
        #expect(formatKoreanUnits(c.n) == c.expected, "formatKoreanUnits(\(c.n))")
    }
    for c in g.dateKo {
        #expect(formatDateKo(Golden.ms(c.at)) == c.expected, "formatDateKo(\(c.at))")
    }
    for c in g.clockTime {
        #expect(formatClockTime(Golden.ms(c.at)) == c.expected, "formatClockTime(\(c.at))")
    }
}

@Test("금액은 반올림하지 않고 내린다")
func alwaysFloors() {
    #expect(formatWon(0.9) == formatWon(0))
    #expect(formatWon(1.999) == formatWon(1))
}
