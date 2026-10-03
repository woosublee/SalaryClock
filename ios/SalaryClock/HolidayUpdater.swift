import Foundation
import Observation
import SalaryClockCore

/// 서명된 공휴일 자료를 내려받아, 앱 업데이트 없이 공휴일 표를 바꾼다.
///
/// 구조는 알람 앱(RoutineAlarm)의 HolidayDataUpdater와 같고, 받는 자료도 같다
/// (woosublee/kairos의 holiday-data/). 검증 규칙은 SalaryClockCore의 HolidayData에
/// 있고, 여기는 내려받기·저장·하루 제한만 맡는다.
///
/// - 앱이 켜지거나 앞으로 돌아올 때 확인하되, 하루에 한 번만 시도한다.
/// - 어느 단계든 실패하면 지금 쓰는 자료를 그대로 둔다.
/// - 받은 자료가 다루는 해만 바꾸고, 나머지 해는 앱에 든 표를 쓴다.
@MainActor
@Observable
final class HolidayUpdater {
    static let shared = HolidayUpdater()

    static let baseURL = URL(string: "https://raw.githubusercontent.com/woosublee/kairos/main/holiday-data/")!
    static let throttleInterval: TimeInterval = 24 * 60 * 60
    static let lastAttemptKey = "holidayData.lastAttemptAt"
    static let lastCheckedKey = "holidayData.lastCheckedAt"

    enum Result: Equatable {
        case updated
        case upToDate
        case skipped
        case failed(String)
    }

    /// 지금 쓰고 있는 내려받은 자료. nil이면 앱에 든 표만 쓴다.
    private(set) var active: HolidayData.Manifest?
    private(set) var lastCheckedAt: Date?
    private(set) var isChecking = false

    @ObservationIgnored private let fetcher = Fetcher()
    @ObservationIgnored private let fileManager = FileManager.default
    @ObservationIgnored private let defaults = UserDefaults.standard
    @ObservationIgnored private var inFlight: Task<Result, Never>?

    /// Application Support/HolidayData
    private var directory: URL? {
        fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("HolidayData", isDirectory: true)
    }

    private init() {
        lastCheckedAt = defaults.object(forKey: Self.lastCheckedKey) as? Date
        loadDownloaded()
    }

    /// 전에 받아 둔 자료를 다시 검증해 쓴다. 깨졌으면 앱에 든 표로 돌아간다.
    private func loadDownloaded() {
        guard let directory, let verified = Self.read(directory) else { return }
        setDownloadedHolidays(verified.holidays)
        active = verified.manifest
    }

    private static func read(_ directory: URL) -> HolidayData.Verified? {
        func data(_ name: String) -> Data? { try? Data(contentsOf: directory.appendingPathComponent(name)) }
        guard let manifest = data(HolidayData.manifestName),
              let signature = data(HolidayData.signatureName),
              let m = try? HolidayData.verifyManifest(manifest, signature: signature) else {
            return nil
        }
        var files: [String: Data] = [:]
        for file in m.files { files[file.filename] = data(file.filename) }
        return try? HolidayData.verify(manifest: manifest, signature: signature, files: files)
    }

    /// force가 아니면 마지막 시도로부터 하루가 지나야 확인한다. 이미 확인 중이면
    /// 그 결과를 같이 기다린다.
    @discardableResult
    func check(force: Bool = false) async -> Result {
        if let inFlight { return await inFlight.value }
        let now = Date()
        if !force, let last = defaults.object(forKey: Self.lastAttemptKey) as? Date,
           now >= last, now.timeIntervalSince(last) < Self.throttleInterval {
            return .skipped
        }
        // 시도한 시각을 먼저 남긴다 — 실패해도 하루에 한 번만 두드린다.
        defaults.set(now, forKey: Self.lastAttemptKey)
        isChecking = true
        let task = Task { await perform() }
        inFlight = task
        let result = await task.value
        inFlight = nil
        isChecking = false
        return result
    }

