#!/usr/bin/env bash
# 릴리스 스크립트들이 공유하는 값. 단독 실행이 아니라 source로 읽는다.
#
# 버전·태그·파일 이름·URL을 한곳에서만 만든다. 스크립트마다 각자 조립하면
# 어느 하나가 어긋났을 때 "업로드는 됐는데 업데이트가 안 올라온다"는 형태로만
# 드러나고, 그때는 어디가 어긋났는지 보이지 않는다.
set -euo pipefail

RELEASE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RELEASE_REPO="woosublee/SalaryClock"
RELEASE_BUNDLE_ID="dev.woosublee.salaryclock"
RELEASE_SPARKLE_ACCOUNT="$RELEASE_BUNDLE_ID.sparkle.ed25519"
# Developer ID로 서명한다. Gatekeeper가 처음 실행을 막지 않으려면 이 신원으로
# 서명하고 공증까지 받아야 한다. 인증서는 Xcode > Settings > Accounts >
# Manage Certificates에서 "Developer ID Application"으로 만든다.
RELEASE_TEAM_ID="2L6ZW98RCP"
RELEASE_IDENTITY="${CODESIGN_IDENTITY:-Developer ID Application: Woosub Lee ($RELEASE_TEAM_ID)}"
RELEASE_MIN_SYSTEM="14.0"

RELEASE_VERSION="$(plutil -extract marketingVersion raw -o - "$RELEASE_ROOT/release/version.json")"
RELEASE_BUILD="$(plutil -extract buildNumber raw -o - "$RELEASE_ROOT/release/version.json")"
RELEASE_TAG="v$RELEASE_VERSION"
RELEASE_DMG_NAME="SalaryClock-$RELEASE_VERSION.dmg"

# 번들도 산출물도 iCloud 동기화 밖에 둔다 — 이유는 bundle-app.sh의 주석.
RELEASE_BUILD_DIR="${BUILD_DIR:-$HOME/Library/Caches/salaryclock/build}"
RELEASE_APP="$RELEASE_BUILD_DIR/SalaryClock.app"
RELEASE_DMG="$RELEASE_BUILD_DIR/$RELEASE_DMG_NAME"
RELEASE_APPCAST="$RELEASE_BUILD_DIR/appcast.xml"

RELEASE_FEED_URL="https://github.com/$RELEASE_REPO/releases/latest/download/appcast.xml"
# 번들에 심는 공개키. bundle-app.sh의 기본값과 같아야 한다 — generate-appcast.sh가
# 둘이 어긋나지 않았는지 확인한다.
RELEASE_PUBLIC_ED_KEY="${SPARKLE_PUBLIC_ED_KEY:-bJHKi2fte2ii7wO/cga6sMGm13GmxwaYr95lMGaMUwQ=}"
RELEASE_DOWNLOAD_URL="https://github.com/$RELEASE_REPO/releases/download/$RELEASE_TAG/$RELEASE_DMG_NAME"
RELEASE_NOTES_URL="https://github.com/$RELEASE_REPO/releases/tag/$RELEASE_TAG"

# 버전 형태를 여기서 한 번 검사한다. 어긋난 채로 태그까지 만들면 되돌리기
# 번거롭다.
[[ "$RELEASE_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
  echo "marketingVersion이 x.y.z 형태가 아니다: $RELEASE_VERSION" >&2
  exit 1
}
[[ "$RELEASE_BUILD" =~ ^[0-9]+$ ]] || {
  echo "buildNumber가 정수가 아니다: $RELEASE_BUILD" >&2
  exit 1
}

# Sparkle 도구는 빌드 산출물 안에 있다. 경로를 박아 두면 Sparkle 버전을
# 올릴 때 조용히 깨지므로 찾아서 쓴다.
release_sparkle_tool() {
  local name="$1"
  local found
  found="$(find "$HOME/Library/Caches/salaryclock/app/artifacts" -type f -name "$name" -perm -u+x -print -quit 2>/dev/null || true)"
  [[ -n "$found" ]] || {
    echo "Sparkle 도구를 못 찾았다: $name (먼저 swift build를 돌릴 것)" >&2
    return 1
  }
  printf '%s' "$found"
}

# 공증(notarytool)에 넘길 인증 인자. 둘 중 하나:
#   - App Store Connect API 키: ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_PATH(.p8) — CI와
#     scripts/appstore-release.sh가 쓰는 것과 같은 키
#   - 키체인 프로필: NOTARY_PROFILE(기본 woosublee-notary). 팀 키라 이 앱 말고도
#     같은 개발자 계정의 다른 앱에서 함께 쓴다. 한 번 만들어 둔다:
#       xcrun notarytool store-credentials woosublee-notary \
#         --key <.p8> --key-id <ID> --issuer <Issuer ID>
release_notary_auth() {
  if [[ -n "${ASC_KEY_ID:-}" ]]; then
    [[ -n "${ASC_ISSUER_ID:-}" && -f "${ASC_KEY_PATH:-}" ]] || {
      echo "ASC_KEY_ID를 줬으면 ASC_ISSUER_ID와 ASC_KEY_PATH(.p8)도 있어야 한다" >&2
      return 1
    }
    printf '%s\n' --key "$ASC_KEY_PATH" --key-id "$ASC_KEY_ID" --issuer "$ASC_ISSUER_ID"
  else
    printf '%s\n' --keychain-profile "${NOTARY_PROFILE:-woosublee-notary}"
  fi
}
