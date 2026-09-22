import AppKit
import SwiftUI
import SalaryClockCore

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var timer: Timer?
    private var lastRingMinute = -1
    private let model = TickModel()
    private var popover: NSPopover!

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

        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePopover)

        popover = NSPopover()
        popover.behavior = .transient
        popover.delegate = self
        popover.contentViewController = NSHostingController(
            rootView: PopoverView(
                model: model,
                onSettings: { [weak self] in self?.openSettings() },
                onQuit: { NSApp.terminate(nil) }
            )
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

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
            startTimer(interval: 1)
        } else {
            tick()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            // 팝오버가 열려 있는 동안만 0.1초로 올려 소수 1자리가 흐르게 한다.
            startTimer(interval: 0.1)
        }
    }

    private func openSettings() { /* Task 11에서 채운다 */ }

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

        model.now = now
        model.earnings = e
        model.settings = s
    }
}

extension AppDelegate: NSPopoverDelegate {
    /// transient 팝오버는 바깥을 클릭하면 togglePopover를 거치지 않고 스스로
    /// 닫힌다. 그 경우에도 0.1초 타이머를 1초로 되돌려야 배터리를 안 먹는다.
    public func popoverDidClose(_ notification: Notification) {
        startTimer(interval: 1)
    }
}
