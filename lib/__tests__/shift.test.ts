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
  lunchMinutes: 60,
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

  it('자정 직후에는 어제 시프트를 버리고 오늘 시프트를 고른다', () => {
    expect(resolveShift(DEFAULT_SETTINGS, at(0, 30)).startMs).toBe(at(9))
  })

  it('자정 직전에는 아직 오늘 시프트를 유지한다', () => {
    expect(resolveShift(DEFAULT_SETTINGS, at(23, 59)).startMs).toBe(at(9))
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
