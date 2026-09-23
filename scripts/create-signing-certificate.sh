#!/usr/bin/env bash
# 이 앱 전용 코드 서명 인증서를 만들어 키체인에 넣는다.
#
# ad-hoc 서명(`codesign --sign -`)으로는 안 되는 이유: ad-hoc 서명에는 고정된
# 신원이 없어서 빌드할 때마다 다른 서명이 나온다. Sparkle은 내려받은 새 버전이
# 지금 돌고 있는 앱과 같은 곳에서 서명됐는지를 확인하는데, 그 확인이 성립하지
# 않는다. 그래서 신원이 고정된 인증서가 하나 필요하다.
#
# Apple Developer 계정(연 $99)이 필요한 Developer ID 대신 자체 서명을 쓴다.
# 본인 기계에서 빌드해 본인이 쓰는 앱이라 공증이 필요 없고, 같은 저장소의
# 다른 앱들(Quill·Drift·cliproxymanager)도 같은 방식이다.
#
# 이미 있으면 아무것도 하지 않는다 — 인증서를 새로 만들면 신원이 바뀌어
# 이전 버전에서 올라오는 업데이트가 거부된다.
set -euo pipefail

IDENTITY="${1:-SalaryClock}"

if security find-identity -v -p codesigning | grep -Fq "\"$IDENTITY\""; then
  echo "이미 있다: $IDENTITY"
  exit 0
fi

if security find-certificate -c "$IDENTITY" >/dev/null 2>&1; then
  echo "인증서는 있는데 서명에 쓸 수 있는 개인키가 없다: $IDENTITY" >&2
  echo "키체인에서 해당 항목을 지우고 다시 실행할 것." >&2
  exit 1
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

cat > "$TMP/openssl.cnf" <<CNF
[req]
distinguished_name = req_distinguished_name
x509_extensions = v3_req
prompt = no
[req_distinguished_name]
CN = $IDENTITY
[v3_req]
basicConstraints = critical,CA:false
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
CNF

openssl req -x509 -newkey rsa:2048 -nodes -sha256 -days 3650 \
  -keyout "$TMP/$IDENTITY.key" -out "$TMP/$IDENTITY.crt" \
  -config "$TMP/openssl.cnf" >/dev/null 2>&1

# p12 비밀번호는 한 번 쓰고 버린다 — 이 프로세스 밖으로 나가지 않는다.
P12_PASSWORD="$(openssl rand -base64 24)"
LEGACY=()
if openssl pkcs12 -help 2>&1 | grep -q -- '-legacy'; then LEGACY=(-legacy); fi
openssl pkcs12 "${LEGACY[@]}" -export \
  -passout pass:"$P12_PASSWORD" \
  -inkey "$TMP/$IDENTITY.key" -in "$TMP/$IDENTITY.crt" \
  -out "$TMP/$IDENTITY.p12" -name "$IDENTITY" >/dev/null 2>&1

KEYCHAIN="$(security default-keychain | sed 's/^ *//; s/"//g')"
# -T /usr/bin/codesign: codesign이 이 키를 쓸 때마다 묻지 않게 한다.
security import "$TMP/$IDENTITY.p12" -k "$KEYCHAIN" -P "$P12_PASSWORD" \
  -T /usr/bin/codesign >/dev/null

# 신뢰 설정은 관리자 인증을 요구할 수 있다. 실패해도 서명 자체는 되므로
# 여기서 죽이지 않는다 — 무엇이 안 됐는지만 알린다.
if ! security add-trusted-cert -d -r trustRoot -p codeSign \
  -k "$KEYCHAIN" "$TMP/$IDENTITY.crt" >/dev/null 2>&1; then
  echo "경고: 신뢰 설정을 추가하지 못했다(관리자 인증이 필요할 수 있다)." >&2
  echo "서명과 업데이트에는 영향이 없다." >&2
fi

# 실제로 서명에 쓸 수 있는지 확인한다. 키체인에 들어갔다는 것만으로는
# 부족하다 — 개인키 접근 권한이 없으면 여기서 걸린다.
PROBE="$TMP/probe"
printf '#!/bin/sh\nexit 0\n' > "$PROBE"
chmod +x "$PROBE"
codesign --force --sign "$IDENTITY" "$PROBE" >/dev/null
codesign --verify --strict "$PROBE"

echo "만들었다: $IDENTITY"
