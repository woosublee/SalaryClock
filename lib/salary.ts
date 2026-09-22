import type { Settings } from '@/lib/settings'
import { resolveShift, paidMsBetween, type Shift } from '@/lib/shift'
import { effectiveWorkDays } from '@/lib/workdays'
import { estimateDeductions } from '@/lib/deductions'
import { isDayOff } from '@/lib/calendar'

export type Phase = 'before' | 'working' | 'lunch' | 'after' | 'dayoff'

export interface Earnings {
  phase: Phase
  /** 오늘 지금까지 적립된 금액 (원) */
  earned: number
  /** 초당 적립액. 근무 중이 아니면 0 */
  perSecond: number
  /** 유급시간 기준 진행률 0..1 */
  progress: number
  elapsedPaidMs: number
  totalPaidMs: number
  /** 출근까지 남은 시간. 이미 출근했으면 0 */
  msUntilStart: number
  /** 퇴근까지 남은 시계 시간(점심 포함). 퇴근했으면 0 */
  msUntilEnd: number
  /** 점심 재개까지 남은 시간. 점심이 아니면 0 */
  msUntilLunchEnd: number
  remainingAmount: number
  /** 오늘 하루를 다 채웠을 때의 총액 */
  dailyTotal: number
  /** 이 계산에 쓰인 이번 달 근무일수 */
  workDays: number
  /** 실수령 기준일 때 적용된 공제율 0..1. 세전 기준이면 0 */
  deductionRate: number
  /** 실수령 기준으로 계산했는지 */
  isNet: boolean
  /** 이 계산에 쓰인 시프트. 휴무일이면 null — 시계에 그릴 근무 구간이 없다 */
  shift: Shift | null
}

/**
 * 세전 월급 환산액.
 * 공제율은 월 급여를 기준으로 매겨지므로 어떤 입력 방식이든 월 단위로 맞춘다.
 */
export function monthlyGross(s: Settings, shift: Shift, workDays: number): number {
  if (s.payMode === 'annual') return s.payAmount / 12
  if (s.payMode === 'monthly') return s.payAmount
  const paidHoursPerDay = shift.paidMs / 3_600_000
  return s.payAmount * paidHoursPerDay * workDays
}

/** 설정에 지정된 공제율이 있으면 그것을, 없으면 추정치를 쓴다. */
export function deductionRateFor(s: Settings, gross: number): number {
  if (!s.netPay) return 0
  if (s.deductionRate !== null) return s.deductionRate
  return estimateDeductions(gross).rate
}

export function perSecondRate(s: Settings, shift: Shift, now: number): number {
  const workDays = effectiveWorkDays(s, now)
  const paidSecondsPerDay = shift.paidMs / 1000
  if (paidSecondsPerDay <= 0 || workDays <= 0) return 0

  const gross =
    s.payMode === 'hourly'
      ? s.payAmount / 3600
      : monthlyGross(s, shift, workDays) / (workDays * paidSecondsPerDay)

  const rate = deductionRateFor(s, monthlyGross(s, shift, workDays))
  return gross * (1 - rate)
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
  const workDays = effectiveWorkDays(s, now)

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
      workDays,
      deductionRate: deductionRateFor(s, monthlyGross(s, shift, workDays)),
      isNet: s.netPay,
      shift: null,
    }
  }

  const phase = phaseOf(shift, now)
  const rate = perSecondRate(s, shift, now)

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
    msUntilLunchEnd:
      phase === 'lunch' && shift.lunchEndMs !== null ? Math.max(0, shift.lunchEndMs - now) : 0,
    remainingAmount: Math.max(0, dailyTotal - earned),
    dailyTotal,
    workDays,
    deductionRate: deductionRateFor(s, monthlyGross(s, shift, workDays)),
    isNet: s.netPay,
    shift,
  }
}
