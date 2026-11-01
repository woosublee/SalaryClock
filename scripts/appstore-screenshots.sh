#!/usr/bin/env bash
# App Store용 iPhone 스크린샷을 시뮬레이터에서 찍는다.
#
# 사용법: appstore-screenshots.sh [출력 디렉터리]          (기본: appstore/screenshots/iphone)
#         appstore-screenshots.sh --duo [출력 디렉터리]        (기본: appstore/screenshots/iphone-duo)
#         appstore-screenshots.sh --duo-outer [출력 디렉터리]  (기본: appstore/screenshots/iphone-duo-outer)
#
# --duo는 iPhone Duo를 펼친 안쪽 화면(2853×2007, 가로)을, --duo-outer는 접은 바깥 화면
# (1398×2034)을 찍는다. App Store Connect의 Duo 칸은 다른 크기를 줄이거나 늘려 채우지
# 않으므로 따로 찍어 올린다. 안쪽에는 펼친 화면 전용 배치(시계 왼쪽, 금액 오른쪽)가 보인다.
#
# 접고 펴기는 simctl로 못 한다. "SalaryClock Screenshots Duo"를 Device Hub에서 펼치거나
# 접어 둔 뒤 돌린다. 반대 상태면 찍을 화면이 꺼져 있어 검은 화면이 나온다.
#
# 6.3인치(iPhone 17 Pro, 1206×2622) 한 벌만 찍는다. 2026년 App Store Connect는
# Dynamic Island 중형 디스플레이(1206×2622, 1179×2556)를 기준 크기로 받고, 다른
# 기기에는 이것을 줄이거나 늘려 쓴다. 6.9인치(1320×2868)로 올리면 크기가 맞지
# 않는다며 거부한다.
#
# 금액이 올라가는 화면이 찍히도록 앱이 보는 시각을 평일 오후 2시 24분으로 옮겨 찍는다
# (개발 빌드만 읽는 -screenshotNow, ScreenshotScene.swift의 AppClock). 오늘이 평일이면
# 오늘, 주말이면 다음 월요일이다. 그래서 언제 돌려도 같은 조건으로 나온다.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DUO=0      # 1: iPhone Duo
DUO_SIDE=inner
case "${1:-}" in
  --duo) DUO=1; shift ;;
  --duo-outer) DUO=1; DUO_SIDE=outer; shift ;;
esac
if (( DUO )); then
  if [[ $DUO_SIDE == outer ]]; then
    OUT="${1:-$ROOT/appstore/screenshots/iphone-duo-outer}"
  else
    OUT="${1:-$ROOT/appstore/screenshots/iphone-duo}"
  fi
  DEVICE_NAME="SalaryClock Screenshots Duo"
  DEVICE_TYPE="com.apple.CoreSimulator.SimDeviceType.iPhone-Duo"
else
  OUT="${1:-$ROOT/appstore/screenshots/iphone}"
  DEVICE_NAME="SalaryClock Screenshots 6.3"
  DEVICE_TYPE="com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro"
fi
BUNDLE_ID="dev.woosublee.salaryclock"
DERIVED="$HOME/Library/Caches/salaryclock/screenshots-dd"

# 찍을 날: 오늘이 평일이면 오늘, 주말이면 다음 월요일. 시각은 근무 중(점심 뒤)으로 고정한다.
SHOT_DAY="$(python3 -c '
import datetime as d
t = d.date.today()
while t.weekday() >= 5: t += d.timedelta(days=1)
print(t.isoformat())')"
SHOT_TIME="14:24"
SHOT_NOW="${SHOT_DAY}T${SHOT_TIME}:05"

# 이 기기 종류를 받는 런타임 중 마지막 것. iPhone Duo는 전용 런타임(…-iPhone19-4)에서만 돈다.
RUNTIME="$(xcrun simctl list runtimes -j | python3 -c '
import json, sys
t = sys.argv[1]
rs = [r for r in json.load(sys.stdin)["runtimes"] if r["platform"] == "iOS" and r["isAvailable"]
      and any(d["identifier"] == t for d in r.get("supportedDeviceTypes", []))]
print(rs[-1]["identifier"])' "$DEVICE_TYPE")"

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

