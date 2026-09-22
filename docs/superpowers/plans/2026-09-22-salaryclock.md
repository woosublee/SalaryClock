# SalaryClock Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 연봉과 근무시간을 입력하면 오늘 지금까지 쌓인 급여를 초 단위로 보여주고, 끊김 없이 흐르는 아날로그 시계로 현재 시각과 근무 진행률을 함께 표시하는 웹앱을 만든다.

**Architecture:** 서버·DB 없는 클라이언트 전용 Next.js 앱. 저장되는 상태는 설정값뿐이고, 적립액은 매 프레임 `f(설정, 현재시각)`으로 새로 계산한다. 계산 로직은 전부 `lib/` 아래 순수 함수로 두고 현재 시각을 인자로 주입받게 해서 DOM 없이 테스트한다. 시간 소스는 `requestAnimationFrame` 틱 하나뿐이라 시계 바늘과 금액이 절대 어긋나지 않는다.

**Tech Stack:** Next.js (App Router), TypeScript, Tailwind CSS, zod, vitest

**Spec:** `docs/superpowers/specs/2026-09-22-salaryclock-design.md`

## Global Constraints

- **git 미초기화.** 사용자가 git 설정을 나중으로 미뤘다. 각 Task의 마지막 스텝은 커밋이 아니라 **검증**이다. git 명령을 실행하지 말 것.
- **서버 코드 금지.** Server Action, Route Handler, `next/headers` 등을 쓰지 않는다. 페이지는 `'use client'`.
- **`lib/` 아래 모든 함수는 순수 함수.** `Date.now()`를 직접 호출하지 않고 현재 시각(epoch ms)을 인자로 받는다. 이 규칙이 테스트 가능성의 전부다.
- **테스트는 타임존 독립적으로 작성한다.** 기대값을 하드코딩한 UTC 오프셋으로 만들지 말고, `new Date(2026, 8, 22, 9, 0, 0).getTime()`처럼 로컬 시각 생성자로 만든다. (월은 0-based: 8 = 9월)
- **바늘 회전에 CSS transition을 걸지 않는다.** 360도→0도 전환 시 역방향으로 한 바퀴 도는 버그가 생긴다.
- **기본 근무시간은 09:00–18:00, 점심 12:00–13:00.** 전부 설정에서 수정 가능해야 한다.
- **통화 표기:** `Intl.NumberFormat('ko-KR', { style: 'currency', currency: 'KRW' })`
- **UI 문구는 한국어.**
- 테스트 실행: `npm test` (= `vitest run`)

---

## File Structure

| 파일 | 책임 |
|---|---|
| `lib/time.ts` | `"HH:mm"` 파싱·검증, 분↔ms 변환. 도메인 타입을 모른다 |
| `lib/settings.ts` | 설정 zod 스키마, 기본값, localStorage 읽기/쓰기 |
| `lib/shift.ts` | 설정 + 현재시각 → 근무 시프트의 절대 시각 |
| `lib/salary.ts` | 시프트 + 현재시각 → 적립액·phase·진행률 |
| `lib/clock.ts` | 시각 → 바늘 각도, 시프트 → 문자판 호(arc) |
| `lib/format.ts` | 통화·기간 표시 문자열 |
| `hooks/useNow.ts` | rAF 틱. 앱의 유일한 시간 소스 |
| `hooks/useSettings.ts` | 설정 상태 + localStorage 연동 |
| `components/AnalogClock.tsx` | SVG 문자판, 바늘, 근무 진행 링 |
| `components/EarningsDisplay.tsx` | 금액과 초당 적립액 |
| `components/StatusLine.tsx` | phase별 한 줄 상태 문구 |
| `components/SettingsPanel.tsx` | 설정 입력 폼 |
| `app/page.tsx` | 조립. 틱을 받아 각 컴포넌트에 내려준다 |

의존 방향은 `time → settings → shift → {salary, clock}` 한 방향뿐이다. 순환 없음.

---

### Task 1: 프로젝트 부트스트랩

**Files:**
- Create: 프로젝트 전체 (create-next-app 스캐폴드)
- Create: `vitest.config.ts`, `lib/__tests__/smoke.test.ts`
- Modify: `package.json`

**Interfaces:**
- Consumes: 없음
- Produces: `npm test`가 도는 환경, `@/*` 경로 별칭

- [ ] **Step 1: Next.js 스캐폴드 생성**

```bash
npx --yes create-next-app@latest . --typescript --tailwind --eslint --app --no-src-dir --import-alias "@/*" --use-npm --turbopack
```

`.git`이 생성되었다면 삭제한다 (git은 사용자가 나중에 직접 설정):

```bash
rm -rf .git
```

- [ ] **Step 2: 의존성 설치**

```bash
npm install zod
npm install --save-dev vitest
```

- [ ] **Step 3: vitest 설정**

`vitest.config.ts`:

```ts
import { defineConfig } from 'vitest/config'
import path from 'node:path'

export default defineConfig({
  test: {
    environment: 'node',
    include: ['**/__tests__/**/*.test.ts'],
  },
  resolve: {
    alias: { '@': path.resolve(__dirname, '.') },
  },
})
```

- [ ] **Step 4: package.json scripts에 추가**

```json
"test": "vitest run",
"test:watch": "vitest"
```

- [ ] **Step 5: 스모크 테스트**

`lib/__tests__/smoke.test.ts`:

```ts
import { describe, it, expect } from 'vitest'

describe('테스트 환경', () => {
  it('동작한다', () => {
    expect(1 + 1).toBe(2)
  })
})
```

- [ ] **Step 6: 검증**

Run: `npm test` → Expected: 1 passed
Run: `npm run build` → Expected: 빌드 성공

---

### Task 2: lib/time.ts — 시각 문자열 유틸

**Files:**
- Create: `lib/time.ts`
- Test: `lib/__tests__/time.test.ts`

**Interfaces:**
- Consumes: 없음
- Produces:
  - `MS_PER_MINUTE: number`, `MS_PER_HOUR: number`, `MS_PER_DAY: number`
  - `isValidHHmm(v: string): boolean`
  - `parseHHmm(v: string): number` — 자정부터의 분. 형식이 틀리면 throw
  - `formatHHmm(minutes: number): string`
  - `durationMinutes(startMin: number, endMin: number): number` — 자정을 넘으면 24시간을 더해 항상 0 이상. 같으면 0
  - `startOfLocalDay(now: number): number`

- [ ] **Step 1: 실패하는 테스트 작성**

`lib/__tests__/time.test.ts`:

```ts
import { describe, it, expect } from 'vitest'
import {
  isValidHHmm,
  parseHHmm,
  formatHHmm,
  durationMinutes,
  startOfLocalDay,
  MS_PER_MINUTE,
} from '@/lib/time'

describe('isValidHHmm', () => {
  it('올바른 형식을 통과시킨다', () => {
    expect(isValidHHmm('00:00')).toBe(true)
    expect(isValidHHmm('09:30')).toBe(true)
    expect(isValidHHmm('23:59')).toBe(true)
  })

  it('잘못된 형식을 거른다', () => {
    expect(isValidHHmm('24:00')).toBe(false)
    expect(isValidHHmm('09:60')).toBe(false)
    expect(isValidHHmm('9:30')).toBe(false)
    expect(isValidHHmm('0930')).toBe(false)
    expect(isValidHHmm('')).toBe(false)
    expect(isValidHHmm('아홉시')).toBe(false)
  })
})

describe('parseHHmm', () => {
  it('자정부터의 분으로 바꾼다', () => {
    expect(parseHHmm('00:00')).toBe(0)
    expect(parseHHmm('09:00')).toBe(540)
    expect(parseHHmm('12:30')).toBe(750)
    expect(parseHHmm('23:59')).toBe(1439)
  })

  it('잘못된 입력에 throw 한다', () => {
    expect(() => parseHHmm('25:00')).toThrow()
  })
})

describe('formatHHmm', () => {
  it('분을 문자열로 되돌린다', () => {
    expect(formatHHmm(0)).toBe('00:00')
    expect(formatHHmm(540)).toBe('09:00')
    expect(formatHHmm(1439)).toBe('23:59')
  })
})

describe('durationMinutes', () => {
  it('같은 날 구간을 계산한다', () => {
    expect(durationMinutes(540, 1080)).toBe(540)
  })

  it('자정을 넘는 구간에 24시간을 더한다', () => {
    expect(durationMinutes(1320, 360)).toBe(480)
  })

  it('시작과 끝이 같으면 0이다', () => {
    expect(durationMinutes(540, 540)).toBe(0)
  })
})

describe('startOfLocalDay', () => {
  it('그날 로컬 자정을 돌려준다', () => {
    const noon = new Date(2026, 8, 22, 12, 34, 56, 789).getTime()
    const midnight = new Date(2026, 8, 22, 0, 0, 0, 0).getTime()
    expect(startOfLocalDay(noon)).toBe(midnight)
  })

  it('이미 자정이면 그대로다', () => {
    const midnight = new Date(2026, 8, 22, 0, 0, 0, 0).getTime()
    expect(startOfLocalDay(midnight)).toBe(midnight)
  })
})

describe('MS_PER_MINUTE', () => {
  it('60000이다', () => {
    expect(MS_PER_MINUTE).toBe(60_000)
  })
})
```

