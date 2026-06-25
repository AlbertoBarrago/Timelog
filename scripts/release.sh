#!/usr/bin/env bash
# release.sh — bump version, update CHANGELOG, commit, push
# Usage: ./scripts/release.sh [patch|minor|major]
# Default: patch
set -euo pipefail

BUMP="${1:-patch}"

# ── Colors ────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
ok()   { echo -e "${GREEN}✔ $*${NC}"; }
warn() { echo -e "${YELLOW}⚠ $*${NC}"; }
err()  { echo -e "${RED}✘ $*${NC}"; exit 1; }

# ── Paths ─────────────────────────────────────────────────────────────
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IOS_PROJ="$ROOT/Timelog.xcodeproj/project.pbxproj"
MAC_PROJ="$ROOT/TimelogMac.xcodeproj/project.pbxproj"
CHANGELOG="$ROOT/CHANGELOG.md"

# ── Argument validation ───────────────────────────────────────────────
case "$BUMP" in
  patch|minor|major) ;;
  *) err "Invalid argument: '$BUMP'. Use: patch | minor | major" ;;
esac

# ── Check clean working tree ──────────────────────────────────────────
cd "$ROOT"
if [[ -n "$(git status --porcelain)" ]]; then
  warn "You have uncommitted changes:"
  git status --short
  echo ""
  read -rp "Continue anyway? (y/N) " CONFIRM
  [[ "${CONFIRM,,}" == "y" ]] || err "Operation cancelled."
fi

# ── Read current version ──────────────────────────────────────────────
CURRENT=$(grep -m1 'MARKETING_VERSION' "$IOS_PROJ" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
[[ -n "$CURRENT" ]] || err "Unable to read MARKETING_VERSION from $IOS_PROJ"

IFS='.' read -r MAJOR MINOR PATCH_N <<< "$CURRENT"

# ── Calculate new version ─────────────────────────────────────────────
case "$BUMP" in
  major) MAJOR=$((MAJOR + 1)); MINOR=0; PATCH_N=0 ;;
  minor) MINOR=$((MINOR + 1)); PATCH_N=0 ;;
  patch) PATCH_N=$((PATCH_N + 1)) ;;
esac

NEW_VERSION="$MAJOR.$MINOR.$PATCH_N"
TODAY=$(date +%Y-%m-%d)

# ── Read and increment build number ──────────────────────────────────
CURRENT_BUILD=$(grep -m1 'CURRENT_PROJECT_VERSION' "$IOS_PROJ" | grep -oE '[0-9]+')
NEW_BUILD=$((CURRENT_BUILD + 1))

echo ""
echo -e "  ${YELLOW}${CURRENT}${NC} → ${GREEN}${NEW_VERSION}${NC}  (build ${CURRENT_BUILD} → ${NEW_BUILD})"
echo ""

# ── Handle skip-worktree on MAC_PROJ ─────────────────────────────────
MAC_SKIP_WORKTREE=false
MAC_LOCAL_PATCH="/tmp/timelog_mac_local.patch"
if git ls-files -v "$MAC_PROJ" | grep -q "^S"; then
  MAC_SKIP_WORKTREE=true
  git update-index --no-skip-worktree "$MAC_PROJ"
  git diff "$MAC_PROJ" > "$MAC_LOCAL_PATCH"
  git checkout -- "$MAC_PROJ"
fi

# ── Bump versions in .xcodeproj files ────────────────────────────────
perl -i -p -e \
  "s/MARKETING_VERSION = [0-9]+\.[0-9]+(\.[0-9]+)?;/MARKETING_VERSION = $NEW_VERSION;/g" \
  "$IOS_PROJ" "$MAC_PROJ"

perl -i -p -e \
  "s/CURRENT_PROJECT_VERSION = [0-9]+;/CURRENT_PROJECT_VERSION = $NEW_BUILD;/g" \
  "$IOS_PROJ" "$MAC_PROJ"

ok "Version updated in Timelog.xcodeproj and TimelogMac.xcodeproj"

# ── Update CHANGELOG ─────────────────────────────────────────────────
# Inserts the new header after the [Unreleased] line.
perl -i -p -e \
  "s|^## \[Unreleased\]|## [Unreleased]\n\n---\n\n## [$NEW_VERSION] — $TODAY|" \
  "$CHANGELOG"

ok "CHANGELOG updated → [$NEW_VERSION] — $TODAY"

# ── Commit ─────────────────────────────────────────────────────────────
git add "$IOS_PROJ" "$MAC_PROJ" "$CHANGELOG"
git commit -m "chore: release $NEW_VERSION (build $NEW_BUILD)"
ok "Commit created"

# ── Restore local changes on MAC_PROJ ────────────────────────────────
if $MAC_SKIP_WORKTREE; then
  if [[ -s "$MAC_LOCAL_PATCH" ]]; then
    # Update the build number in the patch; context already changed after the bump.
    sed -i "" "s/ CURRENT_PROJECT_VERSION = $CURRENT_BUILD;$/ CURRENT_PROJECT_VERSION = $NEW_BUILD;/g" "$MAC_LOCAL_PATCH"
    git apply "$MAC_LOCAL_PATCH" 2>/dev/null || warn "Local MAC_PROJ patch was not applied; manually recheck signing"
  fi
  git update-index --skip-worktree "$MAC_PROJ"
  ok "skip-worktree restored on TimelogMac.xcodeproj"
fi

# ── Tag ───────────────────────────────────────────────────────────────
git tag -f "v$NEW_VERSION"
ok "Tag v$NEW_VERSION created"

# ── Push ──────────────────────────────────────────────────────────────
echo ""
read -rp "Push origin main + tag v$NEW_VERSION? (y/N) " PUSH_CONFIRM
if [[ "${PUSH_CONFIRM,,}" == "y" ]]; then
  git push origin main
  git push origin "v$NEW_VERSION"
  ok "Pushed to origin (main + tag v$NEW_VERSION)"
else
  warn "Push skipped. Run manually: git push origin main && git push origin v$NEW_VERSION"
fi

echo ""
echo -e "${GREEN}🚀 Release $NEW_VERSION published!${NC}"
