// 생성된 파일이다. 손으로 고치지 말 것.
// shared/golden/palette.json 에서 npm run palette:swift 로 다시 만든다.
//
// 웹은 P3 디스플레이에서 lab() 값을 그리지만 여기서는 sRGB hex만 쓴다.
// lab 값은 palette.json에 남아 있으니 나중에 붙일 수 있다.

import SwiftUI

public enum Palette {
    /// 밝게·어둡게 한 쌍. 시스템 설정에 따라 고른다.
    public struct Pair: Sendable {
        public let light: Color
        public let dark: Color
        public func resolve(_ scheme: ColorScheme) -> Color { scheme == .dark ? dark : light }
    }

    private static func srgb(_ r: Double, _ g: Double, _ b: Double) -> Color {
        Color(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }

    /// slate-100 — #f1f5f9
    public static let slate100 = srgb(0.945098, 0.960784, 0.976471)

    /// slate-200 — #e2e8f0
    public static let slate200 = srgb(0.886275, 0.909804, 0.941176)

    /// slate-300 — #cad5e2
    public static let slate300 = srgb(0.792157, 0.835294, 0.886275)

    /// slate-400 — #90a1b9
    public static let slate400 = srgb(0.564706, 0.631373, 0.725490)

    /// slate-500 — #62748e
    public static let slate500 = srgb(0.384314, 0.454902, 0.556863)

    /// slate-600 — #45556c
    public static let slate600 = srgb(0.270588, 0.333333, 0.423529)

    /// slate-700 — #314158
    public static let slate700 = srgb(0.192157, 0.254902, 0.345098)

    /// slate-800 — #1d293d
    public static let slate800 = srgb(0.113725, 0.160784, 0.239216)

    /// slate-900 — #0f172b
    public static let slate900 = srgb(0.058824, 0.090196, 0.168627)

    /// slate-950 — #020618
    public static let slate950 = srgb(0.007843, 0.023529, 0.094118)

    /// emerald-400 — #00d294
    public static let emerald400 = srgb(0.000000, 0.823529, 0.580392)

    /// emerald-500 — #00bb7f
    public static let emerald500 = srgb(0.000000, 0.733333, 0.498039)

    /// emerald-600 — #009767
    public static let emerald600 = srgb(0.000000, 0.592157, 0.403922)

    /// white — #fff
    public static let white = srgb(1.000000, 1.000000, 1.000000)

    /// app/page.tsx의 <main>이 칠하는 background
    public static let surfaceBackground = Pair(
        light: white, dark: slate950
    )

    /// app/page.tsx의 <main>이 칠하는 foreground
    public static let surfaceForeground = Pair(
        light: slate900, dark: slate100
    )

}