- [ ] **Step 2: 실패 확인**

Run: `npm test`
Expected: FAIL — `Failed to resolve import "@/lib/time"`

- [ ] **Step 3: 구현**

`lib/time.ts`:

```ts
export const MS_PER_MINUTE = 60_000
export const MS_PER_HOUR = 3_600_000
export const MS_PER_DAY = 86_400_000

const HHMM = /^([01]\d|2[0-3]):([0-5]\d)$/

export function isValidHHmm(v: string): boolean {
  return HHMM.test(v)
}

export function parseHHmm(v: string): number {
  const m = HHMM.exec(v)
  if (!m) throw new Error(`시각 형식이 올바르지 않습니다: ${v}`)
  return Number(m[1]) * 60 + Number(m[2])
}

export function formatHHmm(minutes: number): string {
  const m = ((minutes % 1440) + 1440) % 1440
  const hh = String(Math.floor(m / 60)).padStart(2, '0')
  const mm = String(m % 60).padStart(2, '0')
  return `${hh}:${mm}`
}

export function durationMinutes(startMin: number, endMin: number): number {
  return (((endMin - startMin) % 1440) + 1440) % 1440
}

export function startOfLocalDay(now: number): number {
  const d = new Date(now)
  d.setHours(0, 0, 0, 0)
  return d.getTime()
}
```

- [ ] **Step 4: 통과 확인**

Run: `npm test` → Expected: PASS

- [ ] **Step 5: 검증**

Run: `npx tsc --noEmit` → Expected: 오류 없음

---

### Task 3: lib/settings.ts — 스키마·기본값·저장

**Files:**
- Create: `lib/settings.ts`
- Test: `lib/__tests__/settings.test.ts`

**Interfaces:**
- Consumes: `lib/time.ts`의 `isValidHHmm`, `parseHHmm`, `durationMinutes`
- Produces:
  - `type PayMode = 'annual' | 'monthly' | 'hourly'`
  - `interface Settings { payMode: PayMode; payAmount: number; workDaysPerMonth: number; workStart: string; workEnd: string; lunchEnabled: boolean; lunchStart: string; lunchEnd: string }`
  - `SettingsSchema`
  - `DEFAULT_SETTINGS: Settings`
  - `STORAGE_KEY = 'salaryclock.settings.v1'`
  - `loadSettings(): { settings: Settings; hasStored: boolean }`
  - `saveSettings(s: Settings): void`

- [ ] **Step 1: 실패하는 테스트 작성**

`lib/__tests__/settings.test.ts`:

```ts
import { describe, it, expect } from 'vitest'
import { SettingsSchema, DEFAULT_SETTINGS, type Settings } from '@/lib/settings'

function withOverrides(o: Partial<Settings>): Settings {
  return { ...DEFAULT_SETTINGS, ...o }
}

describe('DEFAULT_SETTINGS', () => {
  it('9 to 6, 점심 1시간이 기본이다', () => {
    expect(DEFAULT_SETTINGS).toEqual({
      payMode: 'annual',
      payAmount: 50_000_000,
      workDaysPerMonth: 21.75,
      workStart: '09:00',
      workEnd: '18:00',
      lunchEnabled: true,
      lunchStart: '12:00',
      lunchEnd: '13:00',
    })
  })

  it('스스로 유효하다', () => {
    expect(SettingsSchema.safeParse(DEFAULT_SETTINGS).success).toBe(true)
  })
})

describe('SettingsSchema', () => {
  it('시급 모드를 통과시킨다', () => {
    expect(SettingsSchema.safeParse(withOverrides({ payMode: 'hourly', payAmount: 12_000 })).success).toBe(true)
  })

  it('점심을 끈 설정을 통과시킨다', () => {
    expect(SettingsSchema.safeParse(withOverrides({ lunchEnabled: false })).success).toBe(true)
  })

  it('자정을 넘는 야간근무를 통과시킨다', () => {
    const s = withOverrides({
      workStart: '22:00',
      workEnd: '06:00',
      lunchStart: '01:00',
      lunchEnd: '02:00',
    })
    expect(SettingsSchema.safeParse(s).success).toBe(true)
  })

  it('급여가 0 이하면 거부한다', () => {
    expect(SettingsSchema.safeParse(withOverrides({ payAmount: 0 })).success).toBe(false)
    expect(SettingsSchema.safeParse(withOverrides({ payAmount: -1 })).success).toBe(false)
  })

  it('시각 형식이 틀리면 거부한다', () => {
    expect(SettingsSchema.safeParse(withOverrides({ workStart: '9:00' })).success).toBe(false)
  })

  it('출근과 퇴근이 같으면 거부한다', () => {
    expect(SettingsSchema.safeParse(withOverrides({ workStart: '09:00', workEnd: '09:00' })).success).toBe(false)
  })

  it('점심 길이가 0이면 거부한다', () => {
    expect(SettingsSchema.safeParse(withOverrides({ lunchStart: '12:00', lunchEnd: '12:00' })).success).toBe(false)
  })

  it('점심이 근무구간 밖이면 거부한다', () => {
    expect(SettingsSchema.safeParse(withOverrides({ lunchStart: '20:00', lunchEnd: '21:00' })).success).toBe(false)
  })

  it('점심이 퇴근을 넘어가면 거부한다', () => {
    expect(SettingsSchema.safeParse(withOverrides({ lunchStart: '17:30', lunchEnd: '18:30' })).success).toBe(false)
  })

  it('점심이 근무시간 전체를 먹으면 거부한다', () => {
    const s = withOverrides({
      workStart: '09:00',
      workEnd: '10:00',
      lunchStart: '09:00',
      lunchEnd: '10:00',
    })
    expect(SettingsSchema.safeParse(s).success).toBe(false)
  })

  it('점심을 껐으면 점심 시각이 이상해도 통과시킨다', () => {
    const s = withOverrides({ lunchEnabled: false, lunchStart: '20:00', lunchEnd: '21:00' })
    expect(SettingsSchema.safeParse(s).success).toBe(true)
  })

  it('근무일수가 0 이하면 거부한다', () => {
    expect(SettingsSchema.safeParse(withOverrides({ workDaysPerMonth: 0 })).success).toBe(false)
  })
})
```

- [ ] **Step 2: 실패 확인**

Run: `npm test` → Expected: FAIL — `Failed to resolve import "@/lib/settings"`

- [ ] **Step 3: 구현**

`lib/settings.ts`:

```ts
import { z } from 'zod'
import { isValidHHmm, parseHHmm, durationMinutes } from '@/lib/time'

export type PayMode = 'annual' | 'monthly' | 'hourly'

export interface Settings {
  payMode: PayMode
  payAmount: number
  workDaysPerMonth: number
  workStart: string
  workEnd: string
  lunchEnabled: boolean
  lunchStart: string
  lunchEnd: string
}

export const STORAGE_KEY = 'salaryclock.settings.v1'

export const DEFAULT_SETTINGS: Settings = {
  payMode: 'annual',
  payAmount: 50_000_000,
  workDaysPerMonth: 21.75,
  workStart: '09:00',
  workEnd: '18:00',
  lunchEnabled: true,
  lunchStart: '12:00',
  lunchEnd: '13:00',
}

const hhmm = z.string().refine(isValidHHmm, { message: 'HH:mm 형식이어야 합니다' })

export const SettingsSchema = z
  .object({
    payMode: z.enum(['annual', 'monthly', 'hourly']),
    payAmount: z.number().finite().positive(),
    workDaysPerMonth: z.number().finite().positive().max(31),
    workStart: hhmm,
    workEnd: hhmm,
    lunchEnabled: z.boolean(),
    lunchStart: hhmm,
    lunchEnd: hhmm,
  })
  .superRefine((s, ctx) => {
    const shiftMin = durationMinutes(parseHHmm(s.workStart), parseHHmm(s.workEnd))
    if (shiftMin === 0) {
      ctx.addIssue({
        code: 'custom',
        path: ['workEnd'],
        message: '출근 시각과 퇴근 시각이 같을 수 없습니다',
      })
      return
    }
    if (!s.lunchEnabled) return

    const lunchMin = durationMinutes(parseHHmm(s.lunchStart), parseHHmm(s.lunchEnd))
    if (lunchMin === 0) {
      ctx.addIssue({
        code: 'custom',
        path: ['lunchEnd'],
        message: '점심 시작과 끝이 같을 수 없습니다',
      })
      return
    }

    // 근무 시작을 원점으로 옮긴 상대 좌표. 야간근무에서도 그대로 성립한다.
    const lunchOffset = durationMinutes(parseHHmm(s.workStart), parseHHmm(s.lunchStart))
    if (lunchOffset + lunchMin > shiftMin) {
      ctx.addIssue({
        code: 'custom',
        path: ['lunchStart'],
        message: '점심시간은 근무시간 안에 있어야 합니다',
      })
      return
    }
    if (lunchMin >= shiftMin) {
      ctx.addIssue({
        code: 'custom',
        path: ['lunchEnd'],
        message: '점심시간이 근무시간 전체를 덮을 수 없습니다',
      })
    }
  })

export function loadSettings(): { settings: Settings; hasStored: boolean } {
  if (typeof window === 'undefined') {
    return { settings: DEFAULT_SETTINGS, hasStored: false }
  }
  try {
    const raw = window.localStorage.getItem(STORAGE_KEY)
    if (!raw) return { settings: DEFAULT_SETTINGS, hasStored: false }
    const parsed = SettingsSchema.safeParse(JSON.parse(raw))
    if (!parsed.success) return { settings: DEFAULT_SETTINGS, hasStored: false }
    return { settings: parsed.data, hasStored: true }
  } catch {
    return { settings: DEFAULT_SETTINGS, hasStored: false }
  }
}

export function saveSettings(s: Settings): void {
  if (typeof window === 'undefined') return
  try {
    window.localStorage.setItem(STORAGE_KEY, JSON.stringify(s))
  } catch {
    // 사파리 프라이빗 모드 등 저장이 막힌 환경. 앱은 계속 돌아야 한다.
  }
}
```

