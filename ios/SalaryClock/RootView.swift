import SwiftUI
import Observation
import SalaryClockCore

/// 화면이 매 tick마다 읽는 상태. 맥의 TickModel과 같은 역할이다.
@MainActor
@Observable
final class HomeModel {
    var now: Int = 0
    var earnings: Earnings = computeEarnings(.default, 0)
    // SwiftUI의 Settings 씬과 이름이 겹치므로 core 쪽을 가리키도록 모듈명을 붙인다.
    var settings: SalaryClockCore.Settings = .default

    func tick() {
        let now = Int((AppClock.now.timeIntervalSince1970 * 1000).rounded())
        let s = SettingsStore.shared.settings
        self.now = now
        earnings = computeEarnings(s, now)
        settings = s
    }
}

/// iOS 메인 화면. 맥 팝오버와 같은 것을 보여주지만(날짜·시계·금액·상태 줄)
/// 폰에 맞게 다시 배치했다 — 시계를 화면 가운데 크게 두고, 버튼은 손가락으로
/// 누르기 좋게 내비게이션 바에 올린다. 문구는 EarningsText.swift를 맥과 같이 쓴다.
struct RootView: View {
    @State private var model = HomeModel()
    @State private var showSettings = ScreenshotScene.current != nil
    /// 기기 설정 — 저장된 테마가 없을 때만 쓴다.
    @Environment(\.colorScheme) private var systemScheme
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var sizeClass

    /// 웹 `loadSettings`와 같은 세 상태 규칙: 저장된 값이 없으면 기기 설정을
    /// 따르고, 한 번이라도 저장했으면 그 값에 고정한다.
    private var effectiveScheme: ColorScheme {
        guard SettingsStore.shared.hasStored else { return systemScheme }
        return model.settings.theme == .dark ? .dark : .light
    }

    private var theme: Theme { Theme(scheme: effectiveScheme) }

