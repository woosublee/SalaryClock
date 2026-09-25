import AppKit
import SwiftUI
import SalaryClockCore

/// 팝오버가 스스로 닫힌 직후 버튼 액션을 무시하는 시간. 누르고 떼는 사이
/// (보통 0.1초 안팎)를 덮되, 닫은 뒤 다시 열려는 두 번째 클릭은 막지 않는다.
let popoverReopenGuard: TimeInterval = 0.3

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var timer: Timer?
    private var lastRingMinute = -1
    /// 직전에 넣은 메뉴바 제목. 같은 값을 다시 넣으면 가변 폭 상태 항목이
    /// 매번 레이아웃과 다시 그리기를 한다.
    private var lastTitle: String?
    /// 화면이 꺼졌거나(잠자기) 다른 사용자로 전환돼 이 세션이 뒤에 있는 동안은
    /// 아무도 메뉴바를 보지 않는다. 그동안은 타이머를 걸지 않는다.
    private var screensAsleep = false
    private var sessionInactive = false
    private var isSuspended: Bool { screensAsleep || sessionInactive }
    private let model = TickModel()
    private var popover: NSPopover!
    private var settingsWindow: NSWindow?

    /// 팝오버를 걸어 두는, 보이지 않는 1pt 창.
    ///
    /// 팝오버를 상태 항목 버튼에 직접 앵커하면 가리기를 켤 때 같이 미끄러진다.
    /// 앵커 사각형은 버튼의 로컬 좌표로 저장되는데, 타이틀이 비면서 항목이
    /// 아이콘만 남는 폭으로 줄면 그 좌표계가 통째로 오른쪽으로 끌려가기
    /// 때문이다 — 버튼 안 어디에 걸든 소용이 없고, 오른쪽 모서리에 걸면
    /// 이동량이 오히려 두 배가 된다.
    ///
    /// 그래서 팝오버를 버튼에서 떼어내 화면 좌표에 고정된 창에 건다. 위치는
    /// 항목의 오른쪽 모서리다. 메뉴바는 오른쪽에서 왼쪽으로 쌓이므로 폭이 변해도
    /// 그 모서리의 화면 좌표는 그대로고, 항목이 줄면 아이콘이 바로 그 모서리
    /// 옆으로 오므로 화살표가 가리키는 곳도 두 상태 모두에서 자연스럽다.
    private var anchorWindow: NSWindow?

    /// 팝오버가 마지막으로 닫힌 시각.
    ///
    /// 팝오버를 버튼이 아니라 anchorWindow에 걸었으므로, 열린 팝오버를 닫으려고
    /// 아이콘을 누르면 AppKit에게 그 클릭은 "팝오버 바깥"이다. transient 팝오버가
    /// 마우스를 누르는 순간 먼저 스스로 닫히고, 이어 버튼 액션(togglePopover)이
    /// 불릴 때는 isShown이 이미 false라 다시 연다 — 닫히지 않고 깜빡인다.
    /// 방금 닫혔다면 그 클릭은 닫으려던 것으로 보고 무시한다.
    private var lastPopoverClose: Date = .distantPast

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
        // 메뉴바 갱신 주기(맥 전용, Settings가 아니라 AppPreferences)가
        // 바뀌면 즉시 타이머에 반영한다.
        NotificationCenter.default.addObserver(
            self, selector: #selector(appPreferencesChanged),
            name: .appPreferencesChanged, object: nil
        )
        // 절전에서 깨어나면 즉시 맞춘다. 타이머만 믿어도 1초 뒤엔 맞지만
        // 화면이 켜지는 순간 옛 숫자가 보이는 게 눈에 띈다.
        // 시스템 시간대가 바뀌면(해외 도착, 시스템 설정 변경) 바로 따라간다.
        // core의 CalendarCache는 TimeZone.current를 매번 읽지만, 프로세스는
        // 시스템 시간대를 캐시해 두므로 resetSystemTimeZone 없이는 옛 값을
        // 계속 돌려줄 수 있다. 다음 분 경계까지 기다리지 않고 즉시 다시 그린다.
        NotificationCenter.default.addObserver(
            self, selector: #selector(systemTimeZoneChanged),
            name: .NSSystemTimeZoneDidChange, object: nil
        )

        let workspace = NSWorkspace.shared.notificationCenter
        workspace.addObserver(
            self, selector: #selector(wakeUp),
            name: NSWorkspace.didWakeNotification, object: nil
        )
        workspace.addObserver(
            self, selector: #selector(screensDidSleep),
            name: NSWorkspace.screensDidSleepNotification, object: nil
        )
        workspace.addObserver(
            self, selector: #selector(screensDidWake),
            name: NSWorkspace.screensDidWakeNotification, object: nil
        )
        workspace.addObserver(
            self, selector: #selector(sessionDidResignActive),
            name: NSWorkspace.sessionDidResignActiveNotification, object: nil
        )
        workspace.addObserver(
            self, selector: #selector(sessionDidBecomeActive),
            name: NSWorkspace.sessionDidBecomeActiveNotification, object: nil
        )

        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePopover)

        popover = NSPopover()
        popover.behavior = .transient
        popover.delegate = self
        let hosting = NSHostingController(
            rootView: PopoverView(
                model: model,
                onSettings: { [weak self] in self?.openSettings() },
                onQuit: { NSApp.terminate(nil) }
            )
        )
        // SwiftUI가 잰 크기를 팝오버에 미리 알린다.
        //
        // 이게 없으면 팝오버가 기본 크기(320×320)로 먼저 열리고, 그다음 SwiftUI
        // 레이아웃이 끝나면서 실제 크기로 바뀐다. 그 두 번째 순간에 AppKit이
        // 창을 다시 놓는데, 어느 쪽 모서리를 고정할지가 화면에 따라 갈린다 —
        // 아래로 늘리면 멀쩡하지만 위로 늘리면 팝오버가 메뉴바를 넘어 화면 밖으로
        // 올라간다. 실측한 어긋남(65pt)이 정확히 기본 높이와 실제 높이의 차이였다.
        //
        // 크기를 미리 알려 두면 처음부터 제 크기로 자리를 잡고, 다시 놓는 일
        // 자체가 없어진다.
        hosting.sizingOptions = [.preferredContentSize]
        popover.contentViewController = hosting

        tick()

        // 업데이터를 깨운다. 만드는 순간 스케줄러가 돌기 시작하므로 여기서
        // 한 번 건드리는 것이 곧 시작이다. 개발 빌드에서는 피드가 없어
        // 아무 일도 하지 않는다 (UpdaterController 주석).
        _ = UpdaterController.shared
    }

    /// 다음 tick 하나를 건다. 타이머는 늘 한 번만 울리고, tick이 끝날 때마다
    /// 그때의 상태로 다음 시점을 다시 정한다(nextTickDelay). 주기가 상태에 따라
    /// 0.1초에서 1분까지 바뀌므로 반복 타이머를 갈아 끼우는 것보다 단순하다.
    private func scheduleTick(after delay: TimeInterval) {
        timer?.invalidate()
        timer = nil
        guard !isSuspended else { return }
        let t = Timer(timeInterval: delay, repeats: false) { [weak self] _ in
            // Timer 콜백 클로저 자체는 격리가 없어 컴파일러 입장에서는 어느
            // 스레드에서 불릴지 증명할 수 없다. 하지만 이 타이머는 바로 아래에서
            // RunLoop.main에 .common 모드로만 등록하므로 실행 스레드는 항상
            // 메인 스레드다 — 그 사실을 우리가 보증한다는 뜻으로
            // assumeIsolated를 쓴다. 아무 데서나 호출되는 콜백에 붙이면 안 된다.
            MainActor.assumeIsolated {
                self?.tick()
            }
        }
        // 늦게 울려도 되는 폭을 알려 주면 시스템이 다른 깨어남과 묶어 처리한다.
        // 분 경계에 거는 긴 대기도 0.5초 넘게 밀리지는 않게 둔다. 팝오버가 열려
        // 있을 때는 주지 않는다 — 소수 자리가 흐르는 간격이 흔들려 눈에 보인다.
        t.tolerance = popover?.isShown == true ? 0 : min(delay * 0.1, 0.5)
        // .common 모드에 넣지 않으면 메뉴나 팝오버를 여는 순간 숫자가 멈춘다.
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    @objc private func settingsChanged() { lastRingMinute = -1; tick() }
    @objc private func wakeUp() { tick() }
    @objc private func systemTimeZoneChanged() {
        NSTimeZone.resetSystemTimeZone()
        lastRingMinute = -1
        tick()
    }
    @objc private func appPreferencesChanged() { tick() }

    @objc private func screensDidSleep() { screensAsleep = true; suspend() }
    @objc private func screensDidWake() { screensAsleep = false; resume() }
    @objc private func sessionDidResignActive() { sessionInactive = true; suspend() }
    @objc private func sessionDidBecomeActive() { sessionInactive = false; resume() }

    private func suspend() {
        timer?.invalidate()
        timer = nil
    }

    /// 멈춰 있던 동안 분이 여러 번 바뀌었을 수 있으니 링도 새로 그린다.
    private func resume() {
        guard !isSuspended else { return }
        lastRingMinute = -1
        tick()
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if Date().timeIntervalSince(lastPopoverClose) < popoverReopenGuard { return }
        if popover.isShown {
            // 타이머를 되돌리는 건 popoverDidClose가 한다 — 여기서 또 부르면
            // 같은 일을 두 번 한다. 바깥 클릭으로 닫히는 경로는 어차피
            // 델리게이트만 타므로 그쪽 하나로 모은다.
            popover.performClose(nil)
        } else {
            // 닫혀 있는 동안에는 모델을 갱신하지 않았으므로 열기 전에 채운다.
            tick(refreshPopover: true)
            sizePopoverToContent()
            if let anchor = makeAnchorWindow(for: button), let content = anchor.contentView {
                anchorWindow = anchor
                popover.show(relativeTo: content.bounds, of: content, preferredEdge: .minY)
            } else {
                // 버튼이 아직 창에 붙어 있지 않으면 화면 좌표를 구할 수 없다.
                // 그때는 예전처럼 버튼에 건다 — 움직일지언정 열리기는 한다.
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            }
            // 이제 isShown이 참이라 다음 tick부터 0.1초로 돈다(nextTickDelay).
            tick()
        }
    }

    /// 팝오버를 열기 전에 내용 크기를 재서 알려 둔다.
    ///
    /// 이게 없으면 팝오버가 기본 크기(320×320)로 먼저 열리고, SwiftUI 레이아웃이
    /// 끝난 뒤 실제 크기로 바뀐다. 그 두 번째 순간에 AppKit이 창을 다시 놓는데
    /// 어느 모서리를 고정할지가 화면에 따라 갈린다 — 아래로 늘리면 멀쩡하지만
    /// 위로 늘리면 팝오버가 메뉴바를 넘어 화면 밖으로 올라간다. 실측한
    /// 어긋남(65pt)이 정확히 기본 높이와 실제 높이의 차이였다.
    ///
    /// 열 때마다 다시 재는 이유는 내용에 따라 높이가 달라질 수 있어서다
    /// (가린 상태와 평소 화면이 다른 줄을 쓴다).
    private func sizePopoverToContent() {
        guard let content = popover.contentViewController?.view else { return }
        content.layoutSubtreeIfNeeded()
        let size = content.fittingSize
        guard size.width > 0, size.height > 0 else { return }
        popover.contentSize = size
    }

    /// 상태 항목 오른쪽 모서리에 보이지 않는 1pt 창을 세운다 — 이유는
    /// anchorWindow 주석. 버튼이 창에 붙어 있지 않으면 nil.
    private func makeAnchorWindow(for button: NSStatusBarButton) -> NSWindow? {
        guard let window = button.window else { return nil }
        let onScreen = window.convertToScreen(button.convert(button.bounds, to: nil))
        let edge = NSRect(x: onScreen.maxX - 1, y: onScreen.minY, width: 1, height: onScreen.height)

        let w = NSWindow(contentRect: edge, styleMask: .borderless, backing: .buffered, defer: false)
        w.isOpaque = false
        w.backgroundColor = .clear
        w.hasShadow = false
        // 클릭을 통과시킨다. 메뉴바 위에 투명한 창이 떠 있는 줄 모르게 한다.
        w.ignoresMouseEvents = true
        w.level = .statusBar
        w.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        w.isReleasedWhenClosed = false
        w.orderFront(nil)
        return w
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
    ///
    /// 팝오버가 닫혀 있으면 SwiftUI 모델은 건드리지 않는다. 화면에 없는 뷰를
    /// 매 tick 무효화할 이유가 없다. 열 때 `refreshPopover`로 한 번 채운다.
    private func tick(refreshPopover: Bool = false) {
        let now = Int((Date().timeIntervalSince1970 * 1000).rounded())
        let s = SettingsStore.shared.settings
        let e = computeEarnings(s, now)

        guard let button = statusItem.button else { return }
        // title + font를 따로 주면 렌더링된 런이 실제로 이 폰트를 쓴다는
        // 보장이 없다 — 실측 결과 자릿수가 같은데도 폭이 몇 pt씩 흔들렸다
        // (monospacedDigitSystemFont가 적용되지 않고 있었다는 뜻). 폰트를
        // attributedTitle 안에 직접 실어 애매함을 없앤다.
        //
        // 색도 같은 이유로 명시한다. attributedTitle에 .foregroundColor가 없으면
        // NSStatusBarButton이 자기 색을 넣어 주는지, 아니면 NSAttributedString의
        // 기본값인 검정으로 그리는지가 애매하다 — 후자면 어두운 메뉴바에서
        // 글자가 안 보인다. 눈으로 확인할 수 없는 환경이므로 애매함 자체를
        // 없앤다. NSColor.labelColor는 동적 색이라 그리는 시점의 NSAppearance
        // (= 메뉴바의 실효 외형)에 맞춰 밝은 메뉴바에서는 거의 검정,
        // 어두운 메뉴바에서는 거의 흰색으로 풀린다. Palette의 고정 색은
        // 웹에서 뽑은 상수라 외형을 따라가지 못하므로 여기에는 쓰지 않는다.

        let title = menuBarTitle(e, hideAmount: s.hideAmount)
        let minute = now / 60_000
        // 휴무일에는 진행이 0이라 링이 비어 보인다. 그때는 바늘을 그려
        // 작은 시계로 만든다 (ringImage 주석).
        let clockAt = e.phase == .dayoff ? now : nil

        if isDevBuild {
            // 개발 빌드는 금액까지 한 박스 이미지로 그린다(devBadgeImage).
            // 금액이 바뀌거나 분이 바뀔 때만 다시 만든다.
            let key = "\(title ?? "")|\(minute)"
            if key != lastTitle || minute != lastRingMinute {
                lastTitle = key
                lastRingMinute = minute
                button.attributedTitle = NSAttributedString(string: "")
                button.image = devBadgeImage(progress: e.progress, clockAt: clockAt, title: title)
            }
        } else {
            let titleText = title.map { " " + $0 } ?? ""
            if titleText != lastTitle {
                lastTitle = titleText
                button.attributedTitle = NSAttributedString(
                    string: titleText,
                    attributes: [
                        .font: NSFont.monospacedDigitSystemFont(ofSize: 0, weight: .regular),
                        .foregroundColor: NSColor.labelColor,
                    ]
                )
            }
            if minute != lastRingMinute {
                lastRingMinute = minute
                button.image = ringImage(progress: e.progress, clockAt: clockAt)
            }
        }

        let popoverShown = popover?.isShown ?? false
        if popoverShown || refreshPopover {
            model.now = now
            model.earnings = e
            model.settings = s
        }

        scheduleTick(after: nextTickDelay(
            e,
            hideAmount: s.hideAmount,
            popoverShown: popoverShown,
            interval: AppPreferences.shared.menuBarInterval,
            now: now
        ))
    }
}

extension AppDelegate: NSPopoverDelegate {
    /// transient 팝오버는 바깥을 클릭하면 togglePopover를 거치지 않고 스스로
    /// 닫힌다. 그 경우에도 0.1초 주기를 되돌려야 배터리를 안 먹는다 — tick이
    /// 닫힌 상태로 다음 시점을 다시 정한다.
    public func popoverDidClose(_ notification: Notification) {
        lastPopoverClose = Date()
        tick()
        anchorWindow?.orderOut(nil)
        anchorWindow = nil
    }
}
