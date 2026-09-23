import SwiftUI
import SalaryClockCore

/// 수위 — 하루가 물처럼 차오른다. 웹 components/clock/LevelFace.tsx.
///
/// 다른 페이스는 진행을 테두리에서 말하는데, 이건 문자판 한가운데를 채운다.
/// 출근이 바닥, 퇴근이 천장이다. 점심시간에는 수면이 그대로 멈춘다 —
/// 돈이 안 쌓이는 시간을 따로 표시할 필요 없이 저절로 드러난다.
///
/// 물결은 장식이 아니라 살아 있다는 신호다. 4초에 한 번 위상이 도는데,
/// 초침과 주기를 어긋나게 둬서 둘이 맞물려 보이지 않게 했다.
struct LevelFaceView: View {
    let now: Int
    let shift: Shift?
    let theme: Theme

    private let r: CGFloat = 88
    private let steps = 28

    var body: some View {
        faceCanvas { ctx in
            let hands = handAngles(now)
            let center = CGPoint(x: faceCX, y: faceCY)

            let progress: Double = {
                guard let shift, shift.paidMs != 0 else { return 0 }
                return Double(paidMsBetween(shift, shift.startMs, now)) / Double(shift.paidMs)
            }()

            // 수면 높이. 진행 0이면 바닥, 1이면 천장.
            let surfaceY = faceCY + r - 2 * r * progress
            let phase = Double(now % 4000) / 4000 * 2 * .pi

            var surface: [CGPoint] = []
            for i in 0...steps {
                let x = faceCX - r + (2 * r * CGFloat(i)) / CGFloat(steps)
                let y = surfaceY + sin(phase + Double(i) / Double(steps) * 4 * .pi) * 2.5
                surface.append(CGPoint(x: x, y: y))
            }

            ctx.fillCircle(center, r, theme.pair(Palette.slate50, Palette.slate900))

            ctx.drawLayer { layer in
                // 웹은 <clipPath>로 원 밖을 자른다. 물결이 석판을 넘지 않게.
                layer.clip(to: Path(ellipseIn: CGRect(
                    x: faceCX - r, y: faceCY - r, width: r * 2, height: r * 2
                )))

                var water = Path()
                water.move(to: surface[0])
                for p in surface.dropFirst() { water.addLine(to: p) }
                water.addLine(to: CGPoint(x: faceCX + r, y: faceCY + r))
                water.addLine(to: CGPoint(x: faceCX - r, y: faceCY + r))
                water.closeSubpath()
                layer.fill(
                    water,
                    with: .color(theme.pair(
                        Palette.emerald400.opacity(0.45), Palette.emerald600.opacity(0.40)
                    ))
                )

                // 수면선 하나만 진하게. 물이 어디까지 찼는지가 이 페이스의 전부다
                var line = Path()
                line.move(to: surface[0])
                for p in surface.dropFirst() { line.addLine(to: p) }
                layer.stroke(
                    line,
                    with: .color(theme.pair(Palette.emerald600, Palette.emerald400)),
                    style: StrokeStyle(lineWidth: 1.5)
                )
            }

            ctx.strokeCircle(
                center, r, width: 1.5, color: theme.pair(Palette.slate300, Palette.slate700)
            )

            // 바늘은 물 위에 뜬다. 수면과 겹쳐도 읽히도록 테두리를 덧그린다
            ctx.strokeHand(angle: hands.hour, from: 8, to: -42, width: 7, color: theme.background)
            ctx.strokeHand(angle: hands.hour, from: 8, to: -42, width: 4, color: theme.hands)
            ctx.strokeHand(angle: hands.minute, from: 10, to: -64, width: 5, color: theme.background)
            ctx.strokeHand(angle: hands.minute, from: 10, to: -64, width: 2.5, color: theme.hands)
            ctx.strokeHand(
                angle: hands.second, from: 12, to: -72, width: 1.25,
                color: theme.pair(Palette.slate500, Palette.slate400)
            )
            ctx.fillCircle(center, 3, theme.hands)
        }
    }
}
