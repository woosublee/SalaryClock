#!/usr/bin/env bash
# 서명된 .app을 DMG로 묶는다.
#
# 응용 프로그램 폴더 심볼릭 링크를 같이 넣어, 처음 받는 사람이 끌어다 놓는
# 화면을 그대로 본다.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/release-common.sh"

[[ -d "$RELEASE_APP" ]] || { echo "번들이 없다: $RELEASE_APP" >&2; exit 1; }

STAGING="$(mktemp -d "${TMPDIR:-/tmp}/salaryclock-dmg.XXXXXX")"
trap 'rm -rf "$STAGING"' EXIT

# ditto --norsrc --noextattr: 확장 속성을 가져가지 않는다. 그대로 복사하면
# iCloud가 붙인 속성이 따라와 DMG 안의 서명 검증이 깨질 수 있다.
ditto --norsrc --noextattr "$RELEASE_APP" "$STAGING/SalaryClock.app"
# --deep: 안에 든 Sparkle.framework까지 검사한다. 껍데기만 맞고 안쪽 서명이
# 깨진 채로 배포되는 것을 여기서 막는다.
codesign --verify --deep --strict --verbose=2 "$STAGING/SalaryClock.app"
ln -s /Applications "$STAGING/Applications"

rm -f "$RELEASE_DMG"
hdiutil create -volname SalaryClock -srcfolder "$STAGING" -ov -format UDZO "$RELEASE_DMG" >/dev/null
codesign --force --sign "$RELEASE_IDENTITY" "$RELEASE_DMG"
codesign --verify --strict "$RELEASE_DMG"

echo "packaged $RELEASE_DMG"
