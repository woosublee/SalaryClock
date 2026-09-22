#!/usr/bin/env bash
# swift build 결과를 .app 번들로 조립한다.
#
# Xcode 프로젝트를 두지 않는 이유: .pbxproj는 손으로 쓰기 어렵고 diff가
# 읽히지 않아 리뷰가 불가능하다. Package.swift와 이 스크립트는 둘 다 읽힌다.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG="${1:-debug}"
APP="$ROOT/macos/build/SalaryClock.app"
# 이 저장소는 ~/Documents 아래에 있어 iCloud Drive가 동기화한다. iCloud가
# 붙이는 확장 속성 때문에 기본 .build 경로에서는 codesign이 실패하므로,
# swift 명령은 항상 동기화 대상 밖의 캐시 경로를 scratch-path로 써야 한다.
SCRATCH="$HOME/Library/Caches/salaryclock/app"

swift build --package-path "$ROOT/macos/SalaryClockApp" --scratch-path "$SCRATCH" -c "$CONFIG"
BIN="$(swift build --package-path "$ROOT/macos/SalaryClockApp" --scratch-path "$SCRATCH" -c "$CONFIG" --show-bin-path)/SalaryClockApp"

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
