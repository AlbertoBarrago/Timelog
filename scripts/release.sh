#!/usr/bin/env bash
# release.sh — bump version, update CHANGELOG, commit, push
# Usage: ./scripts/release.sh [patch|minor|major]
# Default: patch
set -euo pipefail

BUMP="${1:-patch}"

# ── Colori ─────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
ok()   { echo -e "${GREEN}✔ $*${NC}"; }
warn() { echo -e "${YELLOW}⚠ $*${NC}"; }
err()  { echo -e "${RED}✘ $*${NC}"; exit 1; }

# ── Paths ─────────────────────────────────────────────────────────────
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IOS_PROJ="$ROOT/Timelog.xcodeproj/project.pbxproj"
MAC_PROJ="$ROOT/TimelogMac.xcodeproj/project.pbxproj"
CHANGELOG="$ROOT/CHANGELOG.md"

# ── Validazione argomento ──────────────────────────────────────────────
case "$BUMP" in
  patch|minor|major) ;;
  *) err "Argomento non valido: '$BUMP'. Usa: patch | minor | major" ;;
esac

# ── Verifica working tree pulito ───────────────────────────────────────
cd "$ROOT"
if [[ -n "$(git status --porcelain)" ]]; then
  warn "Hai modifiche non committate:"
  git status --short
  echo ""
  read -rp "Continuare comunque? (y/N) " CONFIRM
  [[ "${CONFIRM,,}" == "y" ]] || err "Operazione annullata."
fi

# ── Leggi versione corrente ────────────────────────────────────────────
CURRENT=$(grep -m1 'MARKETING_VERSION' "$IOS_PROJ" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
[[ -n "$CURRENT" ]] || err "Impossibile leggere MARKETING_VERSION da $IOS_PROJ"

IFS='.' read -r MAJOR MINOR PATCH_N <<< "$CURRENT"

# ── Calcola nuova versione ─────────────────────────────────────────────
case "$BUMP" in
  major) MAJOR=$((MAJOR + 1)); MINOR=0; PATCH_N=0 ;;
  minor) MINOR=$((MINOR + 1)); PATCH_N=0 ;;
  patch) PATCH_N=$((PATCH_N + 1)) ;;
esac

NEW_VERSION="$MAJOR.$MINOR.$PATCH_N"
TODAY=$(date +%Y-%m-%d)

# ── Leggi e incrementa build number ───────────────────────────────────
CURRENT_BUILD=$(grep -m1 'CURRENT_PROJECT_VERSION' "$IOS_PROJ" | grep -oE '[0-9]+')
NEW_BUILD=$((CURRENT_BUILD + 1))

echo ""
echo -e "  ${YELLOW}${CURRENT}${NC} → ${GREEN}${NEW_VERSION}${NC}  (build ${CURRENT_BUILD} → ${NEW_BUILD})"
echo ""

# ── Bump versioni nei .xcodeproj ──────────────────────────────────────
perl -i -p -e \
  "s/MARKETING_VERSION = [0-9]+\.[0-9]+(\.[0-9]+)?;/MARKETING_VERSION = $NEW_VERSION;/g" \
  "$IOS_PROJ" "$MAC_PROJ"

perl -i -p -e \
  "s/CURRENT_PROJECT_VERSION = [0-9]+;/CURRENT_PROJECT_VERSION = $NEW_BUILD;/g" \
  "$IOS_PROJ" "$MAC_PROJ"

ok "Versione aggiornata in Timelog.xcodeproj e TimelogMac.xcodeproj"

# ── Aggiorna CHANGELOG ─────────────────────────────────────────────────
# Inserisce il nuovo header dopo la riga [Unreleased]
perl -i -p -e \
  "s|^## \[Unreleased\]|## [Unreleased]\n\n---\n\n## [$NEW_VERSION] — $TODAY|" \
  "$CHANGELOG"

ok "CHANGELOG aggiornato → [$NEW_VERSION] — $TODAY"

# ── Commit ─────────────────────────────────────────────────────────────
git add "$IOS_PROJ" "$MAC_PROJ" "$CHANGELOG"
git commit -m "chore: release $NEW_VERSION (build $NEW_BUILD)"
ok "Commit creato"

# ── Tag ───────────────────────────────────────────────────────────────
git tag -f "v$NEW_VERSION"
ok "Tag v$NEW_VERSION creato"

# ── Push ──────────────────────────────────────────────────────────────
echo ""
read -rp "Push origin main + tag v$NEW_VERSION? (y/N) " PUSH_CONFIRM
if [[ "${PUSH_CONFIRM,,}" == "y" ]]; then
  git push origin main
  git push origin "v$NEW_VERSION"
  ok "Pushato su origin (main + tag v$NEW_VERSION)"
else
  warn "Push saltato. Esegui manualmente: git push origin main && git push origin v$NEW_VERSION"
fi

echo ""
echo -e "${GREEN}🚀 Release $NEW_VERSION pubblicata!${NC}"
