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
    #expect(UpdaterController.shared.automaticallyDownloads == false)
}

