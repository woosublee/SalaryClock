# macOS 메뉴바 앱 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 적립 금액이 macOS 메뉴바에 1초마다 갱신되는 텍스트로 뜨고, 클릭하면 시계와 상세가 담긴 팝오버가 떨어지는 네이티브 앱을 만든다.

**Architecture:** 도메인 계산은 `macos/SalaryClockCore/`(Swift Package)에 순수 함수로 옮기고, `shared/golden/*.json`을 웹과 함께 읽어 두 구현이 같은 답을 내는지 테스트로 고정한다. 앱 타깃은 코어를 의존하기만 하는 AppKit 껍데기다 — `NSStatusItem` 타이틀을 1초 타이머로 갱신하고, 팝오버와 설정 창은 SwiftUI로 그린다.

**Tech Stack:** Swift 6.4, Swift Testing, SwiftPM, AppKit (`NSStatusItem`·`NSPopover`·`NSWindow`), SwiftUI, `ServiceManagement`

**Spec:** `docs/superpowers/specs/2026-09-22-macos-menubar-design.md`

## Global Constraints

- **스펙 12장의 3~7번을 담는다.** 1~2번(웹 규칙 변경, 골든 추출)은 이미 끝났다 — `feat/macos-menubar` 브랜치에 커밋돼 있다.
- **`SalaryClockCore`의 계산은 전부 순수 함수다.** `Date()`를 직접 부르지 않고 현재 시각을 인자로 받는다. 이 규칙이 테스트 가능성의 전부다.
- **시각은 epoch 밀리초 `Int`로 다룬다.** TypeScript가 `number`(ms)로 계산하므로 같은 단위를 쓰면 골든 값이 그대로 맞는다. `Date`로 바꾸는 건 표시 직전에만 한다.
- **금액과 비율은 `Double`.** 골든의 `166666.66666666666` 같은 값이 그대로 나와야 한다.
- **골든 비교 허용 오차는 상대 `1e-9`.** `#expect(abs(a - b) <= max(abs(b), 1.0) * 1e-9)`.
- **골든의 시각은 `[연, 월(0-based), 일, 시, 분, 초]` 배열이다.** 각 언어가 자기 로컬 타임존에서 다시 만든다. 월이 0-based인 것에 주의 — Swift `DateComponents.month`는 1-based라 **+1 해야 한다.**
- **UI 문구는 한국어.** 웹과 글자까지 같게 쓴다 (스펙 5.4).
- **색은 `shared/golden/palette.json`에서 생성한다.** hex를 손으로 적지 않는다. `hex`가 3자리(`#fff`)일 수 있고 `lab`이 `null`일 수 있다.
- **바늘 회전에 애니메이션을 걸지 않는다.** 360°→0°에서 역방향으로 한 바퀴 돈다.
- **새 Swift 의존성을 추가하지 않는다.** 표준 라이브러리와 Apple 프레임워크만 쓴다.
- **`swift build`·`swift test`는 반드시 `--scratch-path`를 붙여 iCloud 밖에서 빌드한다.** 이 저장소는 `~/Documents` 안에 있고 그 아래는 iCloud Drive가 동기화한다. iCloud가 빌드 산출물에 확장 속성을 붙이면 `codesign`이 `resource fork, Finder information, or similar detritus not allowed`로 실패한다 — 기본 `.build` 경로로는 테스트가 아예 돌지 않는다. 확인한 사실이다.
  ```bash
  swift test  --package-path macos/SalaryClockCore --scratch-path "$HOME/Library/Caches/salaryclock/core"
  swift test  --package-path macos/SalaryClockApp  --scratch-path "$HOME/Library/Caches/salaryclock/app"
  swift build --package-path macos/SalaryClockApp  --scratch-path "$HOME/Library/Caches/salaryclock/app"
  ```
  짧은 이름으로도 부를 수 있게 `package.json`에 `swift:test:core`·`swift:test:app`을 둔다 (Task 3). `scripts/bundle-app.sh`도 같은 경로를 쓴다 (Task 9).
- Swift 테스트: 위 명령. **아래 Task 본문에 `swift test --package-path ...`로만 적힌 곳은 전부 `--scratch-path`를 붙여 읽는다.**
- 웹 테스트(회귀 확인용): `npm test`
- 커밋 메시지는 한국어, `feat:` / `fix:` / `chore:` / `docs:` 접두사. 말미에 `Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>`.

### 스펙에서 의도적으로 벗어나는 것

스펙 4장은 `macos/SalaryClock.xcodeproj`를 전제한다. **이 계획은 Xcode 프로젝트를 만들지 않고 SwiftPM 실행 파일 + 번들 조립 스크립트로 간다.** `.pbxproj`는 손으로 쓰기 어렵고 diff가 읽히지 않아 리뷰가 불가능한 반면, `Package.swift`와 20줄짜리 셸 스크립트는 둘 다 읽힌다. `swift build`는 AppKit·SwiftUI를 그대로 컴파일하고, `.app` 번들은 디렉터리 구조 + `Info.plist` + ad-hoc 서명이면 끝이다. Task 12에서 스펙 4장을 이 구조로 고친다.

---

## File Structure

```
macos/
  SalaryClockCore/
    Package.swift
    Sources/SalaryClockCore/
      Time.swift            HH:mm 파싱, 분↔ms, 로컬 자정
      Settings.swift        Codable 설정 + 기본값 + 검증
      Shift.swift           설정 + 현재시각 → 시프트
      Holidays.swift        대한민국 공휴일 표 (2026·2027)
      DayOff.swift          isDefaultOff / isDayOff / dateKey
      Workdays.swift        월별 근무일수
      Deductions.swift      4대보험 + 소득세 추정
      Salary.swift          Phase, Earnings, computeEarnings
      Format.swift          통화·기간·날짜 표시 문자열
      ClockGeometry.swift   바늘 각도, 문자판 호
      Palette.swift         생성물 — 손으로 고치지 않는다
    Tests/SalaryClockCoreTests/
      GoldenLoader.swift    shared/golden/*.json 로더
      ShiftTests.swift      · WorkdaysTests.swift · DeductionsTests.swift
      SalaryTests.swift     · FormatTests.swift · ClockGeometryTests.swift
  SalaryClockApp/
    Package.swift
    Sources/SalaryClockApp/
      main.swift            NSApplication 부팅
      AppDelegate.swift     상태 아이템·타이머·창 수명
      MenuBarTitle.swift    Earnings → 메뉴바 문자열과 아이콘
      RingIcon.swift        진행률 링을 NSImage로
      PopoverView.swift     SwiftUI 팝오버
      MinimalFaceView.swift SwiftUI Canvas 시계
      SettingsView.swift    SwiftUI 설정 폼
      SettingsStore.swift   UserDefaults 저장 + 변경 알림
      Theme.swift           Palette를 SwiftUI Color로
  scripts/
    generate-palette-swift.ts   palette.json → Palette.swift
    bundle-app.sh               swift build → SalaryClock.app
    install-app.sh              /Applications 설치
scripts/generate-golden.ts      (수정) format·clock 골든 추가
shared/golden/format.json       (신규)
shared/golden/clock.json        (신규)
```

의존 방향은 웹과 같다: `Time → Settings → Shift → {Salary, ClockGeometry}`, `DayOff → Holidays`, `Workdays → DayOff`. 앱은 코어를 한 방향으로만 의존한다.

**골든 파일을 Swift 패키지 리소스로 복사하지 않는다.** SPM 리소스는 타깃 디렉터리 안에 있어야 하는데, 복사하면 단일 출처가 깨진다. 대신 테스트가 `#filePath`에서 저장소 루트를 거슬러 올라가 원본을 읽는다 (Task 2).

---

### Task 1: 웹에 format·clock 골든을 추가한다

**Files:**
- Modify: `scripts/generate-golden.ts`
- Modify: `lib/__tests__/golden.test.ts`
- Create: `shared/golden/format.json`, `shared/golden/clock.json` (생성물)

**Interfaces:**
- Consumes: `lib/format.ts`의 `formatWon`·`formatPerSecond`·`formatDuration`·`formatClockTime`·`formatDateKo`·`formatKoreanUnits`, `lib/clock.ts`의 `handAngles`·`dialAngle`·`arcBetween`
- Produces: `shared/golden/format.json`, `shared/golden/clock.json` — Task 8의 Swift 테스트가 읽는다

최종 리뷰가 남긴 구멍이다. 스펙 5.4는 **"금액은 항상 내림한다 — 반올림하면 아직 벌지 않은 1원이 먼저 뜬다"**를 공유 규칙으로 못박았는데 이를 검증하는 골든이 없다. Swift `NumberFormatter`의 기본 반올림은 `.halfEven`이라, **가장 자연스럽게 짠 Swift 구현이 바로 이 규칙을 어긴다.** 스위프 초침(`handAngles`가 밀리초를 버리지 않는 것)도 마찬가지로 미검증이다.

- [ ] **Step 1: 생성 스크립트에 두 블록을 추가한다**

`scripts/generate-golden.ts`에서 `write('workdays.json', workdays)` 바로 위에 넣는다:

```ts
/** 내림 규칙과 소수 자리 처리를 고정한다. 반올림하면 안 벌은 돈이 먼저 뜬다. */
const FORMAT_AMOUNTS = [0, 0.4, 0.9, 1, 999.99, 1234.56, 83412.49, 166666.66666666666, 1_0000_0000]

const formats = {
  won: FORMAT_AMOUNTS.map((n) => ({ n, expected: formatWon(n) })),
  wonOneDecimal: FORMAT_AMOUNTS.map((n) => ({ n, expected: formatWon(n, 1) })),
  perSecond: [0, 0.04, 5.79, 99.94, 99.96, 100, 1234.5].map((n) => ({
    n,
    expected: formatPerSecond(n),
  })),
  duration: [0, -1, 999, 1000, 59_000, 60_000, 3_599_000, 3_600_000, 32_401_000, 86_399_000].map(
    (ms) => ({ ms, expected: formatDuration(ms) }),
  ),
  koreanUnits: [0, 1, 9999, 10_000, 100_000_000, 123_456_789, 40_000_000].map((n) => ({
    n,
    expected: formatKoreanUnits(n),
  })),
  dateKo: MOMENTS.map((m) => ({ at: m.at, expected: formatDateKo(ms(m.at)) })),
  clockTime: MOMENTS.map((m) => ({ at: m.at, expected: formatClockTime(ms(m.at)) })),
}

/** 스위프 운동. 밀리초를 버리면 1초마다 6도씩 튀는 쿼츠 시계가 된다. */
const CLOCK_MOMENTS: [number, number, number, number, number, number, number][] = [
  [2026, 8, 22, 0, 0, 0, 0],
  [2026, 8, 22, 0, 0, 0, 500],
  [2026, 8, 22, 3, 0, 0, 0],
  [2026, 8, 22, 9, 30, 15, 250],
  [2026, 8, 22, 12, 0, 0, 0],
  [2026, 8, 22, 15, 45, 30, 750],
  [2026, 8, 22, 23, 59, 59, 999],
]

const clocks = {
  hands: CLOCK_MOMENTS.map((c) => {
    const t = new Date(c[0], c[1], c[2], c[3], c[4], c[5], c[6]).getTime()
    const h = handAngles(t)
    return { at: c, expected: { hour: h.hour, minute: h.minute, second: h.second } }
  }),
  dial: CLOCK_MOMENTS.map((c) => {
    const t = new Date(c[0], c[1], c[2], c[3], c[4], c[5], c[6]).getTime()
    return { at: c, expected: dialAngle(t) }
  }),
  arcs: MOMENTS.map((m) => {
    const sh = resolveShift(SETTINGS[m.settings], ms(m.at))
    const a = arcBetween(sh.startMs, sh.endMs)
    return {
      label: m.label,
      settings: m.settings,
      at: m.at,
      expected: { startDeg: a.startDeg, sweepDeg: a.sweepDeg },
    }
  }),
}

write('format.json', formats)
write('clock.json', clocks)
```

`CLOCK_MOMENTS`에 밀리초 자리가 따로 있는 이유: `MOMENTS`는 초 단위까지만 적어서 스위프 운동을 검증할 수 없다. `.500`과 `.250`이 들어가야 "밀리초를 버리지 않는다"가 확인된다.

파일 맨 위 import에 필요한 것을 추가한다:

```ts
import {
  formatWon,
  formatPerSecond,
  formatDuration,
  formatClockTime,
  formatDateKo,
  formatKoreanUnits,
} from '@/lib/format'
import { handAngles, dialAngle, arcBetween } from '@/lib/clock'
```

- [ ] **Step 2: 생성해서 눈으로 확인한다**

```bash
npm run golden
python3 -c "
import json
f = json.load(open('shared/golden/format.json'))
print([x['expected'] for x in f['won'][:4]])
print([x['expected'] for x in f['wonOneDecimal'][:4]])
c = json.load(open('shared/golden/clock.json'))
print(c['hands'][0]['expected'], c['hands'][1]['expected'])
"
```

Expected: `won`의 0.4와 0.9가 **둘 다 `₩0`** 이어야 한다(내림). `₩1`이 나오면 `formatWon`이 반올림하고 있다는 뜻이니 멈추고 보고한다.
`hands[0]`(00:00:00.000)은 셋 다 `0`, `hands[1]`(00:00:00.500)은 `second`가 `3`(=0.5/60×360)이어야 한다. `0`이면 밀리초가 버려지고 있다.

- [ ] **Step 3: 골든 테스트에 두 블록을 추가한다**

`lib/__tests__/golden.test.ts` 맨 끝에 붙인다:

```ts
describe('golden — format', () => {
  const f = read('format.json')

  it('케이스가 비어 있지 않다', () => {
    expect(f.won.length).toBeGreaterThan(0)
  })

  for (const c of f.won) {
    it(`formatWon(${c.n})`, () => expect(formatWon(c.n)).toBe(c.expected))
  }
  for (const c of f.wonOneDecimal) {
    it(`formatWon(${c.n}, 1)`, () => expect(formatWon(c.n, 1)).toBe(c.expected))
  }
  for (const c of f.perSecond) {
    it(`formatPerSecond(${c.n})`, () => expect(formatPerSecond(c.n)).toBe(c.expected))
  }
  for (const c of f.duration) {
    it(`formatDuration(${c.ms})`, () => expect(formatDuration(c.ms)).toBe(c.expected))
  }
  for (const c of f.koreanUnits) {
    it(`formatKoreanUnits(${c.n})`, () => expect(formatKoreanUnits(c.n)).toBe(c.expected))
  }
  for (const c of f.dateKo) {
    it(`formatDateKo(${c.at.join(',')})`, () => expect(formatDateKo(ms(c.at))).toBe(c.expected))
  }
  for (const c of f.clockTime) {
    it(`formatClockTime(${c.at.join(',')})`, () =>
      expect(formatClockTime(ms(c.at))).toBe(c.expected))
  }
})

describe('golden — clock', () => {
  const c = read('clock.json')
  const msMilli = (a: number[]) => new Date(a[0], a[1], a[2], a[3], a[4], a[5], a[6]).getTime()

  it('케이스가 비어 있지 않다', () => {
    expect(c.hands.length).toBeGreaterThan(0)
  })

  for (const h of c.hands) {
    it(`handAngles(${h.at.join(',')})`, () => {
      const got = handAngles(msMilli(h.at))
      expect(got.hour).toBeCloseTo(h.expected.hour, 9)
      expect(got.minute).toBeCloseTo(h.expected.minute, 9)
      expect(got.second).toBeCloseTo(h.expected.second, 9)
    })
  }
  for (const d of c.dial) {
    it(`dialAngle(${d.at.join(',')})`, () =>
      expect(dialAngle(msMilli(d.at))).toBeCloseTo(d.expected, 9))
  }
  for (const a of c.arcs) {
    it(`arcBetween — ${a.label} (${a.settings})`, () => {
      const sh = resolveShift(SETTINGS[a.settings], ms(a.at))
      const got = arcBetween(sh.startMs, sh.endMs)
      expect(got.startDeg).toBeCloseTo(a.expected.startDeg, 9)
      expect(got.sweepDeg).toBeCloseTo(a.expected.sweepDeg, 9)
    })
  }
})
```

파일 맨 위 import에 `formatWon` 등과 `handAngles`·`dialAngle`·`arcBetween`을 추가한다.

- [ ] **Step 4: 전부 통과하는지 확인한다**

```bash
npm test && npx tsc --noEmit && npm run lint
npm run golden && git diff --exit-code shared/golden/
TZ=UTC npx vitest run
```

Expected: 전부 통과, 재생성 diff 없음, 다른 타임존에서도 통과

- [ ] **Step 5: 커밋**

