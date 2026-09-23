import SwiftUI
import SalaryClockCore

/// 말끔 — 사무실 벽시계. 웹 components/clock/MinimalFace.tsx를 그대로 옮긴다.
///
/// 문자판은 조용하게 두고, 하루 진행은 바깥 링 하나로만 말한다.
///
/// 바늘 회전에 애니메이션을 걸지 않는다. 360°에서 0°로 넘어가는 순간
/// 역방향으로 한 바퀴 돈다. 매 tick마다 각도를 직접 찍으므로 필요도 없다.
struct MinimalFaceView: View {
    let now: Int
    let shift: Shift?
    let theme: Theme

    private let ringR: CGFloat = 92
    private let dialR: CGFloat = 76

    var body: some View {
        faceCanvas { ctx in
            let arcs = shiftArcs(shift, now)
            let hands = handAngles(now)

            ctx.strokeArc(arcs.work, radius: ringR, width: 5, color: theme.ringTrack)
            ctx.strokeArc(arcs.progress, radius: ringR, width: 5, color: theme.accent)

            if let lunch = arcs.lunch {
                // 점심 구간은 링을 배경색으로 덧그어 지운다 —
                // "여기는 돈이 안 붙는다"를 보여주는 것이 전부다.
                ctx.strokeArc(lunch, radius: ringR, width: 9, color: theme.background)
                ctx.strokeArc(
                    lunch, radius: ringR, width: 1.5,
                    color: theme.lunchDash, cap: .butt, dash: [2, 3]
                )
            }

            for i in 0..<12 {
                let deg = Double(i) * 30
                let long = i % 3 == 0
                ctx.strokeLine(
                    from: facePolar(dialR, deg),
                    to: facePolar(dialR - (long ? 11 : 5), deg),
                    width: long ? 3 : 1.5, color: theme.ticks, cap: .round
                )
            }

            ctx.strokeHand(angle: hands.hour, from: 10, to: -42, width: 5, color: theme.hands)
            ctx.strokeHand(angle: hands.minute, from: 12, to: -62, width: 3, color: theme.hands)
            ctx.strokeHand(angle: hands.second, from: 16, to: -68, width: 1.5, color: theme.accent)

            ctx.fillCircle(CGPoint(x: faceCX, y: faceCY), 3.5, theme.accent)
        }
    }
}
