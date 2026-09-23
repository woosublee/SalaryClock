import AppKit
import SwiftUI
import SalaryClockCore

/// 하루 진행률만큼 차오르는 링. 웹 시계의 바깥 진행 링과 같은 emerald를 쓴다.
///
/// 1분에 한 번만 다시 그리면 된다 — 18px 링에서 1초치 진행은 보이지 않는다.
/// template 이미지로 만들지 않는 이유: 진행 색이 메뉴바 색에 먹히면
/// 링이 전부 같은 색이 되어 진행이 안 보인다.
///
/// `clockAt`에 시각을 주면 링 안에 시침·분침을 그린다. 휴무일에는 진행이 0이라
/// 회색 테두리만 남아 빈자리처럼 보이는데, 바늘을 넣으면 실제로 시각을 읽을 수
/// 있는 작은 시계가 된다 — 휴무일에 이 앱을 시계로 쓴다는 원래 의도와 맞는다.
public func ringImage(progress: Double, clockAt now: Int? = nil, size: CGFloat = 16) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    defer { image.unlockFocus() }

    let inset: CGFloat = 1.5
    let rect = NSRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
    let center = NSPoint(x: size / 2, y: size / 2)
    let radius = rect.width / 2
    let lineWidth: CGFloat = 2

    let track = NSBezierPath()
    track.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360)
    track.lineWidth = lineWidth
    NSColor.tertiaryLabelColor.setStroke()
    track.stroke()

    let clamped = min(max(progress, 0), 1)
    if clamped > 0 {
        let arc = NSBezierPath()
        // 12시 방향에서 시계방향. AppKit은 반시계가 양수라 부호를 뒤집는다.
        arc.appendArc(
            withCenter: center, radius: radius,
            startAngle: 90, endAngle: 90 - 360 * clamped, clockwise: true
        )
        arc.lineWidth = lineWidth
        arc.lineCapStyle = .round
        NSColor(Palette.emerald500).setStroke()
        arc.stroke()
    }

    if let now {
        // 12시 방향 0도, 시계방향 — 웹과 같은 handAngles를 쓴다. AppKit은 y축이
        // 위로 향하므로 sin/cos를 그대로 두고 y에 더한다.
        let hands = handAngles(now)
        func draw(angle: Double, length: CGFloat, width: CGFloat) {
            let rad = angle * .pi / 180
            let tip = NSPoint(
                x: center.x + sin(rad) * length,
                y: center.y + cos(rad) * length
            )
            let path = NSBezierPath()
            path.move(to: center)
            path.line(to: tip)
            path.lineWidth = width
            path.lineCapStyle = .round
            path.stroke()
        }
        // 메뉴바 색을 따라가도록 labelColor를 쓴다. 진행 링과 달리 바늘은
        // 색으로 구분할 정보가 없다.
        NSColor.labelColor.setStroke()
        draw(angle: hands.hour, length: radius * 0.45, width: 1.6)
        draw(angle: hands.minute, length: radius * 0.72, width: 1.1)
    }

    return image
}
