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
# 이미 있으면 아무것도 하지 않는다. 다시 만들 이유가 없고, 바꾸면 이 기계에서
# 만든 예전 빌드와 서명이 갈린다.
#
# 다만 신원이 바뀌어도 업데이트가 끊기지는 않는다. Sparkle은 EdDSA 서명과 코드
# 서명 중 하나만 유효하면 통과시킨다 — 소스의 SUUpdateValidator.m에 "키 교체가
# 신뢰 사슬을 끊지 않도록 하나의 실패를 허용한다"고 적혀 있다. EdDSA 키를 그대로
# 두는 한 이미 나간 버전에서도 새 버전이 올라온다.
#
# 사용법:
#   create-signing-certificate.sh                  # 없으면 만든다
#   create-signing-certificate.sh --export <경로>  # 만들면서 p12로도 내보낸다
#                                                  # (GitHub Actions 시크릿용)
#   create-signing-certificate.sh --replace ...    # 있어도 지우고 다시 만든다
#
# --export는 p12 비밀번호를 표준출력 마지막 줄에 낸다. 받는 쪽이 바로 시크릿에
# 넣을 수 있게 하려는 것이고, 로그로 남는 곳에서 돌리면 안 된다.
set -euo pipefail

IDENTITY="SalaryClock"
EXPORT_PATH=""
REPLACE=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --export) EXPORT_PATH="${2:?--export 뒤에 경로를 줄 것}"; shift 2 ;;
    --replace) REPLACE=1; shift ;;
    --identity) IDENTITY="${2:?--identity 뒤에 이름을 줄 것}"; shift 2 ;;
    *) echo "모르는 인자: $1" >&2; exit 1 ;;
  esac
done

if security find-identity -v -p codesigning | grep -Fq "\"$IDENTITY\""; then
  if (( REPLACE == 0 )); then
    echo "이미 있다: $IDENTITY"
    exit 0
  fi
  echo "기존 신원을 지운다: $IDENTITY"
  security delete-identity -c "$IDENTITY" -t >/dev/null
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

# 내보내기는 키체인에서 다시 꺼내는 게 아니라 방금 만든 p12를 그대로 옮긴다.
# security export는 키체인 단위로만 동작해서 다른 앱 신원까지 딸려 나온다.
if [[ -n "$EXPORT_PATH" ]]; then
  cp "$TMP/$IDENTITY.p12" "$EXPORT_PATH"
  chmod 600 "$EXPORT_PATH"
fi

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
if [[ -n "$EXPORT_PATH" ]]; then
  echo "내보냈다: $EXPORT_PATH"
  # 마지막 줄에 비밀번호. 부르는 쪽이 읽어 시크릿에 넣는다.
  echo "$P12_PASSWORD"
fi
