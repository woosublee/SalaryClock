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
    private var cachedHasStored: Bool

    private init() {
        (cached, cachedHasStored) = Self.load()
    }

    public var settings: Settings {
        get { lock.withLock { cached } }
        set {
            lock.withLock { cached = newValue; cachedHasStored = true }
            Self.save(newValue)
            NotificationCenter.default.post(name: .settingsChanged, object: nil)
        }
    }

    /// 저장된 값이 있었는지 — 웹 `lib/settings.ts`의 `loadSettings`가 돌려주는
    /// `hasStored`와 같다. 저장된 게 전혀 없거나 깨져 있으면 false다: 이때
    /// 팝오버·설정 창은 `settings.theme` 대신 `@Environment(\.colorScheme)`로
    /// 기기 설정을 따라간다. 한 번이라도 저장하면(사용자가 토글을 누르면)
    /// true로 굳는다 — 그 뒤로는 기기 설정이 바뀌어도 고른 값을 지킨다.
    public var hasStored: Bool {
        lock.withLock { cachedHasStored }
    }

    public func reload() {
        lock.withLock { (cached, cachedHasStored) = Self.load() }
        NotificationCenter.default.post(name: .settingsChanged, object: nil)
    }

    private static func load() -> (Settings, Bool) {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode(Settings.self, from: data),
              isValid(decoded)
        else { return (.default, false) }
        return (decoded, true)
    }

    private static func save(_ s: Settings) {
        guard let data = try? JSONEncoder().encode(s) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    /// 웹 `lib/settings.ts`의 `SettingsSchema` 규칙을 옮긴 것. 하나라도 깨지면 기본값으로 돌아간다.
    static func isValid(_ s: Settings) -> Bool {
        guard s.payAmount > 0, s.payAmount.isFinite else { return false }
        guard s.workDaysPerMonth > 0, s.workDaysPerMonth <= 31 else { return false }
        guard isValidHHmm(s.workStart), isValidHHmm(s.workEnd) else { return false }
        // 웹 스키마는 lunchStart를 lunchEnabled와 무관하게 항상 HH:mm 형식으로
        // 요구한다(SettingsSchema의 최상위 필드라 조건부가 아니다) — 여기서도
        // lunchEnabled 분기보다 먼저 검사한다.
        guard isValidHHmm(s.lunchStart) else { return false }
        // 웹도 lunchMinutes를 0..1440으로 항상(lunchEnabled와 무관하게) 제한한다.
        guard s.lunchMinutes >= 0, s.lunchMinutes <= 1440 else { return false }
        guard s.dayOverrides.count <= 732, s.dayOverrides.allSatisfy(isValidDateString) else { return false }
        guard validClockStyles.contains(s.clockStyle) else { return false }
        guard let start = parseHHmm(s.workStart), let end = parseHHmm(s.workEnd) else { return false }
        let shiftMin = durationMinutes(start, end)
        guard shiftMin > 0 else { return false }
        if let r = s.deductionRate, !(r >= 0 && r <= 0.9) { return false }
        guard s.lunchEnabled else { return true }
        guard let ls = parseHHmm(s.lunchStart) else { return false }
        guard s.lunchMinutes > 0, s.lunchMinutes < shiftMin else { return false }
        return durationMinutes(start, ls) + s.lunchMinutes <= shiftMin
    }

    /// 웹의 `/^\d{4}-\d{2}-\d{2}$/`와 같은 검사. 달력상 실존하는 날짜인지는
    /// 웹도 따지지 않으므로(정규식뿐) 여기서도 형식만 본다.
    private static func isValidDateString(_ s: String) -> Bool {
        guard s.count == 10 else { return false }
        for (i, c) in s.enumerated() {
            if i == 4 || i == 7 {
                guard c == "-" else { return false }
            } else {
                guard c.isASCII, c.isNumber else { return false }
            }
        }
        return true
    }
}
