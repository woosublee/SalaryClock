import SwiftUI
import SalaryClockCore

/// 모든 페이스가 같은 좌표계를 쓴다 — 웹 components/clock/types.ts의
/// `viewBox="0 0 200 200"`. 페이스는 자기 지름을 모르고, 크기는 바깥에서 정한다.
let faceCX: CGFloat = 100
let faceCY: CGFloat = 100
let faceSize: CGFloat = 200

/// 12시 방향 0도, 시계방향 증가 — 웹 lib/clock.ts의 polarPoint와 같다.
///
/// Core가 아니라 여기에 두는 이유: Core는 CoreGraphics를 들이지 않는 순수
/// 도메인이고, 이건 그리기 좌표다. 각도 자체(handAngles·arcBetween·angleInArc)는
/// Core에 있고 골든이 고정한다.
func facePolar(_ r: CGFloat, _ deg: Double) -> CGPoint {
    let rad = (deg - 90) * .pi / 180
    return CGPoint(x: faceCX + r * cos(rad), y: faceCY + r * sin(rad))
}

/// 200×200 좌표계를 실제 크기에 맞춰 놓고 그린다. 페이스마다 반복되는 세 줄을
/// 한곳에 모은 것뿐이다.
func faceCanvas(_ draw: @escaping (inout GraphicsContext) -> Void) -> some View {
    Canvas { ctx, size in
        let scale = min(size.width, size.height) / faceSize
        ctx.scaleBy(x: scale, y: scale)
        draw(&ctx)
    }
}

extension GraphicsContext {
    /// 웹 `arcPath` + `<path stroke>`. 길이가 0이면 아무것도 그리지 않는다 —
    /// 휴무일에 페이스마다 분기를 넣지 않아도 되는 이유다.
    func strokeArc(
        _ arc: Arc, radius: CGFloat, width: CGFloat, color: Color,
        cap: CGLineCap = .round, dash: [CGFloat] = []
    ) {
        strokeArc(
            startDeg: arc.startDeg, sweepDeg: arc.sweepDeg,
            radius: radius, width: width, color: color, cap: cap, dash: dash
        )
    }

    func strokeArc(
        startDeg: Double, sweepDeg: Double, radius: CGFloat, width: CGFloat,
        color: Color, cap: CGLineCap = .round, dash: [CGFloat] = []
    ) {
        guard sweepDeg > 0 else { return }
        // 정확히 360도는 시작점과 끝점이 같아 아무것도 그려지지 않는다.
        // 웹 arcPath가 359.99로 줄이는 것과 같은 처리다.
        let sweep = min(sweepDeg, 359.99)
        var path = Path()
        path.addArc(
            center: CGPoint(x: faceCX, y: faceCY), radius: radius,
            startAngle: .degrees(startDeg - 90),
            endAngle: .degrees(startDeg - 90 + sweep),
            clockwise: false
        )
        stroke(path, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: cap, dash: dash))
    }

    /// 웹 `sectorPath` — 호를 중심에서 닫은 부채꼴. 면적으로 진행을 보여준다.
    func fillSector(_ arc: Arc, radius: CGFloat, color: Color) {
        guard arc.sweepDeg > 0 else { return }
        let sweep = min(arc.sweepDeg, 359.99)
        let center = CGPoint(x: faceCX, y: faceCY)
        var path = Path()
        path.move(to: center)
        path.addLine(to: facePolar(radius, arc.startDeg))
        path.addArc(
            center: center, radius: radius,
            startAngle: .degrees(arc.startDeg - 90),
            endAngle: .degrees(arc.startDeg - 90 + sweep),
            clockwise: false
        )
        path.closeSubpath()
        fill(path, with: .color(color))
    }

    /// 중심을 축으로 회전한 선분 바늘 — 웹의 `<line transform="rotate(...)">`.
    /// from·to는 중심에서의 세로 오프셋이라 웹 좌표를 그대로 옮겨 적을 수 있다.
    func strokeHand(
        angle: Double, from: CGFloat, to: CGFloat,
        width: CGFloat, color: Color, cap: CGLineCap = .round
    ) {
        var path = Path()
        path.move(to: CGPoint(x: faceCX, y: faceCY + from))
        path.addLine(to: CGPoint(x: faceCX, y: faceCY + to))
        stroke(
            rotatedAboutCenter(path, angle),
            with: .color(color),
            style: StrokeStyle(lineWidth: width, lineCap: cap)
        )
    }

    /// 중심을 축으로 회전한 사각 바늘 — 웹의 `<rect transform="rotate(...)">`.
    /// 끝이 잘린 각진 바늘은 선분 cap으로는 안 나온다.
    func fillHandRect(
        angle: Double, x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat,
        radius: CGFloat = 0, color: Color
    ) {
        let rect = CGRect(x: x, y: y, width: width, height: height)
        let path = radius > 0
            ? Path(roundedRect: rect, cornerRadius: radius)
            : Path(rect)
        fill(rotatedAboutCenter(path, angle), with: .color(color))
    }

    func strokeLine(
        from: CGPoint, to: CGPoint, width: CGFloat, color: Color, cap: CGLineCap = .butt
    ) {
        var path = Path()
        path.move(to: from)
        path.addLine(to: to)
        stroke(path, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: cap))
    }

    func fillCircle(_ center: CGPoint, _ r: CGFloat, _ color: Color) {
        let rect = CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)
        fill(Path(ellipseIn: rect), with: .color(color))
    }

    func strokeCircle(_ center: CGPoint, _ r: CGFloat, width: CGFloat, color: Color) {
        let rect = CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)
        stroke(Path(ellipseIn: rect), with: .color(color), style: StrokeStyle(lineWidth: width))
    }

    /// 컨텍스트 자체를 문자판 중심을 축으로 돌린다 — 웹의
    /// `<g transform="rotate(deg cx cy)">`에 해당한다. 경로만이 아니라
    /// 그라디언트까지 같이 돌아야 할 때 쓴다.
    mutating func rotateAboutFaceCenter(_ deg: Double) {
        translateBy(x: faceCX, y: faceCY)
        rotate(by: .degrees(deg))
        translateBy(x: -faceCX, y: -faceCY)
    }

    private func rotatedAboutCenter(_ path: Path, _ angle: Double) -> Path {
        path.applying(
            CGAffineTransform(translationX: faceCX, y: faceCY)
                .rotated(by: angle * .pi / 180)
                .translatedBy(x: -faceCX, y: -faceCY)
        )
    }
}
