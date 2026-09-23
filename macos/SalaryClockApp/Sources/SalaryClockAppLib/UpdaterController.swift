import AppKit
import Combine
import Foundation
import Sparkle

/// Sparkle 업데이터를 감싼다.
///
/// 피드가 없는 빌드에서는 아예 만들지 않는다. `bundle-app.sh`가 개발 빌드에는
/// `SUFeedURL`을 넣지 않는데(작업 중인 빌드가 릴리스 피드를 보고 스스로를
/// 덮어쓰면 안 되므로), 그 상태로 Sparkle을 시작하면 "피드가 없다"는 오류만
/// 반복해서 낸다. 없으면 없는 대로 두고, 설정 창은 그 사실을 그대로 보여준다.
@MainActor
final class UpdaterController: ObservableObject {
    static let shared = UpdaterController()

    private let controller: SPUStandardUpdaterController?
    private var cancellable: AnyCancellable?

    /// 지금 "확인" 버튼을 누를 수 있는지. 업데이트를 받는 중에는 false가 된다.
    @Published private(set) var canCheck = false

    /// 이 빌드에 업데이트 기능이 있는지 — 곧 릴리스 빌드인지다.
    var isAvailable: Bool { controller != nil }

    /// 자동 확인 여부. Sparkle이 자기 UserDefaults 키에 담으므로 우리가
    /// AppPreferences에 따로 저장하지 않는다 — 두 군데 두면 어긋난다.
    var automaticallyChecks: Bool {
        get { controller?.updater.automaticallyChecksForUpdates ?? false }
        set { controller?.updater.automaticallyChecksForUpdates = newValue }
    }

    /// 마지막으로 확인한 시각. 설정 창이 보여준다.
    var lastCheckDate: Date? { controller?.updater.lastUpdateCheckDate }

    private init() {
        let feed = Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String
        guard let feed, feed.hasPrefix("https://") else {
            controller = nil
            return
        }
        // startingUpdater: true — 앱이 뜨는 즉시 스케줄러가 돈다. 델리게이트는
        // 두지 않는다: 기본 동작(자동 확인 여부를 사용자에게 한 번 묻고,
        // 새 버전이 있으면 표준 대화상자를 띄운다)이 우리가 원하는 그대로다.
        let controller = SPUStandardUpdaterController(
            startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil
        )
        self.controller = controller
        cancellable = controller.updater.publisher(for: \.canCheckForUpdates)
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.canCheck = $0 }
    }

    /// 사용자가 직접 누른 확인. 최신이면 "최신입니다"까지 보여준다 —
    /// 자동 확인과 달리 누른 사람에게는 결과를 알려야 한다.
    func checkForUpdates() {
        guard let controller else { return }
        // LSUIElement 앱이라 Sparkle 창이 뒤에 뜰 수 있다. 먼저 앞으로 꺼낸다.
        //
        // NSApp은 암묵적 언래핑 옵셔널이라 NSApplication 인스턴스가 없는
        // 곳(테스트 프로세스)에서 그냥 쓰면 터진다. 실제 앱에서는 늘 있지만,
        // 있다고 가정하는 대신 옵셔널로 받는다.
        NSApp?.activate(ignoringOtherApps: true)
        controller.updater.checkForUpdates()
    }
}
