import SwiftUI
import SalaryClockCore

/// 시계 얼굴 10종. 웹 `lib/settings.ts`의 `ClockStyle` 유니언과 1:1이고,
/// 순서는 웹 `ClockStylePicker`의 `STYLES` 배열과 같다 — 고르는 화면에
/// 늘어놓는 차례가 곧 이 순서다.
///
/// 공유 `Settings`의 `clockStyle`은 여전히 String이다. 골든이 그 필드를
/// 문자열로 고정하고 있고, 모르는 값이 들어와도 디코딩이 깨지지 않아야 한다 —
/// 웹이 `FACES[style] ?? MinimalFace`로 받아넘기는 것과 같은 자리다. 그래서
/// enum은 뷰 층에만 두고, 문자열에서 만들 때 모르는 값은 말끔으로 떨어뜨린다.
enum ClockStyle: String, CaseIterable, Sendable {
    case minimal, numerals, grain, rings, sector
    case dots, countdown, level, sundial, pulse

    /// 웹 `AnalogClock.tsx`의 `CLOCK_STYLE_LABELS`.
    var label: String {
        switch self {
        case .minimal: return "말끔"
        case .numerals: return "숫자판"
        case .grain: return "결"
        case .rings: return "고리"
        case .sector: return "채움"
        case .dots: return "점"
        case .countdown: return "남은"
        case .level: return "수위"
        case .sundial: return "해시계"
        case .pulse: return "파문"
        }
    }

    /// 모르는 값은 말끔으로. 웹 `FACES[style] ?? MinimalFace`와 같은 규칙이다.
    init(name: String) {
        self = ClockStyle(rawValue: name) ?? .minimal
    }
}

/// 고른 얼굴을 그린다 — 웹 `AnalogClock`에 해당한다.
///
/// 얼굴은 자기 지름을 모른다. 크기는 부르는 쪽이 `.frame`으로 정한다.
struct ClockFaceView: View {
    let style: ClockStyle
    let now: Int
    let shift: Shift?
    let theme: Theme

    var body: some View {
        switch style {
        case .minimal: MinimalFaceView(now: now, shift: shift, theme: theme)
        case .numerals: NumeralsFaceView(now: now, shift: shift, theme: theme)
        case .grain: GrainFaceView(now: now, shift: shift, theme: theme)
        case .rings: RingsFaceView(now: now, shift: shift, theme: theme)
        case .sector: SectorFaceView(now: now, shift: shift, theme: theme)
        case .dots: DotsFaceView(now: now, shift: shift, theme: theme)
        case .countdown: CountdownFaceView(now: now, shift: shift, theme: theme)
        case .level: LevelFaceView(now: now, shift: shift, theme: theme)
        case .sundial: SundialFaceView(now: now, shift: shift, theme: theme)
        case .pulse: PulseFaceView(now: now, shift: shift, theme: theme)
        }
    }
}
