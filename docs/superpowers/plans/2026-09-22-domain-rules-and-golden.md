# 도메인 규칙 수정과 골든 파일 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 웹앱의 휴무일·자정 버그 두 개를 `lib/`에서 고치고, 맥 앱이 읽을 골든 파일과 팔레트를 `shared/golden/`으로 내보낸다.

**Architecture:** 규칙의 단일 출처는 `lib/`다. `resolveShift`를 "가장 가까운 시프트"에서 "진행 중 → 오늘 끝난 → 오늘 시작할" 3단계로 바꾸고, `isDayOff`를 새로 만들어 `computeEarnings`가 휴무일이면 `phase: 'dayoff'`와 `shift: null`을 돌려주게 한다. 그 다음 웹 구현에서 기대값을 뽑아 골든 파일로 커밋한다.

**Tech Stack:** TypeScript, vitest, Next.js 16 (App Router), Tailwind v4, zod 4

**Spec:** `docs/superpowers/specs/2026-09-22-macos-menubar-design.md`

## Global Constraints

- **이 계획은 맥 앱을 만들지 않는다.** 스펙 12장의 1~2번만 담는다. 3~7번(Swift 포팅, 메뉴바, 팝오버, 설정 창)은 별도 계획이다.
- **`lib/` 아래 모든 함수는 순수 함수.** `Date.now()`를 직접 호출하지 않고 현재 시각(epoch ms)을 인자로 받는다.
- **테스트는 타임존 독립적으로 작성한다.** 기대값을 하드코딩한 UTC 오프셋으로 만들지 말고 `new Date(2026, 8, 22, 9, 0, 0).getTime()`처럼 로컬 시각 생성자로 만든다. (월은 0-based: 8 = 9월)
- **서버 코드 금지.** Server Action, Route Handler, `next/headers`를 쓰지 않는다. 페이지는 `'use client'`.
- **`react-hooks/set-state-in-effect` 린트 규칙이 켜져 있다.** `useEffect` 안에서 `setState`를 부르면 에러다.
- **UI 문구는 한국어.**
- **새 의존성을 추가하지 않는다.** 골든 생성에는 vitest에 딸려 오는 `vite-node`를 쓴다.
- 테스트 실행: `npm test` (= `vitest run`)
- 타입 검사: `npx tsc --noEmit`
- 린트: `npm run lint`
- 커밋 메시지는 한국어, `feat:` / `fix:` / `chore:` 접두사를 쓴다.
- 커밋 말미에 `Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>`를 붙인다.

---

## File Structure

| 파일 | 이 계획에서의 책임 |
|---|---|
| `lib/shift.ts` | `resolveShift`를 3단계 규칙으로 교체 |
| `lib/calendar.ts` | `isDayOff(overrides, dateMs)` 추가 |
| `lib/salary.ts` | `Phase`에 `'dayoff'` 추가, `Earnings.shift`를 `Shift \| null`로, 휴무일 분기 |
| `lib/clock.ts` | `shiftArcs`가 `null` 시프트를 받으면 빈 호를 돌려줌 |
| `components/clock/types.ts` | `ClockFaceProps.shift`를 `Shift \| null`로 |
| `components/AnalogClock.tsx` | `Props.shift`를 `Shift \| null`로 |
| `components/clock/CountdownFace.tsx` | `shift`를 직접 읽으므로 null 가드 |
| `components/clock/LevelFace.tsx` | 〃 |
| `components/clock/RingsFace.tsx` | 〃 |
| `components/StatusLine.tsx` | `'dayoff'` 분기 (switch 완전성) |
| `components/TimeDisplay.tsx` | 〃 |
| `app/page.tsx` | 휴무일이면 가리기 화면 강제, 가리기 토글 숨김 |
| `scripts/generate-golden.ts` | 웹 구현에서 골든 JSON을 뽑는 스크립트 |
| `scripts/extract-palette.ts` | 빌드된 CSS에서 색 토큰을 뽑는 스크립트 |
| `shared/golden/*.json` | 생성물. 맥 앱 계획이 읽는다 |
| `lib/__tests__/golden.test.ts` | 골든이 현재 구현과 일치하는지 확인 |

`isDayOff`를 `calendar.ts`에 두고 `Settings`가 아니라 `overrides` 배열을 받게 하는 이유: `calendar.ts`는 지금 `Settings`를 모르고, 의존 방향(`calendar → holidays`)을 유지하려면 계속 몰라야 한다.

---

### Task 1: 의존성 설치와 기준선 확인

**Files:**
- Modify: 없음

**Interfaces:**
- Consumes: 없음
- Produces: 통과하는 테스트 212개 — 이후 모든 Task의 기준선

`node_modules`가 비어 있다. 아무것도 고치기 전에 현재 상태가 초록인지 확인한다.

- [ ] **Step 1: 의존성 설치**

```bash
npm ci
```

- [ ] **Step 2: 테스트가 전부 통과하는지 확인**

```bash
npm test
```

Expected: 212개 통과, 실패 0

통과하지 않으면 여기서 멈추고 보고한다. 기준선이 빨간 상태로 시작하면 이후 실패가 내 변경 탓인지 알 수 없다.

- [ ] **Step 3: 타입과 린트도 확인**

```bash
npx tsc --noEmit && npm run lint
```

Expected: 둘 다 오류 없음

---

### Task 2: `resolveShift`를 3단계 규칙으로 바꾼다

**Files:**
- Modify: `lib/shift.ts:44-56` (`distanceTo`와 `resolveShift`)
- Test: `lib/__tests__/shift.test.ts`

**Interfaces:**
- Consumes: `buildShift(s: Settings, dayStart: number): Shift` (같은 파일, 변경 없음)
- Produces: `resolveShift(s: Settings, now: number): Shift` — 시그니처 그대로. 동작만 바뀐다

기존 테스트 12개는 전부 그대로 통과한다. 버그 구간이 자정~01:30로 좁아서 기존 한밤중 케이스(02:00)가 그 밖에 있기 때문이다. 그래서 **실패하는 테스트를 먼저 추가**한다.

- [ ] **Step 1: 실패하는 테스트를 추가한다**

`lib/__tests__/shift.test.ts`의 `describe('resolveShift — 주간근무 (9 to 6)')` 블록 맨 끝, `'출근 시각 정각은 근무 중으로 본다'` 다음에 넣는다:

```ts
  it('자정 직후에는 어제 시프트를 버리고 오늘 시프트를 고른다', () => {
    expect(resolveShift(DEFAULT_SETTINGS, at(0, 30)).startMs).toBe(at(9))
  })

  it('자정 직전에는 아직 오늘 시프트를 유지한다', () => {
    expect(resolveShift(DEFAULT_SETTINGS, at(23, 59)).startMs).toBe(at(9))
  })
```

