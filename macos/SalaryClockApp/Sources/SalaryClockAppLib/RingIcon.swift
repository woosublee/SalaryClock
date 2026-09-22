import AppKit
import SwiftUI
import SalaryClockCore

/// 하루 진행률만큼 차오르는 링. 웹 시계의 바깥 진행 링과 같은 emerald를 쓴다.
///
/// 1분에 한 번만 다시 그리면 된다 — 18px 링에서 1초치 진행은 보이지 않는다.
/// template 이미지로 만들지 않는 이유: 진행 색이 메뉴바 색에 먹히면
/// 링이 전부 같은 색이 되어 진행이 안 보인다.
public func ringImage(progress: Double, phase: Phase, size: CGFloat = 16) -> NSImage {
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
        emeraldColor(for: phase).setStroke()
        arc.stroke()
    }

    return image
}

private func emeraldColor(for phase: Phase) -> NSColor {
    NSColor(Palette.emerald500)
}
