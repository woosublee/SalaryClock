import SwiftUI
import Observation
import SalaryClockCore

/// 팝오버가 매 tick마다 읽는 상태. AppDelegate의 tick()이 메인 액터에서만
/// 채워 넣으므로 이 모델도 메인 액터에 묶는다 — @unchecked Sendable이나
/// nonisolated(unsafe)로 액터 경계를 슬쩍 피하지 않는다.
@MainActor
@Observable
final class TickModel {
    var now: Int = 0
    var earnings: Earnings = computeEarnings(.default, 0)
    // SwiftUI도 Settings라는 타입(Settings 씬)을 갖고 있어 이름이 겹친다 —
    // 여기서는 항상 core 쪽을 가리키도록 모듈명을 붙인다.
    var settings: SalaryClockCore.Settings = .default
}

struct PopoverView: View {
    let model: TickModel
    var onSettings: () -> Void
    var onQuit: () -> Void

    /// 기기 설정 — 저장된 테마가 없을 때만 쓴다.
    @Environment(\.colorScheme) private var systemScheme

    /// 웹 `loadSettings`와 같은 세 상태 규칙: 저장된 값이 없으면(hasStored ==
    /// false) 기기 설정을 따르고, 한 번이라도 저장했으면 그 값에 고정한다.
    private var effectiveScheme: ColorScheme {
        guard SettingsStore.shared.hasStored else { return systemScheme }
        return model.settings.theme == .dark ? .dark : .light
    }

    private var theme: Theme { Theme(scheme: effectiveScheme) }

    /// 웹 app/page.tsx의 `minimal = settings.hideAmount || dayOff`와 같은
    /// 조건. 날짜·시계자리·상태줄이 전부 이 하나를 기준으로 갈라진다.
    private var hidden: Bool { model.settings.hideAmount || model.earnings.phase == .dayoff }

