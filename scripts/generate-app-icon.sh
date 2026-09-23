#!/usr/bin/env bash
# 앱 아이콘을 그려서 번들에 넣을 Assets.car와 AppIcon.icns를 만든다.
#
# 밝게·어둡게 두 장을 넣는다. macOS 26부터 아이콘도 시스템 외형을 따라가는데,
# 그러려면 .icns 하나가 아니라 두 외형이 다 담긴 Assets.car가 있어야 하고
# Info.plist가 CFBundleIconName으로 그걸 가리켜야 한다. .icns도 같이 만들어
# 두는 이유는 옛 경로(CFBundleIconFile)로 읽는 곳이 남아 있어서다.
#
# 사용법: generate-app-icon.sh <출력 디렉터리>
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${1:?출력 디렉터리를 줄 것}"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/salaryclock-icon.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

# 1024 원본 두 장을 그린다. 색은 팔레트에서 읽는다 (render-app-icon.swift).
swiftc -O "$ROOT/scripts/render-app-icon.swift" -o "$WORK/render"
"$WORK/render" "$ROOT/shared/golden/palette.json" "$WORK"

# 각 크기로 줄여 appiconset을 조립한다. 어두운 쪽에만 appearances를 달면
# 밝은 쪽이 기본이 된다.
ICONSET="$WORK/Assets.xcassets/AppIcon.appiconset"
mkdir -p "$ICONSET"
python3 - "$WORK" "$ICONSET" <<'PY'
import json, subprocess, sys
work, iconset = sys.argv[1], sys.argv[2]
images = []
for pt in (16, 32, 128, 256, 512):
    for scale in (1, 2):
        for mode, src in (("light", "AppIcon-Light.png"), ("dark", "AppIcon-Dark.png")):
            name = f"icon_{pt}x{pt}@{scale}x_{mode}.png"
            px = pt * scale
            subprocess.run(
                ["sips", "-z", str(px), str(px), f"{work}/{src}", "--out", f"{iconset}/{name}"],
                check=True, capture_output=True,
            )
            entry = {"filename": name, "idiom": "mac", "scale": f"{scale}x", "size": f"{pt}x{pt}"}
            if mode == "dark":
                entry["appearances"] = [{"appearance": "luminosity", "value": "dark"}]
            images.append(entry)
json.dump({"images": images, "info": {"author": "salaryclock", "version": 1}},
          open(f"{iconset}/Contents.json", "w"), indent=2)
PY

mkdir -p "$OUT"
xcrun actool "$WORK/Assets.xcassets" \
  --compile "$OUT" \
  --platform macosx \
  --minimum-deployment-target 14.0 \
  --app-icon AppIcon \
  --output-partial-info-plist "$WORK/partial.plist" >/dev/null

[[ -f "$OUT/Assets.car" ]] || { echo "actool이 Assets.car를 내놓지 않았다" >&2; exit 1; }
[[ -f "$OUT/AppIcon.icns" ]] || { echo "actool이 AppIcon.icns를 내놓지 않았다" >&2; exit 1; }
echo "icon → $OUT/Assets.car, $OUT/AppIcon.icns"
