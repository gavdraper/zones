#!/usr/bin/env bash
# Produces a signed, notarised, stapled Zones DMG ready for distribution.
#
# Pipeline: bundle.sh (build + sign the .app) -> create-dmg -> notarytool -> staple -> verify.
#
# Usage:
#   ./Scripts/release.sh                  # ship the version in ./VERSION, then
#                                         # auto-bump patch + build for next time
#   ./Scripts/release.sh patch            # same as no args (explicit)
#   ./Scripts/release.sh minor            # bump the minor component instead
#   ./Scripts/release.sh major            # bump the major component instead
#   ./Scripts/release.sh 0.2.0            # explicit version (build defaults to 1)
#   ./Scripts/release.sh 0.2.0 7          # explicit version + build
#
# The ./VERSION file (committed) holds "<semver> <build>" — the *next* release to
# ship. A successful run rewrites it with the bumped values, so repeated no-arg
# runs march the version forward on their own. A version is only persisted on a
# successful build, so a failed run leaves VERSION untouched and is safe to retry.
#
# Environment:
#   ZONES_RELEASE_IDENTITY  Code-signing identity for the .app. Defaults to the
#                           first "Developer ID Application" identity in the
#                           keychain. If none is found it falls back to the
#                           self-signed "Zones Dev" identity, which CANNOT be
#                           notarised — the DMG is still produced, notarisation
#                           is skipped, and Gatekeeper will warn on download.
#
#   ZONES_NOTARY_PROFILE    notarytool keychain profile (default: ZonesNotary).
#                           Create it once with:
#                             xcrun notarytool store-credentials ZonesNotary \
#                               --apple-id you@example.com \
#                               --team-id  YOURTEAMID \
#                               --password <app-specific-password>
#
#   ZONES_SKIP_NOTARIZE=1   Build + sign + DMG, but skip notarisation/stapling.
set -euo pipefail

# ---------------------------------------------------------------------------
# Arguments, version & build
# ---------------------------------------------------------------------------
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION_FILE="$ROOT/VERSION"

# Read the next-to-ship "<semver> <build>" from ./VERSION, seeding sane defaults
# if the file is missing or partial.
FILE_VERSION="" FILE_BUILD=""
[[ -f "$VERSION_FILE" ]] && read -r FILE_VERSION FILE_BUILD < "$VERSION_FILE"
FILE_VERSION="${FILE_VERSION:-0.1.0}"
FILE_BUILD="${FILE_BUILD:-1}"

# Each bumper takes a semver and echoes the next one. IFS=. is local to the
# function so it doesn't leak into the rest of the script.
bump_patch() { local IFS=. a b c; read -r a b c <<< "$1"; echo "$a.$b.$((c + 1))"; }
bump_minor() { local IFS=. a b c; read -r a b c <<< "$1"; echo "$a.$((b + 1)).0"; }
bump_major() { local IFS=. a b c; read -r a b c <<< "$1"; echo "$((a + 1)).0.0"; }

case "${1:-}" in
    "")                  # no args: ship the file's version as-is
        VERSION="$FILE_VERSION"
        BUILD="$FILE_BUILD"
        ;;
    patch|minor|major)   # keyword bump from the file's version
        VERSION="$(bump_"$1" "$FILE_VERSION")"
        BUILD="$FILE_BUILD"
        ;;
    *)                   # explicit "<version> [build]"
        VERSION="$1"
        BUILD="${2:-$FILE_BUILD}"
        ;;
esac

# What ./VERSION will hold after a successful run: patch above whatever we shipped
# this time, with a monotonically increasing build (Sparkle orders updates by it).
NEXT_VERSION="$(bump_patch "$VERSION")"
NEXT_BUILD="$((BUILD + 1))"

# Persist the bumped state. Called only on a successful build path so a failed
# run can be retried against the same version.
persist_next_version() {
    printf '%s %s\n' "$NEXT_VERSION" "$NEXT_BUILD" > "$VERSION_FILE"
    echo "==> VERSION bumped: next release will be $NEXT_VERSION (build $NEXT_BUILD)"
}

APP="$ROOT/build/Zones.app"
DMG="$ROOT/build/Zones-$VERSION.dmg"
NOTARY_PROFILE="${ZONES_NOTARY_PROFILE:-ZonesNotary}"