    var body: some View {
        // 웹은 아이콘 버튼 줄을 app/page.tsx에서 `absolute right-4 top-4`로
        // 콘텐츠 위에 띄운다 — 아래쪽 줄에 나란히 두지 않는다. 여기서도
        // ZStack으로 우측 상단에 얹는다.
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 12) {
                dateLine

                // 얼굴은 팝오버 폭(220)에서 좌우 여백 16씩을 뺀 만큼 꽉 채운다.
                // 스펙 5.3의 비례 축소(132pt)보다 큰데, 숫자판·남은·해시계처럼
                // 글자와 잔눈금이 들어가는 얼굴은 그 크기에서 읽히지 않는다.
                ClockFaceView(
                    style: ClockStyle(name: model.settings.clockStyle),
                    now: model.now, shift: model.earnings.shift, theme: theme
                )
                .frame(width: 188, height: 188)

                if hidden {
                    // 쉬는 날과 가린 상태에서는 금액 대신 시각을 보여준다.
                    // 웹의 가리기 화면과 같은 규칙이다.
                    timeDisplay
                } else {
                    amount
                }

                status
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
            // 위쪽만 더 준다 — 우측 상단 아이콘 줄과 시계가 겹치지 않게.
            .padding(.top, 36)

            controls
                .padding(.top, 8)
                .padding(.trailing, 10)
        }
        .frame(width: 220)
        .background(theme.background)
        // 두 줄이 서로 다른 일을 한다.
        //
        // preferredColorScheme은 이 화면(팝오버 창)의 선호 외형을 알린다 —
        // 하위 뷰의 @Environment(\.colorScheme)에는 이 값이 쓰이지 않는다.
        // MonthCalendarView처럼 스스로 그 키를 읽어 Theme을 만드는 뷰에도
        // 고른 테마가 닿게 하려면 환경에 직접 심어야 한다.
        //
        // 팝오버에는 지금 그런 하위 뷰가 없지만(시계 얼굴은 theme을
        // 인자로 받는다) 설정 창과 규칙을 하나로 둔다.
        .environment(\.colorScheme, effectiveScheme)
        .preferredColorScheme(effectiveScheme)
    }

    /// 웹 DateLine — 평소엔 시계 위에 작게, 가려지면 날짜만 크게. 두 상태의
    /// 높이를 고정해 두지 않으면 가리기를 누를 때 시계가 통째로 밀린다
    /// (DateLine.tsx의 `h-[2.375rem]` 박스와 같은 이유).
    @ViewBuilder private var dateLine: some View {
        if hidden {
            Text(formatDateKo(model.now))
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(theme.dateMinimal)
                .frame(height: 26)
        } else {
            Text(formatDateKo(model.now))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(theme.dateNormal)
                .frame(height: 26)
        }
    }

    /// 테마·가리기·설정·종료 아이콘 줄. 앞의 셋은 웹 순서(테마·가리기·설정)를
    /// 그대로 따른다 — 종료는 웹에 없는 맥 전용 항목이라 맨 끝에 둔다. 네
    /// 아이콘이 220pt 폭 안에 들어간다는 것은 Task 10 리뷰에서 확인됐다.
    private var controls: some View {
        HStack(spacing: 2) {
            IconButton(systemName: themeIconName, label: themeLabel, theme: theme, action: toggleTheme)
            // 쉬는 날에는 가릴 금액이 없으므로 토글을 숨긴다 — 웹
            // app/page.tsx의 `{!dayOff && ...}`와 같다. 누른들 화면은 그대로인데
            // hideAmount만 몰래 뒤집혀 연휴가 끝난 뒤까지 금액이 가려진다.
            //
            // 조건은 `hidden`이 아니라 phase로 본다. `hidden`은 사용자가 스스로
            // 가렸을 때도 true라, 그걸로 걸면 다시 켤 버튼까지 같이 사라진다.
            if model.earnings.phase != .dayoff {
                IconButton(
                    systemName: model.settings.hideAmount ? "eye.slash" : "eye",
                    label: hideAmountLabel, theme: theme, action: toggleHideAmount
                )
            }
            IconButton(systemName: "gearshape", label: "설정", theme: theme, action: onSettings)
            IconButton(systemName: "power", label: "종료", theme: theme, action: onQuit)
        }
    }

    /// 지금 상태가 아니라 누르면 가게 될 상태를 그린다 — 웹 ThemeIcon과 같은 규칙.
    private var themeIconName: String { effectiveScheme == .light ? "moon" : "sun.max" }
    private var themeLabel: String { effectiveScheme == .light ? "어두운 화면으로" : "밝은 화면으로" }

    /// SettingsStore.shared.settings는 메인 액터에서만 대입한다 — 버튼 액션은
    /// SwiftUI View 프로토콜이 메인 액터로 격리하므로 안전하다.
    private func toggleTheme() {
        var s = model.settings
        s.theme = effectiveScheme == .dark ? .light : .dark
        SettingsStore.shared.settings = s
    }

    private var hideAmountLabel: String { model.settings.hideAmount ? "금액 보이기" : "금액 가리기" }

    private func toggleHideAmount() {
        var s = model.settings
        s.hideAmount.toggle()
        SettingsStore.shared.settings = s
    }

    private var amount: some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Text("오늘 벌어들인 금액")
                    .font(.system(size: 11))
                    .foregroundStyle(theme.secondary)
                Text(model.earnings.isNet ? "실수령" : "세전")
                    .font(.system(size: 10))
                    .foregroundStyle(theme.dim)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 3).stroke(theme.badgeBorder, lineWidth: 1)
                    )
            }

            // 소수 1자리까지 보여준다. 정수만 쓰면 초당 5.8원일 때 0.17초마다
            // 한 번씩 또각또각 올라가는데, 한 자리를 더 두면 흐르듯 보인다.
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text(formatWon(model.earnings.earned))
                    .foregroundStyle(theme.foreground)
                Text(String(format: ".%d", Int((model.earnings.earned.truncatingRemainder(dividingBy: 1)) * 10)))
                    .foregroundStyle(theme.dim)
            }
            .font(.system(size: 28, weight: .bold, design: .monospaced))
            .monospacedDigit()

            Text(
                model.earnings.perSecond > 0
                    ? "+\(formatPerSecond(model.earnings.perSecond)) / 초" : " "
            )
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(theme.perSecond)
        }
    }

    /// 가려졌을 때 amount 자리에 들어간다. 웹 TimeDisplay와 같은 이유로
    /// amount와 줄 구성·글자 크기를 맞춘다 — 라벨 줄 자리에 빈 줄,
    /// 큰 숫자 자리에 시각, 초당 적립액 줄 자리에 라벨 없는 남은 시간
    /// (문구를 넣으면 "퇴근까지"처럼 가린 티가 나므로 숫자만 둔다).
    private var timeDisplay: some View {
        VStack(spacing: 4) {
            Text(" ").font(.system(size: 11))

            Text(formatClockTime(model.now))
                .font(.system(size: 28, weight: .bold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(theme.foreground)

            Text(remainingTimeText)
                .font(.system(size: 11, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(theme.dim)
        }
    }

    private var remainingTimeText: String {
        let e = model.earnings
        switch e.phase {
        case .before: return formatDuration(e.msUntilStart)
        case .lunch: return formatDuration(e.msUntilLunchEnd)
        case .working: return formatDuration(e.msUntilEnd)
        case .after, .dayoff: return " "
        }
    }

    @ViewBuilder private var status: some View {
        let e = model.earnings
        // 가려진 상태(가리기 켜짐 또는 휴무일)에서는 줄 전체를 비운다.
        // "퇴근까지 04:00:00" 같은 문구만 남아도 뭔가 가려져 있다는 티가
        // 난다 — 웹 StatusLine의 hidden 분기와 같은 규칙이다. 높이는
        // 그대로 차지해야 팝오버가 들썩이지 않는다.
        if hidden {
            Text(" ")
                .font(.system(size: 11, design: .monospaced))
        } else {
            let text: String = {
                switch e.phase {
                case .before: return "출근까지 \(formatDuration(e.msUntilStart))"
                // "· 재개까지"를 빼서 짧게 줄였다 — 웹 StatusLine도 같은 문구다.
                case .lunch: return "점심시간 \(formatDuration(e.msUntilLunchEnd))"
                // 종류(kind)는 SalaryClockCore가 정하고, 문구는 여기(UI)가 갖는다.
                // 표는 웹 components/StatusLine.tsx의 AFTER_WORK_TEXT와 같다.
                case .after: return afterWorkText(afterWorkKind(model.settings, model.now))
                case .working: return "퇴근까지 \(formatDuration(e.msUntilEnd))"
                // hidden이 이미 .dayoff를 걸러내므로 여기 오지 않는다 —
                // switch를 다 채우기 위한 자리만 지킨다.
                case .dayoff: return " "
                }
            }()

            // HStack에 Text 두 개를 따로 두면 minimumScaleFactor가 각자
            // 따로 줄어들어(한쪽만 말줄임표가 남는 등) 어색해진다. Text를
            // +로 이어 붙여 한 덩어리로 만들어야 전체가 같은 비율로 줄어든다.
            Group {
                if e.phase != .after {
                    Text(text).foregroundStyle(theme.secondary)
                        + Text(" · 남은 \(formatWon(e.remainingAmount))").foregroundStyle(theme.dim)
                } else {
                    Text(text).foregroundStyle(theme.secondary)
                }
            }
            .font(.system(size: 11, design: .monospaced))
            .monospacedDigit()
            // 실제로 쓰는 범위(남은 금액 6자리, ₩999,999까지)는 188pt 폭에
            // 그대로 들어간다 — minimumScaleFactor는 자연스러운 크기가
            // 이미 맞으면 아무 것도 안 줄이는 "바닥값"이라, 이 범위에서는
            // 100% 그대로 그려진다. 0.85는 그보다 큰 급여를 입력했을 때(7~8
            // 자리, 예: "· 남은 ₩10,416,666")를 위한 안전망이다 — 줄바꿈을
            // 허용하면 팝오버 높이가 들쑥날쑥해지므로 한 줄로 고정하고,
            // 안 맞을 때만 그만큼 줄여서 맞춘다. 문구는 그대로 두고
            // 레이아웃만 양보한다.
            .lineLimit(1)
            .minimumScaleFactor(0.85)
        }
    }
}

/// 퇴근 후 격려 문구. 종류(kind)는 SalaryClockCore.afterWorkKind가 정하고,
/// 실제 한국어 문장은 여기(UI)가 갖는다 — 웹 components/StatusLine.tsx의
/// AFTER_WORK_TEXT와 같은 표를 따른다.
private func afterWorkText(_ kind: AfterWorkKind) -> String {
    switch kind {
    case .tomorrow: return "오늘도 고생하셨어요"
    case .restThisWeek: return "오늘도 고생하셨어요, 푹 쉬세요"
    case .nextWeek: return "이번 주도 고생하셨어요"
    case .longBreak: return "연휴 잘 보내세요"
    }
}

/// 웹 우측 상단의 아이콘 버튼(테두리 없음, 흐린 색 → hover에 진해짐)과 같은
/// 톤으로 맞춘 버튼. 아래 amount·status가 주인공이라 여기는 조용히 앉아
/// 있어야 한다 — 툴바처럼 존재감을 키우지 않는다.
private struct IconButton: View {
    let systemName: String
    let label: String
    let theme: Theme
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            // 심볼 자체가 갖는 기본 접근성 라벨("gear" 등 영문)이 버튼의
            // 라벨과 겹치지 않도록 이미지는 장식으로 숨기고, 라벨은 버튼에만 둔다.
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .medium))
                .frame(width: 22, height: 22)
                .accessibilityHidden(true)
        }
        .buttonStyle(.plain)
        .foregroundStyle(isHovering ? theme.iconButtonHover : theme.iconButton)
        .animation(.easeInOut(duration: 0.15), value: isHovering)
        .onHover { isHovering = $0 }
        // 이미지를 숨겼으니 버튼 자체를 단일 접근성 요소로 묶고 라벨을 준다.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .help(label)
    }
}
