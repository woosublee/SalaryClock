import { describe, it, expect } from 'vitest'
import {
  formatWon,
  formatPerSecond,
  formatDuration,
  formatKoreanUnits,
  formatDateKo,
  formatClockTime,
} from '@/lib/format'

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

  it('소수 자릿수를 지정할 수 있다', () => {
    expect(formatWon(47382.96, 1)).toBe('₩47,382.9')
    expect(formatWon(47382, 1)).toBe('₩47,382.0')
  })

  it('소수 표시에서도 반올림하지 않고 내린다', () => {
    expect(formatWon(99.99, 1)).toBe('₩99.9')
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

describe('formatKoreanUnits', () => {
  it('만 단위로 끊어 읽어준다', () => {
    expect(formatKoreanUnits(50_000_000)).toBe('5,000만원')
  })

  it('억과 만을 함께 보여준다', () => {
    expect(formatKoreanUnits(120_000_000)).toBe('1억 2,000만원')
  })

  it('딱 떨어지는 억은 억만 보여준다', () => {
    expect(formatKoreanUnits(100_000_000)).toBe('1억원')
  })

  it('만 미만 자리를 남긴다', () => {
    expect(formatKoreanUnits(12_000)).toBe('1만 2,000원')
  })

  it('만 미만이면 그대로 보여준다', () => {
    expect(formatKoreanUnits(5_000)).toBe('5,000원')
  })

  it('0을 처리한다', () => {
    expect(formatKoreanUnits(0)).toBe('0원')
  })

  it('음수는 0으로 본다', () => {
    expect(formatKoreanUnits(-100)).toBe('0원')
  })
})

describe('formatDateKo', () => {
  it('년월일과 요일을 보여준다', () => {
    expect(formatDateKo(new Date(2026, 8, 22, 14).getTime())).toBe('2026년 9월 22일 (화)')
  })

  it('한 자리 월과 일에 0을 붙이지 않는다', () => {
    expect(formatDateKo(new Date(2026, 0, 5, 9).getTime())).toBe('2026년 1월 5일 (월)')
  })

  it('일요일을 처리한다', () => {
    expect(formatDateKo(new Date(2026, 1, 1, 9).getTime())).toBe('2026년 2월 1일 (일)')
  })
})

describe('formatClockTime', () => {
  it('24시간제로 0을 채워 보여준다', () => {
    expect(formatClockTime(new Date(2026, 8, 22, 16, 53, 21).getTime())).toBe('16:53:21')
  })

  it('자정을 00으로 쓴다', () => {
    expect(formatClockTime(new Date(2026, 8, 22, 0, 5, 9).getTime())).toBe('00:05:09')
  })

  it('밀리초는 버린다', () => {
    expect(formatClockTime(new Date(2026, 8, 22, 9, 0, 0, 999).getTime())).toBe('09:00:00')
  })
})
