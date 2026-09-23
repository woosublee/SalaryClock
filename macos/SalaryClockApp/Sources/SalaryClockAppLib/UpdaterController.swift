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
    private var cancellables = Set<AnyCancellable>()

    /// 지금 "확인" 버튼을 누를 수 있는지. 업데이트를 받는 중에는 false가 된다.
    @Published private(set) var canCheck = false
    /// 마지막으로 확인한 시각. 확인이 끝나면 갱신되므로 설정 창이 바로 따라간다.
    @Published private(set) var lastCheck: Date?

    /// 이 빌드에 업데이트 기능이 있는지 — 곧 릴리스 빌드인지다.
    var isAvailable: Bool { controller != nil }

    /// 새 버전을 찾으면 묻지 않고 받아서 설치할지. 설정 창이 주는 유일한
    /// 선택지다.
    ///
    /// 확인 자체는 설정에 두지 않는다. 껐을 때 얻는 것이라고는 "새 버전이
    /// 있는지 모르는 상태"뿐이고, 주기를 고르게 해도 하루냐 일주일이냐를
    /// 사용자가 판단할 근거가 없다. 아래 checkInterval로 못 박는다.
    var automaticallyDownloads: Bool {
        get { controller?.updater.automaticallyDownloadsUpdates ?? false }
        set { controller?.updater.automaticallyDownloadsUpdates = newValue }
    }

    /// 확인 주기. 하루에 한 번.
    private static let checkInterval: TimeInterval = 86_400

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

        // 확인은 늘 켜 두고 주기를 하루로 못 박는다. 이 둘을 설정에서 빼기로
        // 했으므로 저장된 값에 기대지 않고 뜰 때마다 덮어쓴다 — 예전 빌드가
        // 남긴 값이나 Sparkle 기본값이 그대로 남아 있으면 안 된다.
        controller.updater.automaticallyChecksForUpdates = true
        controller.updater.updateCheckInterval = Self.checkInterval

        // 앱을 열 때도 한 번 본다. Sparkle의 스케줄러는 마지막 확인에서
        // 주기가 지났을 때만 도는데, 며칠 꺼 뒀다 켠 경우 그 판단을 기다리지
        // 않고 바로 확인하는 편이 사용자가 기대하는 동작이다. 조용히 돌고,
        // 새 버전이 있을 때만 화면에 나온다.
        controller.updater.checkForUpdatesInBackground()

        cancellables.insert(
            controller.updater.publisher(for: \.canCheckForUpdates)
                .receive(on: RunLoop.main)
                .sink { [weak self] in self?.canCheck = $0 }
        )
        cancellables.insert(
            controller.updater.publisher(for: \.lastUpdateCheckDate)
                .receive(on: RunLoop.main)
                .sink { [weak self] in self?.lastCheck = $0 }
        )
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


