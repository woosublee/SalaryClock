import Testing
import Foundation
@testable import SalaryClockCore

struct AfterWorkCase: Decodable {
    let label: String
    let settings: String
    let at: [Int]
    let expected: String
}

@Test("골든 — afterWork")
func goldenAfterWork() throws {
    let settings: [String: Settings] = try Golden.decode("settings.json", as: [String: Settings].self)
    let cases: [AfterWorkCase] = try Golden.decode("afterWork.json", as: [AfterWorkCase].self)
    #expect(cases.count > 0)

    for c in cases {
        let s = try #require(settings[c.settings], "알 수 없는 설정: \(c.settings)")
        let want = try #require(AfterWorkKind(rawValue: c.expected), "알 수 없는 kind: \(c.expected)")
        let got = afterWorkKind(s, Golden.ms(c.at))
        #expect(got == want, "\(c.label) (\(c.settings))")
    }
}
