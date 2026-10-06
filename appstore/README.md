# App Store 출시

iOS 앱과 Mac 메뉴바 앱을 App Store에 앱 하나로 낸다. 번들 ID가 같아
(`dev.woosublee.salaryclock`) App Store Connect가 두 플랫폼을 한 앱으로 묶는다 —
페이지도 하나고, 한쪽에서 받은 사람은 다른 쪽도 같은 앱으로 본다.

GitHub로 내는 DMG(`scripts/release.sh`, Sparkle 자동 업데이트)는 그대로 둔다.
두 채널의 차이:

| | App Store (Mac) | GitHub DMG |
| --- | --- | --- |
| 빌드 | `ios/SalaryClock.xcodeproj`의 `SalaryClockMac` 타깃 | `scripts/bundle-app.sh` (SwiftPM) |
| 샌드박스 | 켬 (`ios/SalaryClockMac.entitlements`) | 끔 |
| 업데이트 | App Store | Sparkle (`APP_STORE`가 꺼진 빌드에만 있음) |
| 설정 저장 위치 | 샌드박스 컨테이너 | `~/Library/Preferences` |

저장 위치가 달라서 DMG판에서 App Store판으로 옮기면 설정을 한 번 다시 넣어야 한다.

## 버전

iOS·Mac(App Store)·DMG 모두 `release/version.json` 하나를 따른다. 올리는 규칙은
DMG 릴리스와 같다. App Store Connect는 같은 빌드 번호를 두 번 받지 않으므로,
반려돼서 다시 올릴 때도 `buildNumber`를 올린다.

## 처음 한 번 (사람이 웹에서)

1. [App Store Connect](https://appstoreconnect.apple.com/apps) › 앱 › **+** › 신규 앱
   - 플랫폼: **iOS**와 **macOS** 둘 다 체크
   - 이름·주 언어·번들 ID·SKU: [`metadata.md`](metadata.md)의 앱 정보 표
   - 번들 ID 목록에 `dev.woosublee.salaryclock`가 없으면 `scripts/appstore-release.sh`를
     한 번 돌린다 — Xcode 자동 서명이 App ID를 등록한다.
2. 앱 정보·가격·앱 개인정보·연령 등급을 `metadata.md`대로 채운다.
3. iOS 앱의 "Apple Silicon Mac에서 사용 가능"은 **끈다**(가격 및 사용 가능 여부 화면).
   Mac에는 진짜 Mac 앱을 내므로 아이폰 화면을 창으로 띄우는 버전이 따로 보일
   이유가 없다.

## 릴리스마다

1. `release/version.json`을 올리고 커밋한다(DMG 릴리스와 같은 커밋이어도 된다).
2. 올린다.

   ```sh
   ./scripts/appstore-release.sh --upload        # iOS와 Mac 둘 다
   ./scripts/appstore-release.sh ios --upload    # 한쪽만
   ```

   이 맥의 Xcode에 개발자 계정이 로그인돼 있으면 된다. 인증서·프로필은 Xcode가
   만든다. CI에서 돌리려면 App Store Connect API 키를 환경 변수로 준다(스크립트
   머리 주석).
3. App Store Connect에서 빌드 처리가 끝나면(수 분~수십 분, 메일이 온다) 각
   플랫폼의 버전 화면에서 빌드를 고르고, 스크린샷·설명을 확인한 뒤 **심사에 제출**.

## 스크린샷

둘 다 평일 근무 시간(9~18시, 점심 제외)에 돌려야 금액이 올라가는 화면이 나온다.

- **iPhone (6.3인치, 1206×2622)**: `./scripts/appstore-screenshots.sh` → `screenshots/iphone/`.
  App Store Connect가 Dynamic Island 중형 디스플레이를 기준 크기로 받는다(6.9인치는
  거부). 메인·근무일 달력·설정·어두운 화면 순. 달력과 설정은 개발 빌드만 읽는
  `-screenshot` 실행 인자로 연 채 찍는다(`ios/SalaryClock/ScreenshotScene.swift`).
- **Mac (2880×1800)**: `./scripts/appstore-screenshots-mac.sh` → `screenshots/mac/`.
  화면을 캡처하지 않는다 — App Store 타깃 개발 빌드가 팝오버·설정 창을 PNG로 그려
  내고(`AppDelegate`의 `-screenshotOut`), `compose-mac-screenshot.swift`가 메뉴바와
  바탕 위에 놓는다. 화면 녹화 권한이 필요 없고 바탕화면이 섞이지 않는다.

## 등록 정보 반영

`appstore/metadata.json`이 기준이다. `node scripts/appstore-metadata.mjs [--screenshots]`가
App Store Connect API로 반영한다 — 단, API 키에 **앱 관리(App Manager)** 권한이 있어야
한다. 1.0.0 때 쓴 키는 "제품 개발" 권한이라 문구를 고칠 수 없어(403) 이 스크립트를
끝까지 돌려 보지 못했고(스크린샷 표시 종류 `APP_IPHONE_61`도 아직 확인 전),
1.0.0의 등록 정보는 웹 화면에서 같은 값으로 채웠다.