# ---------------------------------------------------------------------------
# Resolve the signing identity
# ---------------------------------------------------------------------------
resolve_identity() {
    if [[ -n "${ZONES_RELEASE_IDENTITY:-}" ]]; then
        printf '%s' "$ZONES_RELEASE_IDENTITY"
        return
    fi
    # `|| true` so a no-match grep doesn't trip `set -e`/`pipefail` in the
    # surrounding command substitution.
    security find-identity -v -p codesigning 2>/dev/null \
        | grep "Developer ID Application" \
        | head -1 \
        | sed -E 's/^[[:space:]]*[0-9]+\)[[:space:]]+[0-9A-F]+[[:space:]]+"(.*)"$/\1/' \
        || true
}

IDENTITY="$(resolve_identity)"
NOTARIZABLE=1

if [[ -z "$IDENTITY" ]]; then
    IDENTITY="Zones Dev"
    NOTARIZABLE=0
    echo "!! No 'Developer ID Application' identity found."
    echo "   Falling back to '$IDENTITY' (self-signed) — DMG will NOT be notarised."
    echo "   Set ZONES_RELEASE_IDENTITY or enrol in the Apple Developer Program to fix."
fi

[[ "${ZONES_SKIP_NOTARIZE:-0}" == "1" ]] && NOTARIZABLE=0

# ---------------------------------------------------------------------------
# Tool checks
# ---------------------------------------------------------------------------
if ! command -v create-dmg >/dev/null 2>&1; then
    echo "!! 'create-dmg' not found. Install it with: brew install create-dmg" >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# 1. Build + sign the .app (delegated to bundle.sh)
# ---------------------------------------------------------------------------
echo "==> Building Zones.app  (version $VERSION, build $BUILD, identity '$IDENTITY')"
ZONES_VERSION="$VERSION" ZONES_BUILD="$BUILD" ZONES_SIGN_IDENTITY="$IDENTITY" \
    "$ROOT/Scripts/bundle.sh"

echo "==> Verifying .app signature (deep — validates the embedded Sparkle helpers too)"
codesign --verify --deep --strict --verbose=2 "$APP"

# ---------------------------------------------------------------------------
# 2. Build the DMG
# ---------------------------------------------------------------------------
echo "==> Building DMG -> $DMG"
rm -f "$DMG"

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
cp -R "$APP" "$STAGE/Zones.app"

CREATE_DMG_ARGS=(
    --volname "Zones"
    --window-pos 200 120
    --window-size 540 380
    --icon-size 100
    --icon "Zones.app" 140 190
    --app-drop-link 400 190
    --no-internet-enable
)
# Sign the DMG itself with the same identity when it's a real one.
[[ "$NOTARIZABLE" == "1" ]] && CREATE_DMG_ARGS+=(--codesign "$IDENTITY")

create-dmg "${CREATE_DMG_ARGS[@]}" "$DMG" "$STAGE"

# ---------------------------------------------------------------------------
# 3. Notarise + staple
# ---------------------------------------------------------------------------
if [[ "$NOTARIZABLE" != "1" ]]; then
    echo "==> Skipping notarisation."
    persist_next_version
    echo "==> Done (UNNOTARISED): $DMG"
    exit 0
fi

echo "==> Submitting to Apple notary service (profile '$NOTARY_PROFILE')"
if ! xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait; then
    echo "!! Notarisation failed. If the profile is missing, create it with:" >&2
    echo "   xcrun notarytool store-credentials $NOTARY_PROFILE \\" >&2
    echo "     --apple-id you@example.com --team-id YOURTEAMID --password <app-specific-password>" >&2
    exit 1
fi

echo "==> Stapling ticket to DMG"
xcrun stapler staple "$DMG"

# ---------------------------------------------------------------------------
# 4. Verify the end result the way Gatekeeper will
# ---------------------------------------------------------------------------
echo "==> Verifying notarisation"
xcrun stapler validate "$DMG"
spctl --assess --type open --context context:primary-signature --verbose=2 "$DMG"

persist_next_version
echo "==> Done: $DMG"
echo "    Notarised, stapled, and ready to attach to a GitHub Release."
