import SwiftUI
import SalaryClockCore

/// 숫자판 — 역 대합실 시계. 웹 components/clock/NumeralsFace.tsx.
///
/// 빨간 초침 하나만 색을 쓰고 나머지는 전부 먹색이다. 그래서 진행 호도
/// 색이 아니라 굵기와 농도로 구분한다. 호를 숫자 안쪽에 둬서 시간을 읽는
/// 동선과 진행을 읽는 동선을 겹치지 않게 했다.
struct NumeralsFaceView: View {
    let now: Int
    let shift: Shift?
    let theme: Theme

    private let numR: CGFloat = 74
    private let arcR: CGFloat = 54

    var body: some View {
        faceCanvas { ctx in
            let arcs = shiftArcs(shift, now)
            let hands = handAngles(now)
            let center = CGPoint(x: faceCX, y: faceCY)
            let rim = theme.pair(Palette.slate300, Palette.slate600)

            ctx.strokeCircle(center, 94, width: 2, color: rim)

            // 분 눈금 — 정시 자리는 숫자가 대신하므로 비운다
            for i in 0..<60 where i % 5 != 0 {
                let deg = Double(i) * 6
                ctx.strokeLine(
                    from: facePolar(90, deg), to: facePolar(86, deg),
                    width: 1, color: rim
                )
            }

            for i in 0..<12 {
                let hour = i == 0 ? 12 : i
                ctx.draw(
                    Text(verbatim: "\(hour)")
                        .font(.custom("Georgia", size: 17))
                        .foregroundStyle(theme.pair(Palette.slate700, Palette.slate200)),
                    at: facePolar(numR, Double(i) * 30), anchor: .center
                )
            }

            ctx.strokeArc(
                arcs.work, radius: arcR, width: 3, color: theme.ringTrack, cap: .butt
            )
            ctx.strokeArc(
                arcs.progress, radius: arcR, width: 3,
                color: theme.pair(Palette.slate500, Palette.slate300), cap: .butt
            )
            if let lunch = arcs.lunch {
                ctx.strokeArc(lunch, radius: arcR, width: 5, color: theme.background, cap: .butt)
            }

            // 각진 바늘. 끝을 자르지 않아야 대합실 시계처럼 읽힌다
            ctx.fillHandRect(
                angle: hands.hour, x: faceCX - 3, y: faceCY - 40,
                width: 6, height: 50, color: theme.hands
            )
            ctx.fillHandRect(
                angle: hands.minute, x: faceCX - 2, y: faceCY - 62,
                width: 4, height: 72, color: theme.hands
            )

            let secondColor = theme.pair(Palette.rose600, Palette.rose500)
            ctx.fillHandRect(
                angle: hands.second, x: faceCX - 0.75, y: faceCY - 70,
                width: 1.5, height: 88, color: secondColor
            )
            ctx.drawLayer { layer in
                layer.rotateAboutFaceCenter(hands.second)
                layer.strokeCircle(
                    CGPoint(x: faceCX, y: faceCY - 58), 5, width: 1.5, color: secondColor
                )
            }

            ctx.fillCircle(center, 4, theme.hands)
        }
    }
}
