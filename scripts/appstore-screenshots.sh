#!/usr/bin/env bash
# App Store용 iPhone 스크린샷을 시뮬레이터에서 찍는다.
#
# 사용법: appstore-screenshots.sh [출력 디렉터리]   (기본: appstore/screenshots/iphone)
#
# 6.3인치(iPhone 17 Pro, 1206×2622) 한 벌만 찍는다. 2026년 App Store Connect는
# Dynamic Island 중형 디스플레이(1206×2622, 1179×2556)를 기준 크기로 받고, 다른
# 기기에는 이것을 줄이거나 늘려 쓴다. 6.9인치(1320×2868)로 올리면 크기가 맞지
# 않는다며 거부한다.
#
# 금액은 지금 시각으로 계산되므로 근무 시간(평일 9~18시, 점심 제외)에 돌려야
# 금액이 올라가는 화면이 찍힌다. 그 밖의 시간에 돌리면 "퇴근" 화면이 나온다.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${1:-$ROOT/appstore/screenshots/iphone}"
DEVICE_NAME="SalaryClock Screenshots 6.3"
DEVICE_TYPE="com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro"
BUNDLE_ID="dev.woosublee.salaryclock"
DERIVED="$HOME/Library/Caches/salaryclock/screenshots-dd"

RUNTIME="$(xcrun simctl list runtimes -j | python3 -c '
import json, sys
rs = [r for r in json.load(sys.stdin)["runtimes"] if r["platform"] == "iOS" and r["isAvailable"]]
print(rs[-1]["identifier"])')"

# 전용 시뮬레이터를 쓴다. 평소 쓰는 시뮬레이터의 상태(설정·외형)를 건드리지 않는다.
UDID="$(xcrun simctl list devices -j | python3 -c '
import json, sys
name = sys.argv[1]
for ds in json.load(sys.stdin)["devices"].values():
    for d in ds:
        if d["name"] == name and d["isAvailable"]:
            print(d["udid"]); sys.exit()' "$DEVICE_NAME")"
[[ -n "$UDID" ]] || UDID="$(xcrun simctl create "$DEVICE_NAME" "$DEVICE_TYPE" "$RUNTIME")"
xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b >/dev/null

xcodebuild -project "$ROOT/ios/SalaryClock.xcodeproj" -scheme SalaryClock \
  -destination "id=$UDID" -derivedDataPath "$DERIVED" \
  CODE_SIGNING_ALLOWED=NO build -quiet
xcrun simctl install "$UDID" "$DERIVED/Build/Products/Debug-iphonesimulator/SalaryClock.app"

# 상태 막대를 깔끔하게. 시각은 덮어쓰지 않는다 — 시계가 지금 시각을 그리므로
# 상태 막대만 9:41이면 둘이 어긋나 보인다.
xcrun simctl status_bar "$UDID" override \
  --dataNetwork wifi --wifiMode active --wifiBars 3 \
  --cellularMode active --cellularBars 4 \
  --batteryState charged --batteryLevel 100

mkdir -p "$OUT"

# 한 장 찍기: $1 파일 이름  $2 시계 스타일  $3 light|dark  [$4 처음 열 화면]  [$5 달력 모드]
#
# 처음 열 화면(settings|calendar)은 개발 빌드만 읽는 실행 인자다(ScreenshotScene.swift).
# 달력 모드를 주면 이번 달에 연차 하루와 주말 출근 하루를 찍어 둔다 — 달력 화면에서
# 날짜를 눌러 바꾸는 기능이 보이게.
shot() {
  local name="$1" style="$2" theme="$3" scene="${4:-}" calendar="${5:-}"
  xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true
  xcrun simctl ui "$UDID" appearance "$theme"
  local mode=auto overrides='[]'
  if [[ -n "$calendar" ]]; then
    mode=calendar
    overrides="$(python3 -c '
import datetime as d
t = d.date.today()
days = [t.replace(day=i) for i in range(1, 29)]
fri = next(x for x in days if x.day >= 10 and x.weekday() == 4)  # 연차
sat = next(x for x in days if x.day >= 18 and x.weekday() == 5)  # 주말 출근
print("[\"%s\",\"%s\"]" % (fri.isoformat(), sat.isoformat()))')"
  fi
  # 설정은 SettingsStore가 읽는 UserDefaults 키(settings.v2)에 JSON으로 넣는다.
  # 연봉 4,800만 원, 9~18시, 점심 12시 1시간.
  local json
  json="$(printf '{"payMode":"annual","payAmount":48000000,"workDaysMode":"%s","workDaysPerMonth":21,"dayOverrides":%s,"workStart":"09:00","workEnd":"18:00","lunchEnabled":true,"lunchStart":"12:00","lunchMinutes":60,"netPay":false,"clockStyle":"%s","hideAmount":false,"hour12":false,"theme":"%s"}' "$mode" "$overrides" "$style" "$theme")"
  xcrun simctl spawn "$UDID" defaults write "$BUNDLE_ID" settings.v2 -data "$(printf '%s' "$json" | xxd -p | tr -d '\n')"
  if [[ -n "$scene" ]]; then
    xcrun simctl launch "$UDID" "$BUNDLE_ID" -screenshot "$scene" >/dev/null
  else
    xcrun simctl launch "$UDID" "$BUNDLE_ID" >/dev/null
  fi
  sleep 3
  xcrun simctl io "$UDID" screenshot --type=png "$OUT/$name.png" >/dev/null
  echo "   $OUT/$name.png"
}

# 설치 직후 첫 실행은 그리기까지 오래 걸려 빈 화면이 찍힌다. 한 번 데운다.
xcrun simctl launch "$UDID" "$BUNDLE_ID" >/dev/null
sleep 5

# 이전에 찍은 파일이 남지 않게 비운다(장 수나 이름이 바뀌었을 때).
rm -f "$OUT"/*.png

# App Store는 앞의 두세 장만 검색 결과에 보인다. 메인 화면 → 달력 → 설정 순으로
# 기능이 다 보이게 하고, 시계 모양이 여럿이라는 건 뒤에서 보여준다.
shot 01-main minimal light
shot 02-calendar minimal light calendar calendar
shot 03-settings rings light settings
shot 04-dark rings dark
shot 05-dots dots dark

xcrun simctl status_bar "$UDID" clear
xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true
