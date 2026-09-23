#!/usr/bin/env bash
# swift build 결과를 .app 번들로 조립한다.
#
# Xcode 프로젝트를 두지 않는 이유: .pbxproj는 손으로 쓰기 어렵고 diff가
# 읽히지 않아 리뷰가 불가능하다. Package.swift와 이 스크립트는 둘 다 읽힌다.
#
# 사용법: bundle-app.sh [debug|release]
#
# debug(기본값)는 개발용이다. Sparkle 프레임워크는 똑같이 들어가지만
# SUFeedURL·SUPublicEDKey를 넣지 않는다 — 개발 빌드가 릴리스 피드를 보고
# "새 버전이 있다"며 스스로를 덮어쓰면 작업 중인 빌드가 사라진다.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG="${1:-debug}"
BUNDLE_ID="dev.woosublee.salaryclock"
# 이 저장소는 ~/Documents 아래에 있어 iCloud Drive가 동기화한다. iCloud가
# 붙이는 확장 속성 때문에 기본 .build 경로에서는 codesign이 실패하므로,
# swift 명령은 항상 동기화 대상 밖의 캐시 경로를 scratch-path로 써야 한다.
SCRATCH="$HOME/Library/Caches/salaryclock/app"

# 조립한 번들도 저장소 안에 두지 않는다.
#
# 전에는 macos/build/에 조립하고 서명 직전에 xattr -cr로 확장 속성을 지웠는데,
# Sparkle.framework가 들어오면서 그 방법이 무너졌다. codesign이 거부하는 건
# com.apple.FinderInfo인데, iCloud fileprovider 데몬은 번들 디렉터리(.app,
# .framework, .xpc, .nib)마다 그 속성을 붙여 "이건 패키지다"를 표시한다.
# 지우면 곧바로 다시 붙으므로 — 실측으로 세 번 연속 졌다 — 재시도로는 이길 수
# 없는 경합이다. 조립을 동기화 밖으로 옮기는 것이 유일한 해법이다.
BUILD_DIR="${BUILD_DIR:-$HOME/Library/Caches/salaryclock/build}"
APP="$BUILD_DIR/SalaryClock.app"

# 서명 신원. ad-hoc이 아니라 고정된 자체 서명 인증서를 쓴다 — Sparkle이
# 새 버전과 지금 버전의 서명이 같은 곳에서 왔는지 확인하려면 신원이
# 빌드마다 바뀌면 안 된다. 없으면 만들라고 알리고 멈춘다.
IDENTITY="${CODESIGN_IDENTITY:-SalaryClock}"
if ! security find-identity -v -p codesigning | grep -Fq "\"$IDENTITY\""; then
  echo "코드 서명 신원이 없다: $IDENTITY" >&2
  echo "scripts/create-signing-certificate.sh 를 먼저 실행할 것." >&2
  exit 1
fi

# 버전은 release/version.json 하나에서만 온다. 여기저기 적어 두면
# appcast와 번들이 어긋나고, 그 어긋남은 업데이트가 안 올라올 때까지
# 드러나지 않는다.
VERSION_JSON="$ROOT/release/version.json"
MARKETING_VERSION="$(plutil -extract marketingVersion raw -o - "$VERSION_JSON")"
BUILD_NUMBER="$(plutil -extract buildNumber raw -o - "$VERSION_JSON")"

# appcast는 최신 릴리스의 에셋으로 올린다. /releases/latest/download/는
# 언제나 가장 최근 릴리스를 가리키므로 별도 호스팅이 필요 없다.
FEED_URL="${SPARKLE_FEED_URL:-https://github.com/woosublee/SalaryClock/releases/latest/download/appcast.xml}"
PUBLIC_ED_KEY="${SPARKLE_PUBLIC_ED_KEY:-bJHKi2fte2ii7wO/cga6sMGm13GmxwaYr95lMGaMUwQ=}"

