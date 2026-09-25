import { describe, it, expect } from 'vitest'
import { hasHolidayData } from '@/lib/holidays'

describe('공휴일 표의 수명', () => {
  // 표에 없는 해는 조용히 평일로 판정된다 — 설날에도 돈이 쌓인다. 표가 끝나는
  // 해가 오기 전에 CI가 먼저 알려야 한다. 갱신 절차는 lib/holidays.ts 머리말.
  it('내년 공휴일 표가 들어 있다', () => {
    const nextYear = new Date().getFullYear() + 1
    expect(
      hasHolidayData(nextYear),
      `${nextYear}년 공휴일 표가 없다. lib/holidays.ts 머리말의 갱신 절차를 따르라`,
    ).toBe(true)
  })
})
