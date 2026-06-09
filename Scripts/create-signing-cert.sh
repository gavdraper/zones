#!/usr/bin/env bash
# One-time setup: create a stable, self-signed code-signing identity ("Zones Dev")
# and trust it for code signing.
#
# Why: ad-hoc signatures change their code hash (cdhash) on every build, so macOS
# treats each rebuild as a new app and re-prompts for Accessibility permission.
# A stable signing identity makes TCC key on the signing certificate instead, so
# you grant Accessibility once and it persists across rebuilds.
#
# Idempotent: does nothing if the identity already exists. May pop a system
# auth dialog when adding trust — approve it with your password/Touch ID.
set -euo pipefail

IDENTITY="Zones Dev"
LOGIN_KC="$HOME/Library/Keychains/login.keychain-db"

if security find-identity -v -p codesigning | grep -q "$IDENTITY"; then
    echo "==> '$IDENTITY' already exists and is valid for code signing. Nothing to do."
    exit 0
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT   # never leave the private key on disk

cat > "$WORK/openssl.cnf" <<'CNF'
[req]
distinguished_name = dn
x509_extensions = v3
prompt = no
[dn]
CN = Zones Dev
[v3]
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
basicConstraints = critical, CA:false
CNF

echo "==> Generating self-signed code-signing certificate"
openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
    -keyout "$WORK/key.pem" -out "$WORK/cert.pem" -config "$WORK/openssl.cnf" >/dev/null 2>&1
openssl pkcs12 -export -inkey "$WORK/key.pem" -in "$WORK/cert.pem" \
    -out "$WORK/cert.p12" -passout pass:zones -name "$IDENTITY" >/dev/null 2>&1

echo "==> Importing into the login keychain"
security import "$WORK/cert.p12" -k "$LOGIN_KC" -P zones -A >/dev/null 2>&1

echo "==> Trusting the certificate for code signing (approve the auth dialog)"
security add-trusted-cert -r trustRoot -p codeSign -k "$LOGIN_KC" "$WORK/cert.pem"

if security find-identity -v -p codesigning | grep -q "$IDENTITY"; then
    echo "==> Success. '$IDENTITY' is ready. Rebuild with Scripts/bundle.sh."
else
    echo "!! '$IDENTITY' still not valid for code signing — check Keychain Access trust settings." >&2
    exit 1
fi
