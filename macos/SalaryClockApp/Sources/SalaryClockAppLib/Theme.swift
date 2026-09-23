import SwiftUI
import SalaryClockCore

/// 웹 화면의 색 역할을 이름으로 옮긴다. 값은 전부 Palette에서 온다 —
/// 여기에 hex를 적지 않는다.
struct Theme {
    let scheme: ColorScheme

    /// 웹의 `text-foo dark:text-bar` 한 쌍을 그대로 옮긴다.
    ///
    /// 시계 얼굴 10종이 쓰는 색은 마흔 가지가 넘고 대부분 그 얼굴에서 한 번씩만
    /// 쓰인다. 전부 이름 붙인 역할로 승격하면 Theme이 얼굴 목록이 되고, 웹의
    /// 어느 클래스에서 왔는지도 오히려 흐려진다. 아래 역할 이름들은 여러 화면이
    /// 공유하는 것만 남기고, 얼굴 한 곳에서만 쓰는 색은 이 짝으로 적는다 —
    /// `theme.pair(Palette.slate200, Palette.slate700)`이 웹의
    /// `text-slate-200 dark:text-slate-700`과 한 줄씩 대응한다.
    func pair(_ light: Color, _ dark: Color) -> Color { scheme == .dark ? dark : light }

    var background: Color { Palette.surfaceBackground.resolve(scheme) }
    var foreground: Color { Palette.surfaceForeground.resolve(scheme) }
    /// 시계 바늘 (시·분)
    var hands: Color { scheme == .dark ? Palette.slate100 : Palette.slate800 }
    /// 문자판 눈금
    var ticks: Color { scheme == .dark ? Palette.slate500 : Palette.slate400 }
    /// 링 — 근무 구간
    var ringTrack: Color { scheme == .dark ? Palette.slate700 : Palette.slate200 }
    /// 링 — 점심 파선
    var lunchDash: Color { scheme == .dark ? Palette.slate600 : Palette.slate300 }
    /// 진행 링 · 초침 · 중심점
    var accent: Color { Palette.emerald500 }
    /// 초당 적립액
    var perSecond: Color { scheme == .dark ? Palette.emerald400 : Palette.emerald600 }
    /// 보조 텍스트
    var secondary: Color { scheme == .dark ? Palette.slate400 : Palette.slate500 }
    /// 금액 소수부 · 흐린 텍스트
    var dim: Color { scheme == .dark ? Palette.slate500 : Palette.slate400 }
    /// 아이콘 버튼(설정·종료) — 웹 app/page.tsx의 iconButton 클래스는
    /// text-slate-400을 밝기 모드와 무관하게 그대로 쓴다.
    var iconButton: Color { Palette.slate400 }
    /// 아이콘 버튼에 마우스를 올렸을 때 — hover:text-slate-700
    /// dark:hover:text-slate-200.
    var iconButtonHover: Color { scheme == .dark ? Palette.slate200 : Palette.slate700 }
    /// 세전·실수령 배지 테두리 — 웹 EarningsDisplay의 ring-slate-200
    /// dark:ring-slate-700. 라벨 글자색(dim)과는 다른 역할이라 opacity로
    /// 흉내내지 않고 따로 둔다.
    var badgeBorder: Color { scheme == .dark ? Palette.slate700 : Palette.slate200 }
    /// 날짜 — 평소 크기일 때. 웹 DateLine의 text-slate-700 dark:text-slate-200.
    var dateNormal: Color { scheme == .dark ? Palette.slate200 : Palette.slate700 }
    /// 날짜 — 가려서 크게 보일 때. 웹 DateLine minimal 분기의
    /// text-slate-800 dark:text-slate-100.
    var dateMinimal: Color { scheme == .dark ? Palette.slate100 : Palette.slate800 }

    // MARK: - 달력(MonthCalendarView) — 웹 components/MonthCalendar.tsx의 KIND_CLASS

    /// 달력 패널 바탕 — bg-slate-50 dark:bg-slate-800/60. 반투명 dark 배경은
    /// 원본 알파 그대로 opacity로 흉내낸다.
    var calendarPanelBackground: Color {
        scheme == .dark ? Palette.slate800.opacity(0.6) : Palette.slate50
    }

    /// 달력 헤더 "N년 N월 · 근무 N일" — text-slate-600 dark:text-slate-300.
    var calendarHeaderText: Color { scheme == .dark ? Palette.slate300 : Palette.slate600 }

    /// "이 달 선택 지우기" — text-slate-400, 밝기와 무관하게 같은 값.
    var calendarClearButton: Color { Palette.slate400 }

    /// 요일 머리글 색 — 일=rose-400, 토=sky-400, 그 외 slate-400. 셋 다
    /// 밝기 모드와 무관하게 같은 값을 쓴다(웹 클래스에 dark: 접두어가 없다).
    func calendarDowLabel(_ dow: Int) -> Color {
        switch dow {
        case 0: return Palette.rose400
        case 6: return Palette.sky400
        default: return Palette.slate400
        }
    }

    /// 달력 칸 배경 — kind별로 웹 KIND_CLASS와 같다.
    func calendarBackground(for kind: DayKind) -> Color {
        switch kind {
        case .work: return .clear
        case .weekend: return scheme == .dark ? Palette.slate800 : Palette.slate100
        case .holiday: return scheme == .dark ? Palette.rose950.opacity(0.4) : Palette.rose50
        case .customOff: return scheme == .dark ? Palette.slate600 : Palette.slate300
        case .customWork: return scheme == .dark ? Palette.emerald900.opacity(0.5) : Palette.emerald100
        }
    }

    /// 달력 칸 글자색 — kind별로 웹 KIND_CLASS와 같다.
    func calendarForeground(for kind: DayKind) -> Color {
        switch kind {
        case .work: return scheme == .dark ? Palette.slate200 : Palette.slate700
        case .weekend: return scheme == .dark ? Palette.slate500 : Palette.slate400
        case .holiday: return Palette.rose400
        case .customOff: return scheme == .dark ? Palette.slate200 : Palette.slate600
        case .customWork: return scheme == .dark ? Palette.emerald300 : Palette.emerald700
        }
    }

    /// custom-off·custom-work만 font-medium — 웹 KIND_CLASS와 같다.
    func calendarBold(for kind: DayKind) -> Bool { kind == .customOff || kind == .customWork }
}