`lunchOffset + lunchMin > shiftMin` 한 줄이 "점심이 근무구간 밖" / "점심이 퇴근을 넘어감"을 동시에 잡는다.

> zod 버전 주의: `ctx.addIssue({ code: 'custom' })`가 타입 오류를 내면 `z.ZodIssueCode.custom`으로 바꾼다 (zod 3 스타일).

- [ ] **Step 4: 통과 확인**

Run: `npm test` → Expected: PASS

- [ ] **Step 5: 검증**

Run: `npx tsc --noEmit` → Expected: 오류 없음

---

### Task 4: lib/shift.ts — 근무 시프트 해석

**Files:**
- Create: `lib/shift.ts`
- Test: `lib/__tests__/shift.test.ts`

**Interfaces:**
- Consumes: `lib/time.ts`, `lib/settings.ts`의 `Settings`
- Produces:
  - `interface Shift { startMs: number; endMs: number; lunchStartMs: number | null; lunchEndMs: number | null; paidMs: number }`
  - `resolveShift(s: Settings, now: number): Shift`
  - `paidMsBetween(shift: Shift, from: number, to: number): number`

**핵심 규칙:** 어제·오늘·내일 세 후보를 만들어 (1) `now`를 포함하는 시프트가 있으면 그것, (2) 없으면 `now`에서 시간적으로 **가장 가까운** 시프트를 고른다.

"가장 가까운" 규칙이 필요한 이유: 퇴근 직후 19:00에 "지금 속한 시프트"를 찾으면 아무것도 안 걸려서 내일 시프트로 넘어가고, 그러면 적립액이 0으로 리셋된다. 가장 가까운 시프트를 고르면 오늘 시프트(1시간 전 종료)가 잡혀 금액이 유지된다. 야간근무에서도 07:00(방금 06:00에 끝남)은 어제 시작한 시프트를, 20:00은 오늘 22:00 시작 시프트를 고르게 되어 자연스럽다.

- [ ] **Step 1: 실패하는 테스트 작성**

`lib/__tests__/shift.test.ts`:

```ts
import { describe, it, expect } from 'vitest'
import { resolveShift, paidMsBetween } from '@/lib/shift'
import { DEFAULT_SETTINGS, type Settings } from '@/lib/settings'

const at = (h: number, m = 0, s = 0) => new Date(2026, 8, 22, h, m, s, 0).getTime()
const DAY = 86_400_000
const HOUR = 3_600_000

const night: Settings = {
  ...DEFAULT_SETTINGS,
  workStart: '22:00',
  workEnd: '06:00',
  lunchEnabled: true,
  lunchStart: '01:00',
  lunchEnd: '02:00',
}

describe('resolveShift — 주간근무 (9 to 6)', () => {
  it('근무 중이면 오늘 시프트를 고른다', () => {
    const shift = resolveShift(DEFAULT_SETTINGS, at(14))
    expect(shift.startMs).toBe(at(9))
    expect(shift.endMs).toBe(at(18))
    expect(shift.lunchStartMs).toBe(at(12))
    expect(shift.lunchEndMs).toBe(at(13))
  })

  it('유급 시간에서 점심을 뺀다', () => {
    expect(resolveShift(DEFAULT_SETTINGS, at(14)).paidMs).toBe(8 * HOUR)
  })

  it('점심을 끄면 근무구간 전체가 유급이다', () => {
    const shift = resolveShift({ ...DEFAULT_SETTINGS, lunchEnabled: false }, at(14))
    expect(shift.paidMs).toBe(9 * HOUR)
    expect(shift.lunchStartMs).toBeNull()
    expect(shift.lunchEndMs).toBeNull()
  })

  it('출근 전이면 오늘 시프트를 고른다', () => {
    expect(resolveShift(DEFAULT_SETTINGS, at(7)).startMs).toBe(at(9))
  })

  it('퇴근 후에도 오늘 시프트를 유지한다 (내일로 넘어가지 않는다)', () => {
    expect(resolveShift(DEFAULT_SETTINGS, at(19)).startMs).toBe(at(9))
  })

  it('한밤중 02:00에는 다가오는 오늘 시프트를 고른다', () => {
    expect(resolveShift(DEFAULT_SETTINGS, at(2)).startMs).toBe(at(9))
  })

  it('출근 시각 정각은 근무 중으로 본다', () => {
    expect(resolveShift(DEFAULT_SETTINGS, at(9)).startMs).toBe(at(9))
  })
})

describe('resolveShift — 야간근무', () => {
  it('자정 직후에는 어제 시작한 시프트를 고른다', () => {
    const shift = resolveShift(night, at(3))
    expect(shift.startMs).toBe(at(22) - DAY)
    expect(shift.endMs).toBe(at(6))
  })

  it('자정을 넘긴 점심 시각도 같은 시프트 안에 놓는다', () => {
    const shift = resolveShift(night, at(3))
    expect(shift.lunchStartMs).toBe(at(1))
    expect(shift.lunchEndMs).toBe(at(2))
  })

  it('저녁에는 오늘 시작하는 시프트를 고른다', () => {
    const shift = resolveShift(night, at(23))
    expect(shift.startMs).toBe(at(22))
    expect(shift.endMs).toBe(at(6) + DAY)
  })

  it('아침 07:00에는 방금 끝난 시프트를 유지한다', () => {
    expect(resolveShift(night, at(7)).startMs).toBe(at(22) - DAY)
  })

  it('야간근무 유급 시간은 8시간에서 점심 1시간을 뺀 7시간이다', () => {
    expect(resolveShift(night, at(3)).paidMs).toBe(7 * HOUR)
  })
})

describe('paidMsBetween', () => {
  const shift = resolveShift(DEFAULT_SETTINGS, at(14))

  it('점심 전 구간을 그대로 센다', () => {
    expect(paidMsBetween(shift, at(9), at(11))).toBe(2 * HOUR)
  })

  it('점심을 가로지르면 점심만큼 뺀다', () => {
    expect(paidMsBetween(shift, at(9), at(14))).toBe(4 * HOUR)
  })

  it('점심 구간 안에서는 0이다', () => {
    expect(paidMsBetween(shift, at(12, 10), at(12, 50))).toBe(0)
  })

  it('시프트 시작 이전은 잘라낸다', () => {
    expect(paidMsBetween(shift, at(7), at(10))).toBe(1 * HOUR)
  })

  it('시프트 종료 이후는 잘라낸다', () => {
    expect(paidMsBetween(shift, at(17), at(23))).toBe(1 * HOUR)
  })

  it('역순 구간은 0이다', () => {
    expect(paidMsBetween(shift, at(14), at(10))).toBe(0)
  })

  it('전체 구간은 paidMs와 같다', () => {
    expect(paidMsBetween(shift, shift.startMs, shift.endMs)).toBe(shift.paidMs)
  })
})
```

- [ ] **Step 2: 실패 확인**

Run: `npm test` → Expected: FAIL — `Failed to resolve import "@/lib/shift"`

- [ ] **Step 3: 구현**

`lib/shift.ts`:

