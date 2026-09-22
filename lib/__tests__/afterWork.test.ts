import { describe, it, expect } from 'vitest'
import { afterWorkKind } from '@/lib/afterWork'
import { DEFAULT_SETTINGS, type Settings } from '@/lib/settings'

const at = (y: number, m: number, d: number, h = 19) => new Date(y, m, d, h, 0, 0).getTime()

describe('afterWorkKind', () => {
  it('화요일 퇴근이면 내일도 근무일이다', () => {
    expect(afterWorkKind(DEFAULT_SETTINGS, at(2026, 8, 22))).toBe('tomorrow')
  })

  it('금요일 퇴근이면 다음 근무일이 다음 주 월요일이다', () => {
    expect(afterWorkKind(DEFAULT_SETTINGS, at(2026, 8, 25))).toBe('nextWeek')
  })

  it('수요일 퇴근에 목요일이 공휴일이고 금요일이 근무일이면 같은 주다', () => {
    // 9/24(목)는 추석이라 그대로 쉬고, 9/25(금)만 출근으로 뒤집는다
    // → 9/23(수) 퇴근 → 다음 근무일 9/25(금), 이틀 뒤, 같은 주(일요일 시작 기준
    // 9/20~9/26) → restThisWeek.
    // (09-24를 뒤집으면 목요일 자체가 근무일이 되어 다음 근무일이 하루 뒤인
    // tomorrow가 된다 — 그건 이 테스트가 말하려는 "같은 주" 케이스가 아니다)
    const s: Settings = { ...DEFAULT_SETTINGS, dayOverrides: ['2026-09-25'] }
    expect(afterWorkKind(s, at(2026, 8, 23))).toBe('restThisWeek')
  })

  it('추석 연휴 직전이면 연휴다', () => {
    // 2026-09-23(수) 퇴근 → 9/24·9/25 추석, 9/26·9/27 주말 → 다음 근무일 9/28(월), 5일 뒤
    expect(afterWorkKind(DEFAULT_SETTINGS, at(2026, 8, 23))).toBe('longBreak')
  })

  it('목요일 퇴근에 금요일만 쉬어도 나흘 뒤라 연휴로 본다', () => {
    // 10/1(목) 퇴근, override로 10/2(금)만 추가로 쉬면 주말과 이어져 다음
    // 근무일이 10/5(월) — 나흘 뒤라 gap>=4 기준에 걸려 longBreak다.
    // ("금요일만 쉬면 다음 근무일이 월요일이라 다음 주"라는 직관은 gap=4가
    // nextWeek이 아니라 longBreak 경계라는 점과 맞지 않는다.)
    // 게다가 2026년 실제 공휴일 표에는 10/5가 개천절(10/3, 토) 대체공휴일이라
    // 그마저 쉬는 날이라 실제 다음 근무일은 10/6(화), 닷새 뒤다.
    const s: Settings = { ...DEFAULT_SETTINGS, dayOverrides: ['2026-10-02'] }
    expect(afterWorkKind(s, at(2026, 9, 1))).toBe('longBreak')
  })
})