    /// 웹 app/page.tsx의 `minimal = settings.hideAmount || dayOff`와 같은 조건.
    private var hidden: Bool { model.settings.hideAmount || model.earnings.phase == .dayoff }

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                if isWide(geo.size) { wideLayout(geo.size) } else { tallLayout(geo.size) }
            }
            .background(theme.background.ignoresSafeArea())
            .toolbar { controls }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .tint(theme.iconButtonHover)
        .sheet(isPresented: $showSettings) {
            SettingsSheet()
        }
        .sensoryFeedback(.selection, trigger: model.settings.hideAmount)
        // preferredColorScheme은 창의 외형을, environment는 하위 뷰가 읽는
        // colorScheme을 바꾼다 — 맥 PopoverView와 같은 이유로 둘 다 둔다.
        .environment(\.colorScheme, effectiveScheme)
        .preferredColorScheme(effectiveScheme)
        // 화면에 있는 동안만 돈다. 앱이 백그라운드로 가면 iOS가 멈추고, 돌아오면
        // 매 tick이 지금 시각으로 다시 계산하므로 따로 맞출 것이 없다.
        // 켜질 때와 앞으로 돌아올 때 공휴일 자료를 확인한다(하루 한 번).
        .onChange(of: scenePhase, initial: true) { _, phase in
            if phase == .active { Task { await HolidayUpdater.shared.check() } }
        }
        .task {
            while !Task.isCancelled {
                model.tick()
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
    }

    // MARK: - 배치

    /// 펼친 iPhone Duo처럼 넓은(regular) 화면을 가로로 쓸 때. 기기 이름이 아니라
    /// 크기 등급과 비율로 고른다 — 접으면(compact) 늘 세로 배치로 돌아온다.
    private func isWide(_ size: CGSize) -> Bool {
        sizeClass == .regular && size.width > size.height
    }

    /// 넓은 화면에서는 글자도 한 단계 키운다.
    private var large: Bool { sizeClass == .regular }

    /// 시계만 화면 주사율로 다시 그려 초침이 흐르게 한다.
    private func clockFace(_ side: CGFloat) -> some View {
        TimelineView(.animation) { context in
            ClockFaceView(
                style: ClockStyle(name: model.settings.clockStyle),
                now: Int((AppClock.shifted(context.date).timeIntervalSince1970 * 1000).rounded()),
                shift: model.earnings.shift, theme: theme
            )
        }
        .frame(width: side, height: side)
    }

    /// 폰(세로): 날짜·시계·금액·상태를 위에서 아래로.
    private func tallLayout(_ size: CGSize) -> some View {
        // 폭에 맞추되 키 작은 폰(SE)에서 금액이 밀려나지 않게 높이로도
        // 제한하고, 큰 화면에서 끝없이 커지지 않게 상한을 둔다.
        let face = min(size.width - 64, size.height * 0.48, large ? 480 : 380)
        return VStack(spacing: 28) {
            Spacer(minLength: 0)
            dateLine
            clockFace(face)
            if hidden { timeDisplay } else { amount }
            status
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
    }

    /// 펼친 화면(가로): 시계를 왼쪽에 크게, 날짜·금액·상태를 오른쪽에.
    /// 오른쪽 칸은 폭을 고정한다 — 금액을 가리거나 쉬는 날이 되어 글이 바뀌어도
    /// 시계가 옆으로 밀리지 않게.
    private func wideLayout(_ size: CGSize) -> some View {
        let gap: CGFloat = 56
        // 양옆에 48pt씩은 남긴다 — 시계가 화면 가장자리에 붙어 보이지 않게.
        let info = min(max(size.width * 0.36, 300), 440)
        let face = max(min(size.height - 80, size.width - info - gap - 96, 560), 200)
        return HStack(spacing: gap) {
            clockFace(face)
            VStack(spacing: 28) {
                dateLine
                if hidden { timeDisplay } else { amount }
                status
            }
            .frame(width: info)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 버튼

    /// 테마·가리기·설정 — 웹과 같은 순서.
    @ToolbarContentBuilder private var controls: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button(action: toggleTheme) {
                Image(systemName: effectiveScheme == .light ? "moon" : "sun.max")
            }
            .accessibilityLabel(effectiveScheme == .light ? "어두운 화면으로" : "밝은 화면으로")

            // 쉬는 날에는 가릴 금액이 없으므로 토글을 숨긴다 — 웹과 같다.
            if model.earnings.phase != .dayoff {
                Button(action: toggleHideAmount) {
                    Image(systemName: model.settings.hideAmount ? "eye.slash" : "eye")
                }
                .accessibilityLabel(model.settings.hideAmount ? "금액 보이기" : "금액 가리기")
            }

            Button { showSettings = true } label: {
                Image(systemName: "gearshape")
            }
            .accessibilityLabel("설정")
        }
    }

    private func toggleTheme() {
        var s = model.settings
        s.theme = effectiveScheme == .dark ? .light : .dark
        SettingsStore.shared.settings = s
        model.tick()
    }

    private func toggleHideAmount() {
        var s = model.settings
        s.hideAmount.toggle()
        // 아직 저장한 적이 없으면 화면은 기기 외형을 따르고 있다. settings.theme에는
        // 앱이 뜰 때 읽은 외형이 남아 있어(그 사이 기기가 다크로 바뀌었을 수 있다)
        // 그대로 저장하면 화면이 갑자기 뒤집혀 고정된다. 지금 보이는 외형을 심는다.
        if !SettingsStore.shared.hasStored { s.theme = effectiveScheme == .dark ? .dark : .light }
        SettingsStore.shared.settings = s
        model.tick()
    }

    // MARK: - 내용

    /// 평소엔 시계 위에 작게, 가려지면 날짜만 크게. 높이를 고정해 가리기를
    /// 누를 때 시계가 들썩이지 않게 한다.
    private var dateLine: some View {
        Text(formatDateKo(model.now))
            .font(hidden ? .system(size: 26, weight: .bold) : .system(size: 15, weight: .medium))
            .foregroundStyle(hidden ? theme.dateMinimal : theme.dateNormal)
            .frame(height: 34)
    }

    private var amount: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Text("오늘 벌어들인 금액")
                    .font(.system(size: 15))
                    .foregroundStyle(theme.secondary)
                Text(model.earnings.isNet ? "실수령" : "세전")
                    .font(.system(size: 12))
                    .foregroundStyle(theme.dim)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(theme.badgeBorder, lineWidth: 1))
            }

            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text(formatWon(model.earnings.earned))
                    .foregroundStyle(theme.foreground)
                Text(earnedFraction(model.earnings.earned))
                    .foregroundStyle(theme.dim)
            }
            .font(.system(size: large ? 60 : 46, weight: .bold, design: .monospaced))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.6)

            Text(model.earnings.perSecond > 0 ? "+\(formatPerSecond(model.earnings.perSecond)) / 초" : " ")
                .font(.system(size: 15, design: .monospaced))
                .foregroundStyle(theme.perSecond)
        }
    }

    /// 가려졌을 때 amount 자리에 들어간다. 줄 구성을 맞춰 화면이 들썩이지 않게 한다.
    private var timeDisplay: some View {
        let parts = splitClockTime(model.now, hour12: model.settings.hour12)
        return VStack(spacing: 6) {
            Text(" ").font(.system(size: 15))
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                if let meridiem = parts.meridiem {
                    Text(meridiem)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(theme.secondary)
                }
                Text(parts.hms)
                    .font(.system(size: large ? 60 : 46, weight: .bold, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(theme.foreground)
            }
            Text(remainingTime(model.earnings))
                .font(.system(size: 15, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(theme.dim)
        }
    }

    @ViewBuilder private var status: some View {
        let e = model.earnings
        // 가려진 상태에서는 줄 전체를 비운다 — 문구만 남아도 가린 티가 난다.
        if hidden {
            Text(" ").font(.system(size: 15, design: .monospaced))
        } else {
            let text = statusText(e, model.settings, model.now)
            Group {
                if e.phase != .after {
                    Text(text).foregroundStyle(theme.secondary)
                        + Text(" · 남은 \(formatWon(e.remainingAmount))").foregroundStyle(theme.dim)
                } else {
                    Text(text).foregroundStyle(theme.secondary)
                }
            }
            .font(.system(size: 15, design: .monospaced))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        }
    }
}