```bash
git add scripts/generate-golden.ts lib/__tests__/golden.test.ts shared/golden
git commit -m "$(cat <<'EOF'
chore: 표시 형식과 시계 각도에도 골든을 건다

스펙 5.4의 "금액은 항상 내림한다"와 스위프 운동(밀리초를 버리지 않는다)이
공유 규칙인데 검증하는 골든이 없었다. Swift NumberFormatter의 기본
반올림이 halfEven이라, 가장 자연스럽게 짠 Swift 구현이 바로 이 규칙을
어긴다.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: Swift 패키지와 골든 로더

**Files:**
- Create: `macos/SalaryClockCore/Package.swift`
- Create: `macos/SalaryClockCore/Sources/SalaryClockCore/Time.swift`
- Create: `macos/SalaryClockCore/Tests/SalaryClockCoreTests/GoldenLoader.swift`
- Create: `macos/SalaryClockCore/Tests/SalaryClockCoreTests/GoldenLoaderTests.swift`

**Interfaces:**
- Consumes: `shared/golden/*.json` (Task 1까지의 산출물)
- Produces:
  - `Golden.url(_ name: String) -> URL`, `Golden.decode<T: Decodable>(_:as:) -> T`
  - `Golden.ms(_ clock: [Int]) -> Int` — `[연, 월(0-based), 일, 시, 분, 초]`를 epoch ms로
  - `Golden.msOrNull(_ clock: [Int]?) -> Int?`
  - `expectClose(_ got: Double, _ want: Double, _ label: String)`
  - `MS_PER_MINUTE`, `MS_PER_HOUR`, `MS_PER_DAY`, `startOfLocalDay(_:)`

- [ ] **Step 1: 패키지를 만든다**

`macos/SalaryClockCore/Package.swift`:

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SalaryClockCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "SalaryClockCore", targets: ["SalaryClockCore"])
    ],
    targets: [
        .target(name: "SalaryClockCore"),
        .testTarget(name: "SalaryClockCoreTests", dependencies: ["SalaryClockCore"]),
    ]
)
```

- [ ] **Step 2: 실패하는 테스트를 먼저 쓴다**

`macos/SalaryClockCore/Tests/SalaryClockCoreTests/GoldenLoaderTests.swift`:

```swift
import Testing
import Foundation
@testable import SalaryClockCore

@Test("골든 디렉터리를 찾는다")
func findsGoldenDirectory() throws {
    #expect(FileManager.default.fileExists(atPath: Golden.url("settings.json").path))
}

@Test("설정 골든을 읽는다")
func decodesSettingsGolden() throws {
    let all: [String: Settings] = try Golden.decode("settings.json", as: [String: Settings].self)
    #expect(all.count == 9)
    let d = try #require(all["default"])
    #expect(d.payAmount == 40_000_000)
    #expect(d.workStart == "09:00")
    #expect(d.lunchMinutes == 60)
}

@Test("골든의 시각 배열을 로컬 시각으로 되돌린다")
func convertsClockArray() throws {
    let got = Golden.ms([2026, 8, 22, 9, 0, 0])
    var c = DateComponents()
    c.year = 2026; c.month = 9; c.day = 22; c.hour = 9; c.minute = 0; c.second = 0
    let want = Calendar.current.date(from: c)!
    #expect(got == Int(want.timeIntervalSince1970 * 1000))
}
```

- [ ] **Step 3: 테스트가 실패하는지 확인한다**

```bash
swift test --package-path macos/SalaryClockCore
```

Expected: 컴파일 실패 — `Golden`도 `Settings`도 아직 없다

- [ ] **Step 4: `Time.swift`를 쓴다**

`macos/SalaryClockCore/Sources/SalaryClockCore/Time.swift`:

```swift
import Foundation

public let MS_PER_MINUTE = 60_000
public let MS_PER_HOUR = 3_600_000
public let MS_PER_DAY = 86_400_000

/// "HH:mm" 형식인지. 24시간제, 00:00~23:59만 통과한다.
public func isValidHHmm(_ v: String) -> Bool {
    guard v.count == 5 else { return false }
    let parts = v.split(separator: ":", omittingEmptySubsequences: false)
    guard parts.count == 2, parts[0].count == 2, parts[1].count == 2,
          let h = Int(parts[0]), let m = Int(parts[1]),
          parts[0].allSatisfy(\.isNumber), parts[1].allSatisfy(\.isNumber)
    else { return false }
    return (0...23).contains(h) && (0...59).contains(m)
}

/// "HH:mm" → 자정 이후 분. 형식이 깨졌으면 nil.
public func parseHHmm(_ v: String) -> Int? {
    guard isValidHHmm(v) else { return nil }
    let parts = v.split(separator: ":")
    return Int(parts[0])! * 60 + Int(parts[1])!
}

public func formatHHmm(_ minutes: Int) -> String {
    let m = ((minutes % 1440) + 1440) % 1440
    return String(format: "%02d:%02d", m / 60, m % 60)
}

/// 자정을 넘는 구간에도 항상 0 이상. 시작과 끝이 같으면 0.
public func durationMinutes(_ startMin: Int, _ endMin: Int) -> Int {
    (((endMin - startMin) % 1440) + 1440) % 1440
}

/// 그 시각이 속한 로컬 날짜의 자정. epoch ms.
public func startOfLocalDay(_ now: Int) -> Int {
    let date = Date(timeIntervalSince1970: Double(now) / 1000)
    let start = Calendar.current.startOfDay(for: date)
    return Int((start.timeIntervalSince1970 * 1000).rounded())
}
```

`parseHHmm`이 throw 대신 `nil`을 돌려주는 것이 TypeScript와 다르다. TS는 zod 검증 뒤에만 불리지만 Swift는 옵셔널이 더 자연스럽고, 부르는 쪽이 이미 검증된 값을 쓰므로 `!`가 아니라 `guard`로 받는다.

- [ ] **Step 5: `Settings.swift`를 쓴다**

`macos/SalaryClockCore/Sources/SalaryClockCore/Settings.swift`:

```swift
import Foundation

public enum PayMode: String, Codable, Sendable { case annual, monthly, hourly }
public enum WorkDaysMode: String, Codable, Sendable { case auto, calendar, manual }
public enum ThemeMode: String, Codable, Sendable { case light, dark }

/// 웹 `lib/settings.ts`의 Settings와 필드 이름·타입이 1:1로 맞아야 한다.
/// shared/golden/settings.json이 이 구조로 그대로 디코드된다.
public struct Settings: Codable, Equatable, Sendable {
    public var payMode: PayMode
    public var payAmount: Double
    public var workDaysMode: WorkDaysMode
    public var workDaysPerMonth: Double
    public var dayOverrides: [String]
    public var workStart: String
    public var workEnd: String
    public var lunchEnabled: Bool
    public var lunchStart: String
    public var lunchMinutes: Int
    public var netPay: Bool
    public var deductionRate: Double?
    public var clockStyle: String
    public var hideAmount: Bool
    public var theme: ThemeMode

    public init(
        payMode: PayMode = .annual,
        payAmount: Double = 40_000_000,
        workDaysMode: WorkDaysMode = .auto,
        workDaysPerMonth: Double = 21,
        dayOverrides: [String] = [],
        workStart: String = "09:00",
        workEnd: String = "18:00",
        lunchEnabled: Bool = true,
        lunchStart: String = "12:00",
        lunchMinutes: Int = 60,
        netPay: Bool = false,
        deductionRate: Double? = nil,
        clockStyle: String = "minimal",
        hideAmount: Bool = false,
        theme: ThemeMode = .light
    ) {
        self.payMode = payMode; self.payAmount = payAmount
        self.workDaysMode = workDaysMode; self.workDaysPerMonth = workDaysPerMonth
        self.dayOverrides = dayOverrides
        self.workStart = workStart; self.workEnd = workEnd
        self.lunchEnabled = lunchEnabled; self.lunchStart = lunchStart
        self.lunchMinutes = lunchMinutes
        self.netPay = netPay; self.deductionRate = deductionRate
        self.clockStyle = clockStyle; self.hideAmount = hideAmount; self.theme = theme
    }

    public static let `default` = Settings()
}
```

`deductionRate`는 JSON에 `null`로 들어오므로 `Double?`이다. `payAmount`와 `workDaysPerMonth`가 `Double`인 것은 TS의 `number`와 산술 결과를 맞추기 위해서다.

- [ ] **Step 6: 골든 로더를 쓴다**

`macos/SalaryClockCore/Tests/SalaryClockCoreTests/GoldenLoader.swift`:

```swift
import Foundation
import Testing

/// shared/golden/*.json 을 저장소 원본에서 직접 읽는다.
///
/// SPM 리소스로 복사하지 않는 이유: 복사본이 생기는 순간 단일 출처가 깨지고,
/// 웹이 골든을 다시 뽑아도 Swift가 옛 값을 보게 된다. #filePath에서
/// 저장소 루트를 거슬러 올라가면 원본을 그대로 읽을 수 있다.
enum Golden {
    /// .../macos/SalaryClockCore/Tests/SalaryClockCoreTests/GoldenLoader.swift → 저장소 루트
    static let root: URL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()  // SalaryClockCoreTests
        .deletingLastPathComponent()  // Tests
        .deletingLastPathComponent()  // SalaryClockCore
        .deletingLastPathComponent()  // macos
        .deletingLastPathComponent()  // 저장소 루트

    static func url(_ name: String) -> URL {
        root.appendingPathComponent("shared/golden").appendingPathComponent(name)
    }

    static func decode<T: Decodable>(_ name: String, as type: T.Type) throws -> T {
        let data = try Data(contentsOf: url(name))
        return try JSONDecoder().decode(T.self, from: data)
    }

    /// 골든의 [연, 월(0-based), 일, 시, 분, 초] → epoch ms.
    /// 월이 0-based인 것에 주의 — DateComponents.month는 1-based다.
    static func ms(_ c: [Int]) -> Int {
        var comps = DateComponents()
        comps.year = c[0]
        comps.month = c[1] + 1
        comps.day = c[2]
        comps.hour = c[3]
        comps.minute = c[4]
        comps.second = c[5]
        if c.count > 6 { comps.nanosecond = c[6] * 1_000_000 }
        let date = Calendar.current.date(from: comps)!
        return Int((date.timeIntervalSince1970 * 1000).rounded())
    }

    static func msOrNull(_ c: [Int]?) -> Int? {
        guard let c else { return nil }
        return ms(c)
    }
}

/// 상대 오차 1e-9로 비교한다. 실패하면 어느 값이 어긋났는지 라벨과 함께 남긴다.
func expectClose(
    _ got: Double, _ want: Double, _ label: String,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    let tolerance = max(abs(want), 1.0) * 1e-9
    #expect(
        abs(got - want) <= tolerance,
        "\(label): got \(got), want \(want)",
        sourceLocation: sourceLocation
    )
}
```

- [ ] **Step 7: 테스트가 통과하는지 확인한다**

```bash
swift test --package-path macos/SalaryClockCore
```

Expected: 3개 PASS

`Golden.root`가 틀린 디렉터리를 가리키면 첫 테스트가 실패한다. 그러면 `#filePath`를 출력해 몇 단계를 올라가야 하는지 세어 고친다.

- [ ] **Step 8: 커밋**

```bash
git add macos/SalaryClockCore
git commit -m "$(cat <<'EOF'
feat: SalaryClockCore 패키지와 골든 로더

골든 파일을 SPM 리소스로 복사하지 않고 #filePath에서 저장소 루트를
거슬러 올라가 원본을 읽는다. 복사본이 생기면 단일 출처가 깨진다.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: Shift

**Files:**
- Create: `macos/SalaryClockCore/Sources/SalaryClockCore/Shift.swift`
- Create: `macos/SalaryClockCore/Tests/SalaryClockCoreTests/ShiftTests.swift`

**Interfaces:**
- Consumes: `Settings`, `parseHHmm`, `durationMinutes`, `startOfLocalDay`, `MS_PER_MINUTE`, `MS_PER_DAY`, `Golden`
- Produces:
  - `struct Shift { startMs, endMs: Int; lunchStartMs, lunchEndMs: Int?; paidMs: Int }`
  - `resolveShift(_ s: Settings, _ now: Int) -> Shift`
  - `paidMsBetween(_ shift: Shift, _ from: Int, _ to: Int) -> Int`

원본은 `lib/shift.ts`다. 규칙은 그 파일의 주석이 설명한다 — 진행 중 → 오늘 안에 끝난 → 오늘 시작할, 세 단계.

- [ ] **Step 1: 골든 테스트를 먼저 쓴다**

`macos/SalaryClockCore/Tests/SalaryClockCoreTests/ShiftTests.swift`:

```swift
import Testing
import Foundation
@testable import SalaryClockCore

struct ShiftCase: Decodable {
    struct Expected: Decodable {
        let start: [Int]
        let end: [Int]
        let lunchStart: [Int]?
        let lunchEnd: [Int]?
        let paidMs: Int
    }
    let label: String
    let settings: String
    let at: [Int]
    let expected: Expected
}

@Test("골든 — shift")
func goldenShift() throws {
    let settings: [String: Settings] = try Golden.decode("settings.json", as: [String: Settings].self)
    let cases: [ShiftCase] = try Golden.decode("shift.json", as: [ShiftCase].self)
    #expect(cases.count > 0)

    for c in cases {
        let s = try #require(settings[c.settings], "알 수 없는 설정: \(c.settings)")
        let got = resolveShift(s, Golden.ms(c.at))
        let what = "\(c.label) (\(c.settings))"

        #expect(got.startMs == Golden.ms(c.expected.start), "\(what) startMs")
        #expect(got.endMs == Golden.ms(c.expected.end), "\(what) endMs")
        #expect(got.lunchStartMs == Golden.msOrNull(c.expected.lunchStart), "\(what) lunchStartMs")
        #expect(got.lunchEndMs == Golden.msOrNull(c.expected.lunchEnd), "\(what) lunchEndMs")
        #expect(got.paidMs == c.expected.paidMs, "\(what) paidMs")
    }
}

@Test("paidMsBetween — 점심을 가로지르면 점심만큼 뺀다")
func paidMsAcrossLunch() {
    let shift = resolveShift(.default, Golden.ms([2026, 8, 22, 14, 0, 0]))
    let from = Golden.ms([2026, 8, 22, 11, 0, 0])
    let to = Golden.ms([2026, 8, 22, 14, 0, 0])
    #expect(paidMsBetween(shift, from, to) == 2 * MS_PER_HOUR)
}

@Test("paidMsBetween — 시프트 밖은 잘라낸다")
func paidMsClamps() {
    let shift = resolveShift(.default, Golden.ms([2026, 8, 22, 14, 0, 0]))
    #expect(paidMsBetween(shift, shift.startMs - MS_PER_HOUR, shift.startMs) == 0)
    #expect(paidMsBetween(shift, shift.endMs, shift.endMs + MS_PER_HOUR) == 0)
    #expect(paidMsBetween(shift, shift.startMs, shift.endMs) == shift.paidMs)
}
```

- [ ] **Step 2: 실패를 확인한다**

```bash
swift test --package-path macos/SalaryClockCore
```

Expected: 컴파일 실패 — `Shift`·`resolveShift`·`paidMsBetween` 없음

- [ ] **Step 3: `Shift.swift`를 쓴다**

```swift
import Foundation

public struct Shift: Equatable, Sendable {
    public let startMs: Int
    public let endMs: Int
    public let lunchStartMs: Int?
    public let lunchEndMs: Int?
    /// 시프트 길이에서 무급 점심을 뺀 시간
    public let paidMs: Int
}

private func buildShift(_ s: Settings, _ dayStart: Int) -> Shift {
    let workStartMin = parseHHmm(s.workStart) ?? 0
    let shiftMin = durationMinutes(workStartMin, parseHHmm(s.workEnd) ?? 0)

    let startMs = dayStart + workStartMin * MS_PER_MINUTE
    let endMs = startMs + shiftMin * MS_PER_MINUTE

    var lunchStartMs: Int?
    var lunchEndMs: Int?
    var lunchMs = 0

    if s.lunchEnabled {
        let offsetMin = durationMinutes(workStartMin, parseHHmm(s.lunchStart) ?? 0)
        let ls = startMs + offsetMin * MS_PER_MINUTE
        lunchStartMs = ls
        lunchEndMs = ls + s.lunchMinutes * MS_PER_MINUTE
        lunchMs = s.lunchMinutes * MS_PER_MINUTE
    }

    return Shift(
        startMs: startMs, endMs: endMs,
        lunchStartMs: lunchStartMs, lunchEndMs: lunchEndMs,
        paidMs: endMs - startMs - lunchMs
    )
}

/// 그 시각을 품고 있으면 true. 시작은 포함, 끝은 제외.
private func contains(_ shift: Shift, _ now: Int) -> Bool {
    now >= shift.startMs && now < shift.endMs
}

/// 화면에 보여줄 시프트.
///
///   1. now를 품는 시프트가 있으면        → 그것        (근무 중 · 점심)
///   2. 없고, 오늘 안에 끝난 것이 있으면  → 그것        (퇴근 후 — 총액 유지)
///   3. 그 외                              → 오늘 시작할 시프트 (출근 전 — 0원)
///
/// 원본은 lib/shift.ts다. 자정을 특별히 다루지 않는데도 초기화가 나오고,
/// 야간근무(22:00–06:00)는 1단계에 걸려 자정에 끊기지 않는다.
public func resolveShift(_ s: Settings, _ now: Int) -> Shift {
    let today = startOfLocalDay(now)
    let yesterday = buildShift(s, today - MS_PER_DAY)
    let todayShift = buildShift(s, today)
    // tomorrow는 고정 오프셋 지역에서는 1단계에 걸리지 않지만, DST fall-back으로
    // 로컬 하루가 25시간인 날에는 now가 today + MS_PER_DAY를 넘을 수 있다.
    let tomorrow = buildShift(s, today + MS_PER_DAY)

    for c in [yesterday, todayShift, tomorrow] where contains(c, now) {
        return c
    }

    if let ended = [yesterday, todayShift].first(where: { $0.endMs <= now && $0.endMs > today }) {
        return ended
    }

    return todayShift
}

/// 두 시각 사이의 유급 시간(ms). 시프트 밖은 잘라내고 점심은 뺀다.
public func paidMsBetween(_ shift: Shift, _ from: Int, _ to: Int) -> Int {
    let lo = max(from, shift.startMs)
    let hi = min(to, shift.endMs)
    if hi <= lo { return 0 }

    var paid = hi - lo
    if let ls = shift.lunchStartMs, let le = shift.lunchEndMs {
        let overlap = min(hi, le) - max(lo, ls)
        if overlap > 0 { paid -= overlap }
    }
    return paid
}
```

- [ ] **Step 4: 통과를 확인한다**

```bash
swift test --package-path macos/SalaryClockCore
```

Expected: 전부 PASS. 골든 32케이스가 한 테스트 안에서 돈다

- [ ] **Step 5: 다른 타임존에서도 확인한다**

```bash
TZ=UTC swift test --package-path macos/SalaryClockCore
TZ=America/New_York swift test --package-path macos/SalaryClockCore
```

Expected: 둘 다 PASS. 골든이 로컬 시각 배열이라 타임존에 무관해야 한다. 실패하면 `Golden.ms`나 `startOfLocalDay`가 UTC를 섞어 쓰고 있다는 뜻이다.

- [ ] **Step 6: 커밋**

```bash
git add macos/SalaryClockCore
git commit -m "$(cat <<'EOF'
feat: Shift를 Swift로 옮긴다

lib/shift.ts의 3단계 규칙을 그대로 옮기고 골든 32케이스로 고정한다.
타임존 세 곳에서 통과를 확인했다.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: Holidays · DayOff · Workdays

**Files:**
- Create: `macos/SalaryClockCore/Sources/SalaryClockCore/Holidays.swift`
- Create: `macos/SalaryClockCore/Sources/SalaryClockCore/DayOff.swift`
- Create: `macos/SalaryClockCore/Sources/SalaryClockCore/Workdays.swift`
- Create: `macos/SalaryClockCore/Tests/SalaryClockCoreTests/WorkdaysTests.swift`

**Interfaces:**
- Consumes: `Settings`, `Golden`
- Produces:
  - `hasHolidayData(_ year: Int) -> Bool`, `isHoliday(_ year: Int, _ month: Int, _ day: Int) -> Bool` (month는 0-based)
  - `dateKey(_ year: Int, _ month: Int, _ day: Int) -> String` — `"YYYY-MM-DD"`
  - `isDefaultOff(_ year: Int, _ month: Int, _ day: Int) -> Bool`
  - `isDayOff(_ overrides: [String], _ dateMs: Int) -> Bool`
  - `weekdaysInMonth(_ now: Int) -> Int`, `workdaysInMonth(_ now: Int) -> Int`
  - `effectiveWorkDays(_ s: Settings, _ now: Int) -> Double`
  - `struct WorkdayInfo { weekdays, holidays, workdays: Int; hasHolidayData: Bool }`, `workdayInfo(_ now: Int) -> WorkdayInfo`

**월 인자는 전부 0-based다.** 웹과 맞추기 위해서다. `DateComponents`로 넘길 때만 +1 한다.

- [ ] **Step 1: 골든 테스트를 먼저 쓴다**

`macos/SalaryClockCore/Tests/SalaryClockCoreTests/WorkdaysTests.swift`:

```swift
import Testing
import Foundation
@testable import SalaryClockCore

struct WorkdaysGolden: Decodable {
    struct Case: Decodable {
        struct Expected: Decodable {
            let autoWorkDays: Double
            let isDayOff: Bool
            let isDayOffWithOverride: Bool
        }
        let at: [Int]
        let expected: Expected
    }
    let overrides: [String]
    let cases: [Case]
}

@Test("골든 — workdays")
func goldenWorkdays() throws {
    let g: WorkdaysGolden = try Golden.decode("workdays.json", as: WorkdaysGolden.self)
    #expect(g.cases.count > 0)

    for c in g.cases {
        let now = Golden.ms(c.at)
        let what = c.at.map(String.init).joined(separator: ",")

        expectClose(effectiveWorkDays(.default, now), c.expected.autoWorkDays, "\(what) autoWorkDays")
        #expect(isDayOff([], now) == c.expected.isDayOff, "\(what) isDayOff")
        #expect(
            isDayOff(g.overrides, now) == c.expected.isDayOffWithOverride,
            "\(what) isDayOffWithOverride"
        )
    }
}

@Test("공휴일 표가 없는 해는 주말만 뺀다")
func noHolidayTable() {
    #expect(hasHolidayData(2026))
    #expect(hasHolidayData(2027))
    #expect(!hasHolidayData(2028))
    let info = workdayInfo(Golden.ms([2028, 8, 22, 12, 0, 0]))
    #expect(info.holidays == 0)
    #expect(info.workdays == info.weekdays)
}

@Test("2026년 9월은 근무일 20일 — 평일 22일에서 추석 평일 2일을 뺀다")
func september2026() {
    let info = workdayInfo(Golden.ms([2026, 8, 22, 12, 0, 0]))
    #expect(info.weekdays == 22)
    #expect(info.holidays == 2)
    #expect(info.workdays == 20)
}

@Test("dateKey는 웹과 같은 문자열을 만든다")
func dateKeyFormat() {
    #expect(dateKey(2026, 8, 22) == "2026-09-22")
    #expect(dateKey(2026, 0, 1) == "2026-01-01")
}
```

- [ ] **Step 2: 실패를 확인한다**

```bash
swift test --package-path macos/SalaryClockCore
```

Expected: 컴파일 실패

- [ ] **Step 3: `Holidays.swift`를 쓴다**

`lib/holidays.ts`의 `HOLIDAYS` 표를 **그대로** 옮긴다. 2026년 20개, 2027년 22개 항목이고 날짜 문자열도 주석도 같은 순서로 둔다. 표가 원본이므로 새로 계산하거나 줄이지 않는다.

```swift
import Foundation

/// 대한민국 관공서 공휴일 (대체공휴일 포함).
///
/// 음력 공휴일과 대체공휴일은 해마다 관보로 확정되어 계산으로 뽑을 수 없다.
/// 표에 없는 해는 hasHolidayData가 false를 돌려주고, 근무일수는 평일만 세는
/// 방식으로 되돌아간다. 낡은 표를 조용히 쓰느니 모른다고 말하는 편이 낫다.
///
/// 원본: lib/holidays.ts — 항목을 고칠 일이 생기면 그쪽을 먼저 고치고
/// 여기에 같은 값을 옮긴다.
private let HOLIDAYS: [Int: Set<String>] = [
    2026: [
        "2026-01-01", "2026-02-16", "2026-02-17", "2026-02-18",
        "2026-03-01", "2026-03-02", "2026-05-05", "2026-05-24",
        "2026-05-25", "2026-06-06", "2026-07-17", "2026-08-15",
        "2026-08-17", "2026-09-24", "2026-09-25", "2026-09-26",
        "2026-10-03", "2026-10-05", "2026-10-09", "2026-12-25",
    ],
    2027: [],  // Step 4에서 채운다
]

public func hasHolidayData(_ year: Int) -> Bool {
    HOLIDAYS[year] != nil
}

/// month는 0-based. 웹과 맞춘다.
public func isHoliday(_ year: Int, _ month: Int, _ day: Int) -> Bool {
    HOLIDAYS[year]?.contains(dateKey(year, month, day)) ?? false
}

/// 그 달의 평일에 걸린 공휴일. 주말과 겹친 것은 세지 않는다.
public func weekdayHolidaysInMonth(_ year: Int, _ month: Int) -> [String] {
    guard let days = HOLIDAYS[year] else { return [] }
    let prefix = String(format: "%04d-%02d-", year, month + 1)
    return days.filter { key in
        guard key.hasPrefix(prefix), let day = Int(key.suffix(2)) else { return false }
        let dow = weekday(year, month, day)
        return dow != 0 && dow != 6
    }.sorted()
}
```

- [ ] **Step 4: 2027년 표를 채운다**

`lib/holidays.ts`의 `2027:` 배열에 든 날짜를 전부 옮긴다. **직접 파일을 열어 옮기고, 개수를 세어 맞는지 확인한다:**

```bash
grep -c "'2027-" lib/holidays.ts
grep -c '"2027-' macos/SalaryClockCore/Sources/SalaryClockCore/Holidays.swift
```

Expected: 두 숫자가 같다. 다르면 옮기다 빠뜨린 것이다.

- [ ] **Step 5: `DayOff.swift`를 쓴다**

```swift
import Foundation

/// "YYYY-MM-DD". month는 0-based.
public func dateKey(_ year: Int, _ month: Int, _ day: Int) -> String {
    String(format: "%04d-%02d-%02d", year, month + 1, day)
}

/// 0=일 … 6=토. month는 0-based.
func weekday(_ year: Int, _ month: Int, _ day: Int) -> Int {
    var c = DateComponents()
    c.year = year; c.month = month + 1; c.day = day; c.hour = 12
    let date = Calendar.current.date(from: c)!
    return Calendar.current.component(.weekday, from: date) - 1
}

/// 아무것도 지정하지 않았을 때 쉬는 날인가 — 주말이거나 공휴일.
public func isDefaultOff(_ year: Int, _ month: Int, _ day: Int) -> Bool {
    let dow = weekday(year, month, day)
    if dow == 0 || dow == 6 { return true }
    return isHoliday(year, month, day)
}

/// 그 날짜가 쉬는 날인가.
///
/// 기본값은 주말·공휴일이고, overrides에 든 날짜는 기본값을 뒤집는다.
/// workDaysMode와 무관하게 반영한다 — 달력에서 "이날은 쉰다"고 찍은 건
/// 근무일수를 어떤 방식으로 세는지와 별개로 참인 사실이다.
public func isDayOff(_ overrides: [String], _ dateMs: Int) -> Bool {
    let date = Date(timeIntervalSince1970: Double(dateMs) / 1000)
    let cal = Calendar.current
    let year = cal.component(.year, from: date)
    let month = cal.component(.month, from: date) - 1
    let day = cal.component(.day, from: date)

    let defaultOff = isDefaultOff(year, month, day)
    return overrides.contains(dateKey(year, month, day)) ? !defaultOff : defaultOff
}
```

- [ ] **Step 6: `Workdays.swift`를 쓴다**

```swift
import Foundation

public struct WorkdayInfo: Sendable {
    /// 그 달의 평일(월~금) 수
    public let weekdays: Int
    /// 평일에 걸린 공휴일 수. 주말과 겹친 공휴일은 세지 않는다
    public let holidays: Int
    /// 실제 근무일수 = 평일 − 평일 공휴일
    public let workdays: Int
    /// 그 해 공휴일 표가 있는지
    public let hasHolidayData: Bool
}

private func daysInMonth(_ year: Int, _ month: Int) -> Int {
    var c = DateComponents()
    c.year = year; c.month = month + 1
    let date = Calendar.current.date(from: c)!
    return Calendar.current.range(of: .day, in: .month, for: date)!.count
}

/// 그 시각이 속한 달의 평일(월~금) 수
public func weekdaysInMonth(_ now: Int) -> Int {
    let date = Date(timeIntervalSince1970: Double(now) / 1000)
    let cal = Calendar.current
    let year = cal.component(.year, from: date)
    let month = cal.component(.month, from: date) - 1

    return (1...daysInMonth(year, month)).count { day in
        let dow = weekday(year, month, day)
        return dow != 0 && dow != 6
    }
}

public func workdayInfo(_ now: Int) -> WorkdayInfo {
    let date = Date(timeIntervalSince1970: Double(now) / 1000)
    let cal = Calendar.current
    let year = cal.component(.year, from: date)
    let month = cal.component(.month, from: date) - 1

    let weekdays = weekdaysInMonth(now)
    let holidays = weekdayHolidaysInMonth(year, month).count

    return WorkdayInfo(
        weekdays: weekdays,
        holidays: holidays,
        workdays: weekdays - holidays,
        hasHolidayData: hasHolidayData(year)
    )
}

public func workdaysInMonth(_ now: Int) -> Int {
    workdayInfo(now).workdays
}

/// 달력 기준 그 달의 근무일수 (calendar 모드)
public func workdaysFromCalendar(_ year: Int, _ month: Int, _ overrides: [String]) -> Int {
    (1...daysInMonth(year, month)).count { day in
        let key = dateKey(year, month, day)
        let defaultOff = isDefaultOff(year, month, day)
        let off = overrides.contains(key) ? !defaultOff : defaultOff
        return !off
    }
}

/// 설정에 따른 이번 달 근무일수.
///
/// auto     — 평일 − 공휴일
/// calendar — 달력에서 고른 것
/// manual   — 사용자가 넣은 숫자 그대로
public func effectiveWorkDays(_ s: Settings, _ now: Int) -> Double {
    switch s.workDaysMode {
    case .manual:
        return s.workDaysPerMonth
    case .calendar:
        let date = Date(timeIntervalSince1970: Double(now) / 1000)
        let cal = Calendar.current
        return Double(
            workdaysFromCalendar(
                cal.component(.year, from: date),
                cal.component(.month, from: date) - 1,
                s.dayOverrides
            )
        )
    case .auto:
        return Double(workdaysInMonth(now))
    }
}
```

웹의 `workdayInfo`에는 월별 캐시가 있다. rAF 틱마다 불려서 초당 수천 개의 `Date`를 만드는 걸 막으려는 것이었는데, 맥은 1초에 한 번(팝오버가 열렸을 때만 10번) 부르므로 캐시 없이 간다. 상태를 안 두는 편이 `Sendable` 검사에도 유리하다.

- [ ] **Step 7: 통과를 확인한다**

```bash
swift test --package-path macos/SalaryClockCore
TZ=UTC swift test --package-path macos/SalaryClockCore
```

Expected: 둘 다 전부 PASS

- [ ] **Step 8: 커밋**

```bash
git add macos/SalaryClockCore
git commit -m "$(cat <<'EOF'
feat: 공휴일 표와 근무일수를 Swift로 옮긴다

월 인자를 웹과 같이 0-based로 두고 DateComponents로 넘길 때만 +1 한다.
웹에 있던 월별 캐시는 두지 않는다 — 맥은 1초에 한 번만 부른다.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 5: Deductions

**Files:**
- Create: `macos/SalaryClockCore/Sources/SalaryClockCore/Deductions.swift`
- Create: `macos/SalaryClockCore/Tests/SalaryClockCoreTests/DeductionsTests.swift`

**Interfaces:**
- Consumes: `Golden`, `expectClose`
- Produces: `struct Deductions { pension, health, longTermCare, employment, incomeTax, total, rate: Double }`, `estimateDeductions(_ monthlyGross: Double) -> Deductions`

원본은 `lib/deductions.ts`다. 4대보험 요율은 법정값이라 정확하고, 소득세는 연말정산 구조로 근사한 **추정치**다.

- [ ] **Step 1: 골든 테스트를 먼저 쓴다**

```swift
import Testing
import Foundation
@testable import SalaryClockCore

struct DeductionCase: Decodable {
    struct Expected: Decodable {
        let pension: Double
        let health: Double
        let longTermCare: Double
        let employment: Double
        let incomeTax: Double
        let total: Double
        let rate: Double
    }
    let gross: Double
    let expected: Expected
}

@Test("골든 — deductions")
func goldenDeductions() throws {
    let cases: [DeductionCase] = try Golden.decode("deductions.json", as: [DeductionCase].self)
    #expect(cases.count > 0)

    for c in cases {
        let got = estimateDeductions(c.gross)
        let what = "gross \(c.gross)"
        expectClose(got.pension, c.expected.pension, "\(what) pension")
        expectClose(got.health, c.expected.health, "\(what) health")
        expectClose(got.longTermCare, c.expected.longTermCare, "\(what) longTermCare")
        expectClose(got.employment, c.expected.employment, "\(what) employment")
        expectClose(got.incomeTax, c.expected.incomeTax, "\(what) incomeTax")
        expectClose(got.total, c.expected.total, "\(what) total")
        expectClose(got.rate, c.expected.rate, "\(what) rate")
    }
}

@Test("0 이하는 전부 0이다")
func nonPositiveGross() {
    let d = estimateDeductions(0)
    #expect(d.total == 0)
    #expect(d.rate == 0)
}

@Test("검산 — 세전 300만의 실수령은 261.7만 근처다")
func sanityCheck() {
    let d = estimateDeductions(3_000_000)
    let net = 3_000_000 - d.total
    #expect(net > 2_600_000 && net < 2_630_000, "실수령 \(net)")
}
```

- [ ] **Step 2: 실패를 확인한다**

```bash
swift test --package-path macos/SalaryClockCore
```

Expected: 컴파일 실패

- [ ] **Step 3: `Deductions.swift`를 쓴다**

`lib/deductions.ts:1-133`을 그대로 옮긴다. 상수(`PENSION_CAP` 6_370_000, `PENSION_FLOOR` 390_000, `PERSONAL_DEDUCTION` 1_500_000, `LOCAL_TAX_RATE` 0.1)와 요율(`pension` 0.045, `health` 0.03545, `longTermCare` 0.1295, `employment` 0.009), 그리고 네 개의 구간 함수 `earnedIncomeDeduction`·`progressiveTax`·`taxCreditCap`·`earnedIncomeTaxCredit`를 **숫자 하나도 바꾸지 않고** 옮긴다. `estimateDeductions`의 계산 순서도 그대로다:

```
pensionBase = min(max(monthlyGross, FLOOR), CAP)
annualInsurance = (pension + health + longTermCare + employment) * 12
taxBase = max(0, annualGross - earnedIncomeDeduction - PERSONAL_DEDUCTION - annualInsurance)
finalTax = max(0, progressiveTax(taxBase) - earnedIncomeTaxCredit(...))
incomeTax = finalTax * 1.1 / 12
```

구간 경계에서 `<=`인지 `<`인지가 값을 가르므로 비교 연산자를 원본 그대로 쓴다.

- [ ] **Step 4: 통과를 확인한다**

```bash
swift test --package-path macos/SalaryClockCore
```

Expected: 골든 9케이스 × 7필드 전부 PASS

한 필드만 어긋나면 그 구간 함수의 경계 비교나 상수를 잘못 옮긴 것이다. 실패 메시지에 어느 gross의 어느 필드인지 나온다.

- [ ] **Step 5: 커밋**

```bash
git add macos/SalaryClockCore
git commit -m "$(cat <<'EOF'
feat: 4대보험·소득세 추정을 Swift로 옮긴다

구간 경계의 비교 연산자와 상수를 원본 그대로 옮기고 골든 9케이스 ×
7필드로 고정한다.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 6: Salary

**Files:**
- Create: `macos/SalaryClockCore/Sources/SalaryClockCore/Salary.swift`
- Create: `macos/SalaryClockCore/Tests/SalaryClockCoreTests/SalaryTests.swift`

**Interfaces:**
- Consumes: `Settings`, `Shift`, `resolveShift`, `paidMsBetween`, `effectiveWorkDays`, `estimateDeductions`, `isDayOff`
- Produces:
  - `enum Phase: String { before, working, lunch, after, dayoff }`
  - `struct Earnings { phase; earned, perSecond, progress: Double; elapsedPaidMs, totalPaidMs, msUntilStart, msUntilEnd, msUntilLunchEnd: Int; remainingAmount, dailyTotal, workDays, deductionRate: Double; isNet: Bool; shift: Shift? }`
  - `computeEarnings(_ s: Settings, _ now: Int) -> Earnings`
  - `monthlyGross(_ s: Settings, _ shift: Shift, _ workDays: Double) -> Double`
  - `perSecondRate(_ s: Settings, _ shift: Shift) -> Double`

이 브랜치의 도메인 수정이 전부 여기 모인다. **두 가지를 놓치면 안 된다:** 휴무일 판정은 `now`가 아니라 `shift.startMs` 기준이고, `effectiveWorkDays`도 마찬가지다. `now` 기준으로 두면 야간근무가 자정을 넘을 때 금액이 튄다.

- [ ] **Step 1: 골든 테스트를 먼저 쓴다**

```swift
import Testing
import Foundation
@testable import SalaryClockCore

struct EarningsCase: Decodable {
    struct Expected: Decodable {
        let phase: String
        let earned: Double
        let perSecond: Double
        let progress: Double
        let elapsedPaidMs: Int
        let totalPaidMs: Int
        let msUntilStart: Int
        let msUntilEnd: Int
        let msUntilLunchEnd: Int
        let remainingAmount: Double
        let dailyTotal: Double
        let workDays: Double
        let deductionRate: Double
        let hasShift: Bool
    }
    let label: String
    let settings: String
    let at: [Int]
    let expected: Expected
}

@Test("골든 — earnings")
func goldenEarnings() throws {
    let settings: [String: Settings] = try Golden.decode("settings.json", as: [String: Settings].self)
    let cases: [EarningsCase] = try Golden.decode("earnings.json", as: [EarningsCase].self)
    #expect(cases.count > 0)

    for c in cases {
        let s = try #require(settings[c.settings], "알 수 없는 설정: \(c.settings)")
        let e = computeEarnings(s, Golden.ms(c.at))
        let what = "\(c.label) (\(c.settings))"

        #expect(e.phase.rawValue == c.expected.phase, "\(what) phase")
        expectClose(e.earned, c.expected.earned, "\(what) earned")
        expectClose(e.perSecond, c.expected.perSecond, "\(what) perSecond")
        expectClose(e.progress, c.expected.progress, "\(what) progress")
        #expect(e.elapsedPaidMs == c.expected.elapsedPaidMs, "\(what) elapsedPaidMs")
        #expect(e.totalPaidMs == c.expected.totalPaidMs, "\(what) totalPaidMs")
        #expect(e.msUntilStart == c.expected.msUntilStart, "\(what) msUntilStart")
        #expect(e.msUntilEnd == c.expected.msUntilEnd, "\(what) msUntilEnd")
        #expect(e.msUntilLunchEnd == c.expected.msUntilLunchEnd, "\(what) msUntilLunchEnd")
        expectClose(e.remainingAmount, c.expected.remainingAmount, "\(what) remainingAmount")
        expectClose(e.dailyTotal, c.expected.dailyTotal, "\(what) dailyTotal")
        expectClose(e.workDays, c.expected.workDays, "\(what) workDays")
        expectClose(e.deductionRate, c.expected.deductionRate, "\(what) deductionRate")
        #expect((e.shift != nil) == c.expected.hasShift, "\(what) hasShift")
    }
}

@Test("야간근무가 월 경계를 넘어도 금액이 튀지 않는다")
func noMidnightJump() throws {
    let settings: [String: Settings] = try Golden.decode("settings.json", as: [String: Settings].self)
    let night = try #require(settings["night"])

    let before = computeEarnings(night, Golden.ms([2026, 11, 31, 23, 59, 59]))
    let after = computeEarnings(night, Golden.ms([2027, 0, 1, 0, 0, 1]))

    #expect(before.workDays == after.workDays, "근무일수가 자정에 바뀌면 안 된다")
    expectClose(after.perSecond, before.perSecond, "초당 단가")
    // 2초치 적립분만 늘어야 한다
    let delta = after.earned - before.earned
    expectClose(delta, before.perSecond * 2, "2초 적립분")
}
```

- [ ] **Step 2: 실패를 확인한다**

```bash
swift test --package-path macos/SalaryClockCore
```

Expected: 컴파일 실패

- [ ] **Step 3: `Salary.swift`를 쓴다**

```swift
import Foundation

public enum Phase: String, Sendable {
    case before, working, lunch, after, dayoff
}

public struct Earnings: Sendable {
    public let phase: Phase
    /// 오늘 지금까지 적립된 금액 (원)
    public let earned: Double
    /// 초당 적립액. 근무 중이 아니면 0
    public let perSecond: Double
    /// 유급시간 기준 진행률 0..1
    public let progress: Double
    public let elapsedPaidMs: Int
    public let totalPaidMs: Int
    /// 출근까지 남은 시간. 이미 출근했으면 0
    public let msUntilStart: Int
    /// 퇴근까지 남은 시계 시간(점심 포함). 퇴근했으면 0
    public let msUntilEnd: Int
    /// 점심 재개까지 남은 시간. 점심이 아니면 0
    public let msUntilLunchEnd: Int
    public let remainingAmount: Double
    /// 오늘 하루를 다 채웠을 때의 총액
    public let dailyTotal: Double
    public let workDays: Double
    public let deductionRate: Double
    public let isNet: Bool
    /// 휴무일이면 nil — 시계에 그릴 근무 구간이 없다
    public let shift: Shift?
}

/// 세전 월급 환산액. 공제율이 월 급여 기준이라 어떤 입력 방식이든 월 단위로 맞춘다.
public func monthlyGross(_ s: Settings, _ shift: Shift, _ workDays: Double) -> Double {
    if s.payMode == .annual { return s.payAmount / 12 }
    if s.payMode == .monthly { return s.payAmount }
    let paidHoursPerDay = Double(shift.paidMs) / 3_600_000
    return s.payAmount * paidHoursPerDay * workDays
}

/// 설정에 지정된 공제율이 있으면 그것을, 없으면 추정치를 쓴다.
public func deductionRateFor(_ s: Settings, _ gross: Double) -> Double {
    guard s.netPay else { return 0 }
    if let r = s.deductionRate { return r }
    return estimateDeductions(gross).rate
}

/// 초당 적립액.
///
/// 근무일수를 now가 아니라 shift.startMs 기준으로 센다. now로 세면 야간근무가
/// 월 경계를 넘는 순간 그 달의 근무일수가 바뀌어 금액이 튄다.
public func perSecondRate(_ s: Settings, _ shift: Shift) -> Double {
    let workDays = effectiveWorkDays(s, shift.startMs)
    let paidSecondsPerDay = Double(shift.paidMs) / 1000
    if paidSecondsPerDay <= 0 || workDays <= 0 { return 0 }

    let gross: Double =
        s.payMode == .hourly
        ? s.payAmount / 3600
        : monthlyGross(s, shift, workDays) / (workDays * paidSecondsPerDay)

    let rate = deductionRateFor(s, monthlyGross(s, shift, workDays))
    return gross * (1 - rate)
}

private func phaseOf(_ shift: Shift, _ now: Int) -> Phase {
    if now < shift.startMs { return .before }
    if now >= shift.endMs { return .after }
    if let ls = shift.lunchStartMs, let le = shift.lunchEndMs, now >= ls, now < le {
        return .lunch
    }
    return .working
}

public func computeEarnings(_ s: Settings, _ now: Int) -> Earnings {
    let shift = resolveShift(s, now)
    let workDays = effectiveWorkDays(s, shift.startMs)

    // 판정은 now가 아니라 시프트 시작일 기준이다. now로 보면 야간근무가 자정을
    // 넘는 순간 다음 날이 공휴일인지에 따라 근무 중에 0이 되어버린다.
    if isDayOff(s.dayOverrides, shift.startMs) {
        return Earnings(
            phase: .dayoff, earned: 0, perSecond: 0, progress: 0,
            elapsedPaidMs: 0,
            // 0이 아닌 이유: 설정 줄이 그날의 유급 시간을 계속 보여준다
            totalPaidMs: shift.paidMs,
            msUntilStart: 0, msUntilEnd: 0, msUntilLunchEnd: 0,
            remainingAmount: 0, dailyTotal: 0,
            workDays: workDays,
            deductionRate: deductionRateFor(s, monthlyGross(s, shift, workDays)),
            isNet: s.netPay, shift: nil
        )
    }

    let phase = phaseOf(shift, now)
    let rate = perSecondRate(s, shift)

    let totalPaidMs = shift.paidMs
    let elapsedPaidMs = paidMsBetween(shift, shift.startMs, now)
    let dailyTotal = rate * Double(totalPaidMs) / 1000
    let earned = rate * Double(elapsedPaidMs) / 1000

    return Earnings(
        phase: phase,
        earned: earned,
        perSecond: phase == .working ? rate : 0,
        progress: totalPaidMs == 0 ? 0 : Double(elapsedPaidMs) / Double(totalPaidMs),
        elapsedPaidMs: elapsedPaidMs,
        totalPaidMs: totalPaidMs,
        msUntilStart: max(0, shift.startMs - now),
        msUntilEnd: max(0, shift.endMs - now),
        msUntilLunchEnd: phase == .lunch ? max(0, (shift.lunchEndMs ?? now) - now) : 0,
        remainingAmount: max(0, dailyTotal - earned),
        dailyTotal: dailyTotal,
        workDays: workDays,
        deductionRate: deductionRateFor(s, monthlyGross(s, shift, workDays)),
        isNet: s.netPay,
        shift: shift
    )
}
```

- [ ] **Step 4: 통과를 확인한다**

```bash
swift test --package-path macos/SalaryClockCore
TZ=UTC swift test --package-path macos/SalaryClockCore
```

Expected: 골든 32케이스 × 14필드 전부 PASS, 두 타임존 모두

**이 단계가 이 계획 전체에서 가장 중요한 확인이다.** 여기가 통과하면 Swift 도메인 계층이 웹과 같은 답을 낸다는 게 증명된 것이고, 남은 작업은 전부 화면이다.

- [ ] **Step 5: 커밋**

```bash
git add macos/SalaryClockCore
git commit -m "$(cat <<'EOF'
feat: 급여 계산을 Swift로 옮긴다

휴무일 판정도 근무일수도 now가 아니라 shift.startMs 기준이다. 골든
32케이스 × 14필드가 웹과 일치하는 것을 확인했다.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 7: Format과 ClockGeometry

**Files:**
- Create: `macos/SalaryClockCore/Sources/SalaryClockCore/Format.swift`
- Create: `macos/SalaryClockCore/Sources/SalaryClockCore/ClockGeometry.swift`
- Create: `macos/SalaryClockCore/Tests/SalaryClockCoreTests/FormatTests.swift`
- Create: `macos/SalaryClockCore/Tests/SalaryClockCoreTests/ClockGeometryTests.swift`

**Interfaces:**
- Consumes: `shared/golden/format.json`·`clock.json` (Task 1), `Shift`
- Produces:
  - `formatWon(_ n: Double, fractionDigits: Int = 0) -> String`
  - `formatPerSecond(_ n: Double) -> String`, `formatDuration(_ ms: Int) -> String`
  - `formatDateKo(_ now: Int) -> String`, `formatClockTime(_ now: Int) -> String`
  - `formatKoreanUnits(_ n: Double) -> String`
  - `struct HandAngles { hour, minute, second: Double }`, `handAngles(_ now: Int) -> HandAngles`
  - `dialAngle(_ now: Int) -> Double`
  - `struct Arc { startDeg, sweepDeg: Double }`, `arcBetween(_ from: Int, _ to: Int) -> Arc`
  - `struct ShiftArcs { work, progress: Arc; lunch: Arc? }`, `shiftArcs(_ shift: Shift?, _ now: Int) -> ShiftArcs`

**두 가지 함정이 있다.** `NumberFormatter`의 기본 반올림은 `.halfEven`인데 규칙은 **항상 내림**이다 — 반올림하면 아직 벌지 않은 1원이 먼저 뜬다. 그리고 `handAngles`는 밀리초를 버리면 안 된다 — 버리는 순간 스위프가 아니라 1초마다 6도씩 튀는 쿼츠 시계가 된다.

- [ ] **Step 1: 골든 테스트를 먼저 쓴다**

`FormatTests.swift`:

```swift
import Testing
import Foundation
@testable import SalaryClockCore

struct FormatGolden: Decodable {
    struct NumCase: Decodable { let n: Double; let expected: String }
    struct MsCase: Decodable { let ms: Int; let expected: String }
    struct AtCase: Decodable { let at: [Int]; let expected: String }
    let won: [NumCase]
    let wonOneDecimal: [NumCase]
    let perSecond: [NumCase]
    let duration: [MsCase]
    let koreanUnits: [NumCase]
    let dateKo: [AtCase]
    let clockTime: [AtCase]
}

@Test("골든 — format")
func goldenFormat() throws {
    let g: FormatGolden = try Golden.decode("format.json", as: FormatGolden.self)
    #expect(g.won.count > 0)

    for c in g.won { #expect(formatWon(c.n) == c.expected, "formatWon(\(c.n))") }
    for c in g.wonOneDecimal {
        #expect(formatWon(c.n, fractionDigits: 1) == c.expected, "formatWon(\(c.n), 1)")
    }
    for c in g.perSecond {
        #expect(formatPerSecond(c.n) == c.expected, "formatPerSecond(\(c.n))")
    }
    for c in g.duration {
        #expect(formatDuration(c.ms) == c.expected, "formatDuration(\(c.ms))")
    }
    for c in g.koreanUnits {
        #expect(formatKoreanUnits(c.n) == c.expected, "formatKoreanUnits(\(c.n))")
    }
    for c in g.dateKo {
        #expect(formatDateKo(Golden.ms(c.at)) == c.expected, "formatDateKo(\(c.at))")
    }
    for c in g.clockTime {
        #expect(formatClockTime(Golden.ms(c.at)) == c.expected, "formatClockTime(\(c.at))")
    }
}

@Test("금액은 반올림하지 않고 내린다")
func alwaysFloors() {
    #expect(formatWon(0.9) == formatWon(0))
    #expect(formatWon(1.999) == formatWon(1))
}
```

`ClockGeometryTests.swift`:

```swift
import Testing
import Foundation
@testable import SalaryClockCore

struct ClockGolden: Decodable {
    struct Hands: Decodable {
        struct Expected: Decodable { let hour: Double; let minute: Double; let second: Double }
        let at: [Int]
        let expected: Expected
    }
    struct Dial: Decodable { let at: [Int]; let expected: Double }
    struct ArcCase: Decodable {
        struct Expected: Decodable { let startDeg: Double; let sweepDeg: Double }
        let label: String
        let settings: String
        let at: [Int]
        let expected: Expected
    }
    let hands: [Hands]
    let dial: [Dial]
    let arcs: [ArcCase]
}

@Test("골든 — clock")
func goldenClock() throws {
    let g: ClockGolden = try Golden.decode("clock.json", as: ClockGolden.self)
    let settings: [String: Settings] = try Golden.decode("settings.json", as: [String: Settings].self)
    #expect(g.hands.count > 0)

    for h in g.hands {
        let got = handAngles(Golden.ms(h.at))
        expectClose(got.hour, h.expected.hour, "hour \(h.at)")
        expectClose(got.minute, h.expected.minute, "minute \(h.at)")
        expectClose(got.second, h.expected.second, "second \(h.at)")
    }
    for d in g.dial {
        expectClose(dialAngle(Golden.ms(d.at)), d.expected, "dialAngle \(d.at)")
    }
    for a in g.arcs {
        let s = try #require(settings[a.settings])
        let sh = resolveShift(s, Golden.ms(a.at))
        let got = arcBetween(sh.startMs, sh.endMs)
        expectClose(got.startDeg, a.expected.startDeg, "\(a.label) startDeg")
        expectClose(got.sweepDeg, a.expected.sweepDeg, "\(a.label) sweepDeg")
    }
}

@Test("초침은 밀리초를 버리지 않는다 — 스위프 운동의 전부다")
func secondHandSweeps() {
    let a = handAngles(Golden.ms([2026, 8, 22, 0, 0, 0, 0]))
    let b = handAngles(Golden.ms([2026, 8, 22, 0, 0, 0, 500]))
    #expect(a.second == 0)
    expectClose(b.second, 3, "0.5초 = 3도")
}

@Test("시프트가 없으면 빈 호를 돌려준다")
func emptyArcsWhenNoShift() {
    let arcs = shiftArcs(nil, Golden.ms([2026, 8, 26, 14, 0, 0]))
    #expect(arcs.work.sweepDeg == 0)
    #expect(arcs.progress.sweepDeg == 0)
    #expect(arcs.lunch == nil)
}
```

- [ ] **Step 2: 실패를 확인한다**

```bash
swift test --package-path macos/SalaryClockCore
```

Expected: 컴파일 실패

- [ ] **Step 3: `Format.swift`를 쓴다**

```swift
import Foundation

/// 통화 표기는 ko-KR 고정이다. 기기 로캘을 따르면 ₩가 KRW로 바뀌거나
/// 자릿수 구분이 달라져 웹과 다른 화면이 된다.
private func wonFormatter(_ fractionDigits: Int) -> NumberFormatter {
    let f = NumberFormatter()
    f.numberStyle = .currency
    f.locale = Locale(identifier: "ko_KR")
    f.currencyCode = "KRW"
    f.minimumFractionDigits = fractionDigits
    f.maximumFractionDigits = fractionDigits
    // 내림은 아래에서 직접 하므로 포매터는 자르지 않는다
    f.roundingMode = .down
    return f
}

/// 금액 표시. 항상 내린다.
///
/// 반올림하면 아직 벌지 않은 1원이 화면에 먼저 뜬다. 적립 카운터에서는
/// 실제로 쌓인 것보다 많아 보이는 쪽이 덜 쌓인 쪽보다 나쁘다.
public func formatWon(_ n: Double, fractionDigits: Int = 0) -> String {
    let scale = pow(10.0, Double(fractionDigits))
    let floored = (n * scale).rounded(.down) / scale
    return wonFormatter(fractionDigits).string(from: NSNumber(value: floored)) ?? "₩0"
}

/// 초당 적립액. 작은 값에서 0으로 뭉개지지 않도록 소수 1자리를 남긴다.
public func formatPerSecond(_ n: Double) -> String {
    n < 100 ? String(format: "%.1f", n) : String(Int(n.rounded()))
}

public func formatDuration(_ ms: Int) -> String {
    let total = max(0, ms / 1000)
    return String(format: "%02d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60)
}

private let WEEKDAYS = ["일", "월", "화", "수", "목", "금", "토"]

/// "2026년 9월 22일 (화)"
public func formatDateKo(_ now: Int) -> String {
    let date = Date(timeIntervalSince1970: Double(now) / 1000)
    let cal = Calendar.current
    let dow = cal.component(.weekday, from: date) - 1
    return "\(cal.component(.year, from: date))년 \(cal.component(.month, from: date))월 "
        + "\(cal.component(.day, from: date))일 (\(WEEKDAYS[dow]))"
}

/// "16:53:21" — 24시간제. 오전/오후를 안 쓰면 폭이 고정돼 숫자가 흔들리지 않는다.
public func formatClockTime(_ now: Int) -> String {
    let date = Date(timeIntervalSince1970: Double(now) / 1000)
    let cal = Calendar.current
    return String(
        format: "%02d:%02d:%02d",
        cal.component(.hour, from: date),
        cal.component(.minute, from: date),
        cal.component(.second, from: date)
    )
}

/// 금액을 억/만 단위로 끊어 읽어준다. 입력창에 0을 몇 개 쳤는지 보기 위한 보조 표시다.
public func formatKoreanUnits(_ n: Double) -> String {
    let v = Int(max(0, n).rounded(.down))
    if v == 0 { return "0원" }

    let grouping = NumberFormatter()
    grouping.numberStyle = .decimal
    grouping.locale = Locale(identifier: "ko_KR")
    let g = { (x: Int) in grouping.string(from: NSNumber(value: x)) ?? String(x) }

    let eok = v / 100_000_000
    let man = (v % 100_000_000) / 10_000
    let rest = v % 10_000

    var parts: [String] = []
    if eok != 0 { parts.append("\(g(eok))억") }
    if man != 0 { parts.append("\(g(man))만") }
    if rest != 0 { parts.append(g(rest)) }

    return parts.joined(separator: " ") + "원"
}
```

`formatDuration`이 `ms / 1000`으로 정수 나눗셈을 하는 것에 주의한다. TS는 `Math.floor(ms / 1000)`이고 Swift의 `Int` 나눗셈은 0 쪽으로 자르므로, 음수에서 다르다. 앞에 `max(0, ...)`이 있어 음수가 들어와도 같은 답이 나온다 — 골든에 `-1` 케이스가 있으니 확인된다.

- [ ] **Step 4: `ClockGeometry.swift`를 쓴다**

```swift
import Foundation

private let MS_PER_12H = 43_200_000

public struct HandAngles: Sendable {
    public let hour: Double
    public let minute: Double
    public let second: Double
}

public struct Arc: Equatable, Sendable {
    public let startDeg: Double
    public let sweepDeg: Double
}

public struct ShiftArcs: Sendable {
    public let work: Arc
    public let progress: Arc
    public let lunch: Arc?
}

/// 그 시각의 자정 이후 경과 밀리초. 로컬 시각 기준.
private func msIntoDay(_ now: Int) -> Int {
    now - startOfLocalDay(now)
}

/// 12시 방향 0도, 시계방향 증가.
///
/// 밀리초를 버리지 않고 그대로 각도로 환산하는 것이 스위프 운동의 전부다.
/// 초를 내림하면 1초마다 6도씩 튀는 쿼츠 시계가 된다.
public func handAngles(_ now: Int) -> HandAngles {
    let t = Double(msIntoDay(now))
    return HandAngles(
        hour: (t.truncatingRemainder(dividingBy: Double(MS_PER_12H)) / Double(MS_PER_12H)) * 360,
        minute: (t.truncatingRemainder(dividingBy: 3_600_000) / 3_600_000) * 360,
        second: (t.truncatingRemainder(dividingBy: 60_000) / 60_000) * 360
    )
}

/// 그 시각의 12시간 문자판 위치 (0~360).
public func dialAngle(_ now: Int) -> Double {
    let t = Double(msIntoDay(now))
    return (t.truncatingRemainder(dividingBy: Double(MS_PER_12H)) / Double(MS_PER_12H)) * 360
}

/// 두 시각 사이를 문자판 호로. 12시간을 넘으면 360도로 자른다.
public func arcBetween(_ fromMs: Int, _ toMs: Int) -> Arc {
    let span = Double(max(0, toMs - fromMs))
    return Arc(
        startDeg: dialAngle(fromMs),
        sweepDeg: min(360, (span / Double(MS_PER_12H)) * 360)
    )
}

private let EMPTY_ARC = Arc(startDeg: 0, sweepDeg: 0)

/// 시프트를 문자판 위의 호 셋으로. 휴무일에는 시프트가 없어 빈 호를 돌려준다.
public func shiftArcs(_ shift: Shift?, _ now: Int) -> ShiftArcs {
    guard let shift else {
        return ShiftArcs(work: EMPTY_ARC, progress: EMPTY_ARC, lunch: nil)
    }
    let clampedNow = min(max(now, shift.startMs), shift.endMs)
    return ShiftArcs(
        work: arcBetween(shift.startMs, shift.endMs),
        progress: arcBetween(shift.startMs, clampedNow),
        lunch: shift.lunchStartMs.flatMap { ls in
            shift.lunchEndMs.map { arcBetween(ls, $0) }
        }
    )
}
```

`msIntoDay`를 `startOfLocalDay`로 빼는 것이 TS와 다르다. TS는 시·분·초를 더해 만드는데 그러면 DST 전환일에 어긋난다. 빼기로 하면 항상 맞는다.

- [ ] **Step 5: 통과를 확인한다**

```bash
swift test --package-path macos/SalaryClockCore
TZ=UTC swift test --package-path macos/SalaryClockCore
```

Expected: 전부 PASS. 특히 `formatWon(0.9)`이 `₩0`이어야 한다 — `₩1`이면 내림이 아니라 반올림이 걸린 것이다

- [ ] **Step 6: 커밋**

```bash
git add macos/SalaryClockCore
git commit -m "$(cat <<'EOF'
feat: 표시 형식과 시계 각도를 Swift로 옮긴다

NumberFormatter의 기본 반올림(halfEven) 대신 직접 내린다. 초침은
밀리초를 그대로 각도로 환산해 스위프 운동을 지킨다.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 8: Palette.swift 생성

**Files:**
- Create: `scripts/generate-palette-swift.ts`
- Create: `macos/SalaryClockCore/Sources/SalaryClockCore/Palette.swift` (생성물)
- Modify: `package.json` (scripts에 `palette:swift` 추가)

**Interfaces:**
- Consumes: `shared/golden/palette.json`
- Produces: `enum Palette` — `Palette.slate400`, `Palette.emerald500` 등 `(light:dark:)` 쌍과 `Palette.surfaceBackground`, `Palette.surfaceForeground`

**hex는 3자리(`#fff`)일 수 있고 `lab`은 `null`일 수 있다.** 생성기가 둘 다 처리해야 한다. 웹은 P3 디스플레이에서 `lab()` 값을 그리지만, 이번 버전은 **sRGB hex만 쓴다** — `lab()`을 SwiftUI `Color`로 정확히 옮기려면 CIELAB→Display P3 변환이 필요하고, 그건 눈으로 확인할 수단이 없는 상태에서 넣을 작업이 아니다. `lab` 값은 JSON에 남아 있으니 나중에 붙일 수 있다.

- [ ] **Step 1: 생성 스크립트를 쓴다**

`scripts/generate-palette-swift.ts`:

```ts
/**
 * shared/golden/palette.json → Palette.swift
 *
 * 색을 손으로 옮겨 적으면 웹과 조용히 어긋난다. 웹 빌드에서 뽑은 값을
 * 그대로 Swift 소스로 찍어낸다.
 *
 * 이번 버전은 sRGB hex만 쓴다. palette.json에는 광색역 lab() 값도 들어
 * 있지만, CIELAB → Display P3 변환을 눈으로 확인할 수단이 없는 상태에서
 * 넣을 작업이 아니다. 나중에 붙일 수 있도록 JSON에는 남아 있다.
 *
 * 실행: npm run palette:swift
 */
