import Testing
import Foundation
import AppKit
@testable import SalaryClockAppLib
import SalaryClockCore

private func at(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int, _ s: Int) -> Int {
    var c = DateComponents()
    c.year = y; c.month = mo + 1; c.day = d; c.hour = h; c.minute = mi; c.second = s
    return Int((Calendar.current.date(from: c)!.timeIntervalSince1970 * 1000).rounded())
}

@Test("근무 중에는 정수 금액을 보여준다")
func titleWhileWorking() {
    let e = computeEarnings(.default, at(2026, 8, 22, 14, 0, 0))
    let title = menuBarTitle(e, hideAmount: false)
    #expect(title == formatWon(e.earned))
    #expect(title?.contains(".") == false, "메뉴바는 소수를 쓰지 않는다")
}

@Test("휴무일에는 금액을 내린다")
func titleOnDayOff() {
    let e = computeEarnings(.default, at(2026, 8, 26, 14, 0, 0))
    #expect(e.phase == .dayoff)
    #expect(menuBarTitle(e, hideAmount: false) == nil)
}

@Test("가리기를 켜면 금액을 내린다")
func titleWhenHidden() {
    let e = computeEarnings(.default, at(2026, 8, 22, 14, 0, 0))
    #expect(menuBarTitle(e, hideAmount: true) == nil)
}

@Test("출근 전에는 0원을 보여준다")
func titleBeforeWork() {
    let e = computeEarnings(.default, at(2026, 8, 22, 0, 30, 0))
    #expect(e.phase == .before)
    #expect(menuBarTitle(e, hideAmount: false) == formatWon(0))
}

/// 휴무일 아이콘에 바늘이 들어가는지.
///
/// 그림을 눈으로 볼 수 없으니 "빈 링과 다른 그림이 나온다"까지만 본다. 바늘을
/// 그리는 코드가 통째로 빠지거나 시각이 전달되지 않으면 두 그림이 같아진다.
@Test("휴무일 아이콘은 빈 링과 다르다 — 바늘이 그려진다")
func dayOffIconDrawsHands() {
    let t = at(2026, 8, 26, 10, 10, 0)
    let empty = ringImage(progress: 0).tiffRepresentation
    let clock = ringImage(progress: 0, clockAt: t).tiffRepresentation
    #expect(empty != nil && clock != nil)
    #expect(empty != clock)
}

@Test("바늘은 시각에 따라 달라진다")
func handsFollowTime() {
    let a = ringImage(progress: 0, clockAt: at(2026, 8, 26, 3, 0, 0)).tiffRepresentation
    let b = ringImage(progress: 0, clockAt: at(2026, 8, 26, 9, 0, 0)).tiffRepresentation
    #expect(a != b)
}

/// 아이콘은 한 번 만든 뒤 그리는 쪽의 외형을 따라가야 한다.
///
/// 이미지를 한 번만 만들고 밝은·어두운 외형에서 각각 비트맵으로 뽑는다.
/// 색이 만드는 순간에 굳어 버리면(lockFocus) 두 비트맵이 같아진다.
@Test("링 아이콘은 그리는 시점의 외형으로 색이 풀린다")
@MainActor
func ringFollowsDrawingAppearance() {
    let image = ringImage(progress: 0.3, clockAt: at(2026, 8, 26, 10, 10, 0))
    // 버튼이 하듯 그래픽 문맥에 직접 그린다. tiffRepresentation은 처음 뽑은
    // 비트맵을 캐시해 두 번째 외형을 보지 않는다.
    func render(_ name: NSAppearance.Name) -> Data? {
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: 32, pixelsHigh: 32,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        )!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSAppearance(named: name)!.performAsCurrentDrawingAppearance {
            image.draw(in: NSRect(x: 0, y: 0, width: 32, height: 32))
        }
        NSGraphicsContext.restoreGraphicsState()
        return rep.tiffRepresentation
    }
    let light = render(.aqua)
    let dark = render(.darkAqua)
    #expect(light != nil && dark != nil)
    #expect(light != dark)
}

/// 개발 빌드 아이콘 — 박스는 칠해지고, 테두리 자리는 파여 비어 있어야 한다.
@Test("개발 빌드 아이콘은 박스를 칠하고 링 테두리를 음각으로 파낸다")
@MainActor
func devBadgeEngravesRing() {
    func alpha(_ image: NSImage, x: Int, y: Int) -> CGFloat {
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: 16, pixelsHigh: 16,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        )!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSAppearance(named: .darkAqua)!.performAsCurrentDrawingAppearance {
            image.draw(in: NSRect(x: 0, y: 0, width: 16, height: 16))
        }
        NSGraphicsContext.restoreGraphicsState()
        return rep.colorAt(x: x, y: y)?.alphaComponent ?? 0
    }
    let badge = ringImage(progress: 0, devBadge: true)
    let plain = ringImage(progress: 0, devBadge: false)
    // 박스 색은 메뉴바 글자색(labelColor)이라 어두운 쪽에서 불투명도가 0.85다.
    // (8, 8): 링 안쪽 가운데. 개발 빌드만 칠해져 있다.
    #expect(alpha(badge, x: 8, y: 8) > 0.7)
    #expect(alpha(plain, x: 8, y: 8) < 0.1)
    // (1, 8): 링 바깥의 박스 가장자리도 칠해져 있다.
    #expect(alpha(badge, x: 1, y: 8) > 0.7)
    // (3, 8): 개발 빌드 링 테두리 자리. 끝까지 파여 있어야 한다.
    #expect(alpha(badge, x: 3, y: 8) < 0.1)
}

@Test("개발 빌드는 금액까지 한 박스에 담고 글자를 파낸다")
@MainActor
func devBadgeHoldsAmount() {
    let withAmount = devBadgeImage(progress: 0.4, clockAt: nil, title: "123,456원")
    let without = devBadgeImage(progress: 0.4, clockAt: nil, title: nil)
    #expect(withAmount.size.width > without.size.width + 30)

    // 금액 영역(링 오른쪽)을 훑어 칠해진 박스와 파낸 글자가 둘 다 있는지 본다.
    let w = Int(withAmount.size.width), h = Int(withAmount.size.height)
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: h,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSAppearance(named: .darkAqua)!.performAsCurrentDrawingAppearance {
        withAmount.draw(in: NSRect(x: 0, y: 0, width: w, height: h))
    }
    NSGraphicsContext.restoreGraphicsState()
    var filled = 0, carved = 0
    for x in 22..<(w - 6) {
        for y in 4..<(h - 4) {
            let a = rep.colorAt(x: x, y: y)?.alphaComponent ?? 0
            if a > 0.7 { filled += 1 } else if a < 0.2 { carved += 1 }
        }
    }
    #expect(filled > 20)
    #expect(carved > 20)
}
