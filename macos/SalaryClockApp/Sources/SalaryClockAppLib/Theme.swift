import SwiftUI
import SalaryClockCore

/// 웹 화면의 색 역할을 이름으로 옮긴다. 값은 전부 Palette에서 온다 —
/// 여기에 hex를 적지 않는다.
struct Theme {
    let scheme: ColorScheme

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
}