import { readFileSync, writeFileSync } from 'node:fs'
import path from 'node:path'

const root = path.resolve(import.meta.dirname, '..')
const palette = JSON.parse(
  readFileSync(path.join(root, 'shared/golden/palette.json'), 'utf8'),
) as {
  surface: { background: Record<string, string>; foreground: Record<string, string> }
  tokens: Record<string, { hex: string; lab: string | null }>
}

/** "#fff" 도 "#f1f5f9" 도 받는다. */
function rgb(hex: string): [number, number, number] {
  const h = hex.replace('#', '')
  const full = h.length === 3 ? h.split('').map((c) => c + c).join('') : h
  if (full.length !== 6) throw new Error(`hex 형식을 모르겠다: ${hex}`)
  return [0, 2, 4].map((i) => parseInt(full.slice(i, i + 2), 16) / 255) as [number, number, number]
}

/** slate-400 → slate400 */
const swiftName = (token: string) => token.replace(/-(\d+)$/, '$1').replace(/-/g, '')

const lines: string[] = [
  '// 생성된 파일이다. 손으로 고치지 말 것.',
  '// shared/golden/palette.json 에서 npm run palette:swift 로 다시 만든다.',
  '//',
  '// 웹은 P3 디스플레이에서 lab() 값을 그리지만 여기서는 sRGB hex만 쓴다.',
  '// lab 값은 palette.json에 남아 있으니 나중에 붙일 수 있다.',
  '',
  'import SwiftUI',
  '',
  'public enum Palette {',
  '    /// 밝게·어둡게 한 쌍. 시스템 설정에 따라 고른다.',
  '    public struct Pair: Sendable {',
  '        public let light: Color',
  '        public let dark: Color',
  '        public func resolve(_ scheme: ColorScheme) -> Color { scheme == .dark ? dark : light }',
  '    }',
  '',
  '    private static func srgb(_ r: Double, _ g: Double, _ b: Double) -> Color {',
  '        Color(.sRGB, red: r, green: g, blue: b, opacity: 1)',
  '    }',
  '',
]

