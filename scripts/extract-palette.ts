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
 * --background/--foreground도 마찬가지다. Tailwind 팔레트 밖의 변수지만
 * 빌드된 CSS에 그대로 나오므로 같은 방식으로 뽑는다.
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
  'slate-50',
  'slate-100',
  'slate-200',
  'slate-300',
  'slate-400',
  'slate-500',
  'slate-600',
  'slate-700',
  'slate-800',
  'slate-900',
  'slate-950',
  'emerald-50',
  'emerald-100',
  'emerald-300',
  'emerald-400',
  'emerald-500',
  'emerald-600',
  'emerald-700',
  'emerald-900',
  'emerald-950',
  // MonthCalendar가 공휴일·요일 머리글에 쓰는 색. 지금까지는 아무 화면도
  // rose/sky를 안 써서 토큰이 없었다.
  'rose-50',
  'rose-400',
  'rose-950',
  'sky-400',
  // 시계 페이스 10종이 쓰는 색. 말끔 하나만 옮겼을 때는 slate/emerald로
  // 충분했지만, 해시계는 stone과 amber로 종이 문자판을 만들고 수위는 sky,
  // 남은은 rose, 파문은 orange를 쓴다.
  'stone-100',
  'stone-200',
  'stone-300',
  'stone-400',
  'stone-600',
  'stone-700',
  'stone-800',
  'stone-900',
  'amber-400',
  'amber-500',
  'amber-600',
  'orange-500',
  'sky-500',
  'sky-600',
  'rose-500',
  'rose-600',
] as const

/**
 * 넓은 색역에서도 같은 색이라 Tailwind가 lab() 변형을 내보내지 않는 토큰.
 * hex 하나만 나오는 게 정상이므로 따로 둔다.
 */
const HEX_ONLY_TOKENS = ['white'] as const

type Entry = { hex: string; lab: string | null }

const values = (name: string) =>
  [...css.matchAll(new RegExp(`--${name}:([^;}]+)[;}]`, 'g'))].map((m) => m[1])

const found: Record<string, Entry> = {}
const missing: string[] = []

for (const token of [...TOKENS, ...HEX_ONLY_TOKENS]) {
  // 토큰마다 --color-<token>: 선언이 두 번 나온다: hex 폴백, 그다음 lab() 값.
  // 순서에 기대지 않고 각 값의 모양으로 hex/lab을 구분한다.
  const vs = values(`color-${token}`)
  const hex = vs.find((v) => v.startsWith('#'))
  const lab = vs.find((v) => v.startsWith('lab(')) ?? null
  const labNeeded = (TOKENS as readonly string[]).includes(token)
  if (hex && (lab || !labNeeded)) found[token] = { hex, lab }
  else missing.push(token)
}

/**
 * 밝게/어둡게가 갈리는 CSS 변수를 뽑는다.
 *
 * 선언 순서는 :root(밝게)가 먼저고 다크 규칙이 뒤따른다. 첫 값이 밝게,
 * 그와 다른 첫 값이 어둡게다. 여기도 손으로 적지 않는다 — 스펙 5.1.
 */
const themedVar = (name: string): { light: string; dark: string } | null => {
  const vs = values(name)
  const light = vs[0]
  const dark = vs.slice(1).find((v) => v !== light)
  return light && dark ? { light, dark } : null
}

const bodyBackground = themedVar('background')
const bodyForeground = themedVar('foreground')

if (!bodyBackground) missing.push('--background')
if (!bodyForeground) missing.push('--foreground')

if (missing.length > 0) {
  console.error(`CSS에서 못 찾은 토큰: ${missing.join(', ')}`)
  console.error('Tailwind가 쓰지 않는 색은 변수로 내보내지 않는다.')
  console.error('스펙 5.1 표와 대조해 실제로 쓰이는 토큰인지, hex/lab 두 값이')
  console.error('전부 나오는지 확인할 것.')
  process.exit(1)
}

/**
 * 화면에 실제로 칠해지는 색. app/page.tsx의 <main>이 bg-white dark:bg-slate-950 /
 * text-slate-900 dark:text-slate-100으로 body 변수를 화면 전체에서 덮어쓴다.
 * 팝오버는 body 변수가 아니라 이쪽을 따라야 웹과 같아 보인다.
 * hex를 다시 적지 않고 tokens의 이름을 가리킨다.
 */
const surface = {
  note: 'app/page.tsx의 <main>이 칠하는 색. 값은 tokens의 키다. 팝오버는 이쪽을 쓴다.',
  background: { light: 'white', dark: 'slate-950' },
  foreground: { light: 'slate-900', dark: 'slate-100' },
}

const dangling = [surface.background, surface.foreground]
  .flatMap((pair) => Object.values(pair))
  .filter((name) => !(name in found))

if (dangling.length > 0) {
  console.error(`surface가 가리키는 토큰이 tokens에 없다: ${dangling.join(', ')}`)
  process.exit(1)
}

const palette = {
  note: 'npm run build && npm run palette 로 다시 뽑는다. 손으로 고치지 말 것.',
  surface,
  // app/globals.css의 body 변수. <main>이 덮어써서 화면에는 거의 보이지 않는다.
  bodyFallback: {
    note: 'app/globals.css의 --background/--foreground. <main>이 덮어쓰는 폴백이다.',
    background: bodyBackground,
    foreground: bodyForeground,
  },
  tokens: found,
}

const outDir = path.join(root, 'shared', 'golden')
mkdirSync(outDir, { recursive: true })
writeFileSync(path.join(outDir, 'palette.json'), `${JSON.stringify(palette, null, 2)}\n`, 'utf8')
console.log('wrote shared/golden/palette.json')
