#!/bin/bash
set -e

# Generate a STABLE self-signed code-signing certificate for Timelog (macOS).
#
# Why this exists:
# macOS TCC (notifications, etc.) anchors a granted permission to the app's
# code-signing identity. With ad-hoc signing (codesign --sign -) TCC falls back
# to the binary's cdhash, which changes on every build, so users are re-prompted
# for permissions on EVERY Sparkle update. Signing every build with the SAME
# certificate keeps the designated requirement constant, so grants survive
# across versions — without paying for an Apple Developer account.
#
# Run this ONCE. Keep the resulting .p12 safe and reuse it for every release.
# The private key never needs to leave your machine except as the GitHub secret.

cd "$(dirname "$0")/.."

CN="Timelog Signing"
ORG="alBz"
OUT_DIR="bin/.signing"          # .p12 is gitignored — see bin/.signing/README.md
P12="${OUT_DIR}/Timelog-signing.p12"
DAYS=3650                       # 10 years; TCC only cares that the cert is stable

mkdir -p "${OUT_DIR}"

if [ -f "${P12}" ]; then
    echo "❌ ${P12} already exists."
    echo "   Reuse the existing certificate — regenerating it would change the"
    echo "   signing identity and reset every user's TCC permissions."
    exit 1
fi

# A random passphrase protects the .p12 at rest; it is stored as a GitHub secret
# alongside the certificate itself, so it never has to be memorised.
P12_PASS=$(openssl rand -base64 24)

echo "▶ Generating key + self-signed code-signing certificate…"
openssl req -x509 -newkey rsa:2048 -sha256 -days "${DAYS}" -nodes \
    -keyout "${OUT_DIR}/key.pem" \
    -out "${OUT_DIR}/cert.pem" \
    -subj "/CN=${CN}/O=${ORG}" \
    -addext "keyUsage=critical,digitalSignature" \
    -addext "extendedKeyUsage=critical,codeSigning" \
    2>/dev/null

echo "▶ Packaging PKCS#12 bundle…"
# -legacy is REQUIRED: OpenSSL 3.x defaults to AES-256/SHA-256 PKCS#12 encryption
# that macOS's Security framework cannot import ("MAC verification failed").
# The legacy (SHA-1/3DES) format imports cleanly via `security import`.
openssl pkcs12 -export -legacy \
    -inkey "${OUT_DIR}/key.pem" \
    -in "${OUT_DIR}/cert.pem" \
    -name "${CN}" \
    -out "${P12}" \
    -passout "pass:${P12_PASS}"

# The PEMs are no longer needed once bundled into the .p12.
rm -f "${OUT_DIR}/key.pem" "${OUT_DIR}/cert.pem"

P12_BASE64=$(base64 < "${P12}")

echo ""
echo "✅ Certificate created → ${P12}"
echo ""
echo "────────────────────────────────────────────────────────────────────────"
echo " Add these THREE GitHub Actions secrets (Settings → Secrets → Actions):"
echo "────────────────────────────────────────────────────────────────────────"
echo ""
echo " 1) SIGNING_CERTIFICATE_P12_BASE64"
echo "    (the base64 blob below — copy it whole)"
echo ""
echo "${P12_BASE64}"
echo ""
echo " 2) SIGNING_CERTIFICATE_PASSWORD"
echo ""
echo "    ${P12_PASS}"
echo ""
echo " 3) SIGNING_IDENTITY"
echo ""
echo "    ${CN}"
echo ""
echo "────────────────────────────────────────────────────────────────────────"
echo "⚠️  Keep ${P12} backed up somewhere safe (password manager)."
echo "   If you lose it, the next release gets a NEW identity and every user"
echo "   will have to re-grant permissions once more."
echo "────────────────────────────────────────────────────────────────────────"
