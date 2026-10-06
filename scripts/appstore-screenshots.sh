#!/usr/bin/env bash
# App Store용 iPhone 스크린샷을 시뮬레이터에서 찍는다.
#
# 사용법: appstore-screenshots.sh [출력 디렉터리]   (기본: appstore/screenshots/iphone)
#
# 6.9인치(iPhone 17 Pro Max, 1320×2868) 한 벌만 찍는다. App Store Connect는
# 가장 큰 화면의 스크린샷을 작은 기기에도 줄여 쓴다.
#
# 금액은 지금 시각으로 계산되므로 근무 시간(평일 9~18시, 점심 제외)에 돌려야
# 금액이 올라가는 화면이 찍힌다. 그 밖의 시간에 돌리면 "퇴근" 화면이 나온다.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${1:-$ROOT/appstore/screenshots/iphone}"
DEVICE_NAME="SalaryClock Screenshots"
DEVICE_TYPE="com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro-Max"
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

# 한 장 찍기: $1 파일 이름  $2 시계 스타일  $3 light|dark
shot() {
  local name="$1" style="$2" theme="$3"
  xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true
  xcrun simctl ui "$UDID" appearance "$theme"
  # 설정은 SettingsStore가 읽는 UserDefaults 키(settings.v2)에 JSON으로 넣는다.
  # 연봉 4,800만 원, 9~18시, 점심 12시 1시간.
  local json
  json="$(printf '{"payMode":"annual","payAmount":48000000,"workDaysMode":"auto","workDaysPerMonth":21,"dayOverrides":[],"workStart":"09:00","workEnd":"18:00","lunchEnabled":true,"lunchStart":"12:00","lunchMinutes":60,"netPay":false,"clockStyle":"%s","hideAmount":false,"hour12":false,"theme":"%s"}' "$style" "$theme")"
  xcrun simctl spawn "$UDID" defaults write "$BUNDLE_ID" settings.v2 -data "$(printf '%s' "$json" | xxd -p | tr -d '\n')"
  xcrun simctl launch "$UDID" "$BUNDLE_ID" >/dev/null
  sleep 3
  xcrun simctl io "$UDID" screenshot --type=png "$OUT/$name.png" >/dev/null
  echo "   $OUT/$name.png"
}

# 설치 직후 첫 실행은 그리기까지 오래 걸려 빈 화면이 찍힌다. 한 번 데운다.
xcrun simctl launch "$UDID" "$BUNDLE_ID" >/dev/null
sleep 5

shot 01-minimal minimal light
shot 02-rings rings dark
shot 03-sundial sundial light
shot 04-dots dots dark

xcrun simctl status_bar "$UDID" clear
xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true
