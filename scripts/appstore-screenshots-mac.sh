#!/usr/bin/env bash
# Mac App Store 스크린샷(2880×1800)을 만든다.
#
# 사용법: appstore-screenshots-mac.sh [출력 디렉터리]   (기본: appstore/screenshots/mac)
#
# 화면을 캡처하지 않는다. Mac App Store 타깃의 개발 빌드를 `-screenshot popover|settings
# -screenshotOut <경로>`로 띄우면 앱이 그 화면을 PNG로 그려 내고 끝난다(AppDelegate).
# 그걸 compose-mac-screenshot.swift가 메뉴바와 바탕 위에 놓는다. 화면 녹화 권한이
# 필요 없고 바탕화면이나 다른 앱이 섞이지 않는다.
#
# 설정은 실행 인자(-settings.v2)로만 넘긴다 — 인자 도메인은 읽기 전용이라 이 맥에서
# 쓰는 SalaryClock 설정을 건드리지 않는다. App Store 타깃이라 설정 창의 업데이트
# 칸에도 App Store 문구가 나온다.
#
# 금액은 지금 시각으로 계산되므로 평일 근무 시간(9~18시, 점심 제외)에 돌린다.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${1:-$ROOT/appstore/screenshots/mac}"
DERIVED="$HOME/Library/Caches/salaryclock/mac-shots-dd"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/salaryclock-mac-shots.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

# 서명하지 않으면 샌드박스 없이 돈다 — 출력 경로에 바로 쓸 수 있다.
xcodebuild -project "$ROOT/ios/SalaryClock.xcodeproj" -scheme SalaryClockMac -configuration Debug \
  -destination 'platform=macOS,arch=arm64' -derivedDataPath "$DERIVED" \
  CODE_SIGNING_ALLOWED=NO build -quiet
APP="$DERIVED/Build/Products/Debug/SalaryClock.app/Contents/MacOS/SalaryClock"
swiftc -O "$ROOT/scripts/compose-mac-screenshot.swift" -o "$WORK/compose"

# $1 화면(popover|settings)  $2 light|dark  $3 시계 스타일
render() {
  local json
  json="$(printf '{"payMode":"annual","payAmount":48000000,"workDaysMode":"auto","workDaysPerMonth":21,"dayOverrides":[],"workStart":"09:00","workEnd":"18:00","lunchEnabled":true,"lunchStart":"12:00","lunchMinutes":60,"netPay":false,"clockStyle":"%s","hideAmount":false,"hour12":false,"theme":"%s"}' "$3" "$2")"
  "$APP" -screenshot "$1" -screenshotOut "$WORK/$1-$2.png" \
    -settings.v2 "<$(printf '%s' "$json" | xxd -p | tr -d '\n')>" >/dev/null 2>&1
  [[ -f "$WORK/$1-$2.png" ]] || { echo "그리지 못했다: $1 $2" >&2; exit 1; }
}
render popover light minimal
render popover dark rings
render settings light minimal

# 메뉴바 글자는 앱이 팝오버를 그린 순간의 것을 쓴다(AppDelegate가 .title로 남긴다).
MENU="$(cat "$WORK/popover-light.png.title")"

mkdir -p "$OUT"
rm -f "$OUT"/*.png
"$WORK/compose" light "$MENU" "$OUT/01-popover.png" "$WORK/popover-light.png:2.0"
"$WORK/compose" dark "$MENU" "$OUT/02-dark.png" "$WORK/popover-dark.png:2.0"
"$WORK/compose" light "$MENU" "$OUT/03-settings.png" "$WORK/settings-light.png:1.0" "$WORK/popover-light.png:1.45"
ls "$OUT"