```ts
import { MS_PER_MINUTE, MS_PER_DAY, parseHHmm, durationMinutes, startOfLocalDay } from '@/lib/time'
import type { Settings } from '@/lib/settings'

export interface Shift {
  startMs: number
  endMs: number
  lunchStartMs: number | null
  lunchEndMs: number | null
  paidMs: number
}

function buildShift(s: Settings, dayStart: number): Shift {
  const workStartMin = parseHHmm(s.workStart)
  const shiftMin = durationMinutes(workStartMin, parseHHmm(s.workEnd))

  const startMs = dayStart + workStartMin * MS_PER_MINUTE
  const endMs = startMs + shiftMin * MS_PER_MINUTE

  let lunchStartMs: number | null = null
  let lunchEndMs: number | null = null
  let lunchMs = 0

  if (s.lunchEnabled) {
    const lunchStartMin = parseHHmm(s.lunchStart)
    const offsetMin = durationMinutes(workStartMin, lunchStartMin)
    const lunchMin = durationMinutes(lunchStartMin, parseHHmm(s.lunchEnd))
    lunchStartMs = startMs + offsetMin * MS_PER_MINUTE
    lunchEndMs = lunchStartMs + lunchMin * MS_PER_MINUTE
    lunchMs = lunchMin * MS_PER_MINUTE
  }

  return { startMs, endMs, lunchStartMs, lunchEndMs, paidMs: endMs - startMs - lunchMs }
}

function distanceTo(shift: Shift, now: number): number {
  if (now < shift.startMs) return shift.startMs - now
  if (now >= shift.endMs) return now - shift.endMs
  return 0
}

export function resolveShift(s: Settings, now: number): Shift {
  const today = startOfLocalDay(now)
  const candidates = [
    buildShift(s, today - MS_PER_DAY),
    buildShift(s, today),
    buildShift(s, today + MS_PER_DAY),
  ]

  return candidates.reduce((best, c) =>
    distanceTo(c, now) < distanceTo(best, now) ? c : best,
  )
}

export function paidMsBetween(shift: Shift, from: number, to: number): number {
  const lo = Math.max(from, shift.startMs)
  const hi = Math.min(to, shift.endMs)
  if (hi <= lo) return 0

  let paid = hi - lo
  if (shift.lunchStartMs !== null && shift.lunchEndMs !== null) {
    const overlap = Math.min(hi, shift.lunchEndMs) - Math.max(lo, shift.lunchStartMs)
    if (overlap > 0) paid -= overlap
  }
  return paid
}
```

`reduce`는 동점일 때 먼저 온 후보(과거 쪽)를 유지한다. 진행 중인 시프트는 거리 0이라 항상 이긴다.

`startOfLocalDay` ± 하루로 후보를 만들므로 서머타임 지역에서도 각 후보가 해당 날짜의 실제 자정에 맞춰진다.

- [ ] **Step 4: 통과 확인**

Run: `npm test` → Expected: PASS

- [ ] **Step 5: 검증**

Run: `npx tsc --noEmit` → Expected: 오류 없음

---

### Task 5: lib/salary.ts — 적립액 계산

**Files:**
- Create: `lib/salary.ts`
- Test: `lib/__tests__/salary.test.ts`

**Interfaces:**
- Consumes: `lib/shift.ts`의 `Shift`, `resolveShift`, `paidMsBetween`; `lib/settings.ts`의 `Settings`
- Produces:
  - `type Phase = 'before' | 'working' | 'lunch' | 'after'`
  - `interface Earnings { phase; earned; perSecond; progress; elapsedPaidMs; totalPaidMs; msUntilStart; msUntilEnd; remainingAmount; dailyTotal; shift }` — 모두 number, `phase`는 `Phase`, `shift`는 `Shift`
  - `perSecondRate(s: Settings, shift: Shift): number`
  - `computeEarnings(s: Settings, now: number): Earnings`

`shift`를 결과에 포함시키는 이유: 화면에서 시계 호를 그릴 때 같은 시프트가 필요한데, 두 번 계산해 서로 어긋나게 두지 않기 위해서다.

- [ ] **Step 1: 실패하는 테스트 작성**

`lib/__tests__/salary.test.ts`:

```ts
import { describe, it, expect } from 'vitest'
import { computeEarnings, perSecondRate } from '@/lib/salary'
import { resolveShift } from '@/lib/shift'
import { DEFAULT_SETTINGS, type Settings } from '@/lib/settings'

const at = (h: number, m = 0, s = 0) => new Date(2026, 8, 22, h, m, s, 0).getTime()
const HOUR = 3_600_000

// 기본 설정 09-18, 점심 12-13 → 하루 유급 8시간
const PAID_SECONDS_PER_DAY = 8 * 3600

describe('perSecondRate', () => {
  it('연봉을 12개월 × 근무일수 × 유급초로 나눈다', () => {
    const shift = resolveShift(DEFAULT_SETTINGS, at(14))
    const expected = 50_000_000 / (12 * 21.75 * PAID_SECONDS_PER_DAY)
    expect(perSecondRate(DEFAULT_SETTINGS, shift)).toBeCloseTo(expected, 10)
  })

  it('월급은 12를 곱하지 않는다', () => {
    const s: Settings = { ...DEFAULT_SETTINGS, payMode: 'monthly', payAmount: 4_000_000 }
    const shift = resolveShift(s, at(14))
    expect(perSecondRate(s, shift)).toBeCloseTo(4_000_000 / (21.75 * PAID_SECONDS_PER_DAY), 10)
  })

  it('시급은 근무일수를 무시하고 3600으로 나눈다', () => {
    const s: Settings = {
      ...DEFAULT_SETTINGS,
      payMode: 'hourly',
      payAmount: 12_000,
      workDaysPerMonth: 1,
    }
    const shift = resolveShift(s, at(14))
    expect(perSecondRate(s, shift)).toBeCloseTo(12_000 / 3600, 10)
  })
})

describe('computeEarnings — phase 판정', () => {
  it('출근 전은 before', () => {
    expect(computeEarnings(DEFAULT_SETTINGS, at(7)).phase).toBe('before')
  })

  it('근무 중은 working', () => {
    expect(computeEarnings(DEFAULT_SETTINGS, at(10)).phase).toBe('working')
  })

  it('점심 중은 lunch', () => {
    expect(computeEarnings(DEFAULT_SETTINGS, at(12, 30)).phase).toBe('lunch')
  })

  it('퇴근 후는 after', () => {
    expect(computeEarnings(DEFAULT_SETTINGS, at(19)).phase).toBe('after')
  })

  it('점심 시작 정각은 lunch', () => {
    expect(computeEarnings(DEFAULT_SETTINGS, at(12)).phase).toBe('lunch')
  })

  it('점심 종료 정각은 working', () => {
    expect(computeEarnings(DEFAULT_SETTINGS, at(13)).phase).toBe('working')
  })
})

describe('computeEarnings — 금액', () => {
  it('출근 전에는 0원이다', () => {
    const e = computeEarnings(DEFAULT_SETTINGS, at(7))
    expect(e.earned).toBe(0)
    expect(e.perSecond).toBe(0)
    expect(e.progress).toBe(0)
  })

  it('근무 1시간 뒤에는 1시간치가 쌓인다', () => {
    const e = computeEarnings(DEFAULT_SETTINGS, at(10))
    const rate = perSecondRate(DEFAULT_SETTINGS, resolveShift(DEFAULT_SETTINGS, at(10)))
    expect(e.earned).toBeCloseTo(rate * 3600, 6)
  })

  it('점심 중에는 금액이 고정되고 초당 적립이 0이다', () => {
    const noon = computeEarnings(DEFAULT_SETTINGS, at(12))
    const mid = computeEarnings(DEFAULT_SETTINGS, at(12, 30))
    expect(mid.earned).toBeCloseTo(noon.earned, 6)
    expect(mid.perSecond).toBe(0)
  })

  it('점심이 끝나면 다시 쌓기 시작한다', () => {
    const before = computeEarnings(DEFAULT_SETTINGS, at(12, 59, 59))
    const after = computeEarnings(DEFAULT_SETTINGS, at(13, 0, 1))
    expect(after.earned).toBeGreaterThan(before.earned)
  })

  it('퇴근 후 금액은 하루치 총액과 같다', () => {
    const e = computeEarnings(DEFAULT_SETTINGS, at(19))
    expect(e.earned).toBeCloseTo(e.dailyTotal, 6)
    expect(e.remainingAmount).toBe(0)
  })

  it('하루치 총액은 연봉을 연간 근무일수로 나눈 값이다', () => {
    const e = computeEarnings(DEFAULT_SETTINGS, at(19))
    expect(e.dailyTotal).toBeCloseTo(50_000_000 / (12 * 21.75), 6)
  })
})

describe('computeEarnings — 진행률과 남은 시간', () => {
  it('출근 정각의 진행률은 0이다', () => {
    expect(computeEarnings(DEFAULT_SETTINGS, at(9)).progress).toBe(0)
  })

  it('유급 절반 지점의 진행률은 0.5다', () => {
    // 09-12(3h) + 13-14(1h) = 4h = 유급 8h의 절반
    expect(computeEarnings(DEFAULT_SETTINGS, at(14)).progress).toBeCloseTo(0.5, 10)
  })

  it('퇴근 후 진행률은 1이다', () => {
    expect(computeEarnings(DEFAULT_SETTINGS, at(19)).progress).toBe(1)
  })

  it('출근 전에는 msUntilStart가 출근까지 남은 시간이다', () => {
    const e = computeEarnings(DEFAULT_SETTINGS, at(7))
    expect(e.msUntilStart).toBe(2 * HOUR)
    expect(e.msUntilEnd).toBe(11 * HOUR)
  })

  it('근무 중에는 msUntilStart가 0이다', () => {
    const e = computeEarnings(DEFAULT_SETTINGS, at(10))
    expect(e.msUntilStart).toBe(0)
    expect(e.msUntilEnd).toBe(8 * HOUR)
  })

  it('퇴근 후에는 msUntilEnd가 0이다', () => {
    expect(computeEarnings(DEFAULT_SETTINGS, at(19)).msUntilEnd).toBe(0)
  })
})

describe('computeEarnings — 야간근무', () => {
  const night: Settings = {
    ...DEFAULT_SETTINGS,
    workStart: '22:00',
    workEnd: '06:00',
    lunchEnabled: false,
  }

  it('자정을 넘겨도 근무 중으로 본다', () => {
    expect(computeEarnings(night, at(3)).phase).toBe('working')
  })

  it('자정 이후 경과분이 이어서 쌓인다', () => {
    expect(computeEarnings(night, at(3)).progress).toBeCloseTo(5 / 8, 10)
  })
})
```

