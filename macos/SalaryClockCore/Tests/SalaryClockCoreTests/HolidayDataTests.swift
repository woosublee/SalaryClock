import Foundation
import Testing
@testable import SalaryClockCore

/// kairos 저장소에 올라간 것과 같은 자료(Fixtures/holiday-data). 실제 서명이 앱의
/// 공개 키로 검증되는지까지 본다 — 키 상수를 잘못 옮기면 여기서 걸린다.
private enum Fixture {
    static let dir = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("Fixtures/holiday-data")

    static func data(_ name: String) -> Data {
        try! Data(contentsOf: dir.appendingPathComponent(name))
    }

    static var manifest: Data { data(HolidayData.manifestName) }
    static var signature: Data { data(HolidayData.signatureName) }
    static var files: [String: Data] {
        ["holidays-2026.json": data("holidays-2026.json"), "holidays-2027.json": data("holidays-2027.json")]
    }
}

@Test("실제 서명된 자료를 앱의 공개 키로 검증한다")
func verifiesRealSignedData() throws {
    let v = try HolidayData.verify(manifest: Fixture.manifest, signature: Fixture.signature, files: Fixture.files)
    #expect(v.manifest.verifiedAt == "2026-09-13")
    #expect(v.manifest.coverageEndExclusive == "2028-01-01")
    #expect(Set(v.holidays.keys) == [2026, 2027])
    // 앱에 든 표에 없던 날 — 원격 갱신이 필요한 이유다.
    #expect(v.holidays[2027]!.contains("2027-07-19"))
    #expect(v.holidays[2026]!.contains("2026-06-03"))
}

@Test("매니페스트가 한 글자라도 바뀌면 서명에서 걸린다")
func rejectsTamperedManifest() {
    var tampered = Fixture.manifest
    tampered[tampered.count - 2] ^= 0x01
    #expect(throws: HolidayData.Failure.signature) {
        try HolidayData.verify(manifest: tampered, signature: Fixture.signature, files: Fixture.files)
    }
}

@Test("연도 파일이 매니페스트의 해시와 다르면 버린다")
func rejectsHashMismatch() {
    var files = Fixture.files
    files["holidays-2027.json"] = Data("{}".utf8)
    #expect(throws: HolidayData.Failure.hash("holidays-2027.json")) {
        try HolidayData.verify(manifest: Fixture.manifest, signature: Fixture.signature, files: files)
    }
}

@Test("매니페스트에 있는 파일이 없으면 버린다")
func rejectsMissingFile() {
    var files = Fixture.files
    files["holidays-2026.json"] = nil
    #expect(throws: HolidayData.Failure.missingFile("holidays-2026.json")) {
        try HolidayData.verify(manifest: Fixture.manifest, signature: Fixture.signature, files: files)
    }
}

@Test("연도 파일은 그 해의 실제 날짜만 겹치지 않게 담아야 한다")
func parsesYearStrictly() {
    func year(_ dates: [String], year: Int = 2026) -> Set<String>? {
        let holidays = dates.map { "{\"date\":\"\($0)\"}" }.joined(separator: ",")
        let json = "{\"schemaVersion\":1,\"year\":\(year),\"holidays\":[\(holidays)]}"
        return HolidayData.parseYear(Data(json.utf8), year: 2026)
    }
    #expect(year(["2026-01-01", "2026-12-25"]) == ["2026-01-01", "2026-12-25"])
    #expect(year(["2026-01-01", "2026-01-01"]) == nil)  // 겹침
    #expect(year(["2027-01-01"]) == nil)  // 다른 해의 날짜
    #expect(year(["2026-02-30"]) == nil)  // 없는 날
    #expect(year(["2026-01-01"], year: 2027) == nil)  // 파일의 해가 다름
    #expect(year([]) == nil)
}

@Test("기준일이나 포함 기간이 줄어드는 자료는 새 자료로 보지 않는다")
func newerRules() {
    func m(_ verified: String, _ end: String) -> HolidayData.Manifest {
        .init(verifiedAt: verified, coverageEndExclusive: end, files: [])
    }
    let current = m("2026-09-13", "2028-01-01")
    #expect(HolidayData.isNewer(current, than: nil))
    #expect(!HolidayData.isNewer(current, than: current))
    #expect(HolidayData.isNewer(m("2026-10-01", "2028-01-01"), than: current))
    #expect(HolidayData.isNewer(m("2026-09-13", "2029-01-01"), than: current))
    #expect(!HolidayData.isNewer(m("2026-10-01", "2027-01-01"), than: current))
    #expect(!HolidayData.isNewer(m("2026-09-01", "2029-01-01"), than: current))
}
