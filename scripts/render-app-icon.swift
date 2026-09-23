// 앱 아이콘을 그린다. 밝게·어둡게 두 장을 1024×1024 PNG로 낸다.
//
// PNG를 저장소에 넣지 않고 그릴 때마다 만드는 이유는 팔레트와 같다: 색을
// 손으로 옮겨 적지 않는다. 여기서도 shared/golden/palette.json에서 읽는다.
// 웹 색이 바뀌면 아이콘도 따라 바뀐다.
//
// 그림은 말끔(minimal) 얼굴을 그대로 키운 것이다 — 바깥에 진행 링, 안에 눈금과
// 바늘. 메뉴바 아이콘·팝오버 시계와 같은 언어를 쓴다.
//
// 사용법: render-app-icon <palette.json> <출력 디렉터리>
import AppKit

let args = CommandLine.arguments
guard args.count == 3 else {
    FileHandle.standardError.write("사용법: render-app-icon <palette.json> <출력 디렉터리>\n".data(using: .utf8)!)
    exit(1)
}
let paletteURL = URL(fileURLWithPath: args[1])
let outDir = URL(fileURLWithPath: args[2])

let json = try JSONSerialization.jsonObject(with: Data(contentsOf: paletteURL)) as! [String: Any]
let tokens = json["tokens"] as! [String: [String: Any]]

func color(_ token: String) -> NSColor {
    guard let hex = tokens[token]?["hex"] as? String else {
        FileHandle.standardError.write("팔레트에 없는 토큰: \(token)\n".data(using: .utf8)!)
        exit(1)
    }
    var s = Substring(hex.dropFirst())
    if s.count == 3 { s = Substring(s.map { "\($0)\($0)" }.joined()) }
    let v = UInt32(s, radix: 16)!
    return NSColor(
        srgbRed: CGFloat((v >> 16) & 0xff) / 255,
        green: CGFloat((v >> 8) & 0xff) / 255,
        blue: CGFloat(v & 0xff) / 255, alpha: 1
    )
}

let side: CGFloat = 1024
// macOS 아이콘은 1024 캔버스를 다 쓰지 않는다. 가장자리를 비워 다른 앱
// 아이콘들과 시각적 크기를 맞춘다.
let inset: CGFloat = 100
let plate = NSRect(x: inset, y: inset, width: side - inset * 2, height: side - inset * 2)
let corner = plate.width * 0.225
let center = CGPoint(x: side / 2, y: side / 2)

/// 12시 방향 0도, 시계방향 증가. AppKit은 y축이 위로 향하므로 웹의
/// polarPoint와 부호가 하나 다르다.
func polar(_ r: CGFloat, _ deg: CGFloat) -> CGPoint {
    let rad = (deg - 90) * .pi / 180
    return CGPoint(x: center.x + r * cos(rad), y: center.y - r * sin(rad))
}

func arc(radius: CGFloat, from: CGFloat, sweep: CGFloat, width: CGFloat, _ c: NSColor) {
    let p = NSBezierPath()
    p.appendArc(withCenter: center, radius: radius,
                startAngle: 90 - from, endAngle: 90 - (from + sweep), clockwise: true)
    p.lineWidth = width
    p.lineCapStyle = .round
    c.setStroke()
    p.stroke()
}

func hand(deg: CGFloat, length: CGFloat, back: CGFloat, width: CGFloat, _ c: NSColor) {
    let p = NSBezierPath()
    p.move(to: polar(-back, deg))
    p.line(to: polar(length, deg))
    p.lineWidth = width
    p.lineCapStyle = .round
    c.setStroke()
    p.stroke()
}

/// 10시 10분. 시계 사진의 관례다 — 바늘이 겹치지 않고 문자판을 가리지 않는다.
let hourHandDegrees: CGFloat = 300
let minuteHandDegrees: CGFloat = 60
/// 진행 링은 하루의 3/4쯤 찬 모습. 가득 차면 링인지 테두리인지 구분이 안 되고,
/// 비어 있으면 이 앱이 무엇을 세는지가 드러나지 않는다.
let progressSweep: CGFloat = 260

func render(background: NSColor, track: NSColor, ring: NSColor, tick: NSColor, hands: NSColor) -> Data {
    let image = NSImage(size: NSSize(width: side, height: side))
    image.lockFocus()
    NSGraphicsContext.current?.imageInterpolation = .high

    NSBezierPath(roundedRect: plate, xRadius: corner, yRadius: corner).addClip()
    background.setFill()
    plate.fill()

    arc(radius: 300, from: 0, sweep: 360, width: 44, track)
    arc(radius: 300, from: 0, sweep: progressSweep, width: 44, ring)

    for i in 0..<12 {
        let deg = CGFloat(i) * 30
        let long = i % 3 == 0
        let p = NSBezierPath()
        p.move(to: polar(232, deg))
        p.line(to: polar(long ? 190 : 208, deg))
        p.lineWidth = long ? 16 : 8
        p.lineCapStyle = .round
        tick.setStroke()
        p.stroke()
    }

    hand(deg: hourHandDegrees, length: 130, back: 34, width: 30, hands)
    hand(deg: minuteHandDegrees, length: 196, back: 40, width: 20, hands)
    ring.setFill()
    NSBezierPath(ovalIn: NSRect(x: center.x - 18, y: center.y - 18, width: 36, height: 36)).fill()

    image.unlockFocus()
    let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
    return rep.representation(using: .png, properties: [:])!
}

// 색 역할은 Theme.swift와 같은 짝이다 (밝게 / 어둡게).
let light = render(
    background: color("white"), track: color("slate-200"), ring: color("emerald-500"),
    tick: color("slate-400"), hands: color("slate-800")
)
let dark = render(
    background: color("slate-950"), track: color("slate-800"), ring: color("emerald-400"),
    tick: color("slate-500"), hands: color("slate-100")
)

try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
try light.write(to: outDir.appendingPathComponent("AppIcon-Light.png"))
try dark.write(to: outDir.appendingPathComponent("AppIcon-Dark.png"))
print("wrote AppIcon-Light.png, AppIcon-Dark.png")
