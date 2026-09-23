import SwiftUI
import SalaryClockCore

/// 채움 — 진행을 선이 아니라 면적으로 읽는다. 웹 components/clock/SectorFace.tsx.
///
/// 링은 굵기가 일정해서 "얼마나 왔나"가 각도로만 읽히는데, 부채꼴은 화면에서
/// 차지하는 넓이로 읽힌다. 하루가 차오르는 걸 몸으로 느끼게 하는 쪽이다.
/// 점심 구간은 바탕색으로 파내서 파이에 홈이 생긴다.
struct SectorFaceView: View {
    let now: Int
    let shift: Shift?
    let theme: Theme

    private let r: CGFloat = 88

    var body: some View {
        faceCanvas { ctx in
            let arcs = shiftArcs(shift, now)
            let hands = handAngles(now)
            let center = CGPoint(x: faceCX, y: faceCY)

            ctx.fillCircle(center, r, theme.pair(Palette.slate50, Palette.slate900))

            // 근무 구간 전체 → 지나간 만큼 → 점심은 파낸다
            ctx.fillSector(
                arcs.work, radius: r,
                color: theme.pair(Palette.slate200.opacity(0.7), Palette.slate800)
            )
            ctx.fillSector(
                arcs.progress, radius: r,
                color: theme.pair(Palette.emerald400.opacity(0.7), Palette.emerald600.opacity(0.5))
            )
            if let lunch = arcs.lunch {
                ctx.fillSector(lunch, radius: r, color: theme.background)
            }

            ctx.strokeCircle(
                center, r, width: 1.5, color: theme.pair(Palette.slate300, Palette.slate700)
            )

            // 정시 눈금만 아주 짧게. 면적이 주인공이라 문자판은 물러선다
            let tickColor = theme.pair(Palette.slate400, Palette.slate600)
            for i in 0..<12 {
                let deg = Double(i) * 30
                let long = i % 3 == 0
                ctx.strokeLine(
                    from: facePolar(r, deg), to: facePolar(r - (long ? 9 : 4), deg),
                    width: long ? 2 : 1, color: tickColor
                )
            }

            ctx.strokeHand(angle: hands.hour, from: 0, to: -44, width: 4, color: theme.hands)
            ctx.strokeHand(angle: hands.minute, from: 0, to: -66, width: 2.5, color: theme.hands)
            ctx.strokeHand(
                angle: hands.second, from: 0, to: -78, width: 1,
                color: theme.pair(Palette.emerald700, Palette.emerald300)
            )
            ctx.fillCircle(center, 3, theme.hands)
        }
    }
}
