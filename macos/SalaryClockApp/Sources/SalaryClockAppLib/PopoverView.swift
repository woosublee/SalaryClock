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

    @Environment(\.colorScheme) private var scheme

    private var theme: Theme { Theme(scheme: scheme) }

    var body: some View {
        // 웹은 아이콘 버튼 줄을 app/page.tsx에서 `absolute right-4 top-4`로
        // 콘텐츠 위에 띄운다 — 아래쪽 줄에 나란히 두지 않는다. 여기서도
        // ZStack으로 우측 상단에 얹는다.
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 12) {
                MinimalFaceView(now: model.now, shift: model.earnings.shift, theme: theme)
                    .frame(width: 132, height: 132)

                if model.earnings.phase == .dayoff || model.settings.hideAmount {
                    // 쉬는 날과 가린 상태에서는 금액 대신 시각을 보여준다.
                    // 웹의 가리기 화면과 같은 규칙이다.
                    Text(formatClockTime(model.now))
                        .font(.system(size: 28, weight: .bold, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(theme.foreground)
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
    }

    /// 설정·종료 아이콘 줄. 지금은 둘뿐이지만 웹 순서(테마·가리기·설정)대로
    /// 앞에 더 끼워 넣을 자리를 남겨 둔다 — 종료만 항상 맨 끝에 남는다.
    private var controls: some View {
        HStack(spacing: 2) {
            IconButton(systemName: "gearshape", label: "설정", theme: theme, action: onSettings)
            IconButton(systemName: "power", label: "종료", theme: theme, action: onQuit)
        }
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
                        RoundedRectangle(cornerRadius: 3).stroke(theme.dim.opacity(0.4), lineWidth: 1)
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

    @ViewBuilder private var status: some View {
        let e = model.earnings
        let text: String = {
            switch e.phase {
            case .before: return "출근까지 \(formatDuration(e.msUntilStart))"
            case .lunch: return "점심시간 · 재개까지 \(formatDuration(e.msUntilLunchEnd))"
            case .after: return "오늘 근무 종료"
            case .working: return "퇴근까지 \(formatDuration(e.msUntilEnd))"
            case .dayoff: return " "
            }
        }()

        HStack(spacing: 4) {
            Text(text).foregroundStyle(theme.secondary)
            if e.phase != .after && e.phase != .dayoff && !model.settings.hideAmount {
                Text("· 남은 \(formatWon(e.remainingAmount))").foregroundStyle(theme.dim)
            }
        }
        .font(.system(size: 11, design: .monospaced))
        .monospacedDigit()
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
