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

    /// slate-50 — #f8fafc
    public static let slate50 = srgb(0.972549, 0.980392, 0.988235)

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

    /// emerald-50 — #ecfdf5
    public static let emerald50 = srgb(0.925490, 0.992157, 0.960784)

    /// emerald-100 — #d0fae5
    public static let emerald100 = srgb(0.815686, 0.980392, 0.898039)

    /// emerald-300 — #5ee9b5
    public static let emerald300 = srgb(0.368627, 0.913725, 0.709804)

    /// emerald-400 — #00d294
    public static let emerald400 = srgb(0.000000, 0.823529, 0.580392)

    /// emerald-500 — #00bb7f
    public static let emerald500 = srgb(0.000000, 0.733333, 0.498039)

    /// emerald-600 — #009767
    public static let emerald600 = srgb(0.000000, 0.592157, 0.403922)

    /// emerald-700 — #007956
    public static let emerald700 = srgb(0.000000, 0.474510, 0.337255)

    /// emerald-900 — #004e3b
    public static let emerald900 = srgb(0.000000, 0.305882, 0.231373)

    /// emerald-950 — #002c22
    public static let emerald950 = srgb(0.000000, 0.172549, 0.133333)

    /// rose-50 — #fff1f2
    public static let rose50 = srgb(1.000000, 0.945098, 0.949020)

    /// rose-400 — #ff667f
    public static let rose400 = srgb(1.000000, 0.400000, 0.498039)

    /// rose-950 — #4d0218
    public static let rose950 = srgb(0.301961, 0.007843, 0.094118)

    /// sky-400 — #00bcfe
    public static let sky400 = srgb(0.000000, 0.737255, 0.996078)

    /// stone-100 — #f5f5f4
    public static let stone100 = srgb(0.960784, 0.960784, 0.956863)

    /// stone-200 — #e7e5e4
    public static let stone200 = srgb(0.905882, 0.898039, 0.894118)

    /// stone-300 — #d6d3d1
    public static let stone300 = srgb(0.839216, 0.827451, 0.819608)

    /// stone-400 — #a6a09b
    public static let stone400 = srgb(0.650980, 0.627451, 0.607843)

    /// stone-600 — #57534d
    public static let stone600 = srgb(0.341176, 0.325490, 0.301961)

    /// stone-700 — #44403b
    public static let stone700 = srgb(0.266667, 0.250980, 0.231373)

    /// stone-800 — #292524
    public static let stone800 = srgb(0.160784, 0.145098, 0.141176)

    /// stone-900 — #1c1917
    public static let stone900 = srgb(0.109804, 0.098039, 0.090196)

    /// amber-400 — #fcbb00
    public static let amber400 = srgb(0.988235, 0.733333, 0.000000)

    /// amber-500 — #f99c00
    public static let amber500 = srgb(0.976471, 0.611765, 0.000000)

    /// amber-600 — #dd7400
    public static let amber600 = srgb(0.866667, 0.454902, 0.000000)

    /// orange-500 — #fe6e00
    public static let orange500 = srgb(0.996078, 0.431373, 0.000000)

    /// sky-500 — #00a5ef
    public static let sky500 = srgb(0.000000, 0.647059, 0.937255)

    /// sky-600 — #0084cc
    public static let sky600 = srgb(0.000000, 0.517647, 0.800000)

    /// rose-500 — #ff2357
    public static let rose500 = srgb(1.000000, 0.137255, 0.341176)

    /// rose-600 — #e70044
    public static let rose600 = srgb(0.905882, 0.000000, 0.266667)

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
