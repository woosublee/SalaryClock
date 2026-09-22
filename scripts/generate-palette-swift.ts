/**
 * shared/golden/palette.json → Palette.swift
 *
 * 색을 손으로 옮겨 적으면 웹과 조용히 어긋난다. 웹 빌드에서 뽑은 값을
 * 그대로 Swift 소스로 찍어낸다.
 *
 * 이번 버전은 sRGB hex만 쓴다. palette.json에는 광색역 lab() 값도 들어
 * 있지만, CIELAB → Display P3 변환을 눈으로 확인할 수단이 없는 상태에서
 * 넣을 작업이 아니다. 나중에 붙일 수 있도록 JSON에는 남아 있다.
 *
 * 실행: npm run palette:swift
 */
import { readFileSync, writeFileSync } from 'node:fs'
import path from 'node:path'

const root = path.resolve(import.meta.dirname, '..')
const palette = JSON.parse(
  readFileSync(path.join(root, 'shared/golden/palette.json'), 'utf8'),
) as {
  surface: { background: Record<string, string>; foreground: Record<string, string> }
  tokens: Record<string, { hex: string; lab: string | null }>
}

/** "#fff" 도 "#f1f5f9" 도 받는다. */
function rgb(hex: string): [number, number, number] {
  const h = hex.replace('#', '')
  const full = h.length === 3 ? h.split('').map((c) => c + c).join('') : h
  if (full.length !== 6) throw new Error(`hex 형식을 모르겠다: ${hex}`)
  return [0, 2, 4].map((i) => parseInt(full.slice(i, i + 2), 16) / 255) as [number, number, number]
}

/** slate-400 → slate400 */
const swiftName = (token: string) => token.replace(/-(\d+)$/, '$1').replace(/-/g, '')

const lines: string[] = [
  '// 생성된 파일이다. 손으로 고치지 말 것.',
  '// shared/golden/palette.json 에서 npm run palette:swift 로 다시 만든다.',
  '//',
  '// 웹은 P3 디스플레이에서 lab() 값을 그리지만 여기서는 sRGB hex만 쓴다.',
  '// lab 값은 palette.json에 남아 있으니 나중에 붙일 수 있다.',
  '',
  'import SwiftUI',
  '',
  'public enum Palette {',
  '    /// 밝게·어둡게 한 쌍. 시스템 설정에 따라 고른다.',
  '    public struct Pair: Sendable {',
  '        public let light: Color',
  '        public let dark: Color',
  '        public func resolve(_ scheme: ColorScheme) -> Color { scheme == .dark ? dark : light }',
  '    }',
  '',
  '    private static func srgb(_ r: Double, _ g: Double, _ b: Double) -> Color {',
  '        Color(.sRGB, red: r, green: g, blue: b, opacity: 1)',
  '    }',
  '',
]

for (const [token, { hex }] of Object.entries(palette.tokens)) {
  const [r, g, b] = rgb(hex)
  lines.push(
    `    /// ${token} — ${hex}`,
    `    public static let ${swiftName(token)} = srgb(${r.toFixed(6)}, ${g.toFixed(6)}, ${b.toFixed(6)})`,
    '',
  )
}

for (const [role, pair] of Object.entries(palette.surface)) {
  if (role === 'note') continue
  const p = pair as Record<string, string>
  lines.push(
    `    /// app/page.tsx의 <main>이 칠하는 ${role}`,
    `    public static let surface${role[0].toUpperCase()}${role.slice(1)} = Pair(`,
    `        light: ${swiftName(p.light)}, dark: ${swiftName(p.dark)}`,
    '    )',
    '',
  )
}

lines.push('}', '')

const out = path.join(root, 'macos/SalaryClockCore/Sources/SalaryClockCore/Palette.swift')
writeFileSync(out, lines.join('\n'), 'utf8')
console.log(`wrote ${path.relative(root, out)}`)