- [ ] **Step 2: 실패 확인**

Run: `npm test` → Expected: FAIL — `Failed to resolve import "@/lib/salary"`

- [ ] **Step 3: 구현**

`lib/salary.ts`:

```ts
import type { Settings } from '@/lib/settings'
import { resolveShift, paidMsBetween, type Shift } from '@/lib/shift'

export type Phase = 'before' | 'working' | 'lunch' | 'after'

export interface Earnings {
  phase: Phase
  earned: number
  perSecond: number
  progress: number
  elapsedPaidMs: number
  totalPaidMs: number
  msUntilStart: number
  msUntilEnd: number
  remainingAmount: number
  dailyTotal: number
  shift: Shift
}

export function perSecondRate(s: Settings, shift: Shift): number {
  if (s.payMode === 'hourly') return s.payAmount / 3600

  const paidSecondsPerDay = shift.paidMs / 1000
  if (paidSecondsPerDay <= 0) return 0

  const monthly = s.payMode === 'annual' ? s.payAmount / 12 : s.payAmount
  return monthly / (s.workDaysPerMonth * paidSecondsPerDay)
}

function phaseOf(shift: Shift, now: number): Phase {
  if (now < shift.startMs) return 'before'
  if (now >= shift.endMs) return 'after'
  if (
    shift.lunchStartMs !== null &&
    shift.lunchEndMs !== null &&
    now >= shift.lunchStartMs &&
    now < shift.lunchEndMs
  ) {
    return 'lunch'
  }
  return 'working'
}

export function computeEarnings(s: Settings, now: number): Earnings {
  const shift = resolveShift(s, now)
  const phase = phaseOf(shift, now)
  const rate = perSecondRate(s, shift)

  const totalPaidMs = shift.paidMs
  const elapsedPaidMs = paidMsBetween(shift, shift.startMs, now)
  const dailyTotal = (rate * totalPaidMs) / 1000
  const earned = (rate * elapsedPaidMs) / 1000

  return {
    phase,
    earned,
    perSecond: phase === 'working' ? rate : 0,
    progress: totalPaidMs === 0 ? 0 : elapsedPaidMs / totalPaidMs,
    elapsedPaidMs,
    totalPaidMs,
    msUntilStart: Math.max(0, shift.startMs - now),
    msUntilEnd: Math.max(0, shift.endMs - now),
    remainingAmount: Math.max(0, dailyTotal - earned),
    dailyTotal,
    shift,
  }
}
```

- [ ] **Step 4: 통과 확인**

Run: `npm test` → Expected: PASS

- [ ] **Step 5: 검증**

Run: `npx tsc --noEmit` → Expected: 오류 없음

---

### Task 6: lib/clock.ts — 바늘 각도와 문자판 호

**Files:**
- Create: `lib/clock.ts`
- Test: `lib/__tests__/clock.test.ts`

**Interfaces:**
- Consumes: `lib/shift.ts`의 `Shift`
- Produces:
  - `interface HandAngles { hour: number; minute: number; second: number }`
  - `handAngles(now: number): HandAngles` — 12시 방향 0도, 시계방향 증가
  - `dialAngle(now: number): number` — 그 시각의 12시간 문자판 위치 (0~360)
  - `interface Arc { startDeg: number; sweepDeg: number }`
  - `arcBetween(fromMs: number, toMs: number): Arc` — sweep은 360으로 clamp
  - `polarPoint(cx: number, cy: number, r: number, deg: number): { x: number; y: number }`
  - `arcPath(cx: number, cy: number, r: number, arc: Arc): string` — SVG path `d`
  - `shiftArcs(shift: Shift, now: number): { work: Arc; progress: Arc; lunch: Arc | null }`

- [ ] **Step 1: 실패하는 테스트 작성**

`lib/__tests__/clock.test.ts`:

```ts
import { describe, it, expect } from 'vitest'
import { handAngles, dialAngle, arcBetween, polarPoint, shiftArcs } from '@/lib/clock'
import { resolveShift } from '@/lib/shift'
import { DEFAULT_SETTINGS } from '@/lib/settings'

const at = (h: number, m = 0, s = 0, ms = 0) =>
  new Date(2026, 8, 22, h, m, s, ms).getTime()

describe('handAngles', () => {
  it('정오에는 세 바늘이 모두 12시를 가리킨다', () => {
    const a = handAngles(at(12))
    expect(a.hour).toBeCloseTo(0, 10)
    expect(a.minute).toBeCloseTo(0, 10)
    expect(a.second).toBeCloseTo(0, 10)
  })

  it('09:00에 시침은 270도다', () => {
    expect(handAngles(at(9)).hour).toBeCloseTo(270, 10)
  })

  it('18:00에 시침은 180도다', () => {
    expect(handAngles(at(18)).hour).toBeCloseTo(180, 10)
  })

  it('초침이 밀리초 단위로 연속 이동한다', () => {
    expect(handAngles(at(0, 0, 0, 500)).second).toBeCloseTo(3, 10)
    expect(handAngles(at(0, 0, 30, 0)).second).toBeCloseTo(180, 10)
    expect(handAngles(at(0, 0, 59, 999)).second).toBeCloseTo(359.994, 6)
  })

  it('분침도 초를 반영해 연속 이동한다', () => {
    expect(handAngles(at(0, 30, 30)).minute).toBeCloseTo(183, 10)
  })

  it('시침도 분을 반영해 연속 이동한다', () => {
    expect(handAngles(at(1, 30)).hour).toBeCloseTo(45, 10)
  })
})

describe('dialAngle', () => {
  it('오전과 오후가 같은 문자판 위치를 갖는다', () => {
    expect(dialAngle(at(9))).toBeCloseTo(dialAngle(at(21)), 10)
  })
})

describe('arcBetween', () => {
  it('9시에서 18시까지는 270도 방향에서 270도만큼 돈다', () => {
    const arc = arcBetween(at(9), at(18))
    expect(arc.startDeg).toBeCloseTo(270, 10)
    expect(arc.sweepDeg).toBeCloseTo(270, 10)
  })

  it('12시간을 넘으면 360도로 자른다', () => {
    expect(arcBetween(at(0), at(0) + 20 * 3_600_000).sweepDeg).toBe(360)
  })

  it('역순이면 0도다', () => {
    expect(arcBetween(at(18), at(9)).sweepDeg).toBe(0)
  })
})

describe('polarPoint', () => {
  it('0도는 12시 방향이다', () => {
    const p = polarPoint(100, 100, 50, 0)
    expect(p.x).toBeCloseTo(100, 10)
    expect(p.y).toBeCloseTo(50, 10)
  })

  it('90도는 3시 방향이다', () => {
    const p = polarPoint(100, 100, 50, 90)
    expect(p.x).toBeCloseTo(150, 10)
    expect(p.y).toBeCloseTo(100, 10)
  })

  it('180도는 6시 방향이다', () => {
    const p = polarPoint(100, 100, 50, 180)
    expect(p.x).toBeCloseTo(100, 10)
    expect(p.y).toBeCloseTo(150, 10)
  })
})

describe('shiftArcs', () => {
  const shift = resolveShift(DEFAULT_SETTINGS, at(14))

  it('근무 호는 출근에서 시작해 근무시간만큼 돈다', () => {
    const { work } = shiftArcs(shift, at(14))
    expect(work.startDeg).toBeCloseTo(270, 10)
    expect(work.sweepDeg).toBeCloseTo(270, 10)
  })

  it('진행 호는 현재 시각까지만 찬다', () => {
    const { progress } = shiftArcs(shift, at(14))
    expect(progress.startDeg).toBeCloseTo(270, 10)
    expect(progress.sweepDeg).toBeCloseTo(150, 10)
  })

  it('출근 전 진행 호는 0이다', () => {
    expect(shiftArcs(shift, at(7)).progress.sweepDeg).toBe(0)
  })

  it('퇴근 후 진행 호는 근무 호와 같다', () => {
    const { work, progress } = shiftArcs(shift, at(19))
    expect(progress.sweepDeg).toBeCloseTo(work.sweepDeg, 10)
  })

  it('점심 호는 12시 위치에서 30도만큼이다', () => {
    const { lunch } = shiftArcs(shift, at(14))
    expect(lunch).not.toBeNull()
    expect(lunch!.startDeg).toBeCloseTo(0, 10)
    expect(lunch!.sweepDeg).toBeCloseTo(30, 10)
  })

  it('점심을 끄면 점심 호가 없다', () => {
    const noLunch = resolveShift({ ...DEFAULT_SETTINGS, lunchEnabled: false }, at(14))
    expect(shiftArcs(noLunch, at(14)).lunch).toBeNull()
  })
})
```

