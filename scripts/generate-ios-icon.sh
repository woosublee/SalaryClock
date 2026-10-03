#!/usr/bin/env bash
# iOS 앱 아이콘(1024 한 장, 밝게·어둡게)을 그려 ios/의 asset catalog에 넣는다.
#
# 맥은 번들을 조립할 때마다 아이콘을 새로 그리지만(generate-app-icon.sh), iOS는
# Xcode가 asset catalog를 직접 읽으므로 결과 PNG를 커밋해 둔다. 팔레트가 바뀌면
# 이 스크립트를 다시 돌려 커밋한다.
#
# App Store는 투명 채널이 있는 아이콘을 거부하므로 알파를 걷어낸다.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$ROOT/ios/SalaryClock/Assets.xcassets/AppIcon.appiconset"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/salaryclock-ios-icon.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

swiftc -O "$ROOT/scripts/render-app-icon.swift" -o "$WORK/render"
"$WORK/render" "$ROOT/shared/golden/palette.json" "$WORK" --ios

for mode in Light Dark; do
  # 레티나 맥에서 그리면 2048로 나온다 — 1024로 줄이고, JPEG를 한 번 거쳐
  # 알파를 없앤다(판이 캔버스를 꽉 채우므로 잃는 픽셀이 없다).
  sips -z 1024 1024 "$WORK/AppIcon-$mode.png" --out "$WORK/$mode.png" >/dev/null
  sips -s format jpeg -s formatOptions best "$WORK/$mode.png" --out "$WORK/$mode.jpg" >/dev/null
  sips -s format png "$WORK/$mode.jpg" --out "$OUT/AppIcon-$mode.png" >/dev/null
done
echo "wrote $OUT"