- [ ] **Step 2: 테스트를 돌려 첫 번째가 실패하는지 확인**

```bash
npx vitest run lib/__tests__/shift.test.ts
```

Expected: `'자정 직후에는 어제 시프트를 버리고 오늘 시프트를 고른다'`가 FAIL.
받은 값은 `at(9) - 86400000`(어제 09:00)이다 — 자정 30분 뒤에는 어제 퇴근(18:00, 6시간 30분 전)이 오늘 출근(09:00, 8시간 30분 뒤)보다 가까워서 어제 시프트가 잡힌다.

`'자정 직전'`은 PASS한다 (이미 오늘 시프트).

- [ ] **Step 3: `resolveShift`를 3단계로 다시 쓴다**

`lib/shift.ts`에서 `distanceTo` 함수와 `resolveShift` 함수를 통째로 아래로 교체한다:

```ts
/** 그 시각을 품고 있으면 true. 시작은 포함, 끝은 제외. */
function contains(shift: Shift, now: number): boolean {
  return now >= shift.startMs && now < shift.endMs
}

/**
 * 화면에 보여줄 시프트.
 *
 *   1. now를 품는 시프트가 있으면        → 그것        (근무 중 · 점심)
 *   2. 없고, 오늘 안에 끝난 것이 있으면  → 그것        (퇴근 후 — 총액 유지)
 *   3. 그 외                              → 오늘 시작할 시프트 (출근 전 — 0원)
 *
 * 2단계가 없으면 퇴근 직후 19:00에 아무것도 안 걸려 적립액이 0으로 리셋된다.
 * "오늘 안에 끝났는가"로 보는 것이 핵심이다. 예전 규칙은 "시간적으로 가장
 * 가까운 시프트"였는데, 자정을 넘겨도 어제 시프트가 계속 가장 가까워서
 * 어제 총액이 그대로 남았다.
 *
 * 자정을 특별히 다루지 않는데도 초기화가 나오고, 야간근무(22:00–06:00)는
 * 1단계에 걸려 자정에 끊기지 않는다.
 */
export function resolveShift(s: Settings, now: number): Shift {
  const today = startOfLocalDay(now)
  const yesterday = buildShift(s, today - MS_PER_DAY)
  const todayShift = buildShift(s, today)
  const tomorrow = buildShift(s, today + MS_PER_DAY)

  for (const c of [yesterday, todayShift, tomorrow]) {
    if (contains(c, now)) return c
  }

  const ended = [yesterday, todayShift]
    .filter((c) => c.endMs <= now && c.endMs > today)
    .sort((a, b) => b.endMs - a.endMs)
  if (ended.length > 0) return ended[0]

  return todayShift
}
```

- [ ] **Step 4: 테스트를 돌려 전부 통과하는지 확인**

```bash
npx vitest run lib/__tests__/shift.test.ts
```

Expected: 14개 전부 PASS (기존 12 + 새 2)

야간근무 4개가 특히 중요하다. `at(3)`·`at(23)`은 1단계, `at(7)`은 2단계(어제 22:00 시작해 오늘 06:00에 끝난 시프트)에 걸린다.

- [ ] **Step 5: 전체 테스트와 타입 확인**

```bash
npm test && npx tsc --noEmit
```

Expected: 214개 통과, 타입 오류 없음

- [ ] **Step 6: 커밋**

```bash
git add lib/shift.ts lib/__tests__/shift.test.ts
git commit -m "$(cat <<'EOF'
fix: 자정을 넘기면 어제 총액이 남던 것을 고친다

resolveShift가 "가장 가까운 시프트"를 고르는 바람에 00:00~01:30 사이에
어제 퇴근이 오늘 출근보다 가까워 어제 총액이 그대로 표시됐다.

"진행 중 → 오늘 안에 끝난 → 오늘 시작할" 3단계로 바꾼다. 자정을 특별
취급하지 않는데도 초기화가 나오고, 야간근무는 1단계에 걸려 자정에
끊기지 않는다.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: `isDayOff`를 만든다

**Files:**
- Modify: `lib/calendar.ts` (파일 끝에 추가)
- Test: `lib/__tests__/calendar.test.ts`

**Interfaces:**
- Consumes: `isDefaultOff(year, month, day): boolean`, `dateKey(year, month, day): string` (같은 파일)
- Produces: `isDayOff(overrides: readonly string[], dateMs: number): boolean`

`Settings`가 아니라 `overrides` 배열을 받는다. `calendar.ts`는 `Settings`를 모르고, 의존 방향을 지키려면 계속 몰라야 한다.

2026-09-22는 화요일(평일), 09-26은 토요일, 09-24·09-25는 추석 연휴다.

- [ ] **Step 1: 실패하는 테스트를 추가한다**

`lib/__tests__/calendar.test.ts` 맨 끝에 붙인다:

```ts
describe('isDayOff', () => {
  const day = (y: number, m: number, d: number) => new Date(y, m, d, 12, 0, 0).getTime()

  it('평일은 쉬는 날이 아니다', () => {
    expect(isDayOff([], day(2026, 8, 22))).toBe(false)
  })

  it('토요일은 쉬는 날이다', () => {
    expect(isDayOff([], day(2026, 8, 26))).toBe(true)
  })

  it('일요일은 쉬는 날이다', () => {
    expect(isDayOff([], day(2026, 8, 27))).toBe(true)
  })

  it('평일 공휴일은 쉬는 날이다', () => {
    expect(isDayOff([], day(2026, 8, 24))).toBe(true)
  })

  it('override로 평일을 쉬는 날로 만든다', () => {
    expect(isDayOff(['2026-09-22'], day(2026, 8, 22))).toBe(true)
  })

  it('override로 공휴일에 출근한 것으로 만든다', () => {
    expect(isDayOff(['2026-09-24'], day(2026, 8, 24))).toBe(false)
  })

  it('하루 중 어느 시각이든 결과가 같다', () => {
    expect(isDayOff([], new Date(2026, 8, 26, 0, 0, 0).getTime())).toBe(true)
    expect(isDayOff([], new Date(2026, 8, 26, 23, 59, 59).getTime())).toBe(true)
  })
})
```

파일 맨 위 import에 `isDayOff`를 추가한다.

- [ ] **Step 2: 테스트를 돌려 실패하는지 확인**

```bash
npx vitest run lib/__tests__/calendar.test.ts
```

Expected: FAIL — `isDayOff is not a function` 또는 import 오류

- [ ] **Step 3: `isDayOff`를 구현한다**

`lib/calendar.ts` 맨 끝에 붙인다:

```ts
/**
 * 그 날짜가 쉬는 날인가.
 *
 * 기본값은 주말·공휴일이고, overrides에 든 날짜는 기본값을 뒤집는다.
 * workDaysMode와 무관하게 반영한다 — 달력에서 "이날은 쉰다"고 찍은 건
 * 근무일수를 어떤 방식으로 세는지와 별개로 참인 사실이다.
 */
