# 개발

사용 안내는 [README](../README.md)에 있습니다.

```bash
npm install
npm run dev      # http://localhost:3000
npm test
```

macOS 앱은 Swift로 작성되어 `macos/`에 있습니다. 계산 규칙은 웹과 공유하며,
`shared/golden/*.json`을 양쪽 테스트가 함께 읽으므로 규칙이 어긋나면 한쪽이
실패합니다.

앱 번들은 이 맥 키체인의 **Developer ID Application** 인증서로 서명합니다. Xcode ›
Settings › Accounts › Manage Certificates에서 한 번 만들어 두면 됩니다. 릴리스
(`scripts/release.sh`)는 DMG를 Apple에 공증받는데, 이때 쓸 App Store Connect API 키를
`xcrun notarytool store-credentials woosublee-notary --key <.p8> --key-id <ID> --issuer <Issuer ID>`로
한 번 저장해 둡니다. CI는 같은 값을 시크릿(`SIGNING_CERTIFICATE_BASE64`·`_PASSWORD`,
`ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8_BASE64`)으로 받습니다.

```bash
./scripts/install-app.sh                  # 빌드 후 /Applications에 설치
npm run swift:test:core
npm run swift:test:app
```

iOS 앱은 `ios/SalaryClock.xcodeproj`입니다. 계산은 `macos/SalaryClockCore`를,
시계 페이스·달력·화면 문구(`EarningsText.swift`)는 `macos/SalaryClockApp`의 SwiftUI
파일을 그대로 가져다 씁니다. 메인 화면과 설정 화면만 `ios/SalaryClock/`에 iOS용으로
따로 있습니다. Xcode에서 열어 실행하거나 아래처럼 빌드합니다. 개발 팀(`2L6ZW98RCP`)은 프로젝트에
지정돼 있습니다.

같은 Xcode 프로젝트에 Mac App Store용 `SalaryClockMac` 타깃도 있습니다. 맥 앱 소스를
그대로 쓰되 샌드박스를 켜고 Sparkle을 뺀(`APP_STORE`) 빌드입니다. App Store 출시
절차는 [`appstore/README.md`](../appstore/README.md)에 있습니다.

iOS 앱은 공휴일을 앱 업데이트 없이 갱신합니다. 알람 앱과 같은 서명된 자료
(`woosublee/kairos`의 `holiday-data/`)를 하루 한 번 받아, 서명과 파일 해시를 확인한 뒤
그 자료가 다루는 해만 앱에 든 표 대신 씁니다. 해마다 관보가 나면 그 자료만 갱신하면
됩니다(절차는 알람 앱 README의 "공휴일 자료 업데이트 방법"). 검증은
`SalaryClockCore/HolidayData.swift`, 내려받기는 `ios/SalaryClock/HolidayUpdater.swift`에
있습니다. 웹과 macOS 앱은 지금처럼 `lib/holidays.ts` 표를 씁니다.

웹에는 App Store 제출용 [개인정보 처리방침](https://sc.vicals.com/privacy)과
[지원](https://sc.vicals.com/support) 페이지가 있습니다.

```bash
xcodebuild -project ios/SalaryClock.xcodeproj -scheme SalaryClock \
  -destination 'generic/platform=iOS Simulator' build
./scripts/generate-ios-icon.sh            # 팔레트가 바뀌었을 때 iOS 아이콘을 다시 그린다
./scripts/generate-app-icon.sh --xcassets  # 같은 때 Mac App Store 타깃 아이콘도
./scripts/appstore-release.sh --upload     # iOS·Mac을 App Store Connect에 올린다
```

버전을 올리고 태그를 푸시하면 GitHub Actions가 릴리스를 발행합니다. 아이콘은
이미지가 아니라 코드로 그리며, 웹 파비콘은 `./scripts/generate-web-icons.sh`로
다시 만듭니다.

설계 배경은 [설계 문서](superpowers/specs/2026-09-22-macos-menubar-design.md)에
있습니다. Next.js · TypeScript · Tailwind CSS로 작성했고 서버 코드는 없습니다.