for (const [token, { hex }] of Object.entries(palette.tokens)) {
  const [r, g, b] = rgb(hex)
  lines.push(
    `    /// ${token} — ${hex}`,
    `    public static let ${swiftName(token)} = srgb(${r.toFixed(6)}, ${g.toFixed(6)}, ${b.toFixed(6)})`,
    '',
  )
}

for (const [role, pair] of Object.entries(palette.surface)) {
  if (role === 'note') continue
  const p = pair as Record<string, string>
  lines.push(
    `    /// app/page.tsx의 <main>이 칠하는 ${role}`,
    `    public static let surface${role[0].toUpperCase()}${role.slice(1)} = Pair(`,
    `        light: ${swiftName(p.light)}, dark: ${swiftName(p.dark)}`,
    '    )',
    '',
  )
}

lines.push('}', '')

const out = path.join(root, 'macos/SalaryClockCore/Sources/SalaryClockCore/Palette.swift')
writeFileSync(out, lines.join('\n'), 'utf8')
console.log(`wrote ${path.relative(root, out)}`)
```

`palette.json`의 `surface`는 값이 토큰 **키**(`"white"`, `"slate-950"`)라서 `swiftName`으로 Swift 상수 이름을 만든다. `tokens`에 `white`가 있는지 확인하고, 없으면 스크립트가 던지는 오류를 보고 `TOKENS`에 추가해야 한다.

- [ ] **Step 2: `package.json`에 스크립트를 추가한다**

기존 `palette` 항목 바로 아래에 넣는다:

```json
    "palette:swift": "node --disable-warning=MODULE_TYPELESS_PACKAGE_JSON --import ./scripts/ts-alias.mjs scripts/generate-palette-swift.ts",
