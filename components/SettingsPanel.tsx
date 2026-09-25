'use client'

import { memo, useEffect, useId, useRef, useState } from 'react'
import { SettingsSchema, type PayMode, type Settings } from '@/lib/settings'
import { formatKoreanUnits } from '@/lib/format'
import { workdayInfo, effectiveWorkDays } from '@/lib/workdays'
import { toggleOverride, clearMonthOverrides, stepMonth } from '@/lib/calendar'
import { MonthCalendar } from '@/components/MonthCalendar'
import { ClockStylePicker } from '@/components/ClockStylePicker'
import { estimateDeductions } from '@/lib/deductions'
import { monthlyGross } from '@/lib/salary'
import { resolveShift } from '@/lib/shift'
import { parseHHmm, isValidHHmm, durationMinutes, formatHHmm } from '@/lib/time'

interface Props {
  settings: Settings
  onSave: (s: Settings) => void
  onClose: () => void
  onReset: () => void
  /** 첫 방문이라 돌아갈 곳이 없으면 취소 버튼을 감춘다 */
  dismissable?: boolean
}

const PAY_LABELS: Record<PayMode, string> = {
  annual: '연봉',
  monthly: '월급',
  hourly: '시급',
}

const FIELD =
  'w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-emerald-500 dark:border-slate-600 dark:bg-slate-800 dark:text-slate-100'

/**
 * 시각 입력 전용.
 *
 * 한국어 로캘에서 <input type="time">은 "오전 09:00"에 달력 아이콘까지 붙어
 * 렌더링된다. 두 칸으로 나눈 좁은 화면에서는 기본 좌우 여백(px-3)만으로도
 * 글자와 아이콘이 맞붙는다. 여백을 줄이고 아이콘도 바짝 당긴다.
 */
const TIME_FIELD =
  'w-full min-w-0 rounded-lg border border-slate-300 bg-white px-2 py-2 text-sm text-slate-900 outline-none focus:border-emerald-500 dark:border-slate-600 dark:bg-slate-800 dark:text-slate-100 [&::-webkit-calendar-picker-indicator]:ml-0 [&::-webkit-calendar-picker-indicator]:shrink-0'

/** 초기화 버튼이 두 번째 누름을 기다리는 시간 */
const RESET_CONFIRM_MS = 3000

const LABEL = 'text-sm text-slate-600 dark:text-slate-300'
const HINT = 'text-xs text-slate-400 dark:text-slate-500'

/**
 * 이 컴포넌트는 열릴 때마다 새로 마운트된다 (부모가 revision을 key로 준다).
 * 덕분에 props를 state로 동기화하는 useEffect가 필요 없다.
 *
 * memo로 감싼다. 부모(Home)는 rAF 틱마다 다시 그려지는데, 그때마다 이 본문이
 * 돌면 zod 파싱·시프트·공제 추정과 페이스 미리보기 10개가 프레임마다 다시
 * 계산된다. 시각을 prop으로 받지 않고(panelNow) 부모가 콜백을 고정해 주므로
 * 입력이 없는 동안에는 다시 그려지지 않는다.
 */
