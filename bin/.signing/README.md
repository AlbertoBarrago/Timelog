# Signing material — Timelog (macOS)

Stable **self-signed code-signing certificate** used to sign every macOS release.

## Why

macOS anchors a granted TCC permission (notifications, etc.) to the app's
code-signing identity. Ad-hoc signing (`codesign --sign -`) changes the binary's
`cdhash` on every build, so users get re-prompted for permissions on **every**
Sparkle update. Signing every release with the **same** certificate keeps the
signing authority constant, so grants survive across versions — without an Apple
Developer account.

## What's in here

| File | Tracked? | Purpose |
|------|----------|---------|
| `Timelog-signing.p12` | **No** (`*.p12` gitignored) | Certificate + private key. Local backup of the CI secret. |
| `README.md` | Yes | This file. |

The `.p12` is **never committed** — it lives here as a local backup only. A second
backup is kept in `~/Documents/Timelog-Signing.p12` and the values are documented
in `CLAUDE.local.md`.

## How it's used

CI (`.github/workflows/release-macos.yml`) reads three GitHub secrets:

- `SIGNING_CERTIFICATE_P12_BASE64` — the `.p12` in base64
- `SIGNING_CERTIFICATE_PASSWORD` — its passphrase
- `SIGNING_IDENTITY` — `Timelog Signing`

It imports the cert into a throwaway keychain and signs the app with it.

## Regenerating (only if lost)

```bash
./bin/make-selfsigned-cert.sh   # prints the three secret values to re-add
```

⚠️ Regenerating produces a **new identity**: the next update will reset every
user's permissions once. Only do it if the `.p12` is truly lost.

## Does it work on other Macs?

Yes. A self-signed cert used to **sign** does not need to be trusted or installed
on the downloading Mac — `codesign --verify` checks seal integrity, not trust,
and Sparkle validates updates via the EdDSA key. The only caveat: being
self-signed (not Developer ID + notarized), Gatekeeper still shows an
"unidentified developer" warning on first launch (right-click → Open once).
