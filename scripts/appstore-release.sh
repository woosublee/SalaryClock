#!/usr/bin/env bash
# iOS·macOS 앱을 아카이브해 App Store Connect에 올린다.
#
# 사용법:
#   ./scripts/appstore-release.sh                 # 둘 다 아카이브하고 .ipa/.pkg까지만 만든다
#   ./scripts/appstore-release.sh --upload        # 둘 다 App Store Connect에 올린다
#   ./scripts/appstore-release.sh ios --upload    # 한쪽만 (ios 또는 mac)
#
# 두 플랫폼은 App Store Connect에서 앱 하나로 묶인다(번들 ID가 같다). 그래서
# 버전도 하나다 — 맥 DMG와 같이 release/version.json에서만 온다.
# project.pbxproj의 MARKETING_VERSION·CURRENT_PROJECT_VERSION은 Xcode에서
# 돌려 볼 때만 쓰이고, 여기서는 명령줄로 덮어쓴다. 버전을 적는 곳이 두 군데가
# 되면 한쪽만 올리는 실수가 반드시 난다.
#
# GitHub로 내는 DMG(scripts/release.sh)와는 빌드 경로가 다르다. 이쪽은
# Xcode 프로젝트의 SalaryClockMac 타깃으로, 샌드박스를 켜고 Sparkle을 뺀다
# (UpdaterController의 APP_STORE 쪽 주석).
#
# 서명은 Xcode의 자동 서명에 맡긴다(-allowProvisioningUpdates). 인증서와
# 프로비저닝 프로필을 Xcode가 만들고 갱신한다. 인증은 둘 중 하나다:
#   - 이 맥의 Xcode > Settings > Accounts에 개발자 계정이 로그인돼 있거나
#   - App Store Connect API 키를 환경 변수로 준다(CI용):
#       ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_PATH(.p8 파일 경로)
#
# 올린 빌드는 App Store Connect에서 처리(수 분~수십 분)를 거친 뒤 TestFlight와
# 심사 제출 화면에 나타난다. 심사 제출 자체는 웹에서 한다 — appstore/README.md.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/release-common.sh"

UPLOAD=0
PLATFORMS=()
for arg in "$@"; do
  case "$arg" in
    --upload) UPLOAD=1 ;;
    ios|mac) PLATFORMS+=("$arg") ;;
    *) echo "모르는 인자: $arg" >&2; exit 1 ;;
  esac
