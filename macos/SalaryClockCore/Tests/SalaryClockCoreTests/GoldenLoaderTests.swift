import Testing
import Foundation
@testable import SalaryClockCore

@Test("골든 디렉터리를 찾는다")
func findsGoldenDirectory() throws {
    #expect(FileManager.default.fileExists(atPath: Golden.url("settings.json").path))
}

@Test("설정 골든을 읽는다")
func decodesSettingsGolden() throws {
    let all: [String: Settings] = try Golden.decode("settings.json", as: [String: Settings].self)
    #expect(all.count == 10)
    let d = try #require(all["default"])
    #expect(d.payAmount == 40_000_000)
    #expect(d.workStart == "09:00")
    #expect(d.lunchMinutes == 60)
}

@Test("골든의 시각 배열을 로컬 시각으로 되돌린다")
func convertsClockArray() throws {
    let got = Golden.ms([2026, 8, 22, 9, 0, 0])
    var c = DateComponents()
    c.year = 2026; c.month = 9; c.day = 22; c.hour = 9; c.minute = 0; c.second = 0
    let want = appCalendar.date(from: c)!
    #expect(got == Int(want.timeIntervalSince1970 * 1000))
}
