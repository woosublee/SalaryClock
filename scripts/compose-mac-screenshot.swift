// Mac App Store 스크린샷(2880×1800)을 조립한다. scripts/appstore-screenshots-mac.sh가 부른다.
//
// 앱이 그려 낸 팝오버·설정 창 PNG를 받아 바탕에 놓고, 위에 메뉴바 한 줄을 그린다.
// 실제 화면을 캡처하지 않는 이유: 화면 녹화 권한이 필요하고, 바탕화면과 다른 앱의
// 메뉴바 항목이 그대로 찍힌다.
//
// 사용법: compose-mac-screenshot <light|dark> <메뉴바 금액> <출력> <PNG[:배율]>...
//   PNG가 하나면 메뉴바 아래 오른쪽에(팝오버처럼), 둘이면 나란히 가운데에 놓는다.
import AppKit

let args = CommandLine.arguments
guard args.count >= 5 else {
    FileHandle.standardError.write(Data("사용법: compose-mac-screenshot <light|dark> <금액> <출력> <PNG[:배율]>...\n".utf8))
    exit(2)
}
let dark = args[1] == "dark"
let menuTitle = args[2]
let outPath = args[3]
let inputs: [(NSImage, CGFloat)] = args[4...].map { spec in
    let parts = spec.split(separator: ":", maxSplits: 1).map(String.init)
    guard let img = NSImage(contentsOfFile: parts[0]), let rep = img.representations.first else {
        FileHandle.standardError.write(Data("이미지를 못 읽었다: \(parts[0])\n".utf8)); exit(1)
    }
    // 픽셀 크기로 다룬다 — 입력은 레티나(2×)로 그려진 PNG다.
    img.size = NSSize(width: rep.pixelsWide, height: rep.pixelsHigh)
    return (img, parts.count > 1 ? CGFloat(Double(parts[1]) ?? 1) : 1)
}

let W: CGFloat = 2880, H: CGFloat = 1800, menuH: CGFloat = 48
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(W), pixelsHigh: Int(H), bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                           bytesPerRow: 0, bitsPerPixel: 0)!
rep.size = NSSize(width: W, height: H)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xff) / 255, green: CGFloat((hex >> 8) & 0xff) / 255,
            blue: CGFloat(hex & 0xff) / 255, alpha: a)
}

// 바탕. 앱 팔레트의 slate·emerald 쪽으로 은은한 대각선 그라데이션.
let bg = dark
    ? NSGradient(colors: [rgb(0x0b1220), rgb(0x10241f)])!
    : NSGradient(colors: [rgb(0xf1f5f9), rgb(0xdff3ea)])!
bg.draw(in: NSRect(x: 0, y: 0, width: W, height: H), angle: -35)

// 메뉴바. 오른쪽에 앱의 상태 항목(링 + 금액)을 그린다.
(dark ? rgb(0x000000, 0.35) : rgb(0xffffff, 0.55)).setFill()
NSRect(x: 0, y: H - menuH, width: W, height: menuH).fill()
let menuFont = NSFont.monospacedDigitSystemFont(ofSize: 26, weight: .medium)
let fg = dark ? rgb(0xf8fafc) : rgb(0x0f172a)
let title = NSAttributedString(string: menuTitle, attributes: [.font: menuFont, .foregroundColor: fg])
let titleSize = title.size()
// 팝오버 하나만 놓는 장은 항목을 가운데 쪽에 두어 화면이 한쪽으로 쏠리지 않게 한다.
let itemRight = args.count == 5 ? W * 0.62 : W - 420
let titleX = itemRight - titleSize.width
title.draw(at: NSPoint(x: titleX, y: H - menuH + (menuH - titleSize.height) / 2))
let ring = NSBezierPath(ovalIn: NSRect(x: titleX - 40, y: H - menuH + 12, width: 24, height: 24))
ring.lineWidth = 4
fg.withAlphaComponent(0.35).setStroke(); ring.stroke()
let arc = NSBezierPath()
arc.appendArc(withCenter: NSPoint(x: titleX - 28, y: H - menuH + 24), radius: 12, startAngle: 90, endAngle: -150, clockwise: true)
arc.lineWidth = 4
rgb(0x10b981).setStroke(); arc.stroke()
let itemCenterX = titleX - 40 + (titleSize.width + 40) / 2

// 창 하나를 둥근 모서리와 그림자로 그린다.
func place(_ img: NSImage, scale: CGFloat, at origin: NSPoint, radius: CGFloat) {
    let rect = NSRect(origin: origin, size: NSSize(width: img.size.width * scale, height: img.size.height * scale))
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(dark ? 0.6 : 0.22)
    shadow.shadowBlurRadius = 60
    shadow.shadowOffset = NSSize(width: 0, height: -20)
    shadow.set()
    let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    (dark ? rgb(0x020617) : NSColor.white).setFill()
    path.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSGraphicsContext.saveGraphicsState()
    path.addClip()
    img.draw(in: rect)
    NSGraphicsContext.restoreGraphicsState()
}

if inputs.count == 1 {
    // 팝오버처럼: 메뉴바 항목 바로 아래, 가운데를 맞춘다.
    let (img, s) = inputs[0]
    let w = img.size.width * s, h = img.size.height * s
    place(img, scale: s, at: NSPoint(x: itemCenterX - w / 2, y: H - menuH - 24 - h), radius: 28)
} else {
    // 나란히. 아래쪽을 맞춰 가운데에 놓는다.
    let gap: CGFloat = 120
    let total = inputs.reduce(0) { $0 + $1.0.size.width * $1.1 } + gap * CGFloat(inputs.count - 1)
    var x = (W - total) / 2
    let tallest = inputs.map { $0.0.size.height * $0.1 }.max()!
    let baseY = (H - menuH - tallest) / 2
    for (img, s) in inputs {
        place(img, scale: s, at: NSPoint(x: x, y: baseY + (tallest - img.size.height * s) / 2), radius: 24)
        x += img.size.width * s + gap
    }
}

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: outPath))
