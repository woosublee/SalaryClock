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
import { estimateDeductions } from '@/lib/deductions'
import { effectiveWorkDays } from '@/lib/workdays'
import { isDayOff } from '@/lib/calendar'
import { DEFAULT_SETTINGS, type Settings } from '@/lib/settings'

const dir = path.resolve(import.meta.dirname, '..', '..', 'shared', 'golden')
const read = (name: string) => JSON.parse(readFileSync(path.join(dir, name), 'utf8'))

const SETTINGS: Record<string, Settings> = read('settings.json')
const ms = (c: number[]) => new Date(c[0], c[1], c[2], c[3], c[4], c[5], 0).getTime()
const msOrNull = (c: number[] | null) => (c === null ? null : ms(c))

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
      expect(e.elapsedPaidMs).toBe(c.expected.elapsedPaidMs)
      expect(e.totalPaidMs).toBe(c.expected.totalPaidMs)
      expect(e.msUntilStart).toBe(c.expected.msUntilStart)
      expect(e.msUntilEnd).toBe(c.expected.msUntilEnd)
      expect(e.msUntilLunchEnd).toBe(c.expected.msUntilLunchEnd)
      expect(e.remainingAmount).toBeCloseTo(c.expected.remainingAmount, 9)
      expect(e.dailyTotal).toBeCloseTo(c.expected.dailyTotal, 9)
      expect(e.workDays).toBe(c.expected.workDays)
      expect(e.deductionRate).toBeCloseTo(c.expected.deductionRate, 9)
      expect(e.shift !== null).toBe(c.expected.hasShift)
    })
  }
})

describe('golden — shift', () => {
  const cases = read('shift.json')

  it('케이스가 비어 있지 않다', () => {
    expect(cases.length).toBeGreaterThan(0)
  })

  for (const c of cases) {
    it(`${c.label} (${c.settings})`, () => {
      const sh = resolveShift(SETTINGS[c.settings], ms(c.at))
      expect(sh.startMs).toBe(ms(c.expected.start))
      expect(sh.endMs).toBe(ms(c.expected.end))
      expect(sh.lunchStartMs).toBe(msOrNull(c.expected.lunchStart))
      expect(sh.lunchEndMs).toBe(msOrNull(c.expected.lunchEnd))
      expect(sh.paidMs).toBe(c.expected.paidMs)
    })
  }
})

describe('golden — deductions', () => {
  const cases = read('deductions.json')

  it('케이스가 비어 있지 않다', () => {
    expect(cases.length).toBeGreaterThan(0)
  })

  for (const c of cases) {
    it(`gross ${c.gross}`, () => {
      const d = estimateDeductions(c.gross)
      expect(d.pension).toBeCloseTo(c.expected.pension, 9)
      expect(d.health).toBeCloseTo(c.expected.health, 9)
      expect(d.longTermCare).toBeCloseTo(c.expected.longTermCare, 9)
      expect(d.employment).toBeCloseTo(c.expected.employment, 9)
      expect(d.incomeTax).toBeCloseTo(c.expected.incomeTax, 9)
      expect(d.total).toBeCloseTo(c.expected.total, 9)
      expect(d.rate).toBeCloseTo(c.expected.rate, 9)
    })
  }
})

describe('golden — workdays', () => {
  const cases = read('workdays.json')

  it('케이스가 비어 있지 않다', () => {
    expect(cases.length).toBeGreaterThan(0)
  })

  for (const c of cases) {
    it(`at ${c.at.join('-')}`, () => {
      expect(effectiveWorkDays(DEFAULT_SETTINGS, ms(c.at))).toBe(c.expected.autoWorkDays)
      expect(isDayOff([], ms(c.at))).toBe(c.expected.isDayOff)
      expect(isDayOff(['2026-09-22', '2026-09-24'], ms(c.at))).toBe(
        c.expected.isDayOffWithOverride,
      )
    })
  }
})
