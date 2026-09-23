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

    /// 자동 확인 여부. Sparkle이 자기 UserDefaults 키에 담으므로 우리가
    /// AppPreferences에 따로 저장하지 않는다 — 두 군데 두면 어긋난다.
    var automaticallyChecks: Bool {
        get { controller?.updater.automaticallyChecksForUpdates ?? false }
        set { controller?.updater.automaticallyChecksForUpdates = newValue }
    }

    /// 새 버전을 자동으로 받아 설치할지. 자동 확인이 꺼져 있으면 의미가 없다 —
    /// 확인을 안 하는데 받을 것도 없다.
    var automaticallyDownloads: Bool {
        get { controller?.updater.automaticallyDownloadsUpdates ?? false }
        set { controller?.updater.automaticallyDownloadsUpdates = newValue }
    }

    /// 자동 확인 주기(초). Sparkle이 정한 하한은 1시간이다.
    var checkInterval: TimeInterval {
        get { controller?.updater.updateCheckInterval ?? UpdateInterval.daily.seconds }
        set { controller?.updater.updateCheckInterval = newValue }
    }

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


/// 자동 확인 주기 선택지.
///
/// 임의의 초를 입력받지 않는다. 메뉴바 갱신 주기(AppPreferences)는 0.1초
/// 차이가 눈에 보여서 숫자 칸이 의미가 있었지만, 업데이트 확인은 하루냐
/// 일주일이냐 정도만 구분되면 된다 — 숫자 칸을 두면 고민거리만 는다.
enum UpdateInterval: String, CaseIterable, Sendable {
    case hourly, daily, weekly

    /// Sparkle이 정한 하한이 1시간이라 그보다 짧은 선택지는 두지 않는다.
    var seconds: TimeInterval {
        switch self {
        case .hourly: return 3600
        case .daily: return 86_400
        case .weekly: return 604_800
        }
    }

    var label: String {
        switch self {
        case .hourly: return "1시간"
        case .daily: return "하루"
        case .weekly: return "일주일"
        }
    }

    /// 저장된 초를 가장 가까운 선택지로 읽는다. Sparkle은 임의의 초를 담을 수
    /// 있고 기본값도 이 목록에 없을 수 있다.
    ///
    /// 차이가 아니라 **비율**로 잰다. 선택지가 1시간~일주일로 자릿수만큼
    /// 벌어져 있어서, 단순히 빼서 비교하면 12시간(43,200초)이 하루보다 1시간에
    /// 가깝다고 나온다 — 2배 차이를 12배 차이보다 멀다고 보는 셈이다.
    /// 로그 거리로 재면 사람이 "어느 쪽에 가깝나"라고 느끼는 것과 맞는다.
    static func nearest(to seconds: TimeInterval) -> UpdateInterval {
        guard seconds > 0 else { return .hourly }
        return allCases.min(by: {
            abs(log(seconds / $0.seconds)) < abs(log(seconds / $1.seconds))
        }) ?? .daily
    }
}