export const SettingsPanel = memo(function SettingsPanel({
  settings,
  onSave,
  onClose,
  onReset,
  dismissable = true,
}: Props) {
  const [draft, setDraft] = useState<Settings>(settings)
  const [error, setError] = useState<string | null>(null)
  // 금액은 콤마가 섞인 표시 문자열을 따로 들고 있어야 입력 중 커서가 튀지 않는다.
  const [amountText, setAmountText] = useState(() => settings.payAmount.toLocaleString('ko-KR'))
  // 공제율도 같은 이유다. 숫자를 다시 서식해 되먹이면 "1"을 치는 순간 "1.0"이
  // 되어 다음 자리를 이어 칠 수 없다. 칸에는 친 그대로를 두고 숫자만 draft로 보낸다.
  const [rateText, setRateText] = useState(() =>
    settings.deductionRate === null ? '' : String(Math.round(settings.deductionRate * 1000) / 10),
  )
  const [showAdvanced, setShowAdvanced] = useState(false)
  // 초기화는 연봉과 달력에 찍어 둔 날까지 되돌릴 수 없게 지운다. 한 번 누르면
  // 무장만 하고, 몇 초 안에 한 번 더 눌러야 실행한다. confirm() 창을 띄우는
  // 것보다 손이 덜 가고, 잘못 누른 경우에는 그냥 두면 풀린다.
  const [resetArmed, setResetArmed] = useState(false)
  useEffect(() => {
    if (!resetArmed) return
    const id = setTimeout(() => setResetArmed(false), RESET_CONFIRM_MS)
    return () => clearTimeout(id)
  }, [resetArmed])
  const [showCalendar, setShowCalendar] = useState(false)
  // 패널이 열린 순간의 시각으로 고정한다. 설정 창을 열어둔 몇 초 사이에 달이
  // 바뀌지는 않는다. 부모의 rAF 시각을 prop으로 받으면 memo가 매 프레임 깨진다.
  const [panelNow] = useState(() => Date.now())

  const titleId = useId()
  const workStartId = useId()
  const workEndId = useId()
  const workDaysId = useId()
  const payLabelId = useId()
  const faceLabelId = useId()

  /*
   * 네이티브 모달 대화상자로 연다. showModal()이 포커스를 창 안으로 옮기고,
   * 창 밖(설정·가리기·테마 버튼)을 inert로 만들어 Tab이 새지 않게 하고,
   * Esc를 cancel 이벤트로 넘겨 준다. 손으로 포커스 트랩을 짜지 않아도 된다.
   *
   * 닫을 때는 연 버튼으로 포커스를 돌려준다. 대화상자는 close()를 거치지 않고
   * 통째로 언마운트되므로 브라우저가 알아서 돌려주지 않는다.
   */
  const dialogRef = useRef<HTMLDialogElement | null>(null)
  useEffect(() => {
    const dialog = dialogRef.current
    if (!dialog) return
    const opener = document.activeElement instanceof HTMLElement ? document.activeElement : null
    if (!dialog.open) dialog.showModal()
    return () => {
      if (dialog.open) dialog.close()
      opener?.focus()
    }
  }, [])

  const set = <K extends keyof Settings>(key: K, value: Settings[K]) =>
    setDraft((d) => ({ ...d, [key]: value }))

  // 브라우저에 따라 <input type="time">이 "09:00:00"을 주기도 한다.
  const setTime = (key: keyof Settings, value: string) => set(key, value.slice(0, 5) as never)

  const monthInfo = workdayInfo(panelNow)
  const autoWorkDays = monthInfo.workdays
  const panelYear = new Date(panelNow).getFullYear()
  const panelMonth = new Date(panelNow).getMonth()
  // 달력이 보여주는 달. 패널을 열 때는 이번 달에서 시작하고, 화살표로 옮긴다.
  // 근무일수 표시는 이번 달 기준 그대로다 — 달력은 날짜를 찍는 도구고,
  // 찍은 날짜는 그 달이 왔을 때 계산에 반영된다.
  const [calendar, setCalendar] = useState({ year: panelYear, month: panelMonth })
  const workDays = effectiveWorkDays(draft, panelNow)

  /**
   * 점심은 시작~종료 시각으로 입력받고, 저장은 무급 분으로 한다.
   * 시작 시각을 바꾸면 무급 길이는 유지한 채 구간이 통째로 이동한다.
   */
  const lunchEndValue = isValidHHmm(draft.lunchStart)
    ? formatHHmm(parseHHmm(draft.lunchStart) + draft.lunchMinutes)
    : '13:00'

  const setLunchEnd = (value: string) => {
    const end = value.slice(0, 5)
    if (!isValidHHmm(end) || !isValidHHmm(draft.lunchStart)) return
    set('lunchMinutes', durationMinutes(parseHHmm(draft.lunchStart), parseHHmm(end)))
  }

  const shiftMinutes =
    isValidHHmm(draft.workStart) && isValidHHmm(draft.workEnd)
      ? durationMinutes(parseHHmm(draft.workStart), parseHHmm(draft.workEnd))
      : 0
  const paidHours = Math.max(0, shiftMinutes - (draft.lunchEnabled ? draft.lunchMinutes : 0)) / 60

  // 실수령 미리보기. 저장 전에도 공제율이 얼마나 되는지 보여준다.
  const previewShift = resolveShift(
    SettingsSchema.safeParse(draft).success ? draft : settings,
    panelNow,
  )
  const gross = monthlyGross(draft, previewShift, workDays)
  const estimated = estimateDeductions(gross)
  const effectiveRate = draft.deductionRate ?? estimated.rate

  const handleSave = () => {
    const parsed = SettingsSchema.safeParse(draft)
    if (!parsed.success) {
      setError(parsed.error.issues[0]?.message ?? '설정값을 확인해 주세요')
      return
    }
    onSave(parsed.data)
    onClose()
  }

  return (
    // 설정 버튼이 우측 상단에 있으니 패널도 우측에서 열린다. 화면이 넓을 때
    // 반대편에서 뜨면 눈이 한 번 건너뛰어야 한다.
    //
    // 대화상자 자체는 화면 전체를 덮는 투명한 스크롤 영역이고, 흰 카드는 그 안에
    // 놓인다. 브라우저 기본 스타일(가운데 정렬, 테두리, 최대 크기)은 걷어낸다.
    <dialog
      ref={dialogRef}
      aria-labelledby={titleId}
      // Esc. 첫 방문에는 닫을 곳이 없으므로 막는다(아래 X 버튼과 같은 이유).
      onCancel={(e) => {
        e.preventDefault()
        if (dismissable) onClose()
      }}
      // 그래도 닫히는 경우가 있다. Chrome은 대화상자가 열린 뒤 사용자가 아무것도
      // 누르지 않았으면 cancel을 막지 못하게 하고 곧바로 닫는다(남용 방지).
      // 첫 방문에 그대로 두면 저장 버튼도 없는 빈 화면에 갇히므로 다시 연다.
      // 언마운트하며 부르는 close()의 이벤트는 문서에서 떨어진 뒤라 여기 오지 않는다.
      onClose={() => {
        if (dismissable) onClose()
        else dialogRef.current?.showModal()
      }}
      className="fixed inset-0 m-0 h-dvh max-h-none w-full max-w-none overflow-y-auto bg-transparent p-4 text-slate-900 backdrop:bg-black/40 dark:text-slate-100"
    >
      <div className="flex min-h-full items-center justify-end">
        <div className="relative w-full max-w-md rounded-2xl bg-white p-6 shadow-xl dark:bg-slate-900">
          <h2 id={titleId} className="text-lg font-semibold">
            설정
          </h2>

          {/*
            첫 방문에는 닫을 곳이 없다. 저장을 해야 시계가 의미를 갖기 때문에
            그때는 X를 감춰 저장 말고는 길이 없게 둔다.
          */}
          {dismissable && (
            <button
              type="button"
              onClick={onClose}
              aria-label="설정 닫기"
              className="absolute right-4 top-4 rounded-lg p-1.5 text-slate-400 transition-colors hover:bg-slate-100 hover:text-slate-700 dark:hover:bg-slate-800 dark:hover:text-slate-200"
            >
              <svg
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                strokeWidth={2}
                strokeLinecap="round"
                className="size-4"
                aria-hidden="true"
              >
                <line x1="5" y1="5" x2="19" y2="19" />
                <line x1="19" y1="5" x2="5" y2="19" />
              </svg>
            </button>
          )}

          <div className="mt-5 space-y-5">
            {/* 시계 페이스 */}
            <div role="group" aria-labelledby={faceLabelId}>
              <span id={faceLabelId} className={LABEL}>
                시계 페이스
              </span>
              <ClockStylePicker
                value={draft.clockStyle}
                now={panelNow}
                shift={previewShift}
                onChange={(clockStyle) => set('clockStyle', clockStyle)}
              />
            </div>

            {/* 급여 ─ 실수령 옵션을 여기에 붙인다. 금액을 보면서 바로 켜고 끌 수 있게 */}
            <div role="group" aria-labelledby={payLabelId}>
              <span id={payLabelId} className={LABEL}>
                급여
              </span>

              <div className="mt-1 flex rounded-lg bg-slate-100 p-1 dark:bg-slate-800">
                {(Object.keys(PAY_LABELS) as PayMode[]).map((m) => (
                  <button
                    key={m}
                    type="button"
                    onClick={() => set('payMode', m)}
                    aria-pressed={draft.payMode === m}
                    className={`flex-1 rounded-md py-1.5 text-sm transition-colors ${
                      draft.payMode === m
                        ? 'bg-white font-medium text-slate-900 shadow-sm dark:bg-slate-700 dark:text-slate-100'
                        : 'text-slate-500 hover:text-slate-700 dark:text-slate-400 dark:hover:text-slate-200'
                    }`}
                  >
                    {PAY_LABELS[m]}
                  </button>
                ))}
              </div>

              <div className="relative mt-2">
                <input
                  type="text"
                  inputMode="numeric"
                  autoComplete="off"
                  aria-label="급여 금액"
                  className={`${FIELD} py-3 pr-10 text-right font-mono text-xl tabular-nums`}
                  value={amountText}
                  onChange={(e) => {
                    const digits = e.target.value.replace(/[^\d]/g, '').slice(0, 12)
                    setAmountText(digits === '' ? '' : Number(digits).toLocaleString('ko-KR'))
                    set('payAmount', digits === '' ? 0 : Number(digits))
                  }}
                />
                <span className="pointer-events-none absolute right-3 top-1/2 -translate-y-1/2 text-sm text-slate-400">
                  원
                </span>
              </div>

              <p className={`mt-1 text-right ${HINT}`}>{formatKoreanUnits(draft.payAmount)}</p>

              <div className="mt-3 rounded-lg bg-slate-50 px-3 py-2.5 dark:bg-slate-800/60">
                <label className="flex items-center justify-between gap-2">
                  <span className="flex items-center gap-2 text-sm text-slate-600 dark:text-slate-300">
                    <input
                      type="checkbox"
                      className="accent-emerald-600"
                      checked={draft.netPay}
                      onChange={(e) => set('netPay', e.target.checked)}
                    />
                    실수령액 기준으로 보기
                  </span>
                  {draft.netPay && (
                    <span className="shrink-0 font-mono text-xs tabular-nums text-slate-500 dark:text-slate-400">
                      −{(effectiveRate * 100).toFixed(1)}%
                    </span>
                  )}
                </label>

                {draft.netPay && (
                  <>
                    <button
                      type="button"
                      onClick={() => setShowAdvanced((v) => !v)}
                      className="mt-1.5 text-xs text-slate-400 underline underline-offset-2 hover:text-slate-600 dark:hover:text-slate-300"
                    >
                      {showAdvanced ? '접기' : '공제 내역 · 직접 설정'}
                    </button>

                    {showAdvanced && (
                      <div className="mt-2 border-t border-slate-200 pt-2 dark:border-slate-700">
                        <dl className="space-y-1 text-xs text-slate-500 dark:text-slate-400">
                          <div className="flex justify-between">
                            <dt>4대보험</dt>
                            <dd className="tabular-nums">
                              {Math.round(
                                estimated.pension +
                                  estimated.health +
                                  estimated.longTermCare +
                                  estimated.employment,
                              ).toLocaleString('ko-KR')}
                              원
                            </dd>
                          </div>
                          <div className="flex justify-between">
                            <dt>소득세 (추정)</dt>
                            <dd className="tabular-nums">
                              {Math.round(estimated.incomeTax).toLocaleString('ko-KR')}원
                            </dd>
                          </div>
                        </dl>

                        <div className="mt-2.5 flex items-center gap-2">
                          <span className="shrink-0 text-xs text-slate-500 dark:text-slate-400">
                            공제율
                          </span>
                          <div className="relative flex-1">
                            <input
                              type="number"
                              step="0.1"
                              min={0}
                              max={90}
                              aria-label="공제율"
                              placeholder={(estimated.rate * 100).toFixed(1)}
                              className={`${FIELD} pr-7 text-right tabular-nums`}
                              value={rateText}
                              onChange={(e) => {
                                setRateText(e.target.value)
                                set(
                                  'deductionRate',
                                  e.target.value === '' ? null : Number(e.target.value) / 100,
                                )
                              }}
                            />
                            <span className="pointer-events-none absolute right-3 top-1/2 -translate-y-1/2 text-sm text-slate-400">
                              %
                            </span>
                          </div>
                        </div>
                        <p className={`mt-1 ${HINT}`}>
                          비워두면 추정치를 씁니다. 명세서의 공제 합계 ÷ 세전 금액
                        </p>
                      </div>
                    )}
                  </>
                )}
              </div>
            </div>

            {/* 근무시간 */}
            {/*
              좁은 화면에서는 세로로 쌓는다. 사파리의 시각 입력은 내부 섀도 요소가
              로캘 기준 최소 폭을 가져서 두 칸으로 나누면 글자와 아이콘이 겹친다.
              CSS로 눌러두긴 했지만 브라우저 고유 크기에 기대지 않는 쪽이 안전하다.
            */}
            <div className="grid grid-cols-1 gap-2 sm:grid-cols-2">
              <div className="min-w-0">
                <label htmlFor={workStartId} className={LABEL}>
                  출근
                </label>
                <input
                  id={workStartId}
                  type="time"
                  className={`${TIME_FIELD} mt-1`}
                  value={draft.workStart}
                  onChange={(e) => setTime('workStart', e.target.value)}
                />
              </div>
              <div className="min-w-0">
                <label htmlFor={workEndId} className={LABEL}>
                  퇴근
                </label>
                <input
                  id={workEndId}
                  type="time"
                  className={`${TIME_FIELD} mt-1`}
                  value={draft.workEnd}
                  onChange={(e) => setTime('workEnd', e.target.value)}
                />
              </div>
            </div>

            {/* 점심 */}
            <div>
              <label className="flex items-center gap-2 text-sm text-slate-600 dark:text-slate-300">
                <input
                  type="checkbox"
                  className="accent-emerald-600"
                  checked={draft.lunchEnabled}
                  onChange={(e) => set('lunchEnabled', e.target.checked)}
                />
                점심시간 제외
              </label>

              {draft.lunchEnabled && (
                <>
                  <div className="mt-2 grid grid-cols-1 gap-2 sm:grid-cols-2">
                    <input
                      type="time"
                      aria-label="점심 시작"
                      className={TIME_FIELD}
                      value={draft.lunchStart}
                      onChange={(e) => setTime('lunchStart', e.target.value)}
                    />
                    <input
                      type="time"
                      aria-label="점심 종료"
                      className={TIME_FIELD}
                      value={lunchEndValue}
                      onChange={(e) => setLunchEnd(e.target.value)}
                    />
                  </div>
                  <p className={`mt-1 ${HINT}`}>무급 {draft.lunchMinutes}분</p>
                </>
              )}
            </div>

            {/* 근무일수 ─ 숫자를 고치면 manual, 달력에서 찍으면 calendar로 넘어간다 */}
            <div>
              <div className="flex items-center justify-between gap-2">
                <label htmlFor={workDaysId} className={LABEL}>
                  월 근무일수
                </label>
                <button
                  type="button"
                  onClick={() => setShowCalendar((v) => !v)}
                  className="text-xs text-slate-400 underline underline-offset-2 hover:text-slate-600 dark:hover:text-slate-300"
                >
                  {showCalendar ? '달력 접기' : '달력에서 고르기'}
                </button>
              </div>

              <div className="relative mt-1">
                <input
                  type="number"
                  id={workDaysId}
                  step="1"
                  min={0}
                  className={`${FIELD} pr-8 text-right tabular-nums`}
                  value={workDays}
                  onChange={(e) => {
                    setDraft((d) => ({
                      ...d,
                      workDaysMode: 'manual',
                      workDaysPerMonth: Number(e.target.value),
                    }))
                  }}
                />
                <span className="pointer-events-none absolute right-3 top-1/2 -translate-y-1/2 text-sm text-slate-400">
                  일
                </span>
              </div>

              <p className={`mt-1 flex items-center justify-between gap-2 ${HINT}`}>
                {draft.workDaysMode === 'auto' && (
                  <span>
                    {monthInfo.hasHolidayData
                      ? `평일 ${monthInfo.weekdays}일 − 공휴일 ${monthInfo.holidays}일. 달이 바뀌면 따라갑니다`
                      : `평일 ${monthInfo.weekdays}일. 이 해의 공휴일 자료가 없어 주말만 뺐습니다`}
                  </span>
                )}
                {draft.workDaysMode === 'calendar' && (
                  <>
                    <span>달력에서 고른 날로 셉니다</span>
                    <button
                      type="button"
                      onClick={() => set('workDaysMode', 'auto')}
                      className="shrink-0 underline underline-offset-2 hover:text-slate-600 dark:hover:text-slate-300"
                    >
                      자동 {autoWorkDays}일로
                    </button>
                  </>
                )}
                {draft.workDaysMode === 'manual' && (
                  <>
                    <span>직접 입력한 값으로 고정됩니다</span>
                    <button
                      type="button"
                      onClick={() => set('workDaysMode', 'auto')}
                      className="shrink-0 underline underline-offset-2 hover:text-slate-600 dark:hover:text-slate-300"
                    >
                      자동 {autoWorkDays}일로
                    </button>
                  </>
                )}
              </p>

              {showCalendar && (
                <MonthCalendar
                  year={calendar.year}
                  month={calendar.month}
                  onStepMonth={(delta) =>
                    setCalendar((c) => stepMonth(c.year, c.month, delta))
                  }
                  onToday={
                    calendar.year === panelYear && calendar.month === panelMonth
                      ? undefined
                      : () => setCalendar({ year: panelYear, month: panelMonth })
                  }
                  overrides={draft.dayOverrides}
                  onToggle={(date) =>
                    setDraft((d) => ({
                      ...d,
                      workDaysMode: 'calendar',
                      dayOverrides: toggleOverride(d.dayOverrides, date),
                    }))
                  }
                  onClearMonth={() =>
                    setDraft((d) => ({
                      ...d,
                      dayOverrides: clearMonthOverrides(
                        d.dayOverrides,
                        calendar.year,
                        calendar.month,
                      ),
                    }))
                  }
                />
              )}
            </div>
          </div>

          <p className="mt-5 rounded-lg bg-slate-50 px-3 py-2 text-center text-xs text-slate-500 dark:bg-slate-800/60 dark:text-slate-400">
            유급 {paidHours % 1 === 0 ? paidHours : paidHours.toFixed(1)}시간 × {workDays}일
          </p>

          {error && <p className="mt-3 text-sm text-red-600 dark:text-red-400">{error}</p>}

          <div className="mt-5 flex items-center justify-between gap-2">
            <button
              type="button"
              onClick={() => {
                if (resetArmed) {
                  setResetArmed(false)
                  onReset()
                } else {
                  setResetArmed(true)
                }
              }}
              aria-live="polite"
              className={
                resetArmed
                  ? 'rounded-lg px-3 py-2 text-sm font-medium text-red-600 dark:text-red-400'
                  : 'rounded-lg px-3 py-2 text-sm text-slate-400 hover:text-red-600 dark:hover:text-red-400'
              }
            >
              {resetArmed ? '한 번 더 누르면 초기화' : '초기화'}
            </button>

            <div className="flex gap-2">
              {dismissable && (
                <button
                  type="button"
                  onClick={onClose}
                  className="rounded-lg px-4 py-2 text-sm text-slate-600 hover:bg-slate-100 dark:text-slate-300 dark:hover:bg-slate-800"
                >
                  취소
                </button>
              )}
              <button
                type="button"
                onClick={handleSave}
                className="rounded-lg bg-emerald-600 px-4 py-2 text-sm font-medium text-white hover:bg-emerald-700"
              >
                저장
              </button>
            </div>
          </div>
        </div>
      </div>
    </dialog>
  )
})
