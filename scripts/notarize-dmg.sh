#!/usr/bin/env bash
# 서명된 DMG를 Apple에 공증받고 티켓을 붙인다(staple).
#
# 공증을 받아야 Gatekeeper가 처음 실행을 막지 않는다. DMG를 공증하면 안에 든
# 앱까지 함께 검사되고, 티켓을 DMG에 붙여 두면 오프라인에서도 통과한다.
#
# appcast보다 먼저 돌아야 한다. staple은 DMG 파일을 고치므로, 그 뒤에
# generate-appcast.sh가 EdDSA 서명을 떠야 Sparkle이 받는 파일과 서명이 맞는다.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/release-common.sh"

[[ -f "$RELEASE_DMG" ]] || { echo "DMG가 없다: $RELEASE_DMG" >&2; exit 1; }

AUTH=()
while IFS= read -r line; do AUTH+=("$line"); done < <(release_notary_auth)

# --wait: 보통 몇 분 안에 끝난다. 실패하면 로그에 이유가 있으므로 꺼내 보인다.
OUT="$(xcrun notarytool submit "$RELEASE_DMG" "${AUTH[@]}" --wait --output-format json)"
STATUS="$(printf '%s' "$OUT" | plutil -extract status raw -o - - 2>/dev/null || true)"
if [[ "$STATUS" != "Accepted" ]]; then
  echo "공증 실패: ${STATUS:-알 수 없음}" >&2
  ID="$(printf '%s' "$OUT" | plutil -extract id raw -o - - 2>/dev/null || true)"
  [[ -n "$ID" ]] && xcrun notarytool log "$ID" "${AUTH[@]}" >&2 || printf '%s\n' "$OUT" >&2
  exit 1
fi

xcrun stapler staple "$RELEASE_DMG" >/dev/null
xcrun stapler validate "$RELEASE_DMG" >/dev/null
# 사용자 맥에서 Gatekeeper가 내릴 판단을 여기서 미리 본다.
spctl --assess --type open --context context:primary-signature --verbose=2 "$RELEASE_DMG"
echo "notarized $RELEASE_DMG"
