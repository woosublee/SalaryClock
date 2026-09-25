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
///
/// 그리기 핸들러로 만든다. lockFocus로 그리면 트랙과 바늘의 동적 색
/// (labelColor)이 만드는 순간의 앱 외형으로 비트맵에
/// 굳는다. 메뉴바 외형은 앱 외형과 따로 논다 — 밝은 모드라도 배경화면이
/// 어두우면 메뉴바 글자는 희다. 핸들러는 버튼이 그릴 때마다 불리고 그때의
/// 외형(버튼의 실효 외형)으로 색이 풀리므로 메뉴바를 그대로 따라간다.
/// 다크모드를 바꿔도 1분 캐시를 기다리지 않고 바로 맞춰진다.
///
/// `devBadge`면 개발 빌드 표시를 한다 — 메뉴바 글자색으로 칠한 둥근 박스에서
/// 테두리와 바늘을 파낸다(음각). 설치된 앱과 개발 빌드를 나란히 띄워도
/// 어느 쪽인지 한눈에 갈린다. 기본값은 debug 구성으로 빌드됐는지다.
public func ringImage(
    progress: Double, clockAt now: Int? = nil, size: CGFloat = 16,
    devBadge: Bool = isDevBuild
) -> NSImage {
    NSImage(size: NSSize(width: size, height: size), flipped: false) { _ in
        drawRing(progress: progress, clockAt: now, size: size, devBadge: devBadge)
        return true
    }
}

/// `swift build`의 debug 구성(bundle-app.sh debug)이면 참. 릴리스 빌드는 거짓.
public let isDevBuild: Bool = {
    #if DEBUG
    return true
    #else
    return false
    #endif
}()

private func drawRing(progress: Double, clockAt now: Int?, size: CGFloat, devBadge: Bool) {
    // 박스 안에서는 링을 줄여 박스 가장자리가 보이게 한다.
    let inset: CGFloat = devBadge ? 3 : 1.5
    let rect = NSRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
    let center = NSPoint(x: size / 2, y: size / 2)
    let radius = rect.width / 2
    let lineWidth: CGFloat = 2

    // 음각: 박스를 칠한 뒤 테두리와 바늘은 destinationOut으로 박스를 파낸다.
    // 파낸 자리로 메뉴바가 비쳐 보인다. 초록 진행 링은 그 위에 보통대로 얹는다.
    let context = NSGraphicsContext.current
    func engrave(_ draw: () -> Void) {
        guard devBadge else { draw(); return }
        // 파내는 획은 불투명해야 끝까지 파인다. labelColor는 어두운 쪽에서
        // 불투명도가 0.85라 그대로 쓰면 박스가 15% 남는다.
        NSGraphicsContext.saveGraphicsState()
        context?.compositingOperation = .destinationOut
        NSColor.black.setStroke()
        draw()
        NSGraphicsContext.restoreGraphicsState()
    }
    if devBadge {
        NSColor.labelColor.setFill()
        NSBezierPath(
            roundedRect: NSRect(x: 0, y: 0, width: size, height: size), xRadius: 3.5, yRadius: 3.5
        ).fill()
    }

    let track = NSBezierPath()
    track.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360)
    track.lineWidth = lineWidth
    // 메뉴바 글자와 같은 색 — 어두운 메뉴바에서는 흰색, 밝은 메뉴바에서는 검정.
    // tertiaryLabelColor는 25% 남짓만 비쳐 어두운 메뉴바에서 링이 흐려 보였다.
    // 흰색으로 박으면 밝은 메뉴바에서 사라진다.
    NSColor.labelColor.setStroke()
    engrave { track.stroke() }

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
        engrave {
            draw(angle: hands.hour, length: radius * 0.45, width: 1.6)
            draw(angle: hands.minute, length: radius * 0.72, width: 1.1)
        }
    }
}
