import Testing
import Foundation
@testable import SalaryClockAppLib
import SalaryClockCore

/// 저장된 설정이 없을 때 테마가 기기 외형을 따라가는지 본다 —
/// 웹 `lib/settings.ts`의 `loadSettings`가 `{ ...DEFAULT_SETTINGS, theme: deviceTheme() }`로
/// 하는 일이다. 이게 빠지면 다크모드 맥에서 첫 저장(가리기 토글이나 설정 창
/// 저장) 한 번에 화면이 하얘진다.
///
/// `UserDefaults.standard`는 프로세스 전역이라 `AppPreferencesTests`와 같은
/// 이유로 `.serialized`로 묶는다.
@Suite(.serialized)
struct SettingsStoreThemeTests {
    @Test("저장된 값이 없으면 테마는 기기 외형이고 hasStored는 그대로 false다")
    func emptyDefaultsSeedDeviceTheme() {
        UserDefaults.standard.removeObject(forKey: SettingsStore.key)
        SettingsStore.shared.reload()
        defer {
            UserDefaults.standard.removeObject(forKey: SettingsStore.key)
            SettingsStore.shared.reload()
        }

        // 기대값은 구현과 다른 경로로 읽는다. 전역 도메인의 AppleInterfaceStyle은
        // 시스템 다크모드 스위치 그 자체라, NSAppearance를 다시 부르는 것보다
        // 독립적인 관측이 된다.
        let systemIsDark = UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark"
        let expected: ThemeMode = systemIsDark ? .dark : .light

        #expect(SettingsStore.shared.settings.theme == expected)
        #expect(SettingsStore.shared.hasStored == false)
    }
}
