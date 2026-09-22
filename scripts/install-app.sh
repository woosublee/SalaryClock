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
