# App Store 등록 정보

App Store Connect의 앱 정보·버전 화면에 그대로 옮겨 넣는 값. 주 언어는 한국어다.
iOS와 macOS가 앱 하나(번들 ID `dev.woosublee.salaryclock`)로 묶이므로 이름·부제·
개인정보·연령 등급은 한 번만 넣고, 설명·키워드·스크린샷은 플랫폼마다 넣는다
(아래 문구를 두 플랫폼에 똑같이 써도 된다 — macOS 차이는 설명 끝 문단에 있다).

글자 수 제한은 App Store Connect가 센다. 고치면 거기서 다시 확인할 것.

## 앱 정보 (공통)

| 항목 | 값 |
| --- | --- |
| 이름 (30자) | SalaryClock: 실시간 월급 시계 |
| 부제 (30자) | 지금까지 번 돈을 초 단위로 |
| 주 언어 | 한국어 |
| 번들 ID | dev.woosublee.salaryclock |
| SKU | salaryclock |
| 주 카테고리 | 금융 |
| 보조 카테고리 | 생산성 |
| 가격 | 무료 |
| 판매 국가 | 대한민국 (한국 공휴일·4대보험 기준이라 다른 나라에는 맞지 않는다) |
| 개인정보 처리방침 URL | https://sc.vicals.com/privacy |
| 지원 URL | https://sc.vicals.com/support |
| 마케팅 URL | https://sc.vicals.com |
| 저작권 | 2026 Woosub Lee |

"SalaryClock - Earnings Timer"라는 다른 앱이 이미 있어 이름을 `SalaryClock`
하나로는 쓰지 않는다. 홈 화면·메뉴바에 보이는 이름은 그대로 SalaryClock이다
(CFBundleDisplayName).

## 프로모션 텍스트 (170자, 심사 없이 언제든 바꿀 수 있음)

출근부터 퇴근까지, 오늘 번 돈이 초 단위로 올라갑니다. 연봉·월급·시급만 넣으면 끝.

## 키워드 (100자, 쉼표로 구분, 띄어쓰기 없이)

월급,연봉,시급,급여,실수령액,퇴근,출근,직장인,월급날,근무시간,타이머,계산기,돈,수입,메뉴바

## 설명 (iOS)

지금 이 순간까지 오늘 얼마를 벌었는지, 초 단위로 보여주는 시계입니다.

연봉·월급·시급 중 하나와 근무 시간만 넣으면 출근 시각부터 금액이 올라가기
시작합니다. 점심시간에는 멈추고, 퇴근하면 오늘 번 금액이 그대로 남습니다.

■ 실시간으로 올라가는 오늘의 금액
• 1초에 얼마씩 버는지, 퇴근까지 몇 시간 남았는지, 남은 금액은 얼마인지
• 출근 전·점심시간·퇴근 후·쉬는 날을 알아서 구분

■ 정확한 근무일 계산
• 한국 공휴일과 대체공휴일을 빼고 이번 달 근무일을 셉니다
• 연차를 쓴 날이나 주말 출근은 달력에서 눌러 바꿀 수 있습니다

■ 세전·실수령액
• 4대보험을 법정 요율로 빼고, 소득세는 추정치로 계산합니다
• 급여명세서의 공제율을 직접 넣으면 내 실수령액에 맞출 수 있습니다

■ 고르는 재미가 있는 시계
• 바늘 시계, 링, 해시계, 점, 카운트다운 등 10가지 시계 모양
• 밝은 화면·어두운 화면
• 회사에서는 눈 모양 버튼 하나로 금액을 가리고 시계로만 쓰기

■ 개인정보를 모으지 않습니다
• 회원가입도 광고도 없습니다
• 입력한 급여 정보는 이 기기 안에만 저장되고 밖으로 나가지 않습니다

## 설명 (macOS) — 위 설명에서 첫 두 문단만 바꾼다

메뉴바에서 오늘 번 돈이 초 단위로 올라갑니다.

연봉·월급·시급 중 하나와 근무 시간만 넣으면 출근 시각부터 메뉴바의 금액이
올라가기 시작합니다. 메뉴바를 누르면 시계와 퇴근까지 남은 시간이 열리고,
점심시간에는 멈추고, 퇴근하면 오늘 번 금액이 그대로 남습니다.

(이하 iOS 설명의 ■ 항목들과 같다. "눈 모양 버튼" 줄은 "눈 모양 버튼 하나로 메뉴바의
금액을 감추기"로, 마지막 묶음에 "로그인할 때 자동으로 켜기"를 더한다.)

## 이 버전의 새로운 기능

첫 버전에는 넣지 않는다(App Store Connect가 첫 버전에는 묻지 않는다).

## 앱 개인정보 (App Privacy)

- 데이터 수집: **수집하지 않음 (Data Not Collected)**
  - 설정은 기기의 UserDefaults에만 있고 서버가 없다.
  - iOS 앱은 하루 한 번 공휴일 자료(공개 JSON)를 GitHub에서 받지만 요청에
    사용자 정보를 싣지 않는다 — 수집이 아니다.
- 추적: 하지 않음
- 앱에 든 개인정보 매니페스트(PrivacyInfo.xcprivacy)와 같은 내용이다.

## 연령 등급

모든 질문에 "없음". 결과는 4+.

## 수출 규정 (암호화)

`ITSAppUsesNonExemptEncryption = NO`가 Info.plist에 있어 빌드마다 묻지 않는다.
HTTPS 말고는 암호화를 쓰지 않는다.

## 심사 메모 (App Review Information > Notes)

로그인이 필요 없어 데모 계정은 없다. 아래를 영어로 넣는다.

```
No account or login is required.

SalaryClock shows how much the user has earned so far today, updated every
second, based on their salary and working hours. Open Settings with the gear
icon (on macOS, click the menu bar item first to open the popover) to enter
an annual/monthly/hourly pay and working hours.

The amount only increases during working hours (default 09:00–18:00 KST,
weekdays, excluding Korean public holidays). Outside those hours the app shows
"off work" or "day off" — this is expected.

macOS: this is a menu bar app (LSUIElement). It has no Dock icon or main
window; look for the clock and amount in the menu bar after launch.

All data stays on device. The iOS app downloads a public holiday table
(JSON) from GitHub once a day; no user data is sent.
```

연락처는 App Store Connect 계정 정보를 쓴다.
