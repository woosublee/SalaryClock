import SwiftUI
import SalaryClockCore

/// 파문 — 초마다 중심에서 물결이 퍼진다. 웹 components/clock/PulseFace.tsx.
///
/// 돈이 한 방울씩 떨어져 번지는 모습이다. 파문의 반지름은 애니메이션이 아니라
/// 현재 시각의 소수점 부분으로 매 프레임 계산된다 — 그래서 팝오버를 닫았다
/// 열어도 시계와 어긋나지 않는다.
///
/// 파문 셋을 1/3씩 어긋나게 띄워서 끊기지 않고 계속 번지게 했다.
struct PulseFaceView: View {
    let now: Int
    let shift: Shift?
    let theme: Theme

    private let ringR: CGFloat = 92
    private let maxRipple: CGFloat = 80
    private let rippleCount = 3

    var body: some View {
        faceCanvas { ctx in
            let arcs = shiftArcs(shift, now)
            let hands = handAngles(now)
            let center = CGPoint(x: faceCX, y: faceCY)

            ctx.strokeArc(
                arcs.work, radius: ringR, width: 4,
                color: theme.pair(Palette.slate200, Palette.slate800), cap: .butt
            )
            ctx.strokeArc(arcs.progress, radius: ringR, width: 4, color: Palette.sky500)

            // 퍼지는 파문. 멀어질수록 옅어진다
            let fraction = Double(now % 1000) / 1000
            for i in 0..<rippleCount {
                let phase = (fraction + Double(i) / Double(rippleCount))
                    .truncatingRemainder(dividingBy: 1)
                ctx.strokeCircle(
                    center, CGFloat(phase) * maxRipple, width: 1.5,
                    color: Palette.sky400.opacity((1 - phase) * 0.7)
                )
            }

            ctx.strokeHand(angle: hands.hour, from: 0, to: -40, width: 4, color: theme.hands)
            ctx.strokeHand(angle: hands.minute, from: 0, to: -62, width: 2.5, color: theme.hands)
            ctx.fillCircle(center, 4, Palette.sky500)
        }
    }
}
