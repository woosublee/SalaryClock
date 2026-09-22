/**
 * 대한민국 관공서 공휴일 (대체공휴일 포함).
 *
 * 음력 기준 공휴일(설날·추석·부처님오신날)과 대체공휴일은 매년 날짜가 바뀌고
 * 공식 확정도 해마다 관보로 난다. 계산으로 뽑을 수 없으므로 연도별 표로 둔다.
 *
 * 표에 없는 연도는 `hasHolidayData`가 false를 돌려주고, 근무일수는 평일만 세는
 * 방식으로 되돌아간다. 낡은 표를 조용히 쓰느니 모른다고 말하는 편이 낫다.
 *
 * 출처: https://publicholidays.co.kr
 *
 * 포함하지 않은 것: 근로자의 날(5월 1일). 관공서 공휴일이 아니라 근로기준법상
 * 휴일이라 회사마다 적용이 갈린다. 쉬는 곳이라면 설정에서 근무일수를 직접
 * 하루 빼면 된다.
 */
const HOLIDAYS: Record<number, readonly string[]> = {
  2026: [
    '2026-01-01', // 새해
    '2026-02-16', // 설날 연휴
    '2026-02-17', // 설날
    '2026-02-18', // 설날 연휴
    '2026-03-01', // 삼일절
    '2026-03-02', // 삼일절 대체공휴일
    '2026-05-05', // 어린이날
    '2026-05-24', // 부처님 오신 날
    '2026-05-25', // 부처님 오신 날 대체공휴일
    '2026-06-06', // 현충일
    '2026-07-17', // 제헌절
    '2026-08-15', // 광복절
    '2026-08-17', // 광복절 대체공휴일
    '2026-09-24', // 추석 연휴
    '2026-09-25', // 추석
    '2026-09-26', // 추석 연휴
    '2026-10-03', // 개천절
    '2026-10-05', // 개천절 대체공휴일
    '2026-10-09', // 한글날
    '2026-12-25', // 크리스마스
  ],
  2027: [
    '2027-01-01', // 새해
    '2027-02-06', // 설날 연휴
    '2027-02-07', // 설날
    '2027-02-08', // 설날 연휴
    '2027-02-09', // 설날 대체공휴일
    '2027-03-01', // 삼일절
    '2027-05-05', // 어린이날
    '2027-05-13', // 부처님 오신 날
    '2027-06-06', // 현충일
    '2027-06-07', // 현충일 대체공휴일
    '2027-07-17', // 제헌절
    '2027-08-15', // 광복절
    '2027-08-16', // 광복절 대체공휴일
    '2027-09-14', // 추석 연휴
    '2027-09-15', // 추석
    '2027-09-16', // 추석 연휴
    '2027-10-03', // 개천절
    '2027-10-04', // 개천절 대체공휴일
    '2027-10-09', // 한글날
    '2027-10-11', // 한글날 대체공휴일
    '2027-12-25', // 크리스마스
    '2027-12-27', // 크리스마스 대체공휴일
  ],
}

/** 표에 그 해 공휴일이 들어 있는지 */
export function hasHolidayData(year: number): boolean {
  return year in HOLIDAYS
}

/** 표가 수록한 연도 범위 */
export function holidayDataYears(): number[] {
  return Object.keys(HOLIDAYS)
    .map(Number)
    .sort((a, b) => a - b)
}

function toKey(year: number, month: number, day: number): string {
  return `${year}-${String(month + 1).padStart(2, '0')}-${String(day).padStart(2, '0')}`
}

/** 그 날짜가 공휴일인지. 표에 없는 연도는 항상 false */
export function isHoliday(year: number, month: number, day: number): boolean {
  return HOLIDAYS[year]?.includes(toKey(year, month, day)) ?? false
}

/** 그 달의 공휴일 중 평일에 걸린 것만. 주말과 겹친 공휴일은 어차피 쉬는 날이라 뺀다 */
export function weekdayHolidaysInMonth(year: number, month: number): string[] {
  const list = HOLIDAYS[year]
  if (!list) return []

  const prefix = `${year}-${String(month + 1).padStart(2, '0')}-`
  return list.filter((date) => {
    if (!date.startsWith(prefix)) return false
    const day = Number(date.slice(8, 10))
    const dow = new Date(year, month, day).getDay()
    return dow !== 0 && dow !== 6
  })
}
