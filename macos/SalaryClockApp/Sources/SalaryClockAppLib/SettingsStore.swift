import AppKit
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

    /// 테스트가 `UserDefaults.standard`에서 직접 지울 수 있도록 private로 감추지
    /// 않는다 — `@testable import`로만 보이는 internal이다(`AppPreferences.key`와 같다).
    static let key = "settings.v2"
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

    /// 저장된 설정을 지우고 기본값으로 되돌린다 — 웹 `resetSettings`와 같다.
    ///
    /// 값을 기본값으로 덮어쓰는 게 아니라 저장소에서 지운다. 그래야
    /// `hasStored`가 다시 false가 되고, 테마가 고정에서 풀려 기기 설정을
    /// 따라간다 — 웹이 초기화 뒤에 하는 일과 같다. 덮어쓰기만 하면
    /// "한 번이라도 저장했다"는 흔적이 남아 기기 외형을 영영 못 따라간다.
    public func reset() {
        UserDefaults.standard.removeObject(forKey: Self.key)
        reload()
    }

    private static func load() -> (Settings, Bool) {
        load(deviceTheme: deviceTheme())
    }

    /// 저장소에서 읽는다. 저장된 값이 없거나 깨졌으면 기본 설정에 기기 외형을
    /// 심어 돌려주고 hasStored는 false다.
    ///
    /// 심을 외형을 인자로 받는다. 안에서 `deviceTheme()`을 부르면 테스트가
    /// 기기의 현재 외형에 매인다 — 밝은 맥에서는 기대값이 `Settings.default.theme`
    /// (`.light`)과 같아져, 씨앗 심기를 통째로 되돌려도 테스트가 통과한다.
    /// 인자로 빼면 두 갈래를 기기와 무관하게 확인할 수 있다.
    ///
    /// `Settings.default.theme`는 `.light`라, 이 자리에서 기기 외형을 심어두지
    /// 않으면 사용자가 처음으로 무언가를 저장하는 순간(가리기 토글이든 설정
    /// 창의 저장이든) `hasStored`만 true가 되고 테마는 `.light`로 굳어
    /// 다크모드 맥이 갑자기 하얘진다. 뷰가 아니라 여기서 심어야 첫 저장에
    /// 그대로 딸려 나간다.
    ///
    /// 웹은 저장값이 깨졌을 때만 이 씨앗 없이 `DEFAULT_SETTINGS`를 쓰지만,
    /// 그 경우도 `hasStored`가 false라 화면은 어차피 기기 외형을 따라간다 —
    /// 여기서는 두 갈래를 나누지 않고 첫 저장까지 일관되게 기기 외형을 남긴다.
    static func load(deviceTheme: ThemeMode) -> (Settings, Bool) {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode(Settings.self, from: data),
              isValid(decoded)
        else {
            var seeded = Settings.default
            seeded.theme = deviceTheme
            return (seeded, false)
        }
        return (decoded, true)
    }

    /// 기기의 다크모드 설정. 웹 `deviceTheme()`의 `matchMedia('(prefers-color-scheme: dark)')`에
    /// 해당한다. `NSAppearance.currentDrawing()`은 그리기 문맥 밖에서도 앱(없으면
    /// 시스템)의 실효 외형을 돌려주므로 앱이 뜨기 전에 불려도 안전하다.
    /// 웹이 못 읽을 때 밝은 쪽으로 보는 것처럼, 판정이 안 되면 `.light`로 둔다.
    static func deviceTheme() -> ThemeMode {
        let appearance = NSAppearance.currentDrawing()
        return appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? .dark : .light
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
