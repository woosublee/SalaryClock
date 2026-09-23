#!/usr/bin/env bash
# DMG에 서명하고 appcast.xml을 만든다.
#
# 비밀키는 키체인에서 나오지 않는다 — sign_update에 --account를 주면 도구가
# 직접 키체인을 읽는다. 키를 셸 변수나 파일로 꺼내면 프로세스 목록과 임시
# 파일에 남을 수 있어서, 꺼낼 이유가 없으면 꺼내지 않는다.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/release-common.sh"

[[ -f "$RELEASE_DMG" ]] || { echo "DMG가 없다: $RELEASE_DMG" >&2; exit 1; }

SIGN_UPDATE="$(release_sparkle_tool sign_update)"
SIGNATURE="$("$SIGN_UPDATE" --account "$RELEASE_SPARKLE_ACCOUNT" -p "$RELEASE_DMG")"
[[ -n "$SIGNATURE" ]] || { echo "sign_update가 서명을 내놓지 않았다" >&2; exit 1; }

# 서명이 실제로 맞는지 여기서 한 번 검증한다. 서명이 잘못된 appcast를 올리면
# 사용자 쪽에서 업데이트가 조용히 거부되고, 그때는 원인이 안 보인다.
"$SIGN_UPDATE" --account "$RELEASE_SPARKLE_ACCOUNT" --verify "$RELEASE_DMG" "$SIGNATURE" >/dev/null

LENGTH="$(wc -c < "$RELEASE_DMG" | tr -d ' ')"
PUB_DATE="$(LC_ALL=C TZ=UTC date '+%a, %d %b %Y %H:%M:%S +0000')"

cat > "$RELEASE_APPCAST" <<XML
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>SalaryClock Updates</title>
    <link>$RELEASE_FEED_URL</link>
    <description>SalaryClock 업데이트</description>
    <item>
      <title>SalaryClock $RELEASE_VERSION</title>
      <pubDate>$PUB_DATE</pubDate>
      <sparkle:version>$RELEASE_BUILD</sparkle:version>
      <sparkle:shortVersionString>$RELEASE_VERSION</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>$RELEASE_MIN_SYSTEM</sparkle:minimumSystemVersion>
      <sparkle:releaseNotesLink>$RELEASE_NOTES_URL</sparkle:releaseNotesLink>
      <enclosure url="$RELEASE_DOWNLOAD_URL" length="$LENGTH" type="application/octet-stream" sparkle:edSignature="$SIGNATURE" sparkle:version="$RELEASE_BUILD" sparkle:shortVersionString="$RELEASE_VERSION" />
    </item>
  </channel>
</rss>
XML

xmllint --noout "$RELEASE_APPCAST"
echo "wrote $RELEASE_APPCAST"
