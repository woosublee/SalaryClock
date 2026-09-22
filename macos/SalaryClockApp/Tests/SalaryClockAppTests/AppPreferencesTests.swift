import Testing
import Foundation
@testable import SalaryClockAppLib

/// `AppPreferences`는 `UserDefaults.standard`라는 프로세스 전역 상태를 쓴다.
/// Swift Testing은 기본적으로 테스트를 병렬로 돌리므로, 같은 키를 주고받는
/// 테스트들이 서로 값을 덮어쓰지 않도록 이 스위트를 `.serialized`로 묶어
/// 한 번에 하나씩만 돌게 한다.
@Suite(.serialized)
struct AppPreferencesTests {
    /// 테스트 앞뒤로 키를 지우고 싱글턴을 다시 읽혀서 다른 테스트나 실제 앱
    /// 실행으로 값이 새지 않게 한다.
    private func withCleanDefaults(_ body: () -> Void) {
        UserDefaults.standard.removeObject(forKey: AppPreferences.key)
        AppPreferences.shared.reload()
        body()
        UserDefaults.standard.removeObject(forKey: AppPreferences.key)
        AppPreferences.shared.reload()
    }

    @Test("기본값은 1.0초다")
    func defaultIntervalIsOneSecond() {
        withCleanDefaults {
            #expect(AppPreferences.shared.menuBarInterval == 1.0)
        }
    }

    @Test("0.1과 10은 유효하다")
    func boundsAreValid() {
        #expect(AppPreferences.isValid(0.1))
        #expect(AppPreferences.isValid(10))
    }

    @Test("0.09와 10.1은 무효다")
    func justOutsideBoundsAreInvalid() {
        #expect(!AppPreferences.isValid(0.09))
        #expect(!AppPreferences.isValid(10.1))
    }

    @Test("NaN과 무한대는 무효다")
    func nonFiniteValuesAreInvalid() {
        #expect(!AppPreferences.isValid(.nan))
        #expect(!AppPreferences.isValid(.infinity))
        #expect(!AppPreferences.isValid(-.infinity))
    }

    @Test("저장된 값이 무효면 기본값으로 읽힌다")
    func invalidStoredValueFallsBackToDefault() {
        withCleanDefaults {
            UserDefaults.standard.set(20.0, forKey: AppPreferences.key)
            AppPreferences.shared.reload()
            #expect(AppPreferences.shared.menuBarInterval == 1.0)
        }
    }

    @Test("유효한 값은 왕복한다")
    func validValueRoundTrips() {
        withCleanDefaults {
            AppPreferences.shared.menuBarInterval = 0.5
            AppPreferences.shared.reload()
            #expect(AppPreferences.shared.menuBarInterval == 0.5)
        }
    }

    /// 0이나 NaN이 그대로 저장되면 `startTimer(interval:)`이 런루프가 도는
    /// 만큼 깨어나는 타이머를 건다. setter가 경계에서 막고 직전 값을 지킨다.
    @Test("무효한 값을 넣으면 무시하고 직전 값을 지킨다")
    func invalidAssignmentIsIgnored() {
        withCleanDefaults {
            AppPreferences.shared.menuBarInterval = 0.5

            for bad in [0, .nan, .infinity, -1, 10.1, 0.09] as [Double] {
                AppPreferences.shared.menuBarInterval = bad
                #expect(AppPreferences.shared.menuBarInterval == 0.5)
            }

            // 저장소에도 새지 않았는지 — reload가 0.5를 그대로 돌려줘야 한다.
            AppPreferences.shared.reload()
            #expect(AppPreferences.shared.menuBarInterval == 0.5)
        }
    }
}