```

- [ ] **Step 3: 생성해서 확인한다**

```bash
npm run palette:swift
head -30 macos/SalaryClockCore/Sources/SalaryClockCore/Palette.swift
grep -c "public static let" macos/SalaryClockCore/Sources/SalaryClockCore/Palette.swift
```

Expected: 토큰 개수 + surface 2개만큼의 상수가 나온다. `white`가 `tokens`에 없어 스크립트가 던지면, `scripts/extract-palette.ts`의 `TOKENS`에 `white`를 추가하고 `npm run build && npm run palette`를 다시 돌린 뒤 이어간다.

- [ ] **Step 4: 빌드되는지 확인한다**

```bash
swift build --package-path macos/SalaryClockCore
swift test --package-path macos/SalaryClockCore
```

Expected: 컴파일 성공, 기존 테스트 전부 PASS

`Palette.swift`가 `SwiftUI`를 import하므로 `SalaryClockCore`가 SwiftUI에 의존하게 된다. macOS 전용 패키지라 문제없다.

- [ ] **Step 5: 커밋**

```bash
git add scripts/generate-palette-swift.ts package.json macos/SalaryClockCore
git commit -m "$(cat <<'EOF'
chore: palette.json에서 Palette.swift를 찍어낸다

색을 손으로 옮기면 웹과 조용히 어긋난다. 3자리 hex(#fff)와 lab이 null인
경우를 둘 다 처리한다. 이번 버전은 sRGB hex만 쓰고 lab은 JSON에 남겨둔다.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 9: 앱 번들과 메뉴바

**Files:**
- Create: `macos/SalaryClockApp/Package.swift`
- Create: `macos/SalaryClockApp/Sources/SalaryClockApp/main.swift`
- Create: `macos/SalaryClockApp/Sources/SalaryClockApp/AppDelegate.swift`
- Create: `macos/SalaryClockApp/Sources/SalaryClockApp/MenuBarTitle.swift`
- Create: `macos/SalaryClockApp/Sources/SalaryClockApp/RingIcon.swift`
- Create: `macos/SalaryClockApp/Sources/SalaryClockApp/SettingsStore.swift`
- Create: `macos/SalaryClockApp/Tests/SalaryClockAppTests/MenuBarTitleTests.swift`
- Create: `scripts/bundle-app.sh`

**Interfaces:**
- Consumes: `SalaryClockCore`의 `computeEarnings`·`formatWon`·`Settings`·`Earnings`·`Phase`
- Produces:
  - `menuBarTitle(_ e: Earnings, hideAmount: Bool) -> String?` — 아이콘만 보일 때는 `nil`
  - `ringImage(progress: Double, phase: Phase, size: CGFloat) -> NSImage`
  - `SettingsStore.shared` — `var settings: Settings`, `func reload()`, 변경 시 `NotificationCenter`로 `.settingsChanged`

여기서 처음으로 메뉴바에 금액이 뜬다.

- [ ] **Step 1: 패키지를 만든다**

`macos/SalaryClockApp/Package.swift`:

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SalaryClockApp",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "SalaryClockApp",
            dependencies: [.product(name: "SalaryClockCore", package: "SalaryClockCore")]
        ),
        .testTarget(name: "SalaryClockAppTests", dependencies: ["SalaryClockApp"]),
    ]
)
package.dependencies = [.package(path: "../SalaryClockCore")]
```

- [ ] **Step 2: 메뉴바 문자열 테스트를 먼저 쓴다**

`macos/SalaryClockApp/Tests/SalaryClockAppTests/MenuBarTitleTests.swift`:

```swift
import Testing
import Foundation
@testable import SalaryClockApp
import SalaryClockCore

private func at(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int, _ s: Int) -> Int {
    var c = DateComponents()
    c.year = y; c.month = mo + 1; c.day = d; c.hour = h; c.minute = mi; c.second = s
    return Int((Calendar.current.date(from: c)!.timeIntervalSince1970 * 1000).rounded())
}

@Test("근무 중에는 정수 금액을 보여준다")
func titleWhileWorking() {
    let e = computeEarnings(.default, at(2026, 8, 22, 14, 0, 0))
    let title = menuBarTitle(e, hideAmount: false)
    #expect(title == formatWon(e.earned))
    #expect(title?.contains(".") == false, "메뉴바는 소수를 쓰지 않는다")
}

@Test("휴무일에는 금액을 내린다")
func titleOnDayOff() {
    let e = computeEarnings(.default, at(2026, 8, 26, 14, 0, 0))
    #expect(e.phase == .dayoff)
    #expect(menuBarTitle(e, hideAmount: false) == nil)
}

@Test("가리기를 켜면 금액을 내린다")
func titleWhenHidden() {
    let e = computeEarnings(.default, at(2026, 8, 22, 14, 0, 0))
    #expect(menuBarTitle(e, hideAmount: true) == nil)
}

@Test("출근 전에는 0원을 보여준다")
func titleBeforeWork() {
    let e = computeEarnings(.default, at(2026, 8, 22, 0, 30, 0))
    #expect(e.phase == .before)
    #expect(menuBarTitle(e, hideAmount: false) == formatWon(0))
}
```

- [ ] **Step 3: 실패를 확인한다**

```bash
swift test --package-path macos/SalaryClockApp
```

Expected: 컴파일 실패 — `menuBarTitle` 없음

- [ ] **Step 4: `MenuBarTitle.swift`를 쓴다**

```swift
import Foundation
import SalaryClockCore

/// 메뉴바에 띄울 금액 문자열. 아이콘만 보여야 하면 nil.
///
/// 소수를 쓰지 않는 이유: 0.1초마다 갱신하면 메뉴바가 끝없이 꿈틀거리고
/// 배터리도 먹는다. 소수 1자리가 흐르는 건 팝오버에서 보여준다.
///
/// hideAmount일 때 현재 시각을 대신 넣지 않는다 — macOS 기본 시계와
/// 나란히 중복되고, 회의 중에 가장 가리고 싶은 게 메뉴바 금액이다.
public func menuBarTitle(_ e: Earnings, hideAmount: Bool) -> String? {
    if hideAmount || e.phase == .dayoff { return nil }
    return formatWon(e.earned)
}
```

- [ ] **Step 5: `RingIcon.swift`를 쓴다**

```swift
import AppKit
import SalaryClockCore

/// 하루 진행률만큼 차오르는 링. 웹 시계의 바깥 진행 링과 같은 emerald를 쓴다.
///
/// 1분에 한 번만 다시 그리면 된다 — 18px 링에서 1초치 진행은 보이지 않는다.
/// template 이미지로 만들지 않는 이유: 진행 색이 메뉴바 색에 먹히면
/// 링이 전부 같은 색이 되어 진행이 안 보인다.
public func ringImage(progress: Double, phase: Phase, size: CGFloat = 16) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    defer { image.unlockFocus() }

    let inset: CGFloat = 1.5
    let rect = NSRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
    let center = NSPoint(x: size / 2, y: size / 2)
    let radius = rect.width / 2
    let lineWidth: CGFloat = 2

    let track = NSBezierPath()
    track.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360)
    track.lineWidth = lineWidth
    NSColor.tertiaryLabelColor.setStroke()
    track.stroke()

    let clamped = min(max(progress, 0), 1)
    if clamped > 0 {
        let arc = NSBezierPath()
        // 12시 방향에서 시계방향. AppKit은 반시계가 양수라 부호를 뒤집는다.
        arc.appendArc(
            withCenter: center, radius: radius,
            startAngle: 90, endAngle: 90 - 360 * clamped, clockwise: true
        )
        arc.lineWidth = lineWidth
        arc.lineCapStyle = .round
        emeraldColor(for: phase).setStroke()
        arc.stroke()
    }

    return image
}

private func emeraldColor(for phase: Phase) -> NSColor {
    NSColor(Palette.emerald500)
}
```

- [ ] **Step 6: `SettingsStore.swift`를 쓴다**

```swift
import Foundation
import SalaryClockCore

public extension Notification.Name {
    static let settingsChanged = Notification.Name("dev.woosublee.salaryclock.settingsChanged")
}

/// UserDefaults에 설정을 담는다.
///
/// 웹은 브라우저 localStorage를 쓰므로 설정이 이어지지 않는다. 맥에서
/// 한 번 새로 넣어야 한다.
///
/// 저장된 값이 규칙을 어기면 기본값으로 되돌린다 — 웹의 zod 검증이 하던 일이다.
public final class SettingsStore: @unchecked Sendable {
    public static let shared = SettingsStore()

    private static let key = "settings.v2"
    private let lock = NSLock()
    private var cached: Settings

    private init() {
        cached = Self.load()
    }

    public var settings: Settings {
        get { lock.withLock { cached } }
        set {
            lock.withLock { cached = newValue }
            Self.save(newValue)
            NotificationCenter.default.post(name: .settingsChanged, object: nil)
        }
    }

    private static func load() -> Settings {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode(Settings.self, from: data),
              isValid(decoded)
        else { return .default }
        return decoded
    }

    private static func save(_ s: Settings) {
        guard let data = try? JSONEncoder().encode(s) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    /// 웹 zod 스키마의 규칙을 옮긴 것. 하나라도 깨지면 기본값으로 돌아간다.
    static func isValid(_ s: Settings) -> Bool {
        guard s.payAmount > 0, s.payAmount.isFinite else { return false }
        guard s.workDaysPerMonth > 0, s.workDaysPerMonth <= 31 else { return false }
        guard isValidHHmm(s.workStart), isValidHHmm(s.workEnd) else { return false }
        guard let start = parseHHmm(s.workStart), let end = parseHHmm(s.workEnd) else { return false }
        let shiftMin = durationMinutes(start, end)
        guard shiftMin > 0 else { return false }
        if let r = s.deductionRate, !(r >= 0 && r <= 0.9) { return false }
        guard s.lunchEnabled else { return true }
        guard isValidHHmm(s.lunchStart), let ls = parseHHmm(s.lunchStart) else { return false }
        guard s.lunchMinutes > 0, s.lunchMinutes < shiftMin else { return false }
        return durationMinutes(start, ls) + s.lunchMinutes <= shiftMin
    }
}
```

- [ ] **Step 7: `AppDelegate.swift`와 `main.swift`를 쓴다**

`AppDelegate.swift`:

```swift
import AppKit
import SalaryClockCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var timer: Timer?
    private var lastRingMinute = -1

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.imagePosition = .imageLeading

        NotificationCenter.default.addObserver(
            self, selector: #selector(settingsChanged),
            name: .settingsChanged, object: nil
        )
        // 절전에서 깨어나면 즉시 맞춘다. 타이머만 믿어도 1초 뒤엔 맞지만
        // 화면이 켜지는 순간 옛 숫자가 보이는 게 눈에 띈다.
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(wakeUp),
            name: NSWorkspace.didWakeNotification, object: nil
        )

        startTimer(interval: 1)
        tick()
    }

    private func startTimer(interval: TimeInterval) {
        timer?.invalidate()
        let t = Timer(timeInterval: interval, repeats: true) { [weak self] _ in self?.tick() }
        // .common 모드에 넣지 않으면 메뉴나 팝오버를 여는 순간 숫자가 멈춘다.
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    @objc private func settingsChanged() { lastRingMinute = -1; tick() }
    @objc private func wakeUp() { tick() }

    /// 매 tick마다 Date()로 전부 다시 계산한다. 누적하지 않으므로 타이머가
    /// 드리프트하든 절전에서 깨어나든 다음 tick에 저절로 맞는다.
    private func tick() {
        let now = Int((Date().timeIntervalSince1970 * 1000).rounded())
        let s = SettingsStore.shared.settings
        let e = computeEarnings(s, now)

        guard let button = statusItem.button else { return }
        button.title = menuBarTitle(e, hideAmount: s.hideAmount).map { " " + $0 } ?? ""
        button.font = NSFont.monospacedDigitSystemFont(ofSize: 0, weight: .regular)

        let minute = now / 60_000
        if minute != lastRingMinute {
            lastRingMinute = minute
            button.image = ringImage(progress: e.progress, phase: e.phase)
        }
    }
}
```

`main.swift`:

```swift
import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
// LSUIElement가 Info.plist에 있으므로 Dock에 뜨지 않는다.
app.setActivationPolicy(.accessory)
app.run()
```

- [ ] **Step 8: 번들 조립 스크립트를 쓴다**

`scripts/bundle-app.sh`:

```bash
#!/usr/bin/env bash
# swift build 결과를 .app 번들로 조립한다.
#
# Xcode 프로젝트를 두지 않는 이유: .pbxproj는 손으로 쓰기 어렵고 diff가
# 읽히지 않아 리뷰가 불가능하다. Package.swift와 이 스크립트는 둘 다 읽힌다.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG="${1:-debug}"
APP="$ROOT/macos/build/SalaryClock.app"

swift build --package-path "$ROOT/macos/SalaryClockApp" -c "$CONFIG"
BIN="$(swift build --package-path "$ROOT/macos/SalaryClockApp" -c "$CONFIG" --show-bin-path)/SalaryClockApp"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/SalaryClock"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>SalaryClock</string>
  <key>CFBundleDisplayName</key><string>SalaryClock</string>
  <key>CFBundleIdentifier</key><string>dev.woosublee.salaryclock</string>
  <key>CFBundleExecutable</key><string>SalaryClock</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <!-- Dock 아이콘 없이 메뉴바에만 상주한다 -->
  <key>LSUIElement</key><true/>
</dict>
</plist>
PLIST

# 본인 기계에서 쓸 것이라 ad-hoc 서명이면 충분하다. Gatekeeper가 막지 않는다.
codesign --force --sign - "$APP"

echo "built $APP"
```

```bash
chmod +x scripts/bundle-app.sh
```

- [ ] **Step 9: 빌드하고 실제로 띄워본다**

```bash
swift test --package-path macos/SalaryClockApp
./scripts/bundle-app.sh
open macos/build/SalaryClock.app
```

확인할 것:
1. **메뉴바 오른쪽에 링 아이콘과 금액이 뜬다** (오늘은 평일이므로 금액이 보인다)
2. 숫자가 1초마다 올라간다
3. Dock에 아이콘이 생기지 않는다
4. 금액 자릿수가 바뀔 때 왼쪽 메뉴바 항목이 밀리지 않는다

확인 후 종료한다:

```bash
pkill -f SalaryClock.app || true
```

**띄우지 못했으면 그렇다고 보고한다.** 화면을 못 본 채 "동작한다"고 쓰지 않는다.

- [ ] **Step 10: 커밋**

```bash
git add macos/SalaryClockApp scripts/bundle-app.sh
git commit -m "$(cat <<'EOF'
feat: 메뉴바에 적립 금액을 띄운다

NSStatusItem 타이틀을 1초 타이머로 갱신한다. RunLoop.common 모드에
넣어 메뉴를 열어도 멈추지 않고, 매 tick마다 Date()로 전부 다시 계산해
절전 복귀에도 저절로 맞는다. monospacedDigitSystemFont로 폭을 고정해
왼쪽 메뉴바 항목이 밀리지 않게 한다.

Xcode 프로젝트 대신 SwiftPM + 번들 스크립트로 간다 — .pbxproj는 diff가
읽히지 않아 리뷰할 수 없다.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 10: 팝오버와 시계

**Files:**
- Create: `macos/SalaryClockApp/Sources/SalaryClockApp/Theme.swift`
- Create: `macos/SalaryClockApp/Sources/SalaryClockApp/MinimalFaceView.swift`
- Create: `macos/SalaryClockApp/Sources/SalaryClockApp/PopoverView.swift`
- Modify: `macos/SalaryClockApp/Sources/SalaryClockApp/AppDelegate.swift`

**Interfaces:**
- Consumes: `Palette`, `handAngles`, `shiftArcs`, `Earnings`, `formatWon`, `formatPerSecond`, `formatDuration`
- Produces: `PopoverView(model:)` — `@Observable final class TickModel { var earnings: Earnings; var now: Int }`