# 상태 막대를 깔끔하게. 시각은 앱이 보는 시각(SHOT_TIME)에 맞춘다 — 9:41로 두면
# 시계와 상태 막대가 어긋나 보인다.
xcrun simctl status_bar "$UDID" override --time "$SHOT_TIME" \
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
import datetime as d, sys
t = d.date.fromisoformat(sys.argv[1])
days = [t.replace(day=i) for i in range(1, 29)]
fri = next(x for x in days if x.day >= 10 and x.weekday() == 4)  # 연차
sat = next(x for x in days if x.day >= 18 and x.weekday() == 5)  # 주말 출근
print("[\"%s\",\"%s\"]" % (fri.isoformat(), sat.isoformat()))' "$SHOT_DAY")"
  fi
  # 설정은 SettingsStore가 읽는 UserDefaults 키(settings.v2)에 JSON으로 넣는다.
  # 연봉 4,800만 원, 9~18시, 점심 12시 1시간.
  local json
  json="$(printf '{"payMode":"annual","payAmount":48000000,"workDaysMode":"%s","workDaysPerMonth":21,"dayOverrides":%s,"workStart":"09:00","workEnd":"18:00","lunchEnabled":true,"lunchStart":"12:00","lunchMinutes":60,"netPay":false,"clockStyle":"%s","hideAmount":false,"hour12":false,"theme":"%s"}' "$mode" "$overrides" "$style" "$theme")"
  xcrun simctl spawn "$UDID" defaults write "$BUNDLE_ID" settings.v2 -data "$(printf '%s' "$json" | xxd -p | tr -d '\n')"
  if [[ -n "$scene" ]]; then
    xcrun simctl launch "$UDID" "$BUNDLE_ID" -screenshotNow "$SHOT_NOW" -screenshot "$scene" >/dev/null
  else
    xcrun simctl launch "$UDID" "$BUNDLE_ID" -screenshotNow "$SHOT_NOW" >/dev/null
  fi
  sleep 3
  xcrun simctl io "$UDID" screenshot --type=png ${DISPLAY_ARG:+"$DISPLAY_ARG"} "$OUT/$name.png" >/dev/null
  if is_blank "$OUT/$name.png"; then
    echo "$name: 화면이 꺼져 있다. Device Hub에서 Duo를 $([[ $DUO_SIDE == inner ]] && echo 펼친 || echo 접은) 뒤 다시 돌릴 것" >&2
    exit 1
  fi
  echo "   $OUT/$name.png"
}

# 꺼진 화면을 찍으면 오류 없이 새까만 PNG가 나온다(Duo를 반대로 접거나 편 경우).
# 작은 BMP(압축 없음)로 줄여 픽셀이 전부 순수한 검정이면 꺼진 화면으로 본다.
# 앱의 어두운 바탕(slate-950)도 파랑이 0이 아니라 걸리지 않는다.
is_blank() {
  local bmp
  bmp="$(mktemp -t salaryclock-shot).bmp"
  sips -Z 64 -s format bmp "$1" --out "$bmp" >/dev/null
  python3 - "$bmp" <<'PY'
import struct, sys
data = open(sys.argv[1], "rb").read()
start, = struct.unpack("<I", data[10:14])
w, h, = struct.unpack("<ii", data[18:26]); bpp, = struct.unpack("<H", data[28:30])
step = bpp // 8
px = data[start:]
# 알파 채널(4바이트 픽셀의 마지막)은 빼고 본다.
vals = [px[i + c] for i in range(0, len(px) - step + 1, step) for c in range(min(step, 3))]
sys.exit(0 if max(vals, default=0) <= 2 else 1)
PY
  local blank=$?
  rm -f "$bmp"
  return $blank
}

# 설치 직후 첫 실행은 그리기까지 오래 걸려 빈 화면이 찍힌다. 한 번 데운다.
xcrun simctl launch "$UDID" "$BUNDLE_ID" >/dev/null
sleep 5

# 화면이 둘인 기기(iPhone Duo)는 찍을 화면을 골라야 한다. 안쪽은 큰 것, 바깥은 작은 것.
# 목록은 화면을 고르지 않고 찍으려 할 때 나오는 오류에서 읽는다(그래서 실패를 삼킨다).
DISPLAY_ARG=""
if (( DUO )); then
  DISPLAY_ARG="$( (xcrun simctl io "$UDID" screenshot /dev/null 2>&1 || true) | python3 -c '
import re, sys
ds = re.findall(r"(--display=\d+)\s.*?(\d+)x(\d+)", sys.stdin.read())
pick = max if sys.argv[1] == "inner" else min
print(pick(ds, key=lambda d: int(d[1]) * int(d[2]))[0] if ds else "")' "$DUO_SIDE")"
  [[ -n "$DISPLAY_ARG" ]] || { echo "Duo 화면 목록을 읽지 못했다" >&2; exit 1; }
fi

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
# 찍기 전용 시뮬레이터라 다 찍으면 끈다. Duo는 켜 둔다 — 끄면 접힌 상태로 돌아가서
# 안쪽·바깥 화면을 이어 찍으려면 다시 펼쳐야 한다. 다 찍은 뒤 직접 끈다.
if (( ! DUO )); then xcrun simctl shutdown "$UDID" 2>/dev/null || true; fi
