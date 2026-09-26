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
    let d = try #require(all["default"])
    #expect(d.payAmount == 40_000_000)
    #expect(d.workStart == "09:00")
    #expect(d.lunchMinutes == 60)
}

/// 디코더는 모르는 키를 조용히 버린다. 웹에 필드가 늘었는데 여기만 빠뜨리면
/// 골든은 통과하고 값만 사라지므로, 인코딩한 키를 골든의 키와 직접 맞춰 본다.
@Test("설정 필드가 골든과 1:1로 맞는다")
func settingsKeysMatchGolden() throws {
    let data = try Data(contentsOf: Golden.url("settings.json"))
    let raw = try #require(try JSONSerialization.jsonObject(with: data) as? [String: [String: Any]])
    let goldenKeys = Set(try #require(raw["default"]).keys)
    // 옵셔널이 nil이면 인코더가 키째 빼므로 값을 채워 둔다.
    var full = Settings.default
    full.deductionRate = 0.1
    let encoded = try JSONSerialization.jsonObject(with: JSONEncoder().encode(full))
    let ours = Set(try #require(encoded as? [String: Any]).keys)
    #expect(ours == goldenKeys)
}

@Test("hour12가 없던 예전 저장값은 24시간제로 읽는다")
func legacySettingsDefaultToHour24() throws {
    let json = #"{"payAmount": 55000000, "hideAmount": true}"#
    let s = try JSONDecoder().decode(Settings.self, from: Data(json.utf8))
    #expect(s.payAmount == 55_000_000)
    #expect(s.hour12 == false)
}

@Test("골든의 시각 배열을 로컬 시각으로 되돌린다")
func convertsClockArray() throws {
    let got = Golden.ms([2026, 8, 22, 9, 0, 0])
    var c = DateComponents()
    c.year = 2026; c.month = 9; c.day = 22; c.hour = 9; c.minute = 0; c.second = 0
    let want = appCalendar.date(from: c)!
    #expect(got == Int(want.timeIntervalSince1970 * 1000))
}