시계는 `components/clock/MinimalFace.tsx`의 `viewBox="0 0 200 200"` 좌표계를 그대로 옮긴다. 스펙 5.3의 치수표가 기준이다: 진행 링 반지름 92, 문자판 76, 링 두께 5, 점심 파선 1.5 `dash [2,3]`, 눈금 길이 3의 배수는 11 나머지는 5, 눈금 두께 3/1.5, 시침 `+10~-42` 두께 5, 분침 `+12~-62` 두께 3, 초침 `+16~-68` 두께 1.5, 중심점 반지름 3.5, 선 끝은 전부 round.

- [ ] **Step 1: `Theme.swift`를 쓴다**

```swift
import SwiftUI
import SalaryClockCore

/// 웹 화면의 색 역할을 이름으로 옮긴다. 값은 전부 Palette에서 온다 —
/// 여기에 hex를 적지 않는다.
struct Theme {
    let scheme: ColorScheme

    var background: Color { Palette.surfaceBackground.resolve(scheme) }
    var foreground: Color { Palette.surfaceForeground.resolve(scheme) }
    /// 시계 바늘 (시·분)
    var hands: Color { scheme == .dark ? Palette.slate100 : Palette.slate800 }
    /// 문자판 눈금
    var ticks: Color { scheme == .dark ? Palette.slate500 : Palette.slate400 }
    /// 링 — 근무 구간
    var ringTrack: Color { scheme == .dark ? Palette.slate700 : Palette.slate200 }
    /// 링 — 점심 파선
    var lunchDash: Color { scheme == .dark ? Palette.slate600 : Palette.slate300 }
    /// 진행 링 · 초침 · 중심점
    var accent: Color { Palette.emerald500 }
    /// 초당 적립액
    var perSecond: Color { scheme == .dark ? Palette.emerald400 : Palette.emerald600 }
    /// 보조 텍스트
    var secondary: Color { scheme == .dark ? Palette.slate400 : Palette.slate500 }
    /// 금액 소수부 · 흐린 텍스트
    var dim: Color { scheme == .dark ? Palette.slate500 : Palette.slate400 }
}
```

- [ ] **Step 2: `MinimalFaceView.swift`를 쓴다**

```swift
import SwiftUI
import SalaryClockCore

/// 말끔 — 사무실 벽시계. 웹 components/clock/MinimalFace.tsx의
/// viewBox="0 0 200 200" 좌표를 그대로 옮긴다.
///
/// 바늘 회전에 애니메이션을 걸지 않는다. 360°에서 0°로 넘어가는 순간
/// 역방향으로 한 바퀴 돈다. 매 tick마다 각도를 직접 찍으므로 필요도 없다.
struct MinimalFaceView: View {
    let now: Int
    let shift: Shift?
    let theme: Theme

    private let cx: CGFloat = 100
    private let cy: CGFloat = 100
    private let ringR: CGFloat = 92
    private let dialR: CGFloat = 76

    var body: some View {
        Canvas { ctx, size in
            let scale = min(size.width, size.height) / 200
            ctx.scaleBy(x: scale, y: scale)

            let arcs = shiftArcs(shift, now)
            let hands = handAngles(now)

            stroke(ctx, arc: arcs.work, radius: ringR, width: 5, color: theme.ringTrack)
            stroke(ctx, arc: arcs.progress, radius: ringR, width: 5, color: theme.accent)

            if let lunch = arcs.lunch {
                // 점심 구간은 링을 배경색으로 덧그어 지운다 —
                // "여기는 돈이 안 붙는다"를 보여주는 것이 전부다.
                stroke(ctx, arc: lunch, radius: ringR, width: 9, color: theme.background)
                stroke(
                    ctx, arc: lunch, radius: ringR, width: 1.5,
                    color: theme.lunchDash, dash: [2, 3]
                )
            }

            for i in 0..<12 {
                let deg = Double(i) * 30
                let long = i % 3 == 0
                let outer = polar(dialR, deg)
                let inner = polar(dialR - (long ? 11 : 5), deg)
                var path = Path()
                path.move(to: outer)
                path.addLine(to: inner)
                ctx.stroke(
                    path, with: .color(theme.ticks),
                    style: StrokeStyle(lineWidth: long ? 3 : 1.5, lineCap: .round)
                )
            }

            hand(ctx, angle: hands.hour, from: 10, to: -42, width: 5, color: theme.hands)
            hand(ctx, angle: hands.minute, from: 12, to: -62, width: 3, color: theme.hands)
            hand(ctx, angle: hands.second, from: 16, to: -68, width: 1.5, color: theme.accent)

            let dot = CGRect(x: cx - 3.5, y: cy - 3.5, width: 7, height: 7)
            ctx.fill(Path(ellipseIn: dot), with: .color(theme.accent))
        }
    }

    /// 12시 방향 0도, 시계방향 증가 — 웹 lib/clock.ts의 polarPoint와 같다.
    private func polar(_ r: CGFloat, _ deg: Double) -> CGPoint {
        let rad = (deg - 90) * .pi / 180
        return CGPoint(x: cx + r * cos(rad), y: cy + r * sin(rad))
    }

    private func stroke(
        _ ctx: GraphicsContext, arc: Arc, radius: CGFloat,
        width: CGFloat, color: Color, dash: [CGFloat] = []
    ) {
        guard arc.sweepDeg > 0 else { return }
        let sweep = min(arc.sweepDeg, 359.99)
        var path = Path()
        path.addArc(
            center: CGPoint(x: cx, y: cy), radius: radius,
            startAngle: .degrees(arc.startDeg - 90),
            endAngle: .degrees(arc.startDeg - 90 + sweep),
            clockwise: false
        )
        ctx.stroke(
            path, with: .color(color),
            style: StrokeStyle(lineWidth: width, lineCap: dash.isEmpty ? .round : .butt, dash: dash)
        )
    }

    private func hand(
        _ ctx: GraphicsContext, angle: Double,
        from: CGFloat, to: CGFloat, width: CGFloat, color: Color
    ) {
        var path = Path()
        path.move(to: CGPoint(x: cx, y: cy + from))
        path.addLine(to: CGPoint(x: cx, y: cy + to))
        let rotated = path.applying(
            CGAffineTransform(translationX: cx, y: cy)
                .rotated(by: angle * .pi / 180)
                .translatedBy(x: -cx, y: -cy)
        )
        ctx.stroke(
            rotated, with: .color(color),
            style: StrokeStyle(lineWidth: width, lineCap: .round)
        )
    }
}
```

- [ ] **Step 3: `PopoverView.swift`를 쓴다**

```swift
import SwiftUI
import SalaryClockCore

@Observable
final class TickModel {
    var now: Int = 0
    var earnings: Earnings = computeEarnings(.default, 0)
    var settings: Settings = .default
}

struct PopoverView: View {
    let model: TickModel
    var onSettings: () -> Void
    var onQuit: () -> Void

    @Environment(\.colorScheme) private var scheme

    private var theme: Theme { Theme(scheme: scheme) }

    var body: some View {
        VStack(spacing: 12) {
            MinimalFaceView(now: model.now, shift: model.earnings.shift, theme: theme)
                .frame(width: 132, height: 132)

            if model.earnings.phase == .dayoff || model.settings.hideAmount {
                // 쉬는 날과 가린 상태에서는 금액 대신 시각을 보여준다.
                // 웹의 가리기 화면과 같은 규칙이다.
                Text(formatClockTime(model.now))
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(theme.foreground)
            } else {
                amount
            }

            status

            HStack(spacing: 8) {
                Button("설정", action: onSettings)
                Button("종료", action: onQuit)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(16)
        .frame(width: 220)
        .background(theme.background)
    }

    private var amount: some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Text("오늘 벌어들인 금액")
                    .font(.system(size: 11))
                    .foregroundStyle(theme.secondary)
                Text(model.earnings.isNet ? "실수령" : "세전")
                    .font(.system(size: 10))
                    .foregroundStyle(theme.dim)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 3).stroke(theme.dim.opacity(0.4), lineWidth: 1)
                    )
            }

            // 소수 1자리까지 보여준다. 정수만 쓰면 초당 5.8원일 때 0.17초마다
            // 한 번씩 또각또각 올라가는데, 한 자리를 더 두면 흐르듯 보인다.
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text(formatWon(model.earnings.earned))
                    .foregroundStyle(theme.foreground)
                Text(String(format: ".%d", Int((model.earnings.earned.truncatingRemainder(dividingBy: 1)) * 10)))
                    .foregroundStyle(theme.dim)
            }
            .font(.system(size: 28, weight: .bold, design: .monospaced))
            .monospacedDigit()

            Text(
                model.earnings.perSecond > 0
                    ? "+\(formatPerSecond(model.earnings.perSecond)) / 초" : " "
            )
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(theme.perSecond)
        }
    }

    @ViewBuilder private var status: some View {
        let e = model.earnings
        let text: String = {
            switch e.phase {
            case .before: return "출근까지 \(formatDuration(e.msUntilStart))"
            case .lunch: return "점심시간 · 재개까지 \(formatDuration(e.msUntilLunchEnd))"
            case .after: return "오늘 근무 종료"
            case .working: return "퇴근까지 \(formatDuration(e.msUntilEnd))"
            case .dayoff: return " "
            }
        }()

        HStack(spacing: 4) {
            Text(text).foregroundStyle(theme.secondary)
            if e.phase != .after && e.phase != .dayoff && !model.settings.hideAmount {
                Text("· 남은 \(formatWon(e.remainingAmount))").foregroundStyle(theme.dim)
            }
        }
        .font(.system(size: 11, design: .monospaced))
        .monospacedDigit()
    }
}
```

- [ ] **Step 4: `AppDelegate`에 팝오버를 붙인다**

`AppDelegate`에 추가한다:

```swift
    private let model = TickModel()
    private var popover: NSPopover!
```

`applicationDidFinishLaunching`의 `startTimer` 호출 앞에 넣는다:

```swift
        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePopover)

        popover = NSPopover()
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: PopoverView(
                model: model,
                onSettings: { [weak self] in self?.openSettings() },
                onQuit: { NSApp.terminate(nil) }
            )
        )
```

그리고 메서드를 추가한다:

```swift
    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
            startTimer(interval: 1)
        } else {
            tick()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            // 팝오버가 열려 있는 동안만 0.1초로 올려 소수 1자리가 흐르게 한다.
            startTimer(interval: 0.1)
        }
    }

    private func openSettings() { /* Task 11에서 채운다 */ }
```

`tick()` 끝에 모델 갱신을 추가한다:

```swift
        model.now = now
        model.earnings = e
        model.settings = s
```

`import SwiftUI`를 파일 맨 위에 추가한다.

`openSettings()`가 Task 11까지 비어 있다 — 이 Task의 검증에서는 설정 버튼이 아무 일도 안 하는 게 맞다.

- [ ] **Step 5: 빌드하고 띄워서 확인한다**

```bash
swift build --package-path macos/SalaryClockApp
./scripts/bundle-app.sh
open macos/build/SalaryClock.app
```

확인할 것:
1. 메뉴바 항목을 **클릭하면 팝오버가 떨어진다**
2. 시계 바늘이 웹과 같은 모양이다 — 눈금 12개, 3의 배수가 길고 굵다
3. **초침이 1초마다 튀지 않고 스르륵 흐른다** (팝오버가 열려 있을 때)
4. 근무 구간 링이 emerald로 차 있고 점심 구간이 파선으로 비어 있다
5. 금액의 소수 자리가 흐른다
6. 팝오버를 닫으면 메뉴바 숫자는 계속 1초마다 갱신된다
7. 시스템 다크모드를 켜면 색이 따라 바뀐다

웹(`http://localhost:3000`)을 나란히 띄워 시계 모양을 비교한다. 어긋나면 어디가 다른지 적는다.

```bash
pkill -f SalaryClock.app || true
```

**띄우지 못했거나 확인 못 한 항목이 있으면 그렇다고 보고한다.**

- [ ] **Step 6: 커밋**

```bash
git add macos/SalaryClockApp
git commit -m "$(cat <<'EOF'
feat: 팝오버와 시계를 붙인다

MinimalFace의 viewBox 좌표를 그대로 SwiftUI Canvas로 옮긴다. 바늘에
애니메이션을 걸지 않는다 — 360도에서 0도로 넘어갈 때 역방향으로 한 바퀴
돈다. 팝오버가 열려 있는 동안만 0.1초로 올려 소수 자리가 흐르게 한다.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 11: 설정 창

**Files:**
- Create: `macos/SalaryClockApp/Sources/SalaryClockApp/SettingsView.swift`
- Modify: `macos/SalaryClockApp/Sources/SalaryClockApp/AppDelegate.swift`
- Create: `macos/SalaryClockApp/Tests/SalaryClockAppTests/SettingsStoreTests.swift`

**Interfaces:**
- Consumes: `SettingsStore`, `Settings`, `formatKoreanUnits`, `isValidHHmm`
- Produces: `SettingsView(onDone:)`, `AppDelegate.openSettings()`

스펙 4.4의 항목만 담는다 — 급여(연봉/월급/시급), 근무 시작·종료, 점심(on/off·시작·무급 분), 실수령액 기준, 로그인 시 자동 실행. 근무일수는 `auto` 고정이고 달력·얼굴·다크모드 토글·가리기는 제외다.

- [ ] **Step 1: 검증 테스트를 먼저 쓴다**

`macos/SalaryClockApp/Tests/SalaryClockAppTests/SettingsStoreTests.swift`:

```swift
import Testing
@testable import SalaryClockApp
import SalaryClockCore

@Test("기본 설정은 유효하다")
func defaultIsValid() {
    #expect(SettingsStore.isValid(.default))
}

@Test("급여가 0 이하면 무효다")
func rejectsNonPositivePay() {
    var s = Settings.default
    s.payAmount = 0
    #expect(!SettingsStore.isValid(s))
}

@Test("출근과 퇴근이 같으면 무효다")
func rejectsZeroShift() {
    var s = Settings.default
    s.workEnd = s.workStart
    #expect(!SettingsStore.isValid(s))
}

@Test("무급 시간이 근무시간 전체를 덮으면 무효다")
func rejectsLunchCoveringShift() {
    var s = Settings.default
    s.lunchMinutes = 9 * 60
    #expect(!SettingsStore.isValid(s))
}

@Test("점심이 퇴근 시각을 넘어가면 무효다")
func rejectsLunchPastEnd() {
    var s = Settings.default
    s.lunchStart = "17:30"
    s.lunchMinutes = 60
    #expect(!SettingsStore.isValid(s))
}

@Test("야간근무는 유효하다")
func acceptsNightShift() {
    var s = Settings.default
    s.workStart = "22:00"
    s.workEnd = "06:00"
    s.lunchStart = "01:00"
    #expect(SettingsStore.isValid(s))
}

@Test("시각 형식이 깨지면 무효다")
func rejectsBadTime() {
    var s = Settings.default
    s.workStart = "9:00"
    #expect(!SettingsStore.isValid(s))
    s.workStart = "24:00"
    #expect(!SettingsStore.isValid(s))
}
```

- [ ] **Step 2: 실패를 확인한다**

```bash
swift test --package-path macos/SalaryClockApp
```

Expected: Task 9에서 `isValid`를 이미 썼다면 전부 PASS한다. 실패하는 것이 있으면 `isValid`의 조건이 웹 zod 스키마와 어긋난 것이니 고친다.

- [ ] **Step 3: `SettingsView.swift`를 쓴다**

```swift
import SwiftUI
import ServiceManagement
import SalaryClockCore

/// 웹 SettingsPanel에서 맥이 쓰는 항목만 남긴 폼.
///
/// macOS 기본 Form 스타일(회색 배경, 오른쪽 정렬 라벨)을 쓰지 않는다 —
/// 그러면 웹과 다른 화면이 된다. 라벨을 왼쪽 위에 두고 입력칸을 폭 가득
/// 채우는 웹의 배치를 따른다.
struct SettingsView: View {
    var onDone: () -> Void

    @State private var draft: Settings = SettingsStore.shared.settings
    @State private var launchAtLogin: Bool = SMAppService.mainApp.status == .enabled
    @Environment(\.colorScheme) private var scheme

    private var theme: Theme { Theme(scheme: scheme) }
    private var isValid: Bool { SettingsStore.isValid(draft) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("설정").font(.system(size: 18, weight: .bold))

            field("급여") {
                Picker("", selection: $draft.payMode) {
                    Text("연봉").tag(PayMode.annual)
                    Text("월급").tag(PayMode.monthly)
                    Text("시급").tag(PayMode.hourly)
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                TextField("", value: $draft.payAmount, format: .number)
                    .textFieldStyle(.roundedBorder)
                Text(formatKoreanUnits(draft.payAmount))
                    .font(.system(size: 11))
                    .foregroundStyle(theme.dim)
            }

            field("근무 시간") {
                HStack {
                    timeField($draft.workStart)
                    Text("–").foregroundStyle(theme.dim)
                    timeField($draft.workEnd)
                }
            }

            field("점심") {
                Toggle("점심시간 제외", isOn: $draft.lunchEnabled)
                if draft.lunchEnabled {
                    HStack {
                        timeField($draft.lunchStart)
                        TextField("", value: $draft.lunchMinutes, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 60)
                        Text("분 무급").font(.system(size: 11)).foregroundStyle(theme.dim)
                    }
                }
            }

            Toggle("실수령액 기준으로 보기", isOn: $draft.netPay)
            Toggle("로그인할 때 자동 실행", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, on in
                    // 등록이 실패해도 앱은 계속 돌아야 한다. 토글만 되돌린다.
                    do {
                        if on { try SMAppService.mainApp.register() }
                        else { try SMAppService.mainApp.unregister() }
                    } catch {
                        launchAtLogin = SMAppService.mainApp.status == .enabled
                    }
                }

            if !isValid {
                Text("설정값이 올바르지 않습니다")
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
            }

            HStack {
                Spacer()
                Button("닫기", action: onDone)
                Button("저장") {
                    SettingsStore.shared.settings = draft
                    onDone()
                }
                .disabled(!isValid)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 340)
        .background(theme.background)
    }

    @ViewBuilder
    private func field<C: View>(_ label: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.system(size: 12, weight: .medium)).foregroundStyle(theme.secondary)
            content()
        }
    }

    /// "HH:mm"을 그대로 받는다. 형식이 깨지면 저장 버튼이 잠긴다.
    private func timeField(_ value: Binding<String>) -> some View {
        TextField("HH:mm", text: value)
            .textFieldStyle(.roundedBorder)
            .frame(width: 70)
            .foregroundStyle(isValidHHmm(value.wrappedValue) ? theme.foreground : .red)
    }
}
```

- [ ] **Step 4: `AppDelegate`에서 설정 창을 연다**

`openSettings()`를 채우고 창을 들고 있을 프로퍼티를 추가한다:

```swift
    private var settingsWindow: NSWindow?

    private func openSettings() {
        popover.performClose(nil)
        startTimer(interval: 1)

        if let w = settingsWindow {
            w.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 460),
            styleMask: [.titled, .closable],
            backing: .buffered, defer: false
        )
        window.title = "SalaryClock 설정"
        window.isReleasedWhenClosed = false
        window.contentViewController = NSHostingController(
            rootView: SettingsView(onDone: { [weak self] in
                self?.settingsWindow?.close()
            })
        )
        window.center()
        settingsWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
```

`LSUIElement` 앱은 기본적으로 창을 앞으로 못 가져오므로 `NSApp.activate`가 필요하다.

- [ ] **Step 5: 빌드하고 확인한다**

```bash
swift test --package-path macos/SalaryClockApp
./scripts/bundle-app.sh
open macos/build/SalaryClock.app
```

확인할 것:
1. 팝오버의 **설정 버튼을 누르면 창이 뜬다**
2. 연봉을 바꾸고 저장하면 **메뉴바 금액이 즉시 따라 바뀐다**
3. 근무 시각을 `9:00`처럼 잘못 넣으면 빨갛게 되고 저장 버튼이 잠긴다
4. 점심 토글을 끄면 유급 시간이 늘어 초당 단가가 내려간다
5. 실수령액 기준을 켜면 금액이 줄고 팝오버 배지가 `실수령`으로 바뀐다
6. 창을 닫고 다시 열어도 저장한 값이 남아 있다
7. 앱을 껐다 켜도 설정이 남아 있다

```bash
pkill -f SalaryClock.app || true
```

- [ ] **Step 6: 커밋**

```bash
git add macos/SalaryClockApp
git commit -m "$(cat <<'EOF'
feat: 설정 창을 붙인다