export function isDayOff(overrides: readonly string[], dateMs: number): boolean {
  const d = new Date(dateMs)
  const year = d.getFullYear()
  const month = d.getMonth()
  const day = d.getDate()

  const defaultOff = isDefaultOff(year, month, day)
  return overrides.includes(dateKey(year, month, day)) ? !defaultOff : defaultOff
}
```

- [ ] **Step 4: 테스트를 돌려 통과하는지 확인**

```bash
npx vitest run lib/__tests__/calendar.test.ts && npm test
```

Expected: 새 7개 포함 221개 통과

- [ ] **Step 5: 커밋**

```bash
git add lib/calendar.ts lib/__tests__/calendar.test.ts
git commit -m "$(cat <<'EOF'
feat: 그 날이 쉬는 날인지 판정하는 isDayOff

주말·공휴일을 기본으로 보고 dayOverrides로 뒤집는다. Settings가 아니라
overrides 배열을 받아 calendar.ts가 Settings를 모르는 상태를 유지한다.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: `computeEarnings`에 휴무일 분기를 넣는다

**Files:**
- Modify: `lib/salary.ts` (`Phase`, `Earnings.shift`, `computeEarnings`)
- Test: `lib/__tests__/salary.test.ts`

**Interfaces:**
- Consumes: `isDayOff(overrides, dateMs)` (Task 3), `resolveShift(s, now)` (Task 2)
- Produces:
  - `type Phase = 'before' | 'working' | 'lunch' | 'after' | 'dayoff'`
  - `Earnings.shift: Shift | null` — 휴무일이면 `null`
  - 휴무일이면 `earned: 0`, `perSecond: 0`, `progress: 0`, `dailyTotal: 0`

**판정 대상은 `now`가 아니라 `shift.startMs`다.** `now`로 판정하면 야간근무가 자정을 넘는 순간 다음 날이 공휴일인지에 따라 근무 중에 0이 된다.

- [ ] **Step 1: 실패하는 테스트를 추가한다**

`lib/__tests__/salary.test.ts` 맨 끝에 붙인다:

```ts
describe('computeEarnings — 휴무일', () => {
  // 2026-09-26은 토요일, 09-24는 추석 연휴(목), 09-22는 화요일
  const sat = (h: number) => new Date(2026, 8, 26, h, 0, 0).getTime()
  const holiday = (h: number) => new Date(2026, 8, 24, h, 0, 0).getTime()

  it('토요일 근무시간 한복판에도 phase가 dayoff다', () => {
    expect(computeEarnings(DEFAULT_SETTINGS, sat(14)).phase).toBe('dayoff')
  })

  it('토요일에는 금액이 쌓이지 않는다', () => {
    const e = computeEarnings(DEFAULT_SETTINGS, sat(14))
    expect(e.earned).toBe(0)
    expect(e.perSecond).toBe(0)
    expect(e.progress).toBe(0)
    expect(e.dailyTotal).toBe(0)
  })

  it('휴무일에는 시계에 그릴 시프트가 없다', () => {
    expect(computeEarnings(DEFAULT_SETTINGS, sat(14)).shift).toBeNull()
  })

  it('평일 공휴일도 휴무일이다', () => {
    expect(computeEarnings(DEFAULT_SETTINGS, holiday(14)).phase).toBe('dayoff')
  })

  it('override로 평일을 쉬게 만들 수 있다', () => {
    const s: Settings = { ...DEFAULT_SETTINGS, dayOverrides: ['2026-09-22'] }
    expect(computeEarnings(s, at(14)).phase).toBe('dayoff')
  })

  it('override로 공휴일에 출근하면 평소대로 쌓인다', () => {
    const s: Settings = { ...DEFAULT_SETTINGS, dayOverrides: ['2026-09-24'] }
    const e = computeEarnings(s, holiday(14))
    expect(e.phase).toBe('working')
    expect(e.earned).toBeGreaterThan(0)
  })

  it('평일에는 영향이 없다', () => {
    expect(computeEarnings(DEFAULT_SETTINGS, at(14)).phase).toBe('working')
  })
})

describe('computeEarnings — 자정 초기화', () => {
  it('자정 직후에는 금액이 0이고 출근 전이다', () => {
    const e = computeEarnings(DEFAULT_SETTINGS, at(0, 30))
    expect(e.phase).toBe('before')
    expect(e.earned).toBe(0)
  })

  it('자정 직전에는 아직 오늘 총액이 남아 있다', () => {
    const e = computeEarnings(DEFAULT_SETTINGS, at(23, 59))
    expect(e.phase).toBe('after')
    expect(e.earned).toBeGreaterThan(0)
  })
})
```

`at` 헬퍼는 이 파일에 이미 있다(`at(h, m = 0, s = 0)`). `Settings` 타입도 이미 import돼 있다.

- [ ] **Step 2: 테스트를 돌려 실패하는지 확인**

```bash
npx vitest run lib/__tests__/salary.test.ts
```

Expected: 휴무일 블록 6개가 FAIL. 토요일 14:00에 `phase`가 `'working'`으로 나온다 — 지금 `salary.ts`는 요일을 전혀 보지 않는다.

`'자정 초기화'` 블록 2개는 Task 2 덕에 이미 PASS한다.

- [ ] **Step 3: `Phase`와 `Earnings.shift` 타입을 고친다**

`lib/salary.ts`에서:

```ts
export type Phase = 'before' | 'working' | 'lunch' | 'after' | 'dayoff'
```

그리고 `Earnings` 인터페이스의 `shift` 필드:

```ts
  /** 이 계산에 쓰인 시프트. 휴무일이면 null — 시계에 그릴 근무 구간이 없다 */
  shift: Shift | null
```

- [ ] **Step 4: import를 추가한다**

`lib/salary.ts` 맨 위 import 블록에 붙인다:

```ts
import { isDayOff } from '@/lib/calendar'
```

- [ ] **Step 5: `computeEarnings`에 휴무일 분기를 넣는다**

`computeEarnings` 본문에서 `const shift = resolveShift(s, now)` 바로 아래에 넣는다:

