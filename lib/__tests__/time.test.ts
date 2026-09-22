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
