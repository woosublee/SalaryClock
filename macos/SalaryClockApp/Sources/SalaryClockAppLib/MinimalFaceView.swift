import SwiftUI
import SalaryClockCore

/// 말끔 — 사무실 벽시계. 웹 components/clock/MinimalFace.tsx의
/// viewBox="0 0 200 200" 좌표를 그대로 옮긴다.
///
/// 바늘 회전에 애니메이션을 걸지 않는다. 360°에서 0°로 넘어가는 순간
/// 역방향으로 한 바퀴 돈다. 매 tick마다 각도를 직접 찍으므로 필요도 없다.
struct MinimalFaceView: View {
    let now: Int
    let shift: Shift?
    let theme: Theme

    private let cx: CGFloat = 100
    private let cy: CGFloat = 100
    private let ringR: CGFloat = 92
    private let dialR: CGFloat = 76

    var body: some View {
        Canvas { ctx, size in
            let scale = min(size.width, size.height) / 200
            ctx.scaleBy(x: scale, y: scale)

            let arcs = shiftArcs(shift, now)
            let hands = handAngles(now)

            stroke(ctx, arc: arcs.work, radius: ringR, width: 5, color: theme.ringTrack)
            stroke(ctx, arc: arcs.progress, radius: ringR, width: 5, color: theme.accent)

            if let lunch = arcs.lunch {
                // 점심 구간은 링을 배경색으로 덧그어 지운다 —
                // "여기는 돈이 안 붙는다"를 보여주는 것이 전부다.
                stroke(ctx, arc: lunch, radius: ringR, width: 9, color: theme.background)
                stroke(
                    ctx, arc: lunch, radius: ringR, width: 1.5,
                    color: theme.lunchDash, dash: [2, 3]
                )
            }

            for i in 0..<12 {
                let deg = Double(i) * 30
                let long = i % 3 == 0
                let outer = polar(dialR, deg)
                let inner = polar(dialR - (long ? 11 : 5), deg)
                var path = Path()
                path.move(to: outer)
                path.addLine(to: inner)
                ctx.stroke(
                    path, with: .color(theme.ticks),
                    style: StrokeStyle(lineWidth: long ? 3 : 1.5, lineCap: .round)
                )
            }

            hand(ctx, angle: hands.hour, from: 10, to: -42, width: 5, color: theme.hands)
            hand(ctx, angle: hands.minute, from: 12, to: -62, width: 3, color: theme.hands)
            hand(ctx, angle: hands.second, from: 16, to: -68, width: 1.5, color: theme.accent)

            let dot = CGRect(x: cx - 3.5, y: cy - 3.5, width: 7, height: 7)
            ctx.fill(Path(ellipseIn: dot), with: .color(theme.accent))
        }
    }

    /// 12시 방향 0도, 시계방향 증가 — 웹 lib/clock.ts의 polarPoint와 같다.
    private func polar(_ r: CGFloat, _ deg: Double) -> CGPoint {
        let rad = (deg - 90) * .pi / 180
        return CGPoint(x: cx + r * cos(rad), y: cy + r * sin(rad))
    }

    private func stroke(
        _ ctx: GraphicsContext, arc: Arc, radius: CGFloat,
        width: CGFloat, color: Color, dash: [CGFloat] = []
    ) {
        guard arc.sweepDeg > 0 else { return }
        let sweep = min(arc.sweepDeg, 359.99)
        var path = Path()
        path.addArc(
            center: CGPoint(x: cx, y: cy), radius: radius,
            startAngle: .degrees(arc.startDeg - 90),
            endAngle: .degrees(arc.startDeg - 90 + sweep),
            clockwise: false
        )
        ctx.stroke(
            path, with: .color(color),
            style: StrokeStyle(lineWidth: width, lineCap: dash.isEmpty ? .round : .butt, dash: dash)
        )
    }

    private func hand(
        _ ctx: GraphicsContext, angle: Double,
        from: CGFloat, to: CGFloat, width: CGFloat, color: Color
    ) {
        var path = Path()
        path.move(to: CGPoint(x: cx, y: cy + from))
        path.addLine(to: CGPoint(x: cx, y: cy + to))
        let rotated = path.applying(
            CGAffineTransform(translationX: cx, y: cy)
                .rotated(by: angle * .pi / 180)
                .translatedBy(x: -cx, y: -cy)
        )
        ctx.stroke(
            rotated, with: .color(color),
            style: StrokeStyle(lineWidth: width, lineCap: .round)
        )
    }
}
