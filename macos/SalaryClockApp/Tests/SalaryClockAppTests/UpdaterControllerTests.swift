import Testing
import Foundation
@testable import SalaryClockAppLib

/// 피드가 없는 번들에서는 업데이터가 아예 없어야 한다.
///
/// 테스트 번들에는 `SUFeedURL`이 없다 — 개발 빌드와 같은 상태다. 여기서
/// isAvailable이 true로 나오면 개발 빌드가 릴리스 피드를 보고 스스로를
/// 덮어쓸 수 있다는 뜻이고, 그건 작업 중인 빌드가 사라지는 사고다.
@MainActor
@Test("피드가 없으면 업데이터를 만들지 않는다")
func updaterIsAbsentWithoutFeed() {
    #expect(Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") == nil)
    #expect(UpdaterController.shared.isAvailable == false)
    // 없는 상태에서 눌러도 죽지 않아야 한다 — 설정 창이 버튼을 감추지만
    // 그 판단을 뷰 하나에만 기대지 않는다.
    UpdaterController.shared.checkForUpdates()
    #expect(UpdaterController.shared.automaticallyChecks == false)
}

/// 저장된 초를 선택지로 되읽는 규칙.
///
/// Sparkle은 임의의 초를 담을 수 있고 기본값도 우리 목록에 없는 값일 수
/// 있다. 못 맞출 때 무엇으로 떨어지는지가 정해져 있지 않으면 설정 창이
/// 빈 선택으로 뜨고, 그 상태에서 저장하면 사용자가 고르지 않은 주기가
/// 들어간다.
@Test("확인 주기는 가장 가까운 선택지로 읽힌다")
func updateIntervalSnapsToNearest() {
    #expect(UpdateInterval.nearest(to: 3600) == .hourly)
    #expect(UpdateInterval.nearest(to: 86_400) == .daily)
    #expect(UpdateInterval.nearest(to: 604_800) == .weekly)
    // 목록에 없는 값들 — 하한 아래와 상한 위, 그리고 사이.
    #expect(UpdateInterval.nearest(to: 0) == .hourly)
    #expect(UpdateInterval.nearest(to: 60) == .hourly)
    #expect(UpdateInterval.nearest(to: 40_000) == .daily)
    #expect(UpdateInterval.nearest(to: 10_000_000) == .weekly)
}

@Test("확인 주기 선택지는 Sparkle의 하한(1시간) 아래로 내려가지 않는다")
func updateIntervalRespectsSparkleFloor() {
    #expect(UpdateInterval.allCases.allSatisfy { $0.seconds >= 3600 })
    let labels = UpdateInterval.allCases.map(\.label)
    #expect(Set(labels).count == labels.count)
}