    private func perform() async -> Result {
        guard let directory else { return .failed("자료를 둘 곳이 없어요") }

        let manifestData: Data
        let signatureData: Data
        let manifest: HolidayData.Manifest
        do {
            manifestData = try await fetcher.data(Self.baseURL.appendingPathComponent(HolidayData.manifestName))
            signatureData = try await fetcher.data(Self.baseURL.appendingPathComponent(HolidayData.signatureName))
        } catch {
            return .failed("자료를 받지 못했어요")
        }
        do {
            manifest = try HolidayData.verifyManifest(manifestData, signature: signatureData)
        } catch {
            return .failed("자료 서명이 맞지 않아요")
        }
        guard HolidayData.isNewer(manifest, than: active) else {
            markChecked()
            return .upToDate
        }

        var files: [String: Data] = [:]
        for file in manifest.files {
            do {
                files[file.filename] = try await fetcher.data(Self.baseURL.appendingPathComponent(file.filename))
            } catch {
                return .failed("자료를 받지 못했어요")
            }
        }
        guard let verified = try? HolidayData.verify(manifest: manifestData, signature: signatureData, files: files) else {
            return .failed("자료 검증에 실패했어요")
        }

        // 옆 폴더에 다 쓴 뒤 한 번에 바꾼다. 도중에 앱이 꺼져도 이전 자료가 남는다.
        let staging = directory.deletingLastPathComponent()
            .appendingPathComponent(".HolidayData-staging-\(UUID().uuidString)", isDirectory: true)
        defer { try? fileManager.removeItem(at: staging) }
        do {
            try fileManager.createDirectory(at: staging, withIntermediateDirectories: true)
            try manifestData.write(to: staging.appendingPathComponent(HolidayData.manifestName))
            try signatureData.write(to: staging.appendingPathComponent(HolidayData.signatureName))
            for (name, data) in files { try data.write(to: staging.appendingPathComponent(name)) }
            if fileManager.fileExists(atPath: directory.path) {
                _ = try fileManager.replaceItemAt(directory, withItemAt: staging)
            } else {
                try fileManager.moveItem(at: staging, to: directory)
            }
        } catch {
            // replaceItemAt이 도중에 실패하면 원본이 다른 곳(임시 위치)에 남아 있을 수
            // 있다 — 오류가 그 위치를 알려 주면 제자리로 돌려 다음 실행에도 읽히게 한다.
            if let original = (error as NSError).userInfo["NSFileOriginalItemLocationKey"] as? URL,
               original.standardizedFileURL != directory.standardizedFileURL,
               !fileManager.fileExists(atPath: directory.path) {
                try? fileManager.moveItem(at: original, to: directory)
            }
            return .failed("자료를 저장하지 못했어요")
        }

        setDownloadedHolidays(verified.holidays)
        active = verified.manifest
        markChecked()
        return .updated
    }

    private func markChecked() {
        lastCheckedAt = Date()
        defaults.set(lastCheckedAt, forKey: Self.lastCheckedKey)
    }

    /// 쿠키·캐시·추가 헤더 없이 GET만 한다. 기기를 알아볼 수 있는 정보는 보내지 않는다.
    private struct Fetcher {
        static let maxBytes = 512 * 1024
        let session: URLSession = {
            let c = URLSessionConfiguration.ephemeral
            c.httpCookieStorage = nil
            c.httpShouldSetCookies = false
            c.urlCache = nil
            c.urlCredentialStorage = nil
            c.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            c.timeoutIntervalForRequest = 15
            c.timeoutIntervalForResource = 30
            c.waitsForConnectivity = false
            return URLSession(configuration: c)
        }()

        func data(_ url: URL) async throws -> Data {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200,
                  data.count <= Self.maxBytes else {
                throw URLError(.badServerResponse)
            }
            return data
        }
    }
}
