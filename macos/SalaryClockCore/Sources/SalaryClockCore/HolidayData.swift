import CryptoKit
import Foundation

/// 서명된 공휴일 자료를 검증하고 해석한다 — 입출력은 하지 않는다.
///
/// 자료는 알람 앱(RoutineAlarm)과 같은 것을 쓴다. 공개 저장소 woosublee/kairos의
/// holiday-data/에 manifest.json, 그 Ed25519 서명(manifest.json.sig), 연도별
/// holidays-YYYY.json이 있다. 매니페스트가 각 파일의 SHA-256을 담고 그 매니페스트에
/// 서명하므로, 서명 하나로 전체가 묶인다. 해마다 관보가 나면 그쪽만 고치면 두 앱이
/// 함께 따라간다.
///
/// 내려받기·저장·하루 제한은 iOS 앱(ios/SalaryClock/HolidayUpdater.swift)이 한다.
public enum HolidayData {
    public static let manifestName = "manifest.json"
    public static let signatureName = "manifest.json.sig"

    /// kairos 서명 키의 공개 키. 개인 키는 관리자 Mac의
    /// ~/.config/kairos/holiday-signing-key에만 있다. 키를 바꾸려면 앱을 다시 내야 한다.
    public static let publicKeyBase64 = "Q2MKQ1wzT9degx0n2QBJS663BAjMwaSKDmcCCkaPcFk="

    public static let publicKey: Curve25519.Signing.PublicKey = {
        // 상수가 깨져 있으면 출시 전에 바로 드러나야 한다(테스트가 실제 서명으로 확인한다).
        try! Curve25519.Signing.PublicKey(rawRepresentation: Data(base64Encoded: publicKeyBase64)!)
    }()

    public enum Failure: Error, Equatable {
        case signature
        case manifest
        case missingFile(String)
        case hash(String)
        case yearFile(String)
    }

    /// 매니페스트에서 내려받을 파일 목록과 버전 정보만 뽑은 것.
    public struct Manifest: Equatable, Sendable {
        public struct File: Equatable, Sendable {
            public let year: Int
            public let filename: String
            public let sha256: String
        }
        /// "YYYY-MM-DD". 같은 형식이라 문자열 비교가 곧 날짜 비교다.
        public let verifiedAt: String
        public let coverageEndExclusive: String
        public let files: [File]
    }

    /// 검증을 마친 자료.
    public struct Verified: Equatable, Sendable {
        public let manifest: Manifest
        public let holidays: [Int: Set<String>]
    }

    /// 서명을 확인하고 매니페스트를 읽는다. 파일 이름은 `holidays-<연도>.json`
    /// 꼴만 받는다 — 서명이 맞더라도 경로를 거슬러 올라가는 이름은 저장하지 않는다.
    public static func verifyManifest(
        _ manifest: Data, signature: Data,
        publicKey: Curve25519.Signing.PublicKey = publicKey
    ) throws(Failure) -> Manifest {
        guard let text = String(data: signature, encoding: .utf8),
              let sig = Data(base64Encoded: text.trimmingCharacters(in: .whitespacesAndNewlines)),
              publicKey.isValidSignature(sig, for: manifest) else {
            throw .signature
        }
        guard let raw = try? JSONDecoder().decode(RawManifest.self, from: manifest),
              raw.schemaVersion == 1,
              isDay(raw.verifiedAt), isDay(raw.coverageEndExclusive),
              !raw.files.isEmpty,
              Set(raw.files.map(\.filename)).count == raw.files.count else {
            throw .manifest
        }
        let files = raw.files.map { Manifest.File(year: $0.year, filename: $0.filename, sha256: $0.sha256.lowercased()) }
        guard files.allSatisfy({ f in
            f.filename == "holidays-\(f.year).json" && (1900...9999).contains(f.year)
                && f.sha256.count == 64 && f.sha256.allSatisfy(\.isHexDigit)
        }) else {
            throw .manifest
        }
        return Manifest(verifiedAt: raw.verifiedAt, coverageEndExclusive: raw.coverageEndExclusive, files: files)
    }

    /// 서명된 매니페스트와 연도 파일 전체를 검증해 공휴일 표로 만든다.
    /// `files`는 파일 이름 → 내용. 하나라도 어긋나면 전체를 버린다.
    public static func verify(
        manifest: Data, signature: Data, files: [String: Data],
        publicKey: Curve25519.Signing.PublicKey = publicKey
    ) throws(Failure) -> Verified {
        let m = try verifyManifest(manifest, signature: signature, publicKey: publicKey)
        var holidays: [Int: Set<String>] = [:]
        for file in m.files {
            guard let data = files[file.filename] else { throw .missingFile(file.filename) }
            guard sha256(data) == file.sha256 else { throw .hash(file.filename) }
            guard let dates = parseYear(data, year: file.year) else { throw .yearFile(file.filename) }
            holidays[file.year] = dates
        }
        return Verified(manifest: m, holidays: holidays)
    }

    /// 지금 쓰는 자료보다 나은가: 줄어드는 것 없이 기준일이나 포함 기간 중 하나가 늘었다.
    /// current가 nil(아직 받은 적 없음)이면 언제나 낫다.
    public static func isNewer(_ candidate: Manifest, than current: Manifest?) -> Bool {
        guard let current else { return true }
        if candidate.verifiedAt < current.verifiedAt { return false }
        if candidate.coverageEndExclusive < current.coverageEndExclusive { return false }
        return candidate.verifiedAt > current.verifiedAt
            || candidate.coverageEndExclusive > current.coverageEndExclusive
    }

    public static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    /// 연도 파일 하나. 날짜는 그 해 안의 실제 날짜여야 하고 겹치면 안 된다.
    /// `kind`(설날·대체공휴일·선거일 등)는 보지 않는다 — 이 앱에서는 모두 쉬는 날이다.
    static func parseYear(_ data: Data, year: Int) -> Set<String>? {
        guard let raw = try? JSONDecoder().decode(RawYear.self, from: data),
              raw.schemaVersion == 1, raw.year == year,
              (1...60).contains(raw.holidays.count) else {
            return nil
        }
        let dates = raw.holidays.map(\.date)
        guard Set(dates).count == dates.count,
              dates.allSatisfy({ isDay($0) && $0.hasPrefix("\(year)-") }) else {
            return nil
        }
        return Set(dates)
    }

    /// "YYYY-MM-DD"이고 달력에 실제로 있는 날인가.
    static func isDay(_ s: String) -> Bool {
        let parts = s.split(separator: "-", omittingEmptySubsequences: false)
        guard s.count == 10, parts.count == 3,
              let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2]),
              (1...12).contains(m), d >= 1 else {
            return false
        }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        guard let date = cal.date(from: DateComponents(year: y, month: m, day: 1)),
              let range = cal.range(of: .day, in: .month, for: date) else {
            return false
        }
        return range.contains(d)
    }

    private struct RawManifest: Decodable {
        struct File: Decodable {
            let year: Int
            let filename: String
            let sha256: String
        }
        let schemaVersion: Int
        let verifiedAt: String
        let coverageEndExclusive: String
        let files: [File]
    }

    private struct RawYear: Decodable {
        struct Holiday: Decodable { let date: String }
        let schemaVersion: Int
        let year: Int
        let holidays: [Holiday]
    }
}
