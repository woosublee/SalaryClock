#!/usr/bin/env bash
# 릴리스 한 판. 빌드 → DMG → appcast → GitHub 릴리스 발행.
#
# 사용법:
#   ./scripts/release.sh                      # 검사하고 만들기만 한다(발행 안 함)
#   ./scripts/release.sh --publish            # 태그를 만들어 밀고 GitHub 릴리스까지
#   ./scripts/release.sh --publish --skip-tag # 태그가 이미 있는 경우(= CI)
#
# 버전은 release/version.json에서만 온다. 올리기 전에 그 파일의
# buildNumber를 올릴 것 — 올리지 않으면 아래 단조 증가 검사에서 멈춘다.
#
# GitHub Actions는 태그가 밀리는 것을 신호로 이 스크립트를 --skip-tag로
# 부른다(.github/workflows/release.yml). 태그를 만드는 쪽은 사람이고,
# 만들어진 태그를 산출물로 바꾸는 쪽은 스크립트 하나다 — 로컬에서 돌리든
# CI에서 돌리든 같은 경로를 지난다.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/release-common.sh"

PUBLISH=0
SKIP_TAG=0
for arg in "$@"; do
  case "$arg" in
    --publish) PUBLISH=1 ;;
    --skip-tag) SKIP_TAG=1 ;;
    *) echo "모르는 인자: $arg" >&2; exit 1 ;;
  esac
done

echo "== SalaryClock $RELEASE_VERSION (빌드 $RELEASE_BUILD), 태그 $RELEASE_TAG"

# 1. 태그.
#
#    직접 만드는 경우(로컬): 이미 있으면 멈춘다. 같은 태그로 다시 올리면 이미
#    그 버전을 받은 사람들에게는 영영 업데이트가 안 보인다.
#
#    이미 있는 경우(CI): 그 태그가 지금 체크아웃한 커밋을 가리키는지 본다.
#    다른 커밋을 가리키면 태그와 다른 소스로 산출물을 만들게 된다.
if (( SKIP_TAG == 1 )); then
  TAGGED="$(git rev-list -n 1 "$RELEASE_TAG" 2>/dev/null || true)"
  [[ -n "$TAGGED" ]] || { echo "태그가 없다: $RELEASE_TAG" >&2; exit 1; }
  [[ "$TAGGED" == "$(git rev-parse HEAD)" ]] || {
    echo "태그 $RELEASE_TAG 가 지금 커밋을 가리키지 않는다" >&2
    exit 1
  }
elif git rev-parse -q --verify "refs/tags/$RELEASE_TAG" >/dev/null; then
  echo "태그가 이미 있다: $RELEASE_TAG — version.json을 올릴 것" >&2
  exit 1
fi

# 2. 빌드 번호는 반드시 올라가야 한다. Sparkle은 sparkle:version(=빌드 번호)로
#    새 버전인지 판단하므로, 같거나 작으면 아무도 업데이트를 못 받는다.
#    이미 나간 appcast를 직접 읽어서 비교한다 — 로컬 기록이 아니라 사용자가
#    실제로 보는 값이 기준이다.
PUBLISHED="$(curl -fsSL "$RELEASE_FEED_URL" 2>/dev/null | sed -n 's/.*<sparkle:version>\([0-9]*\)<\/sparkle:version>.*/\1/p' | head -1 || true)"
if [[ -n "$PUBLISHED" ]]; then
  if (( RELEASE_BUILD <= PUBLISHED )); then
    echo "빌드 번호가 올라가지 않았다: 이미 나간 것 $PUBLISHED, 지금 $RELEASE_BUILD" >&2
    exit 1
  fi
  echo "   이미 나간 빌드 $PUBLISHED → $RELEASE_BUILD"
else
  echo "   아직 나간 릴리스가 없다 (첫 릴리스)"
fi

