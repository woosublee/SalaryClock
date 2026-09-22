import Foundation
import SalaryClockCore

public extension Notification.Name {
    static let settingsChanged = Notification.Name("dev.woosublee.salaryclock.settingsChanged")
}

/// UserDefaults에 설정을 담는다.
///
/// 웹은 브라우저 localStorage를 쓰므로 설정이 이어지지 않는다. 맥에서
/// 한 번 새로 넣어야 한다.
///
/// 저장된 값이 규칙을 어기면 기본값으로 되돌린다 — 웹의 zod 검증이 하던 일이다.
public final class SettingsStore: @unchecked Sendable {
    public static let shared = SettingsStore()

    private static let key = "settings.v2"
    private let lock = NSLock()
    private var cached: Settings

    private init() {
        cached = Self.load()
    }

    public var settings: Settings {
        get { lock.withLock { cached } }
        set {
            lock.withLock { cached = newValue }
            Self.save(newValue)
            NotificationCenter.default.post(name: .settingsChanged, object: nil)
        }
    }

    public func reload() {
        lock.withLock { cached = Self.load() }
        NotificationCenter.default.post(name: .settingsChanged, object: nil)
    }

    private static func load() -> Settings {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode(Settings.self, from: data),
              isValid(decoded)
        else { return .default }
        return decoded
    }

    private static func save(_ s: Settings) {
        guard let data = try? JSONEncoder().encode(s) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    /// 웹 zod 스키마의 규칙을 옮긴 것. 하나라도 깨지면 기본값으로 돌아간다.
    static func isValid(_ s: Settings) -> Bool {
        guard s.payAmount > 0, s.payAmount.isFinite else { return false }
        guard s.workDaysPerMonth > 0, s.workDaysPerMonth <= 31 else { return false }
        guard isValidHHmm(s.workStart), isValidHHmm(s.workEnd) else { return false }
        guard let start = parseHHmm(s.workStart), let end = parseHHmm(s.workEnd) else { return false }
        let shiftMin = durationMinutes(start, end)
        guard shiftMin > 0 else { return false }
        if let r = s.deductionRate, !(r >= 0 && r <= 0.9) { return false }
        guard s.lunchEnabled else { return true }
        guard isValidHHmm(s.lunchStart), let ls = parseHHmm(s.lunchStart) else { return false }
        guard s.lunchMinutes > 0, s.lunchMinutes < shiftMin else { return false }
        return durationMinutes(start, ls) + s.lunchMinutes <= shiftMin
    }
}
