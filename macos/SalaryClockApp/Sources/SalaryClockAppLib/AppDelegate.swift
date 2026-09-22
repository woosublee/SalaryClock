import AppKit
import SalaryClockCore

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var timer: Timer?
    private var lastRingMinute = -1

    public override init() {
        super.init()
    }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.imagePosition = .imageLeading

        NotificationCenter.default.addObserver(
            self, selector: #selector(settingsChanged),
            name: .settingsChanged, object: nil
        )
        // 절전에서 깨어나면 즉시 맞춘다. 타이머만 믿어도 1초 뒤엔 맞지만
        // 화면이 켜지는 순간 옛 숫자가 보이는 게 눈에 띈다.
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(wakeUp),
            name: NSWorkspace.didWakeNotification, object: nil
        )

        startTimer(interval: 1)
        tick()
    }

    private func startTimer(interval: TimeInterval) {
        timer?.invalidate()
        let t = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            // Timer 콜백 클로저 자체는 격리가 없어 컴파일러 입장에서는 어느
            // 스레드에서 불릴지 증명할 수 없다. 하지만 이 타이머는 바로 아래에서
            // RunLoop.main에 .common 모드로만 등록하므로 실행 스레드는 항상
            // 메인 스레드다 — 그 사실을 우리가 보증한다는 뜻으로
            // assumeIsolated를 쓴다. 아무 데서나 호출되는 콜백에 붙이면 안 된다.
            MainActor.assumeIsolated {
                self?.tick()
            }
        }
        // .common 모드에 넣지 않으면 메뉴나 팝오버를 여는 순간 숫자가 멈춘다.
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    @objc private func settingsChanged() { lastRingMinute = -1; tick() }
    @objc private func wakeUp() { tick() }

    /// 매 tick마다 Date()로 전부 다시 계산한다. 누적하지 않으므로 타이머가
    /// 드리프트하든 절전에서 깨어나든 다음 tick에 저절로 맞는다.
    private func tick() {
        let now = Int((Date().timeIntervalSince1970 * 1000).rounded())
        let s = SettingsStore.shared.settings
        let e = computeEarnings(s, now)

        guard let button = statusItem.button else { return }
        button.title = menuBarTitle(e, hideAmount: s.hideAmount).map { " " + $0 } ?? ""
        button.font = NSFont.monospacedDigitSystemFont(ofSize: 0, weight: .regular)

        let minute = now / 60_000
        if minute != lastRingMinute {
            lastRingMinute = minute
            button.image = ringImage(progress: e.progress, phase: e.phase)
        }
    }
}