# 3. 릴리스 노트가 이번 버전을 가리키는지. 지난 버전 노트를 그대로 올리는
#    실수가 잦아서 기계로 막는다.
grep -Fq "SalaryClock $RELEASE_VERSION" "$RELEASE_ROOT/release/notes.md" || {
  echo "release/notes.md가 $RELEASE_VERSION 을 가리키지 않는다" >&2
  exit 1
}

# 4. 작업 트리가 깨끗해야 한다. 안 올라간 변경이 빌드에 섞이면 나중에
#    "이 태그의 소스"를 되살릴 수 없다.
[[ -z "$(git status --porcelain)" ]] || {
  echo "커밋하지 않은 변경이 있다 — 먼저 정리할 것" >&2
  git status --short >&2
  exit 1
}

"$RELEASE_ROOT/scripts/bundle-app.sh" release
"$RELEASE_ROOT/scripts/package-dmg.sh"
"$RELEASE_ROOT/scripts/generate-appcast.sh"

# 5. 번들에 박힌 버전과 appcast가 같은 이야기를 하는지 대조한다. 둘이
#    어긋나면 업데이트가 올라오지 않거나 무한히 올라온다.
BUNDLED_BUILD="$(plutil -extract CFBundleVersion raw "$RELEASE_APP/Contents/Info.plist")"
[[ "$BUNDLED_BUILD" == "$RELEASE_BUILD" ]] || {
  echo "번들 CFBundleVersion($BUNDLED_BUILD)과 release/version.json($RELEASE_BUILD)이 다르다" >&2
  exit 1
}
BUNDLED_FEED="$(plutil -extract SUFeedURL raw "$RELEASE_APP/Contents/Info.plist")"
[[ "$BUNDLED_FEED" == "$RELEASE_FEED_URL" ]] || {
  echo "번들 SUFeedURL이 다르다: $BUNDLED_FEED" >&2
  exit 1
}

# 6. 실제로 뜨는지 본다.
#
#    codesign --verify는 통과하는데 실행은 안 되는 경우가 있다. 실제로 겪었다:
#    하드닝 런타임의 라이브러리 검증이 번들 안의 Sparkle.framework를 거부해
#    dyld 단계에서 죽었는데(자체 서명이라 Team ID가 없다), 서명 자체는 끝까지
#    유효했다. 서명 검사만으로는 못 잡는 종류라 한 번 띄워 본다.
"$RELEASE_APP/Contents/MacOS/SalaryClock" >/dev/null 2>&1 &
SMOKE_PID=$!
sleep 3
if ! kill -0 "$SMOKE_PID" 2>/dev/null; then
  echo "앱이 실행 직후 죽는다 — 서명이나 프레임워크 임베드를 확인할 것" >&2
  exit 1
fi
kill "$SMOKE_PID" 2>/dev/null || true
wait "$SMOKE_PID" 2>/dev/null || true
echo "   실행 확인 완료"

if (( PUBLISH == 0 )); then
  echo
  echo "여기까지 만들었다. 올리려면 --publish 를 줄 것."
  echo "  DMG:     $RELEASE_DMG"
  echo "  appcast: $RELEASE_APPCAST"
  exit 0
fi

# 7. 발행. 태그를 먼저 만들어 밀고, 그 태그에 산출물을 붙인다.
if (( SKIP_TAG == 0 )); then
  git tag -a "$RELEASE_TAG" -m "SalaryClock $RELEASE_VERSION"
  git push origin "$RELEASE_TAG"
fi
gh release create "$RELEASE_TAG" \
  --repo "$RELEASE_REPO" \
  --title "SalaryClock $RELEASE_VERSION" \
  --notes-file "$RELEASE_ROOT/release/notes.md" \
  "$RELEASE_DMG" "$RELEASE_APPCAST"

echo
echo "발행 완료: $RELEASE_NOTES_URL"
echo "피드가 이 릴리스를 가리키는지 확인:"
echo "  curl -fsSL $RELEASE_FEED_URL | head -20"
