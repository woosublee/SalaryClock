'use client'

/**
 * 통화 기호를 숫자보다 작게 그린다.
 *
 * Geist Mono의 ₩는 고정폭이라 숫자와 같은 칸을 차지하는데 글자 높이까지 숫자보다
 * 커서, 큰 글씨에서 기호가 금액보다 앞서 보인다. 폰트가 없어 폴백된 것이 아니다 —
 * latin-ext 서브셋이 이미 실려 있어 ₩도 Geist Mono로 그려진다. 글리프 자체의
 * 크기 차이라 폰트 설정이 아니라 표시에서 줄인다.
 *
 * 크기를 em으로 둔 이유: 금액(text-5xl)과 상태줄(text-sm)이 같은 비율로 따라온다.
 *
 * formatWon이 돌려주는 문자열을 그대로 받는다 — 기호와 숫자를 따로 만들지 않는
 * 이유는 통화 표기가 도메인 규칙이고 골든이 그 문자열을 고정하고 있어서다.
 */
export function Won({ text }: { text: string }) {
  // 첫 숫자 앞까지를 기호로 본다. ko-KR은 "₩166,666"이지만 로캘이 바뀌어도
  // 깨지지 않고, 숫자를 못 찾으면 통째로 그대로 그린다.
  const firstDigit = text.search(/\d/)
  if (firstDigit <= 0) return <>{text}</>

  return (
    <>
      <span className="text-[0.72em]">{text.slice(0, firstDigit)}</span>
      {text.slice(firstDigit)}
    </>
  )
}