- [ ] **Step 2: 실패 확인**

Run: `npm test` → Expected: FAIL — `Failed to resolve import "@/lib/clock"`

- [ ] **Step 3: 구현**

`lib/clock.ts`:

```ts
import type { Shift } from '@/lib/shift'

const MS_PER_12H = 43_200_000

export interface HandAngles {
  hour: number
  minute: number
  second: number
}

export interface Arc {
  startDeg: number
  sweepDeg: number
}

/** 그 시각의 자정 이후 경과 밀리초. 로컬 시각 기준. */
function msIntoDay(now: number): number {
  const d = new Date(now)
  return (
    d.getHours() * 3_600_000 +
    d.getMinutes() * 60_000 +
    d.getSeconds() * 1000 +
    d.getMilliseconds()
  )
}

export function handAngles(now: number): HandAngles {
  const t = msIntoDay(now)
  return {
    second: ((t % 60_000) / 60_000) * 360,
    minute: ((t % 3_600_000) / 3_600_000) * 360,
    hour: ((t % MS_PER_12H) / MS_PER_12H) * 360,
  }
}

export function dialAngle(now: number): number {
  return ((msIntoDay(now) % MS_PER_12H) / MS_PER_12H) * 360
}

export function arcBetween(fromMs: number, toMs: number): Arc {
  const span = Math.max(0, toMs - fromMs)
  return {
    startDeg: dialAngle(fromMs),
    sweepDeg: Math.min(360, (span / MS_PER_12H) * 360),
  }
}

export function polarPoint(cx: number, cy: number, r: number, deg: number) {
  const rad = ((deg - 90) * Math.PI) / 180
  return { x: cx + r * Math.cos(rad), y: cy + r * Math.sin(rad) }
}

export function arcPath(cx: number, cy: number, r: number, arc: Arc): string {
  // 360도는 단일 호로 그릴 수 없다. 살짝 줄여 닫힌 것처럼 보이게 한다.
  const sweep = Math.min(arc.sweepDeg, 359.999)
  const start = polarPoint(cx, cy, r, arc.startDeg)
  const end = polarPoint(cx, cy, r, arc.startDeg + sweep)
  const largeArc = sweep > 180 ? 1 : 0
  return `M ${start.x} ${start.y} A ${r} ${r} 0 ${largeArc} 1 ${end.x} ${end.y}`
}

export function shiftArcs(shift: Shift, now: number) {
  const clampedNow = Math.min(Math.max(now, shift.startMs), shift.endMs)
  return {
    work: arcBetween(shift.startMs, shift.endMs),
    progress: arcBetween(shift.startMs, clampedNow),
    lunch:
      shift.lunchStartMs !== null && shift.lunchEndMs !== null
        ? arcBetween(shift.lunchStartMs, shift.lunchEndMs)
        : null,
  }
}
```

- [ ] **Step 4: 통과 확인**

Run: `npm test` → Expected: PASS

- [ ] **Step 5: 검증**

Run: `npx tsc --noEmit` → Expected: 오류 없음

---

### Task 7: lib/format.ts — 표시 문자열

**Files:**
- Create: `lib/format.ts`
- Test: `lib/__tests__/format.test.ts`

**Interfaces:**
- Consumes: 없음
- Produces:
  - `formatWon(n: number): string` — `'₩47,382'`
  - `formatPerSecond(n: number): string` — 100 미만이면 소수 1자리, 아니면 정수
  - `formatDuration(ms: number): string` — `'04:12:33'`

- [ ] **Step 1: 실패하는 테스트 작성**

`lib/__tests__/format.test.ts`:

```ts
import { describe, it, expect } from 'vitest'
import { formatWon, formatPerSecond, formatDuration } from '@/lib/format'

describe('formatWon', () => {
  it('원화 기호와 천 단위 구분을 붙인다', () => {
    expect(formatWon(47382)).toBe('₩47,382')
  })

  it('소수점을 버린다', () => {
    expect(formatWon(47382.9)).toBe('₩47,382')
  })

  it('0을 처리한다', () => {
    expect(formatWon(0)).toBe('₩0')
  })
})

describe('formatPerSecond', () => {
  it('작은 값은 소수 1자리로 보여준다', () => {
    expect(formatPerSecond(3.333)).toBe('3.3')
  })

  it('100 이상은 정수로 보여준다', () => {
    expect(formatPerSecond(532.7)).toBe('533')
  })

  it('0을 처리한다', () => {
    expect(formatPerSecond(0)).toBe('0.0')
  })
})

describe('formatDuration', () => {
  it('HH:MM:SS로 만든다', () => {
    expect(formatDuration(15_153_000)).toBe('04:12:33')
  })

  it('0을 처리한다', () => {
    expect(formatDuration(0)).toBe('00:00:00')
  })

  it('한 자리 수를 0으로 채운다', () => {
    expect(formatDuration(61_000)).toBe('00:01:01')
  })

  it('24시간을 넘어도 시간 자리를 늘린다', () => {
    expect(formatDuration(90_000_000)).toBe('25:00:00')
  })

  it('음수는 0으로 본다', () => {
    expect(formatDuration(-5000)).toBe('00:00:00')
  })
})
```

- [ ] **Step 2: 실패 확인**

Run: `npm test` → Expected: FAIL

- [ ] **Step 3: 구현**

`lib/format.ts`:

```ts
const wonFormatter = new Intl.NumberFormat('ko-KR', {
  style: 'currency',
  currency: 'KRW',
  maximumFractionDigits: 0,
})

export function formatWon(n: number): string {
  return wonFormatter.format(Math.floor(n))
}

export function formatPerSecond(n: number): string {
  return n < 100 ? n.toFixed(1) : String(Math.round(n))
}

export function formatDuration(ms: number): string {
  const total = Math.max(0, Math.floor(ms / 1000))
  const h = Math.floor(total / 3600)
  const m = Math.floor((total % 3600) / 60)
  const s = total % 60
  const pad = (v: number) => String(v).padStart(2, '0')
  return `${pad(h)}:${pad(m)}:${pad(s)}`
}
```

> `formatWon` 테스트가 실패하면 Node의 ICU가 `'₩47,382'`가 아닌 다른 형태(공백 포함 등)를 내는 경우다. 실제 출력을 확인하고 테스트 기대값을 그에 맞추되, 기호·천단위 구분이 나오는지는 반드시 확인할 것.

- [ ] **Step 4: 통과 확인**

Run: `npm test` → Expected: PASS

- [ ] **Step 5: 검증**

Run: `npx tsc --noEmit` → Expected: 오류 없음

---

### Task 8: hooks — 시간 틱과 설정 상태

**Files:**
- Create: `hooks/useNow.ts`, `hooks/useSettings.ts`

**Interfaces:**
- Consumes: `lib/settings.ts`
- Produces:
  - `useNow(): number` — 현재 epoch ms. rAF마다 갱신
  - `useSettings(): { settings: Settings; isLoaded: boolean; hasStored: boolean; update(s: Settings): void }`

테스트 없음 — 브라우저 API에 직접 묶인 얇은 어댑터이고, 계산은 전부 `lib/`에서 이미 검증했다. 대신 Task 12의 수동 검증으로 확인한다.

- [ ] **Step 1: useNow 작성**

`hooks/useNow.ts`:

```ts
'use client'

import { useEffect, useState } from 'react'

/**
 * 앱의 유일한 시간 소스.
 * rAF로 매 프레임 갱신하므로 초침이 끊기지 않고 흐른다.
 * prefers-reduced-motion이면 1초 간격으로 낮춘다.
 */
export function useNow(): number {
  const [now, setNow] = useState(() => Date.now())

  useEffect(() => {
    const reduced =
      typeof window !== 'undefined' &&
      window.matchMedia('(prefers-reduced-motion: reduce)').matches

    if (reduced) {
      const id = window.setInterval(() => setNow(Date.now()), 1000)
      return () => window.clearInterval(id)
    }

    let frame = 0
    const tick = () => {
      setNow(Date.now())
      frame = window.requestAnimationFrame(tick)
    }
    frame = window.requestAnimationFrame(tick)
    return () => window.cancelAnimationFrame(frame)
  }, [])

  return now
}
```

- [ ] **Step 2: useSettings 작성**

`hooks/useSettings.ts`:

