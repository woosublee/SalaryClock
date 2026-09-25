import Testing
import Foundation
@testable import SalaryClockAppLib
import SalaryClockCore

/// 저장된 설정이 없을 때 테마가 기기 외형을 따라가는지 본다 —
/// 웹 `lib/settings.ts`의 `loadSettings`가 `{ ...DEFAULT_SETTINGS, theme: deviceTheme() }`로
/// 하는 일이다. 이게 빠지면 다크모드 맥에서 첫 저장(가리기 토글이나 설정 창
/// 저장) 한 번에 화면이 하얘진다.
///
/// 씨앗을 심는 갈래는 `load(deviceTheme:)`로 뽑아 두 값을 다 넣어 본다.
/// 기기 외형을 그대로 기대값에 쓰면 밝은 맥에서는 기대값이
/// `Settings.default.theme`(`.light`)과 같아져, 씨앗 심기를 통째로 되돌려도
/// 테스트가 통과한다 — 다크 맥에서만 이빨이 있는 테스트가 된다.
///
/// `UserDefaults.standard`는 프로세스 전역이라 `AppPreferencesTests`와 같은
/// 이유로 `.serialized`로 묶는다.
@Suite(.serialized)
struct SettingsStoreThemeTests {
    /// 테스트 앞뒤로 키를 지우고 싱글턴을 다시 읽혀 값이 새지 않게 한다.
    private func withCleanDefaults(_ body: () -> Void) {
        UserDefaults.standard.removeObject(forKey: SettingsStore.key)
        SettingsStore.shared.reload()
        body()
        UserDefaults.standard.removeObject(forKey: SettingsStore.key)
        SettingsStore.shared.reload()
    }

    @Test("저장된 값이 없으면 넘겨준 기기 외형을 그대로 심는다 — 두 갈래 모두")
    func emptyDefaultsSeedGivenTheme() {
        withCleanDefaults {
            let (dark, darkHasStored) = SettingsStore.load(deviceTheme: .dark)
            #expect(dark.theme == .dark)
            #expect(darkHasStored == false)

            let (light, lightHasStored) = SettingsStore.load(deviceTheme: .light)
            #expect(light.theme == .light)
            #expect(lightHasStored == false)

            // 테마만 갈아끼운다 — 나머지는 기본값 그대로다.
            #expect(dark.payAmount == Settings.default.payAmount)
            #expect(dark.workStart == Settings.default.workStart)
        }
    }

    @Test("저장된 값이 깨져 있어도 기기 외형을 심는다 — 두 갈래 모두")
    func brokenStoredValueSeedsGivenTheme() {
        withCleanDefaults {
            UserDefaults.standard.set(Data("not json".utf8), forKey: SettingsStore.key)

            #expect(SettingsStore.load(deviceTheme: .dark).0.theme == .dark)
            #expect(SettingsStore.load(deviceTheme: .light).0.theme == .light)
            #expect(SettingsStore.load(deviceTheme: .dark).1 == false)
        }
    }

    @Test("저장된 값이 있으면 기기 외형을 심지 않는다 — 고른 테마를 지킨다")
    func storedValueWins() {
        withCleanDefaults {
            var stored = Settings.default
            stored.theme = .light
            SettingsStore.shared.settings = stored

            let (loaded, hasStored) = SettingsStore.load(deviceTheme: .dark)
            #expect(loaded.theme == .light)
            #expect(hasStored == true)
        }
    }

    /// 필드가 늘기 전에 저장한 값 — 웹 `storage.test.ts`의 같은 이름 테스트와 짝이다.
    @Test("필드가 추가되기 전에 저장한 값도 살리고, 빠진 테마는 기기 외형을 심는다")
    func olderStoredValueSurvives() {
        withCleanDefaults {
            let older = #"{"payMode":"monthly","payAmount":3500000,"dayOverrides":["2026-09-22"],"workStart":"10:00","workEnd":"19:00"}"#
            UserDefaults.standard.set(Data(older.utf8), forKey: SettingsStore.key)

            let (loaded, hasStored) = SettingsStore.load(deviceTheme: .dark)
            #expect(hasStored == true)
            #expect(loaded.payMode == .monthly)
            #expect(loaded.payAmount == 3_500_000)
            #expect(loaded.dayOverrides == ["2026-09-22"])
            #expect(loaded.workStart == "10:00")
            #expect(loaded.clockStyle == Settings.default.clockStyle)
            #expect(loaded.theme == .dark)
        }
    }

    @Test("있는 필드의 타입이 틀리면 버린다 — 웹 스키마 검증 실패와 같다")
    func wrongTypeFieldRejected() {
        withCleanDefaults {
            UserDefaults.standard.set(Data(#"{"payAmount":"많이"}"#.utf8), forKey: SettingsStore.key)
            let (loaded, hasStored) = SettingsStore.load(deviceTheme: .light)
            #expect(hasStored == false)
            #expect(loaded == Settings.default)
        }
    }

    /// 싱글턴이 실제로 `deviceTheme()`을 물려 읽는지 — 배선까지 본다.
    /// 기대값은 구현과 다른 경로로 읽는다. 전역 도메인의 AppleInterfaceStyle은
    /// 시스템 다크모드 스위치 그 자체라, NSAppearance를 다시 부르는 것보다
    /// 독립적인 관측이 된다.
    @Test("싱글턴은 기기 외형을 물려 읽는다")
    func sharedStoreUsesDeviceTheme() {
        withCleanDefaults {
            let systemIsDark = UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark"
            let expected: ThemeMode = systemIsDark ? .dark : .light

            #expect(SettingsStore.shared.settings.theme == expected)
            #expect(SettingsStore.shared.hasStored == false)
        }
    }
}