웹 SettingsPanel에서 맥이 쓰는 항목만 남기고 배치는 그대로 따른다.
macOS 기본 Form 스타일을 쓰지 않는다 — 그러면 웹과 다른 화면이 된다.
UserDefaults에 저장하고 값이 규칙을 어기면 기본값으로 되돌린다.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 12: 설치와 스펙 갱신

**Files:**
- Create: `scripts/install-app.sh`
- Modify: `docs/superpowers/specs/2026-09-22-macos-menubar-design.md` (4장, 10장)
- Modify: `README.md`

**Interfaces:**
- Consumes: `scripts/bundle-app.sh`
- Produces: `/Applications/SalaryClock.app`

- [ ] **Step 1: 설치 스크립트를 쓴다**

`scripts/install-app.sh`:

```bash
#!/usr/bin/env bash
# release 빌드를 만들어 /Applications에 설치한다.
#
# 본인 기계에서 빌드한 ad-hoc 서명 앱이라 Gatekeeper가 막지 않는다 —
# 우클릭으로 열기나 xattr -dr com.apple.quarantine이 필요 없다.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="/Applications/SalaryClock.app"

"$ROOT/scripts/bundle-app.sh" release

# 돌고 있으면 먼저 내린다. 실행 중인 번들을 덮어쓰면 다음 실행이 깨진다.
pkill -f "SalaryClock.app/Contents/MacOS/SalaryClock" || true
sleep 1

rm -rf "$DEST"
cp -R "$ROOT/macos/build/SalaryClock.app" "$DEST"

echo "설치 완료: $DEST"
echo "실행: open $DEST"
```

```bash
chmod +x scripts/install-app.sh
```

- [ ] **Step 2: 설치해서 확인한다**

```bash
./scripts/install-app.sh
open /Applications/SalaryClock.app
```

확인할 것:
1. Gatekeeper 경고 없이 바로 뜬다
2. 메뉴바에 금액이 보인다
3. 설정에서 "로그인할 때 자동 실행"을 켜면 `SMAppService.mainApp.status`가 `.enabled`가 된다 — 시스템 설정 → 일반 → 로그인 항목에 SalaryClock이 보이는지 확인한다

- [ ] **Step 3: 스펙을 실제 구조에 맞춘다**

`docs/superpowers/specs/2026-09-22-macos-menubar-design.md` 4장 맨 앞의 디렉터리 블록을 고친다:

```
macos/
  SalaryClockCore/        Swift Package — 도메인 순수 함수 + 테스트
  SalaryClockApp/         Swift Package — 메뉴바, 팝오버, 설정 창
scripts/
  bundle-app.sh           swift build → SalaryClock.app
  install-app.sh          /Applications 설치
  generate-palette-swift.ts   palette.json → Palette.swift
```

그리고 그 아래에 한 문단을 넣는다:

> Xcode 프로젝트를 두지 않는다. `.pbxproj`는 손으로 쓰기 어렵고 diff가
> 읽히지 않아 리뷰가 불가능한 반면, `Package.swift`와 20줄짜리 번들
> 스크립트는 둘 다 읽힌다. `swift build`가 AppKit·SwiftUI를 그대로
> 컴파일하고, `.app` 번들은 디렉터리 구조 + `Info.plist` + ad-hoc
> 서명이면 끝이다.

10장의 `xcodebuild`를 `scripts/install-app.sh`로 바꾸고, 5.1에 한 줄을 더한다:

> `Palette.swift` 생성기는 `hex`가 3자리(`#fff`)일 수 있고 `lab`이
> `null`일 수 있음을 처리해야 한다. 이번 버전은 sRGB `hex`만 쓰고
> `lab`은 JSON에 남겨둔다.

- [ ] **Step 4: README에 맥 앱을 적는다**

`README.md`의 맨 끝에 붙인다:

```markdown
## 맥 메뉴바 앱

금액을 메뉴바에 직접 띄우는 네이티브 앱이 `macos/`에 있다.

```bash
./scripts/install-app.sh      # 빌드해서 /Applications에 설치
open /Applications/SalaryClock.app
```

계산 규칙은 웹과 공유한다 — `shared/golden/*.json`을 양쪽 테스트가 함께
읽으므로, 규칙이 갈라지면 한쪽이 빨개진다.

```bash
npm test                                      # 웹
swift test --package-path macos/SalaryClockCore   # 맥
```
```

- [ ] **Step 5: 전체 검증**

```bash
npm test && npx tsc --noEmit && npm run lint && npm run build
npm run golden && npm run palette && npm run palette:swift && git diff --exit-code shared/golden/
swift test --package-path macos/SalaryClockCore
swift test --package-path macos/SalaryClockApp
TZ=UTC swift test --package-path macos/SalaryClockCore
git status --short
```

Expected: 전부 통과, 워킹 트리 clean(`palette:swift` 재생성이 diff를 만들지 않아야 한다)

- [ ] **Step 6: 커밋**

```bash
git add scripts/install-app.sh docs README.md
git commit -m "$(cat <<'EOF'
chore: 설치 스크립트와 스펙 갱신

본인 기계에서 빌드한 ad-hoc 서명 앱이라 Gatekeeper가 막지 않는다.
스펙 4장의 Xcode 프로젝트 전제를 실제 구조(SwiftPM + 번들 스크립트)로
고친다.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## 최종 검증

- [ ] `npm test` — 웹 전부 통과
- [ ] `swift test --package-path macos/SalaryClockCore` — 골든 전부 통과
- [ ] `swift test --package-path macos/SalaryClockApp` — 전부 통과
- [ ] `TZ=UTC` / `TZ=America/New_York`에서도 두 Swift 스위트 통과
- [ ] `npm run golden && npm run palette && npm run palette:swift` 후 `git diff --exit-code`
- [ ] `/Applications/SalaryClock.app`이 설치되고 메뉴바에 금액이 뜬다
- [ ] 클릭하면 팝오버, 설정 버튼으로 설정 창이 열린다
- [ ] 연봉을 바꾸면 메뉴바가 즉시 따라온다
- [ ] 웹과 맥을 나란히 띄웠을 때 같은 금액을 보여준다

## Self-Review

**스펙 커버리지:**

| 스펙 항목 | 구현 위치 |
|---|---|
| 4.1 메뉴바 (표·폰트·아이콘) | Task 9 |
| 4.2 타이머 (`RunLoop.common`, 매 tick 재계산, 0.1초 전환) | Task 9, Task 10 |
| 4.3 팝오버 | Task 10 |
| 4.4 설정 창 | Task 11 |
| 4.5 저장 (`UserDefaults` + 검증) | Task 9, Task 11 |
| 5.1 팔레트 | Task 8 |
| 5.2 글꼴 | 아래 "스펙과 달라진 점" |
| 5.3 치수 | Task 10 |
| 5.4 문구·포맷 | Task 7, Task 10 |
| 6 SalaryClockCore | Task 2–8 |
| 7 의존 방향 | File Structure |
| 8 엣지 케이스 | Task 3·4·6 골든, Task 9 절전 복귀 |
| 9 테스트 전략 | Task 1–7 골든 |
| 10 빌드와 배포 | Task 12 |
| 12장 3~7번 | 이 계획 전체 |

**스펙과 달라진 점 (의도적):**

- **Xcode 프로젝트를 만들지 않는다.** SwiftPM + 번들 스크립트로 간다. 이유는 Global Constraints와 Task 12에 적었고, 스펙 4장을 Task 12에서 고친다.
- **글꼴 (5.2)을 이번 버전에서 다루지 않는다.** 스펙은 금액에 Geist Mono를 번들하라고 하는데, 팝오버에서는 `.monospaced` 시스템 글꼴을 쓴다. Geist Mono를 번들하려면 OFL 라이선스 파일과 `ATSApplicationFontsPath`를 더해야 하고, 그 차이는 22pt 숫자 몇 개에서만 드러난다. 웹과 나란히 놓고 봤을 때 거슬리면 그때 붙인다 — Task 10 Step 5의 비교가 그 판단 재료다.
- **`lab()` 색을 쓰지 않는다.** sRGB hex만 쓴다. Task 8에 이유를 적었다.
- **시계 얼굴은 `minimal` 1종.** 스펙 2장의 제외 항목 그대로다.

**미해결로 남긴 것:**

- 앱 아이콘이 없다. `LSUIElement` 앱이라 Dock에 뜨지 않으므로 없어도 동작에 지장이 없고, 메뉴바 아이콘은 `RingIcon`이 그린다. 시스템 설정의 로그인 항목 목록에서는 기본 아이콘으로 보인다.
- 스펙 13장에 적힌 야간근무 월요일 문제(일요일 22시 시작 시프트 때문에 월요일 낮이 휴무일로 보인다)는 그대로 남는다. 코드를 고치지 않고 기록만 해둔 상태다.

---

### Task 15: 근무일수 설정과 달력

> 실행 순서상 Task 11 다음이다. 번호는 계획에 덧붙인 순서이지 실행 순서가 아니다.

**Files:**
- Modify: `scripts/generate-golden.ts`, `lib/__tests__/golden.test.ts`
- Create: `shared/golden/calendar.json` (생성물)
- Create: `macos/SalaryClockCore/Sources/SalaryClockCore/MonthCells.swift`
- Create: `macos/SalaryClockCore/Tests/SalaryClockCoreTests/MonthCellsTests.swift`
- Create: `macos/SalaryClockApp/Sources/SalaryClockAppLib/MonthCalendarView.swift`
- Modify: `macos/SalaryClockApp/Sources/SalaryClockAppLib/SettingsView.swift`

**Interfaces:**
- Consumes: `isDefaultOff`, `dateKey`, `workdaysFromCalendar`, `effectiveWorkDays` (`SalaryClockCore`), `Theme`/`Palette`
- Produces:
  - `enum DayKind: String { work, weekend, holiday, customOff, customWork }`
  - `struct DayCell { date: String; day: Int; dow: Int; kind: DayKind; isWorkday: Bool }`
  - `monthCells(_ year: Int, _ month: Int, _ overrides: [String]) -> [DayCell]` (month는 0-based)
  - `toggleOverride(_ overrides: [String], _ date: String) -> [String]`
  - `clearMonthOverrides(_ overrides: [String], _ year: Int, _ month: Int) -> [String]`
  - `MonthCalendarView(year:month:overrides:onToggle:onClearMonth:)`

웹과 맥이 같은 설정인데 다른 금액을 보여주는 원인이었다 — 맥에 근무일수 설정이 없어 늘 `auto`로 계산했다. 웹의 세 모드를 그대로 옮긴다.

**JSON의 `kind` 문자열은 웹의 것을 그대로 쓴다** — `custom-off`·`custom-work`에 하이픈이 들어간다. Swift `DayKind`의 `rawValue`를 그 문자열에 맞춰야 골든이 맞는다.

- [ ] **Step 1: 웹에 monthCells 골든을 추가한다**

`scripts/generate-golden.ts`의 `write('workdays.json', workdays)` 위에 넣는다:

```ts
/** 달력 그리드가 그리는 날짜별 상태. 맥의 MonthCalendarView가 같은 칸을 칠해야 한다. */
const CALENDAR_MONTHS: { label: string; year: number; month: number; overrides: string[] }[] = [
  { label: '2026년 9월 — 추석이 평일에 걸린 달', year: 2026, month: 8, overrides: [] },
  { label: '2026년 9월 — 평일 하나를 쉬고 토요일 하나를 일함', year: 2026, month: 8,
    overrides: ['2026-09-22', '2026-09-26'] },
  { label: '2026년 2월 — 설 연휴', year: 2026, month: 1, overrides: [] },
  { label: '2027년 1월 — 다음 해 표', year: 2027, month: 0, overrides: [] },
  { label: '2028년 9월 — 공휴일 표가 없는 해', year: 2028, month: 8, overrides: [] },
]

const calendars = CALENDAR_MONTHS.map((m) => ({
  ...m,
  expected: {
    workdays: workdaysFromCalendar(m.year, m.month, m.overrides),
    cells: monthCells(m.year, m.month, m.overrides).map((c) => ({
      date: c.date, day: c.day, dow: c.dow, kind: c.kind, isWorkday: c.isWorkday,
    })),
  },
}))

write('calendar.json', calendars)
```

import에 `monthCells`와 `workdaysFromCalendar`를 `@/lib/calendar`에서 추가한다.

- [ ] **Step 2: 골든을 뽑고 눈으로 확인한다**

```bash
npm run golden
python3 -c "
import json
d=json.load(open('shared/golden/calendar.json'))
for m in d:
    print(m['label'], '→ 근무', m['expected']['workdays'], '일')
print([c['kind'] for c in d[0]['expected']['cells'][20:27]])
"
```

Expected: 첫 달이 근무 20일. 9월 21~27일의 `kind`가 `work, work, work, holiday, holiday, holiday, weekend` — 9/26(토)은 추석이지만 주말이 먼저라 `weekend`다.

- [ ] **Step 3: 웹 골든 테스트를 추가한다**

`lib/__tests__/golden.test.ts` 맨 끝:

```ts
describe('golden — calendar', () => {
  const cases = read('calendar.json')

  it('케이스가 비어 있지 않다', () => {
    expect(cases.length).toBeGreaterThan(0)
  })

  for (const m of cases) {
    it(m.label, () => {
      expect(workdaysFromCalendar(m.year, m.month, m.overrides)).toBe(m.expected.workdays)
      const cells = monthCells(m.year, m.month, m.overrides)
      expect(cells.length).toBe(m.expected.cells.length)
      cells.forEach((c, i) => {
        const want = m.expected.cells[i]
        expect(c.date).toBe(want.date)
        expect(c.day).toBe(want.day)
        expect(c.dow).toBe(want.dow)
        expect(c.kind).toBe(want.kind)
        expect(c.isWorkday).toBe(want.isWorkday)
      })
    })
  }
})
```

import에 `monthCells`·`workdaysFromCalendar`를 추가한다.

- [ ] **Step 4: 검증 — 웹이 전부 통과하는지**

```bash
npm test && npx tsc --noEmit && npm run lint
npm run golden && git diff --exit-code shared/golden/
TZ=UTC npx vitest run
```

- [ ] **Step 5: Swift 골든 테스트를 먼저 쓴다**

`macos/SalaryClockCore/Tests/SalaryClockCoreTests/MonthCellsTests.swift`:

```swift
import Testing
import Foundation
@testable import SalaryClockCore

struct CalendarCase: Decodable {
    struct Cell: Decodable {
        let date: String; let day: Int; let dow: Int; let kind: String; let isWorkday: Bool
    }
    struct Expected: Decodable { let workdays: Int; let cells: [Cell] }
    let label: String
    let year: Int
    let month: Int
    let overrides: [String]
    let expected: Expected
}

@Test("골든 — calendar")
func goldenCalendar() throws {
    let cases: [CalendarCase] = try Golden.decode("calendar.json", as: [CalendarCase].self)
    #expect(cases.count > 0)

    for c in cases {
        #expect(workdaysFromCalendar(c.year, c.month, c.overrides) == c.expected.workdays, "\(c.label) workdays")
        let cells = monthCells(c.year, c.month, c.overrides)
        #expect(cells.count == c.expected.cells.count, "\(c.label) 칸 수")
        for (i, want) in c.expected.cells.enumerated() {
            let got = cells[i]
            #expect(got.date == want.date, "\(c.label) [\(i)] date")
            #expect(got.day == want.day, "\(c.label) [\(i)] day")
            #expect(got.dow == want.dow, "\(c.label) [\(i)] dow")
            #expect(got.kind.rawValue == want.kind, "\(c.label) [\(i)] kind")
            #expect(got.isWorkday == want.isWorkday, "\(c.label) [\(i)] isWorkday")
        }
    }
}

@Test("override는 기본값을 뒤집는다")
func overrideFlips() {
    let plain = monthCells(2026, 8, [])
    let flipped = monthCells(2026, 8, ["2026-09-22", "2026-09-26"])
    #expect(plain[21].kind == .work && flipped[21].kind == .customOff)
    #expect(plain[25].kind == .weekend && flipped[25].kind == .customWork)
}

@Test("toggleOverride는 넣고 빼고 정렬한다")
func toggles() {
    let once = toggleOverride([], "2026-09-22")
    #expect(once == ["2026-09-22"])
    #expect(toggleOverride(once, "2026-09-22").isEmpty)
    #expect(toggleOverride(["2026-09-24"], "2026-09-22") == ["2026-09-22", "2026-09-24"])
}

@Test("clearMonthOverrides는 그 달만 지운다")
func clearsOneMonth() {
    let all = ["2026-08-15", "2026-09-22", "2026-09-26", "2026-10-03"]
    #expect(clearMonthOverrides(all, 2026, 8) == ["2026-08-15", "2026-10-03"])
}
```

- [ ] **Step 6: 실패를 확인한다**

```bash
swift test --package-path macos/SalaryClockCore --scratch-path "$HOME/Library/Caches/salaryclock/core"
```

Expected: 컴파일 실패 — `monthCells`·`DayKind`·`toggleOverride`·`clearMonthOverrides` 없음

- [ ] **Step 7: `MonthCells.swift`를 쓴다**

원본은 `lib/calendar.ts`다. `rawValue`가 웹의 문자열과 같아야 한다.

```swift
import Foundation

public enum DayKind: String, Sendable {
    case work
    case weekend
    case holiday
    case customOff = "custom-off"
    case customWork = "custom-work"
}

public struct DayCell: Sendable {
    /// "YYYY-MM-DD"
    public let date: String
    public let day: Int
    /// 0=일 … 6=토
    public let dow: Int
    public let kind: DayKind
    /// 근무일로 세는 날인지
    public let isWorkday: Bool
}

/// 그 달의 날짜별 상태. month는 0-based.
///
/// overrides는 "기본값을 뒤집은 날"의 목록이다. 연차를 더하는 것과 공휴일에
/// 출근한 것을 같은 방식으로 담을 수 있다.
public func monthCells(_ year: Int, _ month: Int, _ overrides: [String]) -> [DayCell] {
    let flipped = Set(overrides)
    var cells: [DayCell] = []

    for day in 1...daysInMonth(year, month) {
        let date = dateKey(year, month, day)
        let dow = weekday(year, month, day)
        let defaultOff = isDefaultOff(year, month, day)
        let isFlipped = flipped.contains(date)
        let off = isFlipped ? !defaultOff : defaultOff

        let kind: DayKind
        if isFlipped {
            kind = off ? .customOff : .customWork
        } else if dow == 0 || dow == 6 {
            kind = .weekend
        } else if defaultOff {
            kind = .holiday
        } else {
            kind = .work
        }

        cells.append(DayCell(date: date, day: day, dow: dow, kind: kind, isWorkday: !off))
    }
    return cells
}

/// 한 날짜의 기본값 뒤집기를 켜고 끈다. 결과는 항상 정렬돼 있다.
public func toggleOverride(_ overrides: [String], _ date: String) -> [String] {
    overrides.contains(date)
        ? overrides.filter { $0 != date }
        : (overrides + [date]).sorted()
}

/// 그 달의 override를 모두 지운다. month는 0-based.
public func clearMonthOverrides(_ overrides: [String], _ year: Int, _ month: Int) -> [String] {
    let prefix = String(format: "%04d-%02d-", year, month + 1)
    return overrides.filter { !$0.hasPrefix(prefix) }
}
```

`daysInMonth`는 `Workdays.swift`에 이미 있다. `private`이면 `internal`로 올린다.

- [ ] **Step 8: 통과를 확인한다**

```bash
swift test --package-path macos/SalaryClockCore --scratch-path "$HOME/Library/Caches/salaryclock/core"
TZ=UTC swift test --package-path macos/SalaryClockCore --scratch-path "$HOME/Library/Caches/salaryclock/core"
```

Expected: 둘 다 전부 PASS

- [ ] **Step 9: 커밋**

```bash
git add scripts/generate-golden.ts lib/__tests__/golden.test.ts shared/golden macos/SalaryClockCore
git commit -m "$(cat <<'EOF'
feat: 달력 날짜 상태를 골든에 걸고 Swift로 옮긴다

