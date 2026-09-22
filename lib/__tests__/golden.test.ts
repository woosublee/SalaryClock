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