```ts
  const workDaysForDay = effectiveWorkDays(s, now)

  // 판정은 now가 아니라 시프트 시작일 기준이다. now로 보면 야간근무가 자정을
  // 넘는 순간 다음 날이 공휴일인지에 따라 근무 중에 0이 되어버린다.
  if (isDayOff(s.dayOverrides, shift.startMs)) {
    return {
      phase: 'dayoff',
      earned: 0,
      perSecond: 0,
      progress: 0,
      elapsedPaidMs: 0,
      totalPaidMs: shift.paidMs,
      msUntilStart: 0,
      msUntilEnd: 0,
      msUntilLunchEnd: 0,
      remainingAmount: 0,
      dailyTotal: 0,
      workDays: workDaysForDay,
      deductionRate: deductionRateFor(s, monthlyGross(s, shift, workDaysForDay)),
      isNet: s.netPay,
      shift: null,
    }
  }
```

`workDays`와 `deductionRate`를 0으로 두지 않는 이유: 설정 화면이 "이번 달 20일", "공제율 12.8%"처럼 그 달의 정보를 보여주는데, 쉬는 날이라고 그게 사라지면 안 된다.

- [ ] **Step 6: 테스트를 돌려 통과하는지 확인**

```bash
npx vitest run lib/__tests__/salary.test.ts
```

Expected: 새 9개 포함 전부 PASS

- [ ] **Step 7: 타입 오류를 확인한다 (아직 고치지 않는다)**

```bash
npx tsc --noEmit
```

Expected: FAIL. `shift`가 `Shift | null`이 되면서 `app/page.tsx`, `components/AnalogClock.tsx`, `components/clock/*.tsx`, `components/StatusLine.tsx`, `components/TimeDisplay.tsx`에서 오류가 난다. **이건 예상된 결과다** — Task 5와 6에서 고친다.

오류 목록을 기록해두면 Task 5·6에서 빠뜨린 파일이 없는지 대조할 수 있다.

- [ ] **Step 8: 커밋**

`tsc`가 아직 빨갛지만 `lib/` 계층은 완결됐고 테스트는 통과한다. 여기서 끊어야 UI 변경과 도메인 변경이 섞이지 않는다.

```bash
git add lib/salary.ts lib/__tests__/salary.test.ts
git commit -m "$(cat <<'EOF'
fix: 주말·공휴일에도 돈이 쌓이던 것을 고친다

computeEarnings가 요일을 전혀 보지 않아 토요일에 열어도 09-18 시프트를
만들어 적립했다. phase에 dayoff를 추가하고 휴무일이면 금액 0, shift null을
돌려준다.

판정은 now가 아니라 시프트 시작일 기준이다. now로 보면 야간근무가 자정을
넘을 때 근무 중에 0이 된다.

UI 쪽 타입 오류는 다음 커밋에서 정리한다.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 5: 시계가 시프트 없는 상태를 그리게 한다

**Files:**
- Modify: `lib/clock.ts:71-81` (`shiftArcs`)
- Modify: `components/clock/types.ts`
- Modify: `components/AnalogClock.tsx`
- Modify: `components/clock/CountdownFace.tsx:20-21`
- Modify: `components/clock/LevelFace.tsx:25`
- Modify: `components/clock/RingsFace.tsx:24`
- Test: `lib/__tests__/clock.test.ts`

**Interfaces:**
- Consumes: `Earnings.shift: Shift | null` (Task 4)
- Produces: `shiftArcs(shift: Shift | null, now: number)` — `null`이면 `work`·`progress`가 `sweepDeg: 0`이고 `lunch`는 `null`

`arcPath`는 `sweepDeg <= 0`이면 빈 문자열을 돌려준다. 그래서 `shiftArcs`만 빈 호를 내주면 **얼굴 10종 중 7종은 코드를 안 고쳐도 아무것도 안 그린다.** `shift`를 직접 읽는 3종만 가드가 필요하다.

- [ ] **Step 1: 실패하는 테스트를 추가한다**

`lib/__tests__/clock.test.ts` 맨 끝에 붙인다:

```ts
describe('shiftArcs — 시프트 없음', () => {
  const now = new Date(2026, 8, 26, 14, 0, 0).getTime()

  it('근무 구간 호가 비어 있다', () => {
    expect(shiftArcs(null, now).work.sweepDeg).toBe(0)
  })

  it('진행 호가 비어 있다', () => {
    expect(shiftArcs(null, now).progress.sweepDeg).toBe(0)
  })

  it('점심 구간이 없다', () => {
    expect(shiftArcs(null, now).lunch).toBeNull()
  })

  it('빈 호는 그려지지 않는다', () => {
    expect(arcPath(100, 100, 92, shiftArcs(null, now).work)).toBe('')
  })
})
```

`shiftArcs`와 `arcPath`가 이 파일에 import돼 있는지 확인하고, 없으면 추가한다.

- [ ] **Step 2: 테스트를 돌려 실패하는지 확인**

```bash
npx vitest run lib/__tests__/clock.test.ts
```

Expected: FAIL — `null`을 넘기면 `Cannot read properties of null (reading 'startMs')`

- [ ] **Step 3: `shiftArcs`가 `null`을 받게 한다**

`lib/clock.ts`의 `shiftArcs`를 교체한다:

```ts
const EMPTY_ARC: Arc = { startDeg: 0, sweepDeg: 0 }

/**
 * 시프트를 문자판 위의 호 셋으로.
 *
 * 휴무일에는 시프트가 없다(null). 빈 호를 돌려주면 arcPath가 빈 d를 만들어
 * 얼굴들이 아무것도 그리지 않는다 — 얼굴마다 분기를 넣을 필요가 없다.
 */