swift build --package-path "$ROOT/macos/SalaryClockApp" --scratch-path "$SCRATCH" -c "$CONFIG"
BIN_DIR="$(swift build --package-path "$ROOT/macos/SalaryClockApp" --scratch-path "$SCRATCH" -c "$CONFIG" --show-bin-path)"
BIN="$BIN_DIR/SalaryClockApp"
SPARKLE_FRAMEWORK="$(find "$BIN_DIR" -maxdepth 1 -type d -name Sparkle.framework -print -quit)"
if [[ -z "$SPARKLE_FRAMEWORK" ]]; then
  echo "빌드 결과에서 Sparkle.framework를 못 찾았다: $BIN_DIR" >&2
  exit 1
fi

rm -rf "$APP"
mkdir -p "$BUILD_DIR"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks"
cp "$BIN" "$APP/Contents/MacOS/SalaryClock"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>SalaryClock</string>
  <key>CFBundleDisplayName</key><string>SalaryClock</string>
  <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
  <key>CFBundleExecutable</key><string>SalaryClock</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$MARKETING_VERSION</string>
  <key>CFBundleVersion</key><string>$BUILD_NUMBER</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <!-- Dock 아이콘 없이 메뉴바에만 상주한다 -->
  <key>LSUIElement</key><true/>
</dict>
</plist>
PLIST

# ditto의 --norsrc --noextattr: 리소스 포크와 확장 속성을 옮기지 않는다.
# 그냥 cp -R로 옮기면 원본에 붙어 있던 iCloud 속성이 따라와 서명이 깨진다.
ditto --norsrc --noextattr "$SPARKLE_FRAMEWORK" "$APP/Contents/Frameworks/Sparkle.framework"

# SwiftPM이 만든 실행 파일은 빌드 디렉터리를 rpath로 갖고 있다. 번들 안에서
# 프레임워크를 찾으려면 @executable_path 기준 경로가 있어야 한다.
if ! otool -l "$APP/Contents/MacOS/SalaryClock" | grep -A2 LC_RPATH | grep -Fq '@executable_path/../Frameworks'; then
  install_name_tool -add_rpath '@executable_path/../Frameworks' "$APP/Contents/MacOS/SalaryClock"
fi

if [[ "$CONFIG" == "release" ]]; then
  [[ "$FEED_URL" == https://* ]] || { echo "SUFeedURL은 HTTPS여야 한다: $FEED_URL" >&2; exit 1; }
  # 공개키는 32바이트를 담은 44자 Base64다. 오타를 여기서 잡지 않으면
  # 업데이트가 조용히 거부되고, 그때는 원인이 드러나지 않는다.
  python3 -c 'import base64,sys; v=sys.argv[1]; sys.exit(0 if len(v)==44 and len(base64.b64decode(v, validate=True))==32 else 1)' \
    "$PUBLIC_ED_KEY" || { echo "SUPublicEDKey가 32바이트 Base64가 아니다" >&2; exit 1; }
  plutil -insert SUFeedURL -string "$FEED_URL" "$APP/Contents/Info.plist"
  plutil -insert SUPublicEDKey -string "$PUBLIC_ED_KEY" "$APP/Contents/Info.plist"
fi

# 안에서 밖으로 서명한다. 바깥 번들을 먼저 서명하면 안쪽을 건드리는 순간
# 그 서명이 깨진다.
sign() {
  [[ -e "$1" ]] || return 0
  codesign --force --options runtime --sign "$IDENTITY" "$1" >/dev/null
}
FW="$APP/Contents/Frameworks/Sparkle.framework/Versions/B"
sign "$FW/XPCServices/Installer.xpc"
sign "$FW/XPCServices/Downloader.xpc"
sign "$FW/Autoupdate"
sign "$FW/Updater.app"
sign "$APP/Contents/Frameworks/Sparkle.framework"

codesign --force --options runtime --sign "$IDENTITY" "$APP"
codesign --verify --strict --verbose=2 "$APP"
echo "built $APP ($MARKETING_VERSION build $BUILD_NUMBER, $CONFIG)"