done
(( ${#PLATFORMS[@]} > 0 )) || PLATFORMS=(ios mac)

TEAM_ID="2L6ZW98RCP"
PROJECT="$RELEASE_ROOT/ios/SalaryClock.xcodeproj"
# 아카이브도 iCloud 동기화 밖에 둔다 — 이유는 bundle-app.sh의 주석.
STORE_BUILD_DIR="${STORE_BUILD_DIR:-$HOME/Library/Caches/salaryclock/appstore}"

echo "== SalaryClock App Store $RELEASE_VERSION (빌드 $RELEASE_BUILD): ${PLATFORMS[*]}"

# 작업 트리가 깨끗해야 한다. 올린 빌드가 어느 커밋에서 나왔는지 되짚을 수
# 있어야 심사에서 반려됐을 때 같은 소스로 고쳐 다시 낼 수 있다.
if (( UPLOAD == 1 )) && [[ -n "$(git -C "$RELEASE_ROOT" status --porcelain)" ]]; then
  echo "커밋하지 않은 변경이 있다 — 먼저 정리할 것" >&2
  git -C "$RELEASE_ROOT" status --short >&2
  exit 1
fi

AUTH_ARGS=()
if [[ -n "${ASC_KEY_ID:-}" ]]; then
  [[ -n "${ASC_ISSUER_ID:-}" && -f "${ASC_KEY_PATH:-}" ]] || {
    echo "ASC_KEY_ID를 줬으면 ASC_ISSUER_ID와 ASC_KEY_PATH(.p8)도 있어야 한다" >&2
    exit 1
  }
  AUTH_ARGS=(
    -authenticationKeyID "$ASC_KEY_ID"
    -authenticationKeyIssuerID "$ASC_ISSUER_ID"
    -authenticationKeyPath "$ASC_KEY_PATH"
  )
fi

# 플랫폼 하나를 아카이브하고 내보낸다(destination=upload면 내보내기가 곧 업로드).
#   $1 ios|mac  $2 스킴  $3 xcodebuild -destination  $4 아카이브 안 Info.plist 상대 경로
ship() {
  local platform="$1" scheme="$2" destination="$3" plist_rel="$4"
  local archive="$STORE_BUILD_DIR/$platform/SalaryClock.xcarchive"
  local export_dir="$STORE_BUILD_DIR/$platform/export"
  local options="$STORE_BUILD_DIR/$platform/ExportOptions.plist"

  echo "-- $platform"
  rm -rf "$archive" "$export_dir"
  mkdir -p "$STORE_BUILD_DIR/$platform"

  xcodebuild archive \
    -project "$PROJECT" \
    -scheme "$scheme" \
    -configuration Release \
    -destination "$destination" \
    -archivePath "$archive" \
    -allowProvisioningUpdates \
    ${AUTH_ARGS[@]+"${AUTH_ARGS[@]}"} \
    DEVELOPMENT_TEAM="$TEAM_ID" \
    MARKETING_VERSION="$RELEASE_VERSION" \
    CURRENT_PROJECT_VERSION="$RELEASE_BUILD" \
    -quiet

  # 아카이브에 박힌 버전이 version.json과 같은지 본다. 덮어쓰기가 어디서
  # 무시되면 엉뚱한 번호로 올라가고, 한 번 올라간 빌드 번호는 다시 쓸 수 없다.
  local plist="$archive/Products/Applications/$plist_rel"
  local version build
  version="$(plutil -extract CFBundleShortVersionString raw "$plist")"
  build="$(plutil -extract CFBundleVersion raw "$plist")"
  [[ "$version" == "$RELEASE_VERSION" && "$build" == "$RELEASE_BUILD" ]] || {
    echo "$platform 아카이브 버전($version/$build)이 version.json($RELEASE_VERSION/$RELEASE_BUILD)과 다르다" >&2
    exit 1
  }

  local export_destination=export
  (( UPLOAD == 1 )) && export_destination=upload
  cat > "$options" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>app-store-connect</string>
  <key>destination</key><string>$export_destination</string>
  <key>teamID</key><string>$TEAM_ID</string>
  <key>signingStyle</key><string>automatic</string>
  <key>uploadSymbols</key><true/>
  <!-- 빌드 번호는 version.json이 정한다. Xcode가 멋대로 올리면 DMG와 어긋난다. -->
  <key>manageAppVersionAndBuildNumber</key><false/>
</dict>
</plist>
PLIST

  xcodebuild -exportArchive \
    -archivePath "$archive" \
    -exportPath "$export_dir" \
    -exportOptionsPlist "$options" \
    -allowProvisioningUpdates \
    ${AUTH_ARGS[@]+"${AUTH_ARGS[@]}"} \
    -quiet

  if (( UPLOAD == 0 )); then
    echo "   $(find "$export_dir" \( -name '*.ipa' -o -name '*.pkg' \) -print -quit)"
  else
    echo "   올렸다"
  fi
}

for platform in "${PLATFORMS[@]}"; do
  case "$platform" in
    ios) ship ios SalaryClock 'generic/platform=iOS' SalaryClock.app/Info.plist ;;
    mac) ship mac SalaryClockMac 'generic/platform=macOS' SalaryClock.app/Contents/Info.plist ;;
  esac
done

if (( UPLOAD == 0 )); then
  echo
  echo "여기까지 만들었다. 올리려면 --upload 를 줄 것."
  exit 0
fi

echo
echo "App Store Connect에서 처리가 끝나면 TestFlight·심사 제출 화면에 보인다:"
echo "  https://appstoreconnect.apple.com/apps"