```ts
'use client'

import { useCallback, useEffect, useState } from 'react'
import { DEFAULT_SETTINGS, loadSettings, saveSettings, type Settings } from '@/lib/settings'

export function useSettings() {
  const [settings, setSettings] = useState<Settings>(DEFAULT_SETTINGS)
  const [isLoaded, setIsLoaded] = useState(false)
  const [hasStored, setHasStored] = useState(false)

  // 서버 렌더와 어긋나지 않도록 마운트 이후에만 읽는다.
  useEffect(() => {
    const { settings: stored, hasStored } = loadSettings()
    setSettings(stored)
    setHasStored(hasStored)
    setIsLoaded(true)
  }, [])

  const update = useCallback((next: Settings) => {
    setSettings(next)
    saveSettings(next)
    setHasStored(true)
  }, [])

  return { settings, isLoaded, hasStored, update }
}
```

- [ ] **Step 3: 검증**

Run: `npx tsc --noEmit` → Expected: 오류 없음
Run: `npm test` → Expected: 기존 테스트 전부 통과

---

### Task 9: components/AnalogClock.tsx

**Files:**
- Create: `components/AnalogClock.tsx`

**Interfaces:**
- Consumes: `lib/clock.ts`의 `handAngles`, `arcPath`, `shiftArcs`; `lib/shift.ts`의 `Shift`
- Produces: `<AnalogClock now={number} shift={Shift} />`

- [ ] **Step 1: 컴포넌트 작성**

`components/AnalogClock.tsx`:

```tsx
'use client'

import { handAngles, arcPath, shiftArcs } from '@/lib/clock'
import type { Shift } from '@/lib/shift'

const CX = 100
const CY = 100
const RING_R = 92
const DIAL_R = 76

interface Props {
  now: number
  shift: Shift
}

export function AnalogClock({ now, shift }: Props) {
  const hands = handAngles(now)
  const arcs = shiftArcs(shift, now)

  return (
    <svg viewBox="0 0 200 200" className="h-64 w-64 sm:h-80 sm:w-80" role="img" aria-label="현재 시각과 근무 진행률">
      {/* 근무 구간 링 (배경) */}
      <path
        d={arcPath(CX, CY, RING_R, arcs.work)}
        fill="none"
        stroke="currentColor"
        strokeWidth={6}
        strokeLinecap="round"
        className="text-slate-200 dark:text-slate-700"
      />

      {/* 진행 링 */}
      <path
        d={arcPath(CX, CY, RING_R, arcs.progress)}
        fill="none"
        stroke="currentColor"
        strokeWidth={6}
        strokeLinecap="round"
        className="text-emerald-500"
      />

      {/* 점심 구간은 링에서 비운다 */}
      {arcs.lunch && (
        <path
          d={arcPath(CX, CY, RING_R, arcs.lunch)}
          fill="none"
          stroke="currentColor"
          strokeWidth={8}
          className="text-white dark:text-slate-900"
        />
      )}

      {/* 문자판 눈금 */}
      {Array.from({ length: 12 }, (_, i) => {
        const deg = i * 30
        const rad = ((deg - 90) * Math.PI) / 180
        const outer = DIAL_R
        const inner = DIAL_R - (i % 3 === 0 ? 10 : 5)
        return (
          <line
            key={i}
            x1={CX + outer * Math.cos(rad)}
            y1={CY + outer * Math.sin(rad)}
            x2={CX + inner * Math.cos(rad)}
            y2={CY + inner * Math.sin(rad)}
            stroke="currentColor"
            strokeWidth={i % 3 === 0 ? 3 : 1.5}
            strokeLinecap="round"
            className="text-slate-400 dark:text-slate-500"
          />
        )
      })}

      {/* 바늘. transition을 걸면 360→0 전환에서 역회전한다 — 절대 걸지 말 것. */}
      <g className="text-slate-800 dark:text-slate-100">
        <line
          x1={CX} y1={CY} x2={CX} y2={CY - 42}
          stroke="currentColor" strokeWidth={5} strokeLinecap="round"
          transform={`rotate(${hands.hour} ${CX} ${CY})`}
        />
        <line
          x1={CX} y1={CY} x2={CX} y2={CY - 60}
          stroke="currentColor" strokeWidth={3} strokeLinecap="round"
          transform={`rotate(${hands.minute} ${CX} ${CY})`}
        />
      </g>
      <line
        x1={CX} y1={CY + 12} x2={CX} y2={CY - 68}
        stroke="currentColor" strokeWidth={1.5} strokeLinecap="round"
        className="text-emerald-500"
        transform={`rotate(${hands.second} ${CX} ${CY})`}
      />
      <circle cx={CX} cy={CY} r={4} className="fill-emerald-500" />
    </svg>
  )
}
```

- [ ] **Step 2: 검증**

Run: `npx tsc --noEmit` → Expected: 오류 없음

---

### Task 10: components/EarningsDisplay.tsx, StatusLine.tsx

**Files:**
- Create: `components/EarningsDisplay.tsx`, `components/StatusLine.tsx`

**Interfaces:**
- Consumes: `lib/salary.ts`의 `Earnings`; `lib/format.ts`
- Produces: `<EarningsDisplay earnings={Earnings} />`, `<StatusLine earnings={Earnings} />`

- [ ] **Step 1: EarningsDisplay 작성**

`components/EarningsDisplay.tsx`:

```tsx
'use client'

import type { Earnings } from '@/lib/salary'
import { formatWon, formatPerSecond } from '@/lib/format'

export function EarningsDisplay({ earnings }: { earnings: Earnings }) {
  return (
    <div className="text-center">
      <p className="text-sm text-slate-500 dark:text-slate-400">오늘 벌어들인 금액</p>
      <p className="mt-1 font-mono text-5xl font-bold tabular-nums tracking-tight sm:text-6xl">
        {formatWon(earnings.earned)}
      </p>
      <p className="mt-2 font-mono text-sm tabular-nums text-emerald-600 dark:text-emerald-400">
        {earnings.perSecond > 0 ? `+${formatPerSecond(earnings.perSecond)} / 초` : ' '}
      </p>
    </div>
  )
}
```

`tabular-nums`가 핵심이다. 없으면 숫자가 바뀔 때마다 폭이 달라져 금액이 덜덜 떨린다.

- [ ] **Step 2: StatusLine 작성**

`components/StatusLine.tsx`:

```tsx
'use client'

import type { Earnings } from '@/lib/salary'
import { formatWon, formatDuration } from '@/lib/format'

export function StatusLine({ earnings }: { earnings: Earnings }) {
  const text = (() => {
    switch (earnings.phase) {
      case 'before':
        return `출근까지 ${formatDuration(earnings.msUntilStart)}`
      case 'lunch':
        return `점심시간 · 재개까지 ${formatDuration(
          (earnings.shift.lunchEndMs ?? 0) - (earnings.shift.startMs + earnings.elapsedPaidMs),
        )}`
      case 'after':
        return '오늘 근무 종료'
      case 'working':
        return `퇴근까지 ${formatDuration(earnings.msUntilEnd)}`
    }
  })()

  return (
    <p className="text-center font-mono text-sm tabular-nums text-slate-600 dark:text-slate-300">
      {text}
      {earnings.phase !== 'after' && (
        <span className="text-slate-400 dark:text-slate-500">
          {' · 남은 '}
          {formatWon(earnings.remainingAmount)}
        </span>
      )}
    </p>
  )
}
```

> `lunch` 문구의 남은 시간 계산이 어색하면 `Earnings`에 `msUntilLunchEnd`를 추가하는 편이 낫다. Task 5의 `computeEarnings`에 다음을 더하고 타입에도 추가한다:
> ```ts
> msUntilLunchEnd: phase === 'lunch' && shift.lunchEndMs !== null ? shift.lunchEndMs - now : 0,
> ```
> 그리고 여기서는 `formatDuration(earnings.msUntilLunchEnd)`를 쓴다. **이 방식을 택할 것.**

- [ ] **Step 3: 검증**

Run: `npx tsc --noEmit` → Expected: 오류 없음
Run: `npm test` → Expected: 전부 통과

---

### Task 11: components/SettingsPanel.tsx

**Files:**
- Create: `components/SettingsPanel.tsx`

**Interfaces:**
- Consumes: `lib/settings.ts`의 `Settings`, `SettingsSchema`
- Produces: `<SettingsPanel open={boolean} settings={Settings} onSave={(s: Settings) => void} onClose={() => void} />`

폼은 로컬 초안 상태를 들고 있다가 저장할 때만 검증해서 올려보낸다. 검증 실패 시 에러 메시지를 보여주고 닫지 않는다.

- [ ] **Step 1: 컴포넌트 작성**

`components/SettingsPanel.tsx`:

```tsx
'use client'

import { useEffect, useState } from 'react'
import { SettingsSchema, type PayMode, type Settings } from '@/lib/settings'

interface Props {
  open: boolean
  settings: Settings
  onSave: (s: Settings) => void
  onClose: () => void
}

const PAY_LABELS: Record<PayMode, string> = {
  annual: '연봉',
  monthly: '월급',
  hourly: '시급',
}

export function SettingsPanel({ open, settings, onSave, onClose }: Props) {
  const [draft, setDraft] = useState<Settings>(settings)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    if (open) {
      setDraft(settings)
      setError(null)
    }
  }, [open, settings])

  if (!open) return null

  const set = <K extends keyof Settings>(key: K, value: Settings[K]) =>
    setDraft((d) => ({ ...d, [key]: value }))

  const handleSave = () => {
    const parsed = SettingsSchema.safeParse(draft)
    if (!parsed.success) {
      setError(parsed.error.issues[0]?.message ?? '설정값을 확인해 주세요')
      return
    }
    onSave(parsed.data)
    onClose()
  }

  const field = 'w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm dark:border-slate-600 dark:bg-slate-800'

  return (
    <div className="fixed inset-0 z-10 flex items-center justify-center bg-black/40 p-4">
      <div className="w-full max-w-md rounded-2xl bg-white p-6 shadow-xl dark:bg-slate-900">
        <h2 className="text-lg font-semibold">설정</h2>

        <div className="mt-4 space-y-4">
          <div>
            <label className="text-sm text-slate-600 dark:text-slate-300">급여</label>
            <div className="mt-1 flex gap-2">
              <select
                className={field + ' w-24'}
                value={draft.payMode}
                onChange={(e) => set('payMode', e.target.value as PayMode)}
              >
                {(Object.keys(PAY_LABELS) as PayMode[]).map((m) => (
                  <option key={m} value={m}>{PAY_LABELS[m]}</option>
                ))}
              </select>
              <input
                type="number"
                className={field}
                value={draft.payAmount}
                onChange={(e) => set('payAmount', Number(e.target.value))}
              />
            </div>
          </div>

          {draft.payMode !== 'hourly' && (
            <div>
              <label className="text-sm text-slate-600 dark:text-slate-300">월 평균 근무일수</label>
              <input
                type="number"
                step="0.25"
                className={field + ' mt-1'}
                value={draft.workDaysPerMonth}
                onChange={(e) => set('workDaysPerMonth', Number(e.target.value))}
              />
            </div>
          )}

          <div className="grid grid-cols-2 gap-2">
            <div>
              <label className="text-sm text-slate-600 dark:text-slate-300">출근</label>
              <input type="time" className={field + ' mt-1'} value={draft.workStart}
                onChange={(e) => set('workStart', e.target.value)} />
            </div>
            <div>
              <label className="text-sm text-slate-600 dark:text-slate-300">퇴근</label>
              <input type="time" className={field + ' mt-1'} value={draft.workEnd}
                onChange={(e) => set('workEnd', e.target.value)} />
            </div>
          </div>

          <div>
            <label className="flex items-center gap-2 text-sm text-slate-600 dark:text-slate-300">
              <input type="checkbox" checked={draft.lunchEnabled}
                onChange={(e) => set('lunchEnabled', e.target.checked)} />
              점심시간 제외
            </label>
            {draft.lunchEnabled && (
              <div className="mt-2 grid grid-cols-2 gap-2">
                <input type="time" className={field} value={draft.lunchStart}
                  onChange={(e) => set('lunchStart', e.target.value)} />
                <input type="time" className={field} value={draft.lunchEnd}
                  onChange={(e) => set('lunchEnd', e.target.value)} />
              </div>
            )}
          </div>
        </div>

        {error && <p className="mt-4 text-sm text-red-600">{error}</p>}

        <div className="mt-6 flex justify-end gap-2">
          <button onClick={onClose} className="rounded-lg px-4 py-2 text-sm text-slate-600 dark:text-slate-300">
            취소
          </button>
          <button onClick={handleSave} className="rounded-lg bg-emerald-600 px-4 py-2 text-sm font-medium text-white">
            저장
          </button>
        </div>
      </div>
    </div>
  )
}
```

> `<input type="time">`는 브라우저에 따라 `"09:00"` 외에 `"09:00:00"`을 줄 수 있다. 저장 시 `SettingsSchema`가 거부하면 `e.target.value.slice(0, 5)`로 잘라서 넣도록 고친다.

- [ ] **Step 2: 검증**

Run: `npx tsc --noEmit` → Expected: 오류 없음

---

### Task 12: app/page.tsx 조립과 수동 검증

**Files:**
- Modify: `app/page.tsx` (스캐폴드 내용을 전부 교체)
- Modify: `app/layout.tsx` (metadata title)

**Interfaces:**
- Consumes: 앞선 모든 것
- Produces: 동작하는 앱

- [ ] **Step 1: page.tsx 작성**

`app/page.tsx`:

```tsx
'use client'

import { useState } from 'react'
import { useNow } from '@/hooks/useNow'
import { useSettings } from '@/hooks/useSettings'
import { computeEarnings } from '@/lib/salary'
import { AnalogClock } from '@/components/AnalogClock'
import { EarningsDisplay } from '@/components/EarningsDisplay'
import { StatusLine } from '@/components/StatusLine'
import { SettingsPanel } from '@/components/SettingsPanel'

export default function Home() {
  const now = useNow()
  const { settings, isLoaded, hasStored, update } = useSettings()
  const [panelOpen, setPanelOpen] = useState(false)

  const earnings = computeEarnings(settings, now)
  // 저장된 설정이 없는 첫 방문이면 설정부터 연다.
  const showPanel = panelOpen || (isLoaded && !hasStored)

  return (
    <main className="flex min-h-screen flex-col items-center justify-center gap-8 bg-white p-6 text-slate-900 dark:bg-slate-900 dark:text-slate-100">
      <button
        onClick={() => setPanelOpen(true)}
        aria-label="설정 열기"
        className="absolute right-4 top-4 rounded-lg p-2 text-slate-400 hover:text-slate-600 dark:hover:text-slate-200"
      >
        ⚙
      </button>

      <AnalogClock now={now} shift={earnings.shift} />
      <EarningsDisplay earnings={earnings} />
      <StatusLine earnings={earnings} />

      <SettingsPanel
        open={showPanel}
        settings={settings}
        onSave={update}
        onClose={() => setPanelOpen(false)}
      />
    </main>
  )
}
```

- [ ] **Step 2: layout.tsx의 metadata 수정**

```ts
export const metadata: Metadata = {
  title: 'SalaryClock',
  description: '지금 이 순간 내 월급이 얼마나 쌓였는지 보여주는 시계',
}
```

- [ ] **Step 3: 빌드와 테스트**

Run: `npm test` → Expected: 전부 통과
Run: `npx tsc --noEmit` → Expected: 오류 없음
Run: `npm run build` → Expected: 빌드 성공

- [ ] **Step 4: 수동 검증**

`npm run dev`로 띄우고 브라우저에서 확인한다:

1. 첫 방문에 설정 패널이 먼저 열린다
2. 기본값이 연봉 50,000,000 / 09:00–18:00 / 점심 12:00–13:00이다
3. 저장하면 패널이 닫히고 시계가 보인다
4. **초침이 1초마다 끊기지 않고 부드럽게 흐른다** ← 이 앱의 핵심
5. 금액이 초 단위로 올라간다 (근무시간 중일 때)
6. 새로고침해도 설정이 유지된다
7. 출근 시각을 지금보다 뒤로 바꾸면 "출근까지 …"가 뜨고 금액이 0이다
8. 퇴근 시각을 지금보다 앞으로 바꾸면 "오늘 근무 종료"가 뜨고 금액이 하루치로 고정된다
9. 점심시간을 지금 시각에 걸치게 바꾸면 금액이 멈추고 "점심시간"이 뜬다
10. 시계 링에서 점심 구간이 비어 있다

각 항목을 확인하고, 어긋나는 것이 있으면 고친 뒤 다시 확인한다.

---

## Self-Review

**스펙 커버리지:**

| 스펙 항목 | 구현 위치 |
|---|---|
| 3. 화면 레이아웃 | Task 9, 10, 12 |
| 4.1 설정 입력 | Task 3 (스키마), Task 11 (폼) |
| 4.2 초당임금 3종 | Task 5 `perSecondRate` |
| 4.3 출력 필드 | Task 5 `Earnings` |
| 4.4 phase별 동작 | Task 5 `phaseOf`, Task 10 `StatusLine` |
| 5.1 스위프 각도 | Task 6 `handAngles`, Task 8 `useNow` |
| 5.2 transition 금지 | Task 9 주석 + Global Constraints |
| 5.3 진행 링 | Task 6 `shiftArcs`, Task 9 |
| 6. 파일 구조 | File Structure 표 |
| 7. localStorage | Task 3 `loadSettings`/`saveSettings`, Task 8 |
| 8. 엣지 케이스 | Task 4 (야간·자정), Task 3 (검증), Task 6 (12시간 clamp), Task 8 (reduced-motion) |
| 10. 테스트 전략 | Task 2–7의 TDD 사이클 |

**스펙과 달라진 점 (의도적):**

- `Earnings`에 `dailyTotal`과 `shift`를 추가했다. 화면에서 시프트를 두 번 계산해 어긋나는 것을 막기 위해서다.
- 시프트 선택을 "지금 속한 시프트"에서 **"가장 가까운 시프트"**로 바꿨다. 스펙대로 하면 퇴근 직후 적립액이 0으로 리셋된다.
- Task 10에 `msUntilLunchEnd` 추가 지시를 넣었다.

**미해결로 남긴 것:** 없음. 모든 스텝에 실행 가능한 코드가 들어 있다.
