#!/usr/bin/env bash
# 웹 파비콘을 앱 아이콘과 같은 그림으로 만든다.
#
# 맥 앱은 빌드할 때마다 아이콘을 그리지만(generate-app-icon.sh), 웹은 그럴 수
# 없다 — 그리는 코드가 AppKit을 쓰므로 리눅스 빌드 환경에서는 못 돈다. 그래서
# 여기서 만든 PNG를 저장소에 넣어 둔다. 색이나 모양을 바꾸면 이 스크립트를
# 다시 돌려야 한다.
#
# 밝은 쪽 한 벌만 쓴다. 탭 아이콘은 제 배경(흰 판)을 갖고 있어서 브라우저가
# 어두운 테마여도 그대로 읽힌다.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/salaryclock-webicon.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

swiftc -O "$ROOT/scripts/render-app-icon.swift" -o "$WORK/render"
"$WORK/render" "$ROOT/shared/golden/palette.json" "$WORK"

# Next.js App Router 규약: app/icon.png은 파비콘, app/apple-icon.png은
# 홈 화면에 추가할 때 쓰인다. 파일이 있으면 링크 태그를 알아서 넣어 준다.
sips -z 512 512 "$WORK/AppIcon-Light.png" --out "$ROOT/app/icon.png" >/dev/null
sips -z 180 180 "$WORK/AppIcon-Light.png" --out "$ROOT/app/apple-icon.png" >/dev/null

# create-next-app이 넣어 둔 기본 파비콘은 치운다. 남겨 두면 /favicon.ico가
# 그쪽을 계속 내보낸다.
rm -f "$ROOT/app/favicon.ico"

echo "wrote app/icon.png, app/apple-icon.png"
