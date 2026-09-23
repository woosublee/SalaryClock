import SwiftUI
import SalaryClockCore

/// 해시계 — 바늘 대신 그림자가 시각을 가리킨다.
/// 웹 components/clock/SundialFace.tsx.
///
/// 아날로그 시계의 조상이고, 원래부터 "하루가 어디쯤 왔나"를 재는 물건이었다.
/// 그래서 이 앱과 주제가 맞는다.
///
/// 해시계에는 초가 없으므로 초침도 두지 않고, 대신 테두리를 도는 작은 점
/// 하나로만 살아 있다는 걸 알린다. 분은 그림자 끝에 붙은 짧은 눈금이 맡는다.
struct SundialFaceView: View {
    let now: Int
    let shift: Shift?
    let theme: Theme

    private let plateR: CGFloat = 90
    private let shadowLen: CGFloat = 78

    var body: some View {
        faceCanvas { ctx in
            let arcs = shiftArcs(shift, now)
            let hands = handAngles(now)
            let center = CGPoint(x: faceCX, y: faceCY)

            // 석판
            ctx.fillCircle(center, plateR, theme.pair(Palette.stone100, Palette.stone900))
            ctx.strokeCircle(
                center, plateR, width: 1.5,
                color: theme.pair(Palette.stone300, Palette.stone700)
            )

            // 석판에 새겨진 근무 구간
            ctx.strokeArc(
                arcs.work, radius: plateR - 8, width: 4,
                color: theme.pair(Palette.stone200, Palette.stone800), cap: .butt
            )
            ctx.strokeArc(
                arcs.progress, radius: plateR - 8, width: 4,
                color: theme.pair(Palette.amber600.opacity(0.7), Palette.amber500.opacity(0.6))
            )

            // 시각선
            let lineColor = theme.pair(Palette.stone400, Palette.stone600)
            for i in 0..<12 {
                let deg = Double(i) * 30
                let long = i % 3 == 0
                ctx.strokeLine(
                    from: facePolar(plateR - 16, deg),
                    to: facePolar(plateR - (long ? 30 : 24), deg),
                    width: long ? 2 : 1, color: lineColor
                )
            }

            // 그림자. 해는 시각의 반대편에 있다고 보고, 그림자는 시침 방향으로
            // 뻗는다. 경로만 돌리면 그라디언트가 따라오지 않으므로 컨텍스트째
            // 돌린다 — 웹은 <g transform="rotate">가 그 일을 한다.
            //
            // 그라디언트 방향은 웹 그대로다: objectBoundingBox의 y=0(그림자 끝)이
            // 0.55, y=1(뿌리)이 0.12다. 웹 주석은 "끝으로 갈수록 옅어진다"고
            // 적혀 있지만 실제로 그려지는 건 그 반대이며, 여기서는 옮겨 적는
            // 쪽이 아니라 실제로 그려지는 쪽을 따른다.
            let shadowColor = theme.pair(Palette.stone700, Palette.stone300)
            ctx.drawLayer { layer in
                layer.rotateAboutFaceCenter(hands.hour)
                var shadow = Path()
                shadow.move(to: CGPoint(x: faceCX - 7, y: faceCY))
                shadow.addLine(to: CGPoint(x: faceCX + 7, y: faceCY))
                shadow.addLine(to: CGPoint(x: faceCX + 2, y: faceCY - shadowLen))
                shadow.addLine(to: CGPoint(x: faceCX - 2, y: faceCY - shadowLen))
                shadow.closeSubpath()
                layer.fill(
                    shadow,
                    with: .linearGradient(
                        Gradient(stops: [
                            .init(color: shadowColor.opacity(0.55), location: 0),
                            .init(color: shadowColor.opacity(0.12), location: 1),
                        ]),
                        startPoint: CGPoint(x: faceCX, y: faceCY - shadowLen),
                        endPoint: CGPoint(x: faceCX, y: faceCY)
                    )
                )
            }

            // 분 눈금
            ctx.strokeLine(
                from: facePolar(plateR - 12, hands.minute),
                to: facePolar(plateR - 20, hands.minute),
                width: 2.5, color: theme.pair(Palette.stone600, Palette.stone300), cap: .round
            )

            // 노몬 — 그림자를 만드는 막대
            ctx.fillCircle(center, 7, theme.pair(Palette.stone300, Palette.stone700))
            ctx.fillCircle(center, 3.5, theme.pair(Palette.stone600, Palette.stone300))

            // 초는 테두리를 도는 점 하나로만
            ctx.fillCircle(
                facePolar(plateR - 5, hands.second), 2,
                theme.pair(Palette.amber600, Palette.amber400)
            )
        }
    }
}
