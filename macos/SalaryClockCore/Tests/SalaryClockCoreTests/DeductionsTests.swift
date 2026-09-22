import Testing
import Foundation
@testable import SalaryClockCore

struct DeductionCase: Decodable {
    struct Expected: Decodable {
        let pension: Double
        let health: Double
        let longTermCare: Double
        let employment: Double
        let incomeTax: Double
        let total: Double
        let rate: Double
    }
    let gross: Double
    let expected: Expected
}

@Test("골든 — deductions")
func goldenDeductions() throws {
    let cases: [DeductionCase] = try Golden.decode("deductions.json", as: [DeductionCase].self)
    #expect(cases.count > 0)

    for c in cases {
        let got = estimateDeductions(c.gross)
        let what = "gross \(c.gross)"
        expectClose(got.pension, c.expected.pension, "\(what) pension")
        expectClose(got.health, c.expected.health, "\(what) health")
        expectClose(got.longTermCare, c.expected.longTermCare, "\(what) longTermCare")
        expectClose(got.employment, c.expected.employment, "\(what) employment")
        expectClose(got.incomeTax, c.expected.incomeTax, "\(what) incomeTax")
        expectClose(got.total, c.expected.total, "\(what) total")
        expectClose(got.rate, c.expected.rate, "\(what) rate")
    }
}

@Test("0 이하는 전부 0이다")
func nonPositiveGross() {
    let d = estimateDeductions(0)
    #expect(d.total == 0)
    #expect(d.rate == 0)
}

@Test("검산 — 세전 300만의 실수령은 261.7만 근처다")
func sanityCheck() {
    let d = estimateDeductions(3_000_000)
    let net = 3_000_000 - d.total
    #expect(net > 2_600_000 && net < 2_630_000, "실수령 \(net)")
}