맥에 근무일수 설정이 없어 늘 auto로 계산한 것이 웹과 금액이 갈린
원인이었다. 달력 모드를 옮기기 전에 monthCells를 골든으로 고정한다.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 10: `MonthCalendarView`를 쓴다**

원본은 `components/MonthCalendar.tsx`다. 7열 그리드, 1일의 요일만큼 앞을 비우고, 칸 색은 `kind`로 가른다. 머리글은 `2026년 9월 · 근무 20일`이고 오른쪽에 그 달 지정을 지우는 버튼이 있다.

색은 웹의 `KIND_CLASS`를 `Theme`의 역할로 옮긴다. 웹이 `holiday`에 rose 계열을 쓰는데 `Palette`에 rose 토큰이 없으므로, **`scripts/extract-palette.ts`의 `TOKENS`에 웹이 실제로 쓰는 rose 토큰을 추가하고 `npm run build && npm run palette && npm run palette:swift`로 다시 뽑는다.** hex를 손으로 적지 않는다.

- [ ] **Step 11: 설정 창에 근무일수 구간을 붙인다**

`SettingsView.swift`에 웹 `SettingsPanel.tsx`의 근무일수 구간을 옮긴다 — `auto` / `달력` / `직접 입력` 세그먼트, 모드별로 보이는 것이 다르다:

| 모드 | 보이는 것 |
|---|---|
| `auto` | `이번 달 N일 (공휴일 M일 제외)` 안내 |
| `달력` | `MonthCalendarView` + 월 이동 |
| `직접 입력` | 숫자 한 칸 |

날짜를 누르면 `dayOverrides`가 `toggleOverride`로 바뀌고, 지우기 버튼은 `clearMonthOverrides`를 쓴다. `workDaysPerMonth`는 `직접 입력`에서만 쓰인다.

- [ ] **Step 12: 검증 — 눈으로 확인한다**

```bash
swift test --package-path macos/SalaryClockApp --scratch-path "$HOME/Library/Caches/salaryclock/app"
./scripts/bundle-app.sh && open macos/build/SalaryClock.app
```

확인할 것:
1. 세 모드가 전환되고, 각 모드에서 보이는 것이 위 표와 같다
2. 달력에서 평일을 누르면 회색(쉬는 날)으로, 주말을 누르면 초록(출근)으로 바뀐다
3. 머리글의 근무일수가 누를 때마다 따라 바뀐다
4. 저장하면 메뉴바 금액이 바뀐다 — 근무일수가 줄면 하루치가 커진다
5. `직접 입력`에 21을 넣으면 `auto`(20일)와 다른 금액이 나온다
6. 껐다 켜도 달력에서 찍은 날이 남아 있다

**캡처 규칙: 화면·영역 캡처 금지.** `CGWindowListCopyWindowInfo`로 창 id를 얻어 `screencapture -l <windowID>`로 그 창만 찍거나 접근성 텍스트로 읽는다. 창을 못 찾으면 "확인 못 함"으로 보고한다.

- [ ] **Step 13: 커밋**

```bash
git add macos/SalaryClockApp scripts shared/golden macos/SalaryClockCore
git commit -m "$(cat <<'EOF'
feat: 설정 창에 근무일수 세 모드와 달력을 붙인다

웹과 같은 auto/달력/직접 입력. 이걸로 "같은 설정인데 금액이 다르다"의
마지막 원인이 사라진다.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 13: 퇴근 후 격려 메시지

> 실행 순서상 Task 15 다음이다.

**Files:**
- Create: `lib/afterWork.ts`, `lib/__tests__/afterWork.test.ts`
- Modify: `scripts/generate-golden.ts`, `lib/__tests__/golden.test.ts`, `components/StatusLine.tsx`
- Create: `shared/golden/afterWork.json` (생성물)
- Create: `macos/SalaryClockCore/Sources/SalaryClockCore/AfterWork.swift`, `macos/SalaryClockCore/Tests/SalaryClockCoreTests/AfterWorkTests.swift`
- Modify: `macos/SalaryClockApp/Sources/SalaryClockAppLib/PopoverView.swift`

**Interfaces:**
- Consumes: `isDayOff`, `resolveShift`, `startOfLocalDay`, `MS_PER_DAY`
- Produces: `type AfterWorkKind = 'tomorrow' | 'restThisWeek' | 'nextWeek' | 'longBreak'`, `afterWorkKind(s, now): AfterWorkKind` (웹), 같은 이름의 Swift enum·함수

`오늘 근무 종료`가 딱딱하다는 사용자 요청에서 나왔다. 날짜에 따라 다른 격려 문구를 보여준다.

**문구는 도메인이 아니라 UI에 둔다.** `lib/`는 *어떤 종류*인지만 정하고(`AfterWorkKind`), 실제 한국어 문장은 웹 `StatusLine`과 맥 `PopoverView`가 각자 갖는다. 골든은 kind를 고정하므로 판정 규칙은 갈라질 수 없고, 문구는 스펙 5.4의 표가 단일 출처다.

| kind | 문구 | 언제 |
|---|---|---|
| `tomorrow` | `오늘도 고생하셨어요` | 내일이 근무일 |
| `restThisWeek` | `오늘도 고생하셨어요, 푹 쉬세요` | 다음 근무일이 2~3일 뒤이고 같은 주 |
| `nextWeek` | `이번 주도 고생하셨어요` | 다음 근무일이 2~3일 뒤이고 다음 주 이후 |
| `longBreak` | `연휴 잘 보내세요` | 다음 근무일이 4일 이상 뒤 |

주 경계는 **일요일 시작**(한국 달력)이다. 금요일 퇴근이면 다음 근무일이 월요일 = 다음 주 → `nextWeek`. 수요일 퇴근 + 목요일 공휴일 + 금요일 출근이면 같은 주 → `restThisWeek`. 그래서 "다음 주에도"가 거짓이 되는 경우가 안 생긴다.

- [ ] **Step 1: 실패하는 웹 테스트를 쓴다**

`lib/__tests__/afterWork.test.ts`:

```ts
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
    // 2026-09-23(수) 퇴근, 9/24(목)·9/25(금)이 추석이라 다음 근무일은 9/28(월)
    // → 이 케이스는 nextWeek다. 같은 주 케이스는 override로 만든다
    const s: Settings = { ...DEFAULT_SETTINGS, dayOverrides: ['2026-09-24'] }
    // 9/24를 출근으로 뒤집으면 9/23(수) 퇴근 → 다음 근무일 9/24(목), 하루 뒤
    expect(afterWorkKind(s, at(2026, 8, 23))).toBe('tomorrow')
  })

  it('추석 연휴 직전이면 연휴다', () => {
    // 2026-09-23(수) 퇴근 → 9/24·9/25 추석, 9/26·9/27 주말 → 다음 근무일 9/28(월), 5일 뒤
    expect(afterWorkKind(DEFAULT_SETTINGS, at(2026, 8, 23))).toBe('longBreak')
  })

  it('목요일 퇴근에 금요일만 쉬면 다음 근무일은 월요일이라 다음 주다', () => {
    const s: Settings = { ...DEFAULT_SETTINGS, dayOverrides: ['2026-10-02'] }
    expect(afterWorkKind(s, at(2026, 9, 1))).toBe('nextWeek')
  })
})
```

- [ ] **Step 2: 실패를 확인한다**

```bash
npx vitest run lib/__tests__/afterWork.test.ts
```

Expected: FAIL — 모듈 없음

- [ ] **Step 3: `lib/afterWork.ts`를 쓴다**

```ts
import { MS_PER_DAY, startOfLocalDay } from '@/lib/time'
import { isDayOff } from '@/lib/calendar'
import { resolveShift } from '@/lib/shift'
import type { Settings } from '@/lib/settings'

/** 퇴근 후 보여줄 격려 문구의 종류. 문구 자체는 UI가 갖는다 */
export type AfterWorkKind = 'tomorrow' | 'restThisWeek' | 'nextWeek' | 'longBreak'

/** 일요일을 주의 시작으로 본 주 번호. 두 날이 같은 주인지만 비교하는 데 쓴다 */
function weekIndex(dayStart: number): number {
  const d = new Date(dayStart)
  return Math.floor((dayStart - d.getDay() * MS_PER_DAY) / MS_PER_DAY)
}

/**
 * 오늘 일을 마친 뒤, 다음 근무일이 언제인지로 격려 문구의 종류를 고른다.
 *
 * 기준일은 now가 아니라 방금 끝낸 시프트의 시작일이다 — 야간근무가 자정을
 * 넘겨 끝나도 "오늘 일한 날"은 시프트가 시작한 날이다.
 */
export function afterWorkKind(s: Settings, now: number): AfterWorkKind {
  const shift = resolveShift(s, now)
  const base = startOfLocalDay(shift.startMs)

  // 최대 30일까지만 찾는다. 그 안에 근무일이 없으면 긴 휴식으로 본다
  for (let gap = 1; gap <= 30; gap += 1) {
    const day = base + gap * MS_PER_DAY
    if (isDayOff(s.dayOverrides, day)) continue

    if (gap === 1) return 'tomorrow'
    if (gap >= 4) return 'longBreak'
    return weekIndex(day) === weekIndex(base) ? 'restThisWeek' : 'nextWeek'
  }
  return 'longBreak'
}
```

**`base + gap * MS_PER_DAY`가 DST 지역에서 자정에서 밀릴 수 있다.** `isDayOff`는 그 시각이 속한 날짜만 보므로 한 시간 밀려도 같은 날이고, 한국에는 DST가 없다. 정오를 더해 안전 여유를 두려면 `base + gap * MS_PER_DAY + 12 * MS_PER_HOUR`를 쓴다 — 이 구현은 그렇게 한다.

위 코드의 `day` 계산에 정오를 더하고, `weekIndex`에는 `startOfLocalDay(day)`를 넘긴다.

- [ ] **Step 4: 통과를 확인한다**

```bash
npx vitest run lib/__tests__/afterWork.test.ts && npm test
```

- [ ] **Step 5: 골든을 추가한다**

`scripts/generate-golden.ts`에 넣는다:

```ts
const AFTER_WORK_DAYS: { label: string; settings: string; at: Clock }[] = [
  { label: '화요일 퇴근', settings: 'default', at: [2026, 8, 22, 19, 0, 0] },
  { label: '수요일 퇴근 — 추석 연휴 직전', settings: 'default', at: [2026, 8, 23, 19, 0, 0] },
  { label: '금요일 퇴근', settings: 'default', at: [2026, 8, 25, 19, 0, 0] },
  { label: '목요일 퇴근', settings: 'default', at: [2026, 9, 1, 19, 0, 0] },
  { label: '연휴 직전 — 설 연휴', settings: 'default', at: [2026, 1, 13, 19, 0, 0] },
  { label: '공휴일을 출근으로 뒤집음', settings: 'workOnHoliday', at: [2026, 8, 23, 19, 0, 0] },
  { label: '야간근무 퇴근 후 아침', settings: 'night', at: [2026, 8, 23, 7, 0, 0] },
]

const afterWork = AFTER_WORK_DAYS.map((m) => ({
  ...m,
  expected: afterWorkKind(SETTINGS[m.settings], ms(m.at)),
}))

write('afterWork.json', afterWork)
```

import에 `afterWorkKind`를 추가한다.

`lib/__tests__/golden.test.ts`에도 블록을 더한다 — 비어있지 않음 가드 + 각 케이스에서 `afterWorkKind`를 다시 불러 비교.

- [ ] **Step 6: 웹 StatusLine을 고친다**

`components/StatusLine.tsx`의 `after` 분기를 kind별 문구로 바꾸고, **점심 문구도 `점심시간 ${formatDuration(...)}`으로 단축한다** (`· 재개까지`를 뺀다 — 사용자가 정한 변경인데 맥에는 이미 반영됐고 웹만 남아 있었다).

문구는 이 Task 머리의 표를 그대로 쓴다.

- [ ] **Step 7: 웹 검증 후 커밋**

```bash
npm test && npx tsc --noEmit && npm run lint && npm run build
npm run golden && git diff --exit-code shared/golden/
TZ=UTC npx vitest run
```

```bash
git add lib scripts shared/golden components/StatusLine.tsx
git commit -m "$(cat <<'EOF'
feat: 퇴근 후 문구를 날짜에 따라 고른다

"오늘 근무 종료"가 딱딱하다는 요청에서 나왔다. 다음 근무일이 언제인지로
네 종류를 가른다. 판정은 lib/에 두고 골든으로 고정하되 문구는 UI가 갖는다.

점심 문구의 "· 재개까지"도 함께 뺀다 — 맥에는 이미 반영됐고 웹만 남아
있었다.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 8: Swift로 옮긴다**

`AfterWork.swift`에 `AfterWorkKind` enum(rawValue는 웹 문자열과 동일)과 `afterWorkKind(_:_:)`를 옮기고, `AfterWorkTests.swift`에서 골든을 읽어 대조한다. 앞선 골든 테스트들과 같은 구조다.

- [ ] **Step 9: 팝오버에 반영한다**

`PopoverView.swift`의 상태줄 `.after` 분기를 kind별 문구로 바꾼다. 표의 네 문구를 그대로 쓴다.

- [ ] **Step 10: 검증 후 커밋**

```bash
swift test --package-path macos/SalaryClockCore --scratch-path "$HOME/Library/Caches/salaryclock/core"
swift test --package-path macos/SalaryClockApp --scratch-path "$HOME/Library/Caches/salaryclock/app"
TZ=UTC swift test --package-path macos/SalaryClockCore --scratch-path "$HOME/Library/Caches/salaryclock/core"
```

네 문구가 모두 188pt 안에 들어가는지 확인한다 — 가장 긴 `오늘도 고생하셨어요, 푹 쉬세요`가 14자다. `after`에는 `· 남은` 접미가 붙지 않으므로 여유가 있다.

---

### Task 14: 팝오버 토글과 갱신 주기

> 실행 순서상 Task 13 다음이다.

**Files:**
- Create: `macos/SalaryClockApp/Sources/SalaryClockAppLib/AppPreferences.swift`, `macos/SalaryClockApp/Tests/SalaryClockAppTests/AppPreferencesTests.swift`
- Modify: `macos/SalaryClockApp/Sources/SalaryClockAppLib/PopoverView.swift`, `SettingsView.swift`, `AppDelegate.swift`, `SettingsStore.swift`

**Interfaces:**
- Produces: `AppPreferences.shared` — `var menuBarInterval: Double`(초), `static func isValid(_ interval: Double) -> Bool`, 변경 시 `.appPreferencesChanged` 알림
- Produces: `SettingsStore.hasStored: Bool`

세 가지를 넣는다. 모두 사용자 요청이다.

**1. 가리기 토글** — 웹의 눈 아이콘. 팝오버 우상단 아이콘 행에 더한다(`eye` / `eye.slash`). `settings.hideAmount`를 뒤집는다. 메인 액터에서만 쓴다.

**2. 라이트/다크 토글** — 웹은 세 상태다: 저장된 값이 없으면 기기 설정, 한 번 고르면 그 값으로 고정. 그래서 `SettingsStore`에 `hasStored`를 노출하고, 팝오버·설정 창이 `hasStored == false`면 `@Environment(\.colorScheme)`를, 아니면 `settings.theme`을 쓴다. 아이콘은 `sun.max` / `moon`.

**3. 메뉴바 갱신 주기** — 설정 창에 숫자 입력칸. 웹에 대응물이 없는 **맥 전용 설정**이므로 `Settings`에 넣지 않는다. `Settings`는 `shared/golden/settings.json`이 고정하는 공유 도메인 모델이고, 필드를 더하면 골든이 깨지고 웹 스키마까지 건드려야 한다.

```
메뉴바 갱신
┌────────────────────┐
│              1.0 초 │
└────────────────────┘
0.1~10초. 짧게 둘수록 부드럽게 흐르지만 배터리를 조금 더 씁니다
```

- 범위 **0.1 ~ 10초**, 기본값 **1.0**
- 범위 밖이거나 숫자로 못 읽으면 다른 칸과 똑같이 빨갛게 되고 저장이 잠긴다
- `초` 접미는 급여의 `원`, 근무일수의 `일`과 같은 방식
- 위치는 `로그인할 때 자동 실행` 옆 — 맥 전용 옵션 묶음
- **팝오버가 열렸을 때 0.1초로 올라가는 기존 동작은 이 설정과 무관하게 유지**한다. 닫으면 이 설정값으로 돌아간다

`AppDelegate.startTimer(interval:)`이 이미 있으므로, 닫을 때 `1`이 아니라 `AppPreferences.shared.menuBarInterval`을 쓰도록 바꾸고 `.appPreferencesChanged`를 구독해 즉시 반영한다.

- [ ] **Step 1: `AppPreferences`와 그 테스트를 먼저 쓴다**

검증 규칙: `0.1 <= interval <= 10`, `isFinite`. 저장은 `UserDefaults`의 별도 키. 잘못된 값이 저장돼 있으면 기본값 1.0으로 되돌린다 — `SettingsStore`와 같은 방침이다.

테스트: 기본값이 1.0이다 / 0.1과 10은 유효하다 / 0.09와 10.1은 무효다 / NaN·무한대는 무효다 / 저장된 값이 무효면 기본값으로 읽힌다 / 유효한 값은 왕복한다.

- [ ] **Step 2: 실패를 확인하고 구현한다**

```bash
swift test --package-path macos/SalaryClockApp --scratch-path "$HOME/Library/Caches/salaryclock/app"
```

- [ ] **Step 3: 설정 창에 갱신 주기 칸을 붙인다**

저장 버튼은 `SettingsStore.isValid(draft)`와 `AppPreferences.isValid(draftInterval)`을 **둘 다** 만족할 때만 활성화된다.

- [ ] **Step 4: `AppDelegate`가 설정을 따르게 한다**

팝오버를 닫을 때와 `.appPreferencesChanged`를 받을 때 `startTimer(interval: AppPreferences.shared.menuBarInterval)`을 쓴다. `@MainActor`와 `MainActor.assumeIsolated` 구조는 그대로 둔다. 빌드 경고 0을 유지한다.

- [ ] **Step 5: 가리기·테마 토글을 아이콘 행에 붙인다**

웹의 순서를 따른다 — 테마, 가리기, 설정. 종료는 웹에 없으므로 맨 끝. 네 아이콘이 220pt 안에 들어간다는 것은 Task 10 리뷰에서 확인됐다.

- [ ] **Step 6: 검증**

```bash
swift test --package-path macos/SalaryClockApp --scratch-path "$HOME/Library/Caches/salaryclock/app"
./scripts/bundle-app.sh && open macos/build/SalaryClock.app
```

확인할 것: 네 아이콘이 보이고 눌린다 / 가리기를 켜면 금액 자리에 시각이 들어가고 상태줄이 빈다 / 테마 토글이 팝오버와 설정 창에 모두 먹는다 / 갱신 주기를 0.1로 저장하면 메뉴바 숫자가 눈에 띄게 부드러워진다 / 0.05를 넣으면 빨갛게 되고 저장이 잠긴다.

**캡처 규칙: 화면·영역 캡처 금지.** `screencapture -l <windowID>` 또는 접근성 텍스트만. 못 하면 "확인 못 함"으로 보고한다.

- [ ] **Step 7: 커밋**

```bash
git add macos/SalaryClockApp
git commit -m "$(cat <<'EOF'
feat: 가리기·테마 토글과 메뉴바 갱신 주기를 넣는다

갱신 주기는 맥 전용이라 공유 Settings가 아니라 별도 저장소에 둔다 —
Settings는 골든이 고정하는 도메인 모델이다. 0.1~10초, 기본 1초,
범위를 벗어나면 다른 칸과 같이 저장이 잠긴다.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
EOF
)"
```
