#!/usr/bin/env bash
# release 빌드를 만들어 /Applications에 설치한다.
#
# Developer ID로 서명하지만 공증은 받지 않는다(공증은 release.sh에서만). 직접
# 빌드해 옮긴 파일에는 격리 속성이 없어 Gatekeeper가 공증을 묻지 않는다.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="/Applications/SalaryClock.app"
# bundle-app.sh와 같은 기본값. 번들은 iCloud 동기화 밖에서 조립된다 —
# 이유는 bundle-app.sh의 주석.
BUILD_DIR="${BUILD_DIR:-$HOME/Library/Caches/salaryclock/build}"

BUILD_DIR="$BUILD_DIR" "$ROOT/scripts/bundle-app.sh" release

# 돌고 있으면 먼저 내린다. 실행 중인 번들을 덮어쓰면 다음 실행이 깨진다.
pkill -f "SalaryClock.app/Contents/MacOS/SalaryClock" || true
sleep 1

rm -rf "$DEST"
# ditto --norsrc --noextattr: 확장 속성을 가져가지 않는다. cp -R로 옮기면
# iCloud가 붙인 속성이 따라붙을 수 있다.
ditto --norsrc --noextattr "$BUILD_DIR/SalaryClock.app" "$DEST"
codesign --verify --strict "$DEST"

echo "설치 완료: $DEST"
echo "실행: open $DEST"
