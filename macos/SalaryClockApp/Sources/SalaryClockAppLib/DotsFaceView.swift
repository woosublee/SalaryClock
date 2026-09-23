import SwiftUI
import SalaryClockCore

/// 점 — 결(60눈금)과 같은 발상이지만 해상도를 12로 낮췄다.
/// 웹 components/clock/DotsFace.tsx.
///
/// 눈금이 촘촘하면 진행이 연속된 띠로 보이고, 12개로 줄이면 "몇 시간 남았나"가
/// 셀 수 있는 덩어리로 보인다. 초침은 선이 아니라 궤도를 도는 작은 점이라
/// 문자판의 어휘를 그대로 쓴다.
struct DotsFaceView: View {
    let now: Int
    let shift: Shift?
    let theme: Theme

    private let dotR: CGFloat = 84

    var body: some View {
        faceCanvas { ctx in
            let arcs = shiftArcs(shift, now)
            let hands = handAngles(now)
            let center = CGPoint(x: faceCX, y: faceCY)

            for i in 0..<12 {
                let deg = Double(i) * 30
                let p = facePolar(dotR, deg)
                let inLunch = arcs.lunch.map { angleInArc(deg, $0) } ?? false

                if inLunch {
                    // 점심은 속을 비운 동그라미. 자리는 지키되 안 쌓인다
                    ctx.strokeCircle(
                        p, 4, width: 1.25,
                        color: theme.pair(Palette.slate300, Palette.slate600)
                    )
                    continue
                }

                let inProgress = angleInArc(deg, arcs.progress)
                let inWork = angleInArc(deg, arcs.work)
                let fill: Color
                if inProgress {
                    fill = theme.accent
                } else if inWork {
                    fill = theme.pair(Palette.slate300, Palette.slate600)
                } else {
                    fill = theme.pair(Palette.slate200, Palette.slate800)
                }
                ctx.fillCircle(p, inProgress ? 5.5 : 3.5, fill)
            }

            ctx.strokeHand(angle: hands.hour, from: 0, to: -40, width: 4.5, color: theme.hands)
            ctx.strokeHand(angle: hands.minute, from: 0, to: -62, width: 2.5, color: theme.hands)

            ctx.fillCircle(facePolar(dotR, hands.second), 2.5, theme.accent)
            ctx.fillCircle(center, 3, theme.hands)
        }
    }
}
