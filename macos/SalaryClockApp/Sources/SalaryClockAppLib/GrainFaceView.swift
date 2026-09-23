import SwiftUI
import SalaryClockCore

/// 결 — 60개 분 눈금이 문자판 전체를 이룬다. 웹 components/clock/GrainFace.tsx.
///
/// 다른 얼굴은 진행을 링 하나로 그리는데, 여기서는 눈금 자체가 물든다.
/// 지나간 시간이 낱낱의 눈금으로 쌓여 보이는 게 이 얼굴의 전부다.
/// 점심 구간 눈금은 비워서 "여기는 안 쌓인다"를 같은 언어로 말한다.
struct GrainFaceView: View {
    let now: Int
    let shift: Shift?
    let theme: Theme

    private let tickOuter: CGFloat = 92

    var body: some View {
        faceCanvas { ctx in
            let arcs = shiftArcs(shift, now)
            let hands = handAngles(now)
            let center = CGPoint(x: faceCX, y: faceCY)
            let second = Palette.orange500

            for i in 0..<60 {
                let deg = Double(i) * 6
                let isHour = i % 5 == 0

                let inLunch = arcs.lunch.map { angleInArc(deg, $0) } ?? false
                let inProgress = !inLunch && angleInArc(deg, arcs.progress)
                let inWork = !inLunch && angleInArc(deg, arcs.work)

                let tone: Color
                if inProgress {
                    tone = second
                } else if inLunch {
                    tone = theme.pair(Palette.slate200, Palette.slate800)
                } else if inWork {
                    tone = theme.pair(Palette.slate400, Palette.slate500)
                } else {
                    tone = theme.pair(Palette.slate200, Palette.slate700)
                }

                ctx.strokeLine(
                    from: facePolar(tickOuter, deg),
                    to: facePolar(tickOuter - (isHour ? 14 : 7), deg),
                    width: isHour ? 3 : 1.5, color: tone
                )
            }

            ctx.fillHandRect(
                angle: hands.hour, x: faceCX - 2.5, y: faceCY - 46,
                width: 5, height: 52, radius: 2.5, color: theme.hands
            )
            ctx.fillHandRect(
                angle: hands.minute, x: faceCX - 2, y: faceCY - 68,
                width: 4, height: 74, radius: 2, color: theme.hands
            )

            // 초침은 꼬리에 추가 달린 한 덩어리라 컨텍스트째 돌린다
            ctx.drawLayer { layer in
                layer.rotateAboutFaceCenter(hands.second)
                layer.fill(
                    Path(CGRect(x: faceCX - 1, y: faceCY - 72, width: 2, height: 82)),
                    with: .color(second)
                )
                layer.fillCircle(CGPoint(x: faceCX, y: faceCY + 14), 4, second)
            }

            ctx.fillCircle(center, 5, theme.hands)
            ctx.fillCircle(center, 2, second)
        }
    }
}