export function shiftArcs(shift: Shift | null, now: number) {
  if (shift === null) {
    return { work: EMPTY_ARC, progress: EMPTY_ARC, lunch: null }
  }

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

- [ ] **Step 4: 테스트를 돌려 통과하는지 확인**

```bash
npx vitest run lib/__tests__/clock.test.ts
```

Expected: 새 4개 포함 전부 PASS

- [ ] **Step 5: 얼굴 props 타입을 넓힌다**

`components/clock/types.ts`:

```ts
export interface ClockFaceProps {
  now: number
  /** 휴무일이면 null. 근무 구간을 그리지 않는다 */
  shift: Shift | null
  /** 바깥에서 크기를 정한다. 페이스는 지름을 모른다 */
  className?: string
}
```

`components/AnalogClock.tsx`의 `Props`:

```ts
interface Props {
  now: number
  shift: Shift | null
  style: ClockStyle
  className?: string
}
```

- [ ] **Step 6: `shift`를 직접 읽는 얼굴 3종에 가드를 넣는다**

`components/clock/CountdownFace.tsx` — 20~21행을 교체한다:

```tsx
  const remaining =
    shift === null
      ? { startDeg: 0, sweepDeg: 0 }
      : arcBetween(Math.min(Math.max(now, shift.startMs), shift.endMs), shift.endMs)
```

`components/clock/LevelFace.tsx` — 25행을 교체한다:

```tsx
  const progress =
    shift === null || shift.paidMs === 0
      ? 0
      : paidMsBetween(shift, shift.startMs, now) / shift.paidMs
```

`components/clock/RingsFace.tsx` — 24행을 교체한다:

```tsx
  const progress =
    shift === null || shift.paidMs === 0
      ? 0
      : paidMsBetween(shift, shift.startMs, now) / shift.paidMs
```

`CountdownFace`에서 `clampedNow` 지역 변수가 더 이상 쓰이지 않으면 지운다. 린트가 잡아준다.

- [ ] **Step 7: 타입과 린트를 확인한다**

```bash
npx tsc --noEmit
```

Expected: `components/clock/*`와 `AnalogClock.tsx` 오류가 사라진다. `app/page.tsx`, `StatusLine.tsx`, `TimeDisplay.tsx` 오류는 남는다 — Task 6에서 고친다.

- [ ] **Step 8: 커밋**

```bash
git add lib/clock.ts lib/__tests__/clock.test.ts components/clock components/AnalogClock.tsx
git commit -m "$(cat <<'EOF'
feat: 시프트가 없는 날에는 진행 링을 그리지 않는다

shiftArcs가 null을 받으면 빈 호를 돌려준다. arcPath가 빈 d를 만들므로
얼굴 10종 중 7종은 그대로 두면 되고, shift를 직접 읽는 3종만 가드를
넣는다.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 6: 휴무일에는 웹앱이 시계로 보이게 한다

**Files:**
- Modify: `components/StatusLine.tsx:14-27` (phase switch)
- Modify: `components/TimeDisplay.tsx:17-30` (phase switch)
- Modify: `app/page.tsx:68-76` (가리기 버튼), `:90` (DateLine), `:100-106` (금액/상태줄)

**Interfaces:**
- Consumes: `Earnings.phase === 'dayoff'` (Task 4), `AnalogClock`의 `shift: Shift | null` (Task 5)
- Produces: 없음 — 이 계획의 마지막 UI 변경이다

휴무일 전용 문구를 만들지 않는다. **가리기 화면을 그대로 쓴다** — 날짜(크게) + 현재 시각 + 빈 상태줄이라, 그날 앱이 통째로 시계가 된다.

- [ ] **Step 1: `StatusLine`의 switch에 `dayoff`를 더한다**

`components/StatusLine.tsx`의 `primary` switch에 케이스를 추가한다. `case 'working':` 다음에:

```ts
      case 'dayoff':
        return ''
```

휴무일에는 `hidden`이 참이라 이 값이 화면에 나오지 않는다. switch 완전성 때문에 필요하다.

- [ ] **Step 2: `TimeDisplay`의 switch에 `dayoff`를 더한다**

`components/TimeDisplay.tsx`의 `remainingMs` switch에서 `case 'after':` 다음에:

```ts
      case 'dayoff':
        return null
```

쉬는 날에는 세어줄 남은 시간이 없다. `null`이면 자리만 차지하는 빈 줄이 된다.

- [ ] **Step 3: `page.tsx`에서 휴무일을 가리기 화면으로 묶는다**

`app/page.tsx`에서 `return (` 바로 위에 추가한다:

```tsx
  // 쉬는 날에는 가리기 화면을 그대로 쓴다. 날짜와 시각만 남아 앱이 시계가 된다.
  const isDayOff = earnings.phase === 'dayoff'
  const minimal = settings.hideAmount || isDayOff
```

그 다음 네 군데를 바꾼다.

가리기 버튼을 감싼다 (쉬는 날에는 가릴 금액이 없다):

```tsx
        {!isDayOff && (
          <button
            onClick={() => update({ ...settings, hideAmount: !settings.hideAmount })}
            aria-label={settings.hideAmount ? '금액 보이기' : '금액 가리기'}
            aria-pressed={settings.hideAmount}
            title={settings.hideAmount ? '금액 보이기' : '금액 가리기'}
            className={iconButton}
          >
            <EyeIcon off={settings.hideAmount} />
          </button>
        )}
```

`DateLine`의 prop:

```tsx
        minimal={minimal}
```

금액 블록:

```tsx
      {minimal ? (
        <TimeDisplay now={now} earnings={earnings} />
      ) : (
        <EarningsDisplay earnings={earnings} />
      )}
```

상태줄:

```tsx
      <StatusLine earnings={earnings} hidden={minimal} />
```

- [ ] **Step 4: 타입·린트·테스트를 전부 확인한다**

```bash
npx tsc --noEmit && npm run lint && npm test
```

Expected: 셋 다 통과. 타입 오류가 0이 되는 건 이번이 처음이다 (Task 4에서 일부러 빨갛게 뒀다).

- [ ] **Step 5: 프로덕션 빌드가 되는지 확인한다**

```bash
npm run build
```

Expected: 성공

- [ ] **Step 6: 실제 화면을 눈으로 확인한다**

```bash
npm run dev
```

브라우저에서 확인할 것:

1. 평일 오늘 — 평소대로 금액이 쌓이고 진행 링이 차 있다
2. 설정에서 근무일수를 `달력`으로 바꾸고 **오늘을 쉬는 날로 찍는다** → 금액 자리에 현재 시각이 들어가고, 진행 링이 사라지고, 상태줄이 비고, 가리기(눈) 버튼이 사라진다
3. 다시 근무일로 되돌린다 → 원래대로 돌아온다
4. 2번 상태에서 시계 얼굴을 10종 전부 넘겨본다 → 어느 얼굴에서도 진행 표시가 남아 있지 않다

확인 후 `Ctrl+C`로 끈다.

- [ ] **Step 7: 커밋**

```bash
git add app/page.tsx components/StatusLine.tsx components/TimeDisplay.tsx
git commit -m "$(cat <<'EOF'
feat: 쉬는 날에는 앱이 시계로 보인다

휴무일 전용 문구를 만들지 않고 가리기 화면을 그대로 쓴다. 날짜와 현재
시각만 남고 진행 링도 사라져 그날은 앱이 통째로 시계가 된다.

가릴 금액이 없으므로 그날은 가리기 토글을 숨긴다.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 7: 골든 파일을 뽑는다

**Files:**
- Create: `scripts/generate-golden.ts`
- Create: `shared/golden/earnings.json`, `shift.json`, `deductions.json`, `workdays.json` (생성물)
- Create: `lib/__tests__/golden.test.ts`
- Modify: `package.json` (scripts에 `golden` 추가)

**Interfaces:**
- Consumes: `computeEarnings`, `resolveShift`, `estimateDeductions`, `effectiveWorkDays`, `isDayOff`
- Produces: 맥 앱 계획이 읽을 JSON. 케이스 형식은 아래 `Case` 타입 그대로

**시각은 `[year, month, day, hour, minute, second]` 배열로 적는다.** (월은 0-based) epoch ms를 박으면 타임존 독립성이 깨진다. Swift 쪽은 `DateComponents`로 같은 방식으로 읽는다.

`vite-node`는 vitest에 딸려 오므로 새 의존성이 없고, `vitest.config.mts`의 `@` 별칭을 그대로 쓴다.

- [ ] **Step 1: 생성 스크립트를 쓴다**

`scripts/generate-golden.ts`:

```ts
/**
 * 맥 앱이 읽을 기대값을 웹 구현에서 뽑는다.
 *
 * 규칙의 단일 출처는 lib/다. 이 파일은 "Swift가 lib/와 같은 답을 내는가"를
 * 물을 재료를 만들 뿐, 정확성을 정의하지 않는다. 정확성은 각 모듈의
 * 유닛 테스트가 본다.
 *
 * 실행: npm run golden
 */
import { writeFileSync, mkdirSync } from 'node:fs'
import path from 'node:path'
import { DEFAULT_SETTINGS, type Settings } from '@/lib/settings'
import { computeEarnings } from '@/lib/salary'
import { resolveShift } from '@/lib/shift'
import { estimateDeductions } from '@/lib/deductions'
import { effectiveWorkDays } from '@/lib/workdays'
import { isDayOff } from '@/lib/calendar'

/** [year, month(0-based), day, hour, minute, second] */
type Clock = [number, number, number, number, number, number]

const ms = (c: Clock) => new Date(c[0], c[1], c[2], c[3], c[4], c[5], 0).getTime()

const night: Settings = {
  ...DEFAULT_SETTINGS,
  workStart: '22:00',
  workEnd: '06:00',
  lunchStart: '01:00',
  lunchMinutes: 60,
}
const hourly: Settings = { ...DEFAULT_SETTINGS, payMode: 'hourly', payAmount: 12_000 }
const monthly: Settings = { ...DEFAULT_SETTINGS, payMode: 'monthly', payAmount: 3_000_000 }
const net: Settings = { ...DEFAULT_SETTINGS, netPay: true }
const offToday: Settings = { ...DEFAULT_SETTINGS, dayOverrides: ['2026-09-22'] }
const workOnHoliday: Settings = { ...DEFAULT_SETTINGS, dayOverrides: ['2026-09-24'] }

const SETTINGS: Record<string, Settings> = {
  default: DEFAULT_SETTINGS,
  night,
  hourly,
  monthly,
  net,
  offToday,
  workOnHoliday,
}

/** 경계만 촘촘히 깐다. 가운데 값은 규칙이 갈라져도 잘 안 드러난다. */
const MOMENTS: { label: string; settings: string; at: Clock }[] = [
  { label: '출근 1초 전', settings: 'default', at: [2026, 8, 22, 8, 59, 59] },
  { label: '출근 정각', settings: 'default', at: [2026, 8, 22, 9, 0, 0] },
  { label: '점심 직전', settings: 'default', at: [2026, 8, 22, 11, 59, 59] },
  { label: '점심 정각', settings: 'default', at: [2026, 8, 22, 12, 0, 0] },
  { label: '점심 종료 정각', settings: 'default', at: [2026, 8, 22, 13, 0, 0] },
  { label: '퇴근 1초 전', settings: 'default', at: [2026, 8, 22, 17, 59, 59] },
  { label: '퇴근 직후', settings: 'default', at: [2026, 8, 22, 18, 0, 1] },
  { label: '자정 1초 전', settings: 'default', at: [2026, 8, 22, 23, 59, 59] },
  { label: '자정 직후', settings: 'default', at: [2026, 8, 23, 0, 0, 1] },
  { label: '새벽 00:30', settings: 'default', at: [2026, 8, 23, 0, 30, 0] },
  { label: '토요일 한낮', settings: 'default', at: [2026, 8, 26, 14, 0, 0] },
  { label: '일요일 한낮', settings: 'default', at: [2026, 8, 27, 14, 0, 0] },
  { label: '추석 연휴 한낮', settings: 'default', at: [2026, 8, 24, 14, 0, 0] },
  { label: '월말 근무 중', settings: 'default', at: [2026, 8, 30, 14, 0, 0] },
  { label: '공휴일 표 없는 해', settings: 'default', at: [2028, 8, 22, 14, 0, 0] },
  { label: '야간근무 자정 넘김', settings: 'night', at: [2026, 8, 23, 3, 0, 0] },
  { label: '야간근무 종료 후 아침', settings: 'night', at: [2026, 8, 23, 7, 0, 0] },
  { label: '시급제 근무 중', settings: 'hourly', at: [2026, 8, 22, 14, 0, 0] },
  { label: '월급제 근무 중', settings: 'monthly', at: [2026, 8, 22, 14, 0, 0] },
  { label: '실수령 기준 근무 중', settings: 'net', at: [2026, 8, 22, 14, 0, 0] },
  { label: 'override로 쉬는 평일', settings: 'offToday', at: [2026, 8, 22, 14, 0, 0] },
  { label: 'override로 출근한 공휴일', settings: 'workOnHoliday', at: [2026, 8, 24, 14, 0, 0] },
]

const earnings = MOMENTS.map((m) => {
  const s = SETTINGS[m.settings]
  const e = computeEarnings(s, ms(m.at))
  return {
    label: m.label,
    settings: m.settings,
    at: m.at,
    expected: {
      phase: e.phase,
      earned: e.earned,
      perSecond: e.perSecond,
      progress: e.progress,
      elapsedPaidMs: e.elapsedPaidMs,
      totalPaidMs: e.totalPaidMs,
      msUntilStart: e.msUntilStart,
      msUntilEnd: e.msUntilEnd,
      msUntilLunchEnd: e.msUntilLunchEnd,
      remainingAmount: e.remainingAmount,
      dailyTotal: e.dailyTotal,
      workDays: e.workDays,
      deductionRate: e.deductionRate,
      hasShift: e.shift !== null,
    },
  }
})

const shifts = MOMENTS.map((m) => {
  const sh = resolveShift(SETTINGS[m.settings], ms(m.at))
  return {
    label: m.label,
    settings: m.settings,
    at: m.at,
    expected: {
      startMs: sh.startMs,
      endMs: sh.endMs,
      lunchStartMs: sh.lunchStartMs,
      lunchEndMs: sh.lunchEndMs,
      paidMs: sh.paidMs,
    },
  }
})

const GROSSES = [1_500_000, 2_000_000, 3_000_000, 3_500_000, 5_000_000, 6_000_000, 10_000_000]

const deductions = GROSSES.map((gross) => {
  const d = estimateDeductions(gross)
  return { gross, expected: d }
})

const DAYS: Clock[] = [
  [2026, 8, 22, 12, 0, 0],
  [2026, 8, 24, 12, 0, 0],
  [2026, 8, 26, 12, 0, 0],
  [2026, 8, 27, 12, 0, 0],
  [2026, 0, 1, 12, 0, 0],
  [2026, 1, 17, 12, 0, 0],
  [2028, 8, 22, 12, 0, 0],
]

const workdays = DAYS.map((at) => ({
  at,
  expected: {
    autoWorkDays: effectiveWorkDays(DEFAULT_SETTINGS, ms(at)),
    isDayOff: isDayOff([], ms(at)),
    isDayOffWithOverride: isDayOff(['2026-09-22', '2026-09-24'], ms(at)),
  },
}))

const outDir = path.resolve(import.meta.dirname, '..', 'shared', 'golden')
mkdirSync(outDir, { recursive: true })

const write = (name: string, data: unknown) => {
  writeFileSync(path.join(outDir, name), `${JSON.stringify(data, null, 2)}\n`, 'utf8')
  console.log(`wrote shared/golden/${name}`)
}

const settingsUsed = Object.fromEntries(
  Object.entries(SETTINGS).map(([k, v]) => [k, v]),
)

write('settings.json', settingsUsed)
write('earnings.json', earnings)
write('shift.json', shifts)
write('deductions.json', deductions)
write('workdays.json', workdays)
```

`estimateDeductions`는 평평한 객체를 돌려주므로 `expected: d`가 그대로 담긴다:

```ts
interface Deductions {
  pension: number       // 국민연금 (월)
  health: number        // 건강보험 (월)
  longTermCare: number  // 장기요양보험 (월)
  employment: number    // 고용보험 (월)
  incomeTax: number     // 소득세 + 지방소득세 (월, 추정)
  total: number         // 월 공제 합계
  rate: number          // 공제율 0..1
}
```

- [ ] **Step 2: `package.json`에 스크립트를 추가한다**

`scripts` 블록에 넣는다:

```json
    "golden": "vite-node scripts/generate-golden.ts",
```

- [ ] **Step 3: 스크립트를 돌린다**

```bash
npm run golden
```

Expected: `shared/golden/`에 5개 파일이 생긴다

```bash
ls -1 shared/golden/
cat shared/golden/earnings.json | head -30
```

`'토요일 한낮'`의 `phase`가 `"dayoff"`이고 `earned`가 `0`인지, `'새벽 00:30'`의 `phase`가 `"before"`이고 `earned`가 `0`인지 눈으로 확인한다. 아니면 앞 Task에 문제가 있는 것이다.

- [ ] **Step 4: 골든이 구현과 일치하는지 보는 테스트를 쓴다**

`lib/__tests__/golden.test.ts`:

```ts
/**
 * 골든 파일이 현재 구현과 맞는지 본다.
 *
 * 규칙을 바꾸면 이 테스트가 먼저 실패한다. `npm run golden`으로 다시 뽑고,
 * 그때 나오는 diff가 곧 맥 앱에서 고쳐야 할 목록이다.
 */
import { describe, it, expect } from 'vitest'
import { readFileSync } from 'node:fs'
import path from 'node:path'
import { computeEarnings } from '@/lib/salary'
import { resolveShift } from '@/lib/shift'
import type { Settings } from '@/lib/settings'

const dir = path.resolve(import.meta.dirname, '..', '..', 'shared', 'golden')
const read = (name: string) => JSON.parse(readFileSync(path.join(dir, name), 'utf8'))

const SETTINGS: Record<string, Settings> = read('settings.json')
const ms = (c: number[]) => new Date(c[0], c[1], c[2], c[3], c[4], c[5], 0).getTime()

describe('golden — earnings', () => {
  const cases = read('earnings.json')

  it('케이스가 비어 있지 않다', () => {
    expect(cases.length).toBeGreaterThan(0)
  })

  for (const c of cases) {
    it(`${c.label} (${c.settings})`, () => {
      const e = computeEarnings(SETTINGS[c.settings], ms(c.at))
      expect(e.phase).toBe(c.expected.phase)
      expect(e.earned).toBeCloseTo(c.expected.earned, 9)
      expect(e.perSecond).toBeCloseTo(c.expected.perSecond, 9)
      expect(e.progress).toBeCloseTo(c.expected.progress, 9)
      expect(e.dailyTotal).toBeCloseTo(c.expected.dailyTotal, 9)
      expect(e.workDays).toBe(c.expected.workDays)
      expect(e.shift !== null).toBe(c.expected.hasShift)
    })
  }
})

describe('golden — shift', () => {
  const cases = read('shift.json')

  for (const c of cases) {
    it(`${c.label} (${c.settings})`, () => {
      const sh = resolveShift(SETTINGS[c.settings], ms(c.at))
      expect(sh.startMs).toBe(c.expected.startMs)
      expect(sh.endMs).toBe(c.expected.endMs)
      expect(sh.paidMs).toBe(c.expected.paidMs)
    })
  }
})
```

`startMs`·`endMs`를 epoch ms로 비교해도 되는 이유: 생성과 검증이 같은 기계·같은 타임존에서 돌기 때문이다. **Swift 쪽은 이 값을 쓰지 않고 `at` 배열로 다시 계산해서 비교한다** — 맥 앱 계획에서 다룬다.

- [ ] **Step 5: 테스트를 돌린다**

```bash
npm test
```

Expected: 전부 통과. 골든 케이스만큼 테스트 수가 늘어난다

- [ ] **Step 6: 커밋**

```bash
git add scripts/generate-golden.ts shared/golden lib/__tests__/golden.test.ts package.json
git commit -m "$(cat <<'EOF'
chore: 맥 앱이 읽을 골든 파일을 웹 구현에서 뽑는다

규칙의 단일 출처는 lib/다. 골든은 "Swift가 lib/와 같은 답을 내는가"만
본다. 시각은 [연,월,일,시,분,초] 배열로 적어 타임존 독립성을 지킨다.

golden.test.ts가 골든과 현재 구현의 차이를 잡는다. 규칙을 바꾸면 이게
먼저 실패하고, npm run golden으로 다시 뽑은 diff가 맥 앱에서 고칠
목록이 된다.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 8: 팔레트를 뽑는다

**Files:**
- Create: `scripts/extract-palette.ts`
- Create: `shared/golden/palette.json` (생성물)
- Modify: `package.json` (scripts에 `palette` 추가)

**Interfaces:**
- Consumes: `npm run build`가 만든 `.next/static/css/*.css`
- Produces: `shared/golden/palette.json` — 맥 앱이 `Palette.swift`를 생성할 재료

Tailwind v4는 색을 `oklch()`로 낸다. 손으로 hex를 적지 않고 **빌드된 CSS에서 실제 쓰인 값을 뽑는다.**

- [ ] **Step 1: 빌드된 CSS에 색이 어떻게 들어 있는지 눈으로 본다**

```bash
npm run build
ls .next/static/css/
grep -o 'oklch([^)]*)' .next/static/css/*.css | sort -u | head -20
```

`oklch(...)` 형태가 보이는지, 아니면 이미 hex/rgb로 낮춰져 있는지 확인한다. **둘 중 무엇이 나오는지에 따라 Step 2의 정규식을 맞춘다.**

- [ ] **Step 2: 추출 스크립트를 쓴다**

`scripts/extract-palette.ts`:

```ts
/**
 * 맥 앱이 쓸 색을 빌드된 CSS에서 뽑는다.
 *
 * Tailwind v4는 팔레트를 oklch로 정의한다. 손으로 hex를 옮겨 적으면 웹과
 * 조용히 어긋나므로, 실제로 빌드된 값을 그대로 가져온다.
 *
 * 실행: npm run build && npm run palette
 */
import { readFileSync, writeFileSync, mkdirSync, readdirSync } from 'node:fs'
import path from 'node:path'

const root = path.resolve(import.meta.dirname, '..')
const cssDir = path.join(root, '.next', 'static', 'css')

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

const found: Record<string, string> = {}
const missing: string[] = []

for (const token of TOKENS) {
  // Tailwind v4는 --color-slate-400: oklch(...) 형태로 변수를 깐다
  const m = css.match(new RegExp(`--color-${token}\\s*:\\s*([^;]+);`))
  if (m) found[token] = m[1].trim()
  else missing.push(token)
}

if (missing.length > 0) {
  console.error(`CSS에서 못 찾은 토큰: ${missing.join(', ')}`)
  console.error('Tailwind가 쓰지 않는 색은 변수로 내보내지 않는다.')
  console.error('스펙 5.1 표와 대조해 실제로 쓰이는 토큰인지 확인할 것.')
  process.exit(1)
}

const palette = {
  note: 'npm run build && npm run palette 로 다시 뽑는다. 손으로 고치지 말 것.',
  background: { light: '#ffffff', dark: '#0a0a0a' },
  foreground: { light: '#171717', dark: '#ededed' },
  tokens: found,
}

const outDir = path.join(root, 'shared', 'golden')
mkdirSync(outDir, { recursive: true })
writeFileSync(path.join(outDir, 'palette.json'), `${JSON.stringify(palette, null, 2)}\n`, 'utf8')
console.log('wrote shared/golden/palette.json')
```

`background`와 `foreground`는 `app/globals.css`가 CSS 변수로 직접 박아둔 값이라 Tailwind 팔레트에 없다. 그래서 여기서만 손으로 적고, 출처를 주석으로 남긴다.

- [ ] **Step 3: `package.json`에 스크립트를 추가한다**

```json
    "palette": "vite-node scripts/extract-palette.ts",
```

- [ ] **Step 4: 돌려서 확인한다**

```bash
npm run build && npm run palette
cat shared/golden/palette.json
```

Expected: 12개 토큰이 전부 값과 함께 들어 있다

못 찾은 토큰이 있으면 Step 1로 돌아가 CSS에서 그 토큰이 어떤 이름으로 나오는지 확인하고 정규식을 고친다. **찾지 못한 토큰을 손으로 채워 넣지 않는다** — 그러면 이 스크립트를 만든 이유가 없어진다.

- [ ] **Step 5: 커밋**

```bash
git add scripts/extract-palette.ts shared/golden/palette.json package.json
git commit -m "$(cat <<'EOF'
chore: 맥 앱이 쓸 색을 빌드된 CSS에서 뽑는다

Tailwind v4가 팔레트를 oklch로 내므로 손으로 hex를 옮기면 웹과 조용히
어긋난다. 실제 빌드 결과에서 가져와 palette.json으로 남긴다.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## 최종 검증

각 항목을 확인하고, 어긋나는 것이 있으면 고친 뒤 다시 확인한다.

- [ ] `npm test` — 전부 통과 (212개 + 새 테스트)
- [ ] `npx tsc --noEmit` — 오류 없음
- [ ] `npm run lint` — 오류 없음
- [ ] `npm run build` — 성공
- [ ] `npm run golden && git diff --exit-code shared/golden/` — 재생성해도 변화 없음
- [ ] `shared/golden/`에 6개 파일 (`settings`, `earnings`, `shift`, `deductions`, `workdays`, `palette`)
- [ ] 브라우저에서 오늘을 쉬는 날로 찍으면 시계 화면이 되고, 되돌리면 원래대로 돌아온다
- [ ] 얼굴 10종 전부 쉬는 날에 진행 표시가 없다

## Self-Review

**스펙 커버리지:**

| 스펙 항목 | 구현 위치 |
|---|---|
| 3.1 시프트 선택 3단계 | Task 2 |
| 3.2 휴무일 · 시작일 기준 판정 | Task 3, Task 4 |
| 3.3 `Phase`·`Earnings.shift` 타입 | Task 4 |
| 3.4 웹 UI 반영 | Task 5, Task 6 |
| 5.1 팔레트 추출 | Task 8 |
| 9.1 골든 파일 형식 | Task 7 |
| 9.2 골든 생성 방식 | Task 7 |
| 9.3 케이스 목록 | Task 7 Step 1의 `MOMENTS` |
| 9.4 기존 테스트 | Task 2 Step 4에서 확인 |
| 12장 1~2번 | 이 계획 전체 |

**이 계획에 없는 스펙 항목** (전부 맥 앱 계획으로 넘어간다): 4장 맥 앱 구조, 5.2~5.4 글꼴·치수·문구, 6장 SalaryClockCore, 10장 빌드와 배포, 12장 3~7번.

**스펙과 달라진 점:**

- 스펙 9.4는 "가장 가까운 시프트 전제에 기대던 케이스는 고친다"고 썼는데, 대입해보니 **고칠 테스트가 하나도 없었다.** 스펙을 그렇게 고쳤고, 계획은 추가만 한다.
- 골든에 `settings.json`을 더했다. 케이스가 어떤 설정을 썼는지 이름으로만 가리키므로, 그 이름이 무엇인지 맥 앱이 알 방법이 필요하다.

**미해결로 남긴 것:** Task 8 Step 1은 빌드 결과를 보고 정규식을 맞추라고 지시한다. Tailwind v4가 `--color-slate-400` 변수를 내보내는지 실제로 확인하지 못했다. 못 찾으면 Step 4에서 멈추고 스크립트를 고치게 되어 있다.
