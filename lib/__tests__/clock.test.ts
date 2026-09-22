import { describe, it, expect } from 'vitest'
import {
  handAngles,
  dialAngle,
  arcBetween,
  polarPoint,
  arcPath,
  shiftArcs,
  angleInArc,
  sectorPath,
} from '@/lib/clock'
import { resolveShift } from '@/lib/shift'
import { DEFAULT_SETTINGS } from '@/lib/settings'

const at = (h: number, m = 0, s = 0, ms = 0) => new Date(2026, 8, 22, h, m, s, ms).getTime()

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

describe('angleInArc', () => {
  it('호 안의 각도를 잡는다', () => {
    expect(angleInArc(300, { startDeg: 270, sweepDeg: 270 })).toBe(true)
  })

  it('호 밖의 각도를 거른다', () => {
    expect(angleInArc(200, { startDeg: 270, sweepDeg: 90 })).toBe(false)
  })

  it('0도를 넘어가는 호를 처리한다', () => {
    // 270도에서 시작해 180도까지 (9시 → 6시)
    const arc = { startDeg: 270, sweepDeg: 270 }
    expect(angleInArc(0, arc)).toBe(true)
    expect(angleInArc(90, arc)).toBe(true)
    expect(angleInArc(180, arc)).toBe(true)
    expect(angleInArc(200, arc)).toBe(false)
  })

  it('시작점과 끝점을 포함한다', () => {
    const arc = { startDeg: 270, sweepDeg: 90 }
    expect(angleInArc(270, arc)).toBe(true)
    expect(angleInArc(360, arc)).toBe(true)
  })

  it('길이가 0인 호는 아무것도 담지 않는다', () => {
    expect(angleInArc(270, { startDeg: 270, sweepDeg: 0 })).toBe(false)
  })
})

describe('sectorPath', () => {
  it('중심에서 시작해 닫힌 도형을 만든다', () => {
    const d = sectorPath(100, 100, 50, { startDeg: 0, sweepDeg: 90 })
    expect(d.startsWith('M 100 100 L')).toBe(true)
    expect(d.endsWith('Z')).toBe(true)
  })

  it('180도를 넘으면 large-arc 플래그를 세운다', () => {
    expect(sectorPath(100, 100, 50, { startDeg: 0, sweepDeg: 270 })).toContain('A 50 50 0 1 1')
  })

  it('180도 이하면 플래그를 내린다', () => {
    expect(sectorPath(100, 100, 50, { startDeg: 0, sweepDeg: 90 })).toContain('A 50 50 0 0 1')
  })

  it('길이가 0이면 빈 문자열이다', () => {
    expect(sectorPath(100, 100, 50, { startDeg: 0, sweepDeg: 0 })).toBe('')
  })
})

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
