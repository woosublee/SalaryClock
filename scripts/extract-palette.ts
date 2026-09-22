/**
 * 맥 앱이 쓸 색을 빌드된 CSS에서 뽑는다.
 *
 * Tailwind v4는 팔레트를 정의할 때 oklch를 쓰지만, 빌드 결과는 그걸 그대로
 * 내보내지 않는다. 실제 프로덕션 빌드(`.next/static/chunks/*.css`)를 보면
 * 토큰마다 선언이 두 번 나온다:
 *
 *   --color-slate-400:#90a1b9;
 *   --color-slate-400:lab(65.5349% -2.25151 -14.5072);
 *
 * 첫 번째는 sRGB로 낮춘 hex 폴백이고, 두 번째는 P3 등 넓은 색역 디스플레이가
 * 쓰는 lab() 값이다. 최신 맥은 전부 P3 디스플레이라 웹은 실제로 lab() 값을
 * 렌더링한다 — hex만 옮기면 맥 앱이 웹과 미묘하게 다른 색으로 보인다. 그래서
 * 손으로 hex를 옮겨 적지 않고, 두 값을 전부 빌드 결과에서 그대로 가져온다.
 *
 * 실행: npm run build && npm run palette
 */
import { readFileSync, writeFileSync, mkdirSync, readdirSync } from 'node:fs'
import path from 'node:path'

const root = path.resolve(import.meta.dirname, '..')
// .next/static/css는 존재하지 않는다 — 빌드된 스타일시트는
// .next/static/chunks/*.css에 해시된 이름으로 나온다. (.next/dev/static/chunks는
// dev 서버 산출물이라 제외한다.)
const cssDir = path.join(root, '.next', 'static', 'chunks')

const css = readdirSync(cssDir)
  .filter((f) => f.endsWith('.css'))
  .map((f) => readFileSync(path.join(cssDir, f), 'utf8'))
  .join('\n')

/** 맥 앱이 실제로 쓰는 토큰만. 스펙 5.1 표와 같은 목록이다. */
const TOKENS = [
  'slate-100',
  'slate-200',
  'slate-300',
  'slate-400',
  'slate-500',
  'slate-600',
  'slate-700',
  'slate-800',
  'slate-950',
  'emerald-400',
  'emerald-500',
  'emerald-600',
] as const

type Entry = { hex: string; lab: string }

const found: Record<string, Entry> = {}
const missing: string[] = []

for (const token of TOKENS) {
  // 토큰마다 --color-<token>: 선언이 두 번 나온다: hex 폴백, 그다음 lab() 값.
  // 순서에 기대지 않고 각 값의 모양으로 hex/lab을 구분한다.
  const matches = [...css.matchAll(new RegExp(`--color-${token}:([^;]+);`, 'g'))]
  const hex = matches.map((m) => m[1]).find((v) => v.startsWith('#'))
  const lab = matches.map((m) => m[1]).find((v) => v.startsWith('lab('))
  if (hex && lab) found[token] = { hex, lab }
  else missing.push(token)
}

if (missing.length > 0) {
  console.error(`CSS에서 못 찾은 토큰: ${missing.join(', ')}`)
  console.error('Tailwind가 쓰지 않는 색은 변수로 내보내지 않는다.')
  console.error('스펙 5.1 표와 대조해 실제로 쓰이는 토큰인지, hex/lab 두 값이')
  console.error('전부 나오는지 확인할 것.')
  process.exit(1)
}

const palette = {
  note: 'npm run build && npm run palette 로 다시 뽑는다. 손으로 고치지 말 것.',
  // app/globals.css의 CSS 변수 값. Tailwind 팔레트에 없어 여기서만 손으로 적는다.
  background: { light: '#ffffff', dark: '#0a0a0a' },
  foreground: { light: '#171717', dark: '#ededed' },
  tokens: found,
}

const outDir = path.join(root, 'shared', 'golden')
mkdirSync(outDir, { recursive: true })
writeFileSync(path.join(outDir, 'palette.json'), `${JSON.stringify(palette, null, 2)}\n`, 'utf8')
console.log('wrote shared/golden/palette.json')
