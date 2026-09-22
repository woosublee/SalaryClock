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
    private var settingsWindow: NSWindow?

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

    /// 설정 창을 연다. 창(NSWindow)은 재사용하지만 그 안의 SettingsView는 열 때마다
    /// 새로 만든다 — SettingsView의 draft는 @State라 한 번 초기화되면 창을 취소로
    /// 닫아도 메모리에 남아 있어서, 창만 재사용하고 뷰를 그대로 두면 다음에 열 때
    /// 저장하지 않은 값이 되돌아온다. 웹이 SettingsPanel을 열릴 때마다
    /// key={revision}으로 다시 마운트해 이 문제를 피하는 것과 같은 이유로,
    /// 여기서는 NSHostingController를 매번 새로 만들어 SettingsView가
    /// SettingsStore.shared.settings에서 다시 초기화되게 한다.
    ///
    /// LSUIElement 앱은 기본적으로 창을 앞으로 못 가져오므로 activate가 필요하다.
    private func openSettings() {
        popover.performClose(nil)
        startTimer(interval: 1)

        let hosting = NSHostingController(
            rootView: SettingsView(onDone: { [weak self] in
                self?.settingsWindow?.close()
            })
        )

        if let w = settingsWindow {
            w.contentViewController = hosting
            w.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 460),
            styleMask: [.titled, .closable],
            backing: .buffered, defer: false
        )
        window.title = "SalaryClock 설정"
        window.isReleasedWhenClosed = false
        window.contentViewController = hosting
        window.center()
        settingsWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// 매 tick마다 Date()로 전부 다시 계산한다. 누적하지 않으므로 타이머가
    /// 드리프트하든 절전에서 깨어나든 다음 tick에 저절로 맞는다.
    private func tick() {
        let now = Int((Date().timeIntervalSince1970 * 1000).rounded())
        let s = SettingsStore.shared.settings
        let e = computeEarnings(s, now)

        guard let button = statusItem.button else { return }
        // title + font를 따로 주면 렌더링된 런이 실제로 이 폰트를 쓴다는
        // 보장이 없다 — 실측 결과 자릿수가 같은데도 폭이 몇 pt씩 흔들렸다
        // (monospacedDigitSystemFont가 적용되지 않고 있었다는 뜻). 폰트를
        // attributedTitle 안에 직접 실어 애매함을 없앤다.
        let titleText = menuBarTitle(e, hideAmount: s.hideAmount).map { " " + $0 } ?? ""
        button.attributedTitle = NSAttributedString(
            string: titleText,
            attributes: [.font: NSFont.monospacedDigitSystemFont(ofSize: 0, weight: .regular)]
        )

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
