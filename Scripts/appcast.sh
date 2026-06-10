#!/usr/bin/env bash
# Generates / updates the Sparkle appcast (docs/appcast.xml) from the release
# DMGs in a local archive directory, signing each update with the EdDSA private
# key stored in your Keychain (created once by `generate_keys`).
#
# Usage:
#   ./Scripts/appcast.sh [archive-dir]      # archive-dir defaults to ./dist
#
# Typical release flow:
#   1. ./Scripts/release.sh 0.2.0           # -> build/Zones-0.2.0.dmg (notarised)
#   2. cp build/Zones-0.2.0.dmg dist/       # keep every shipped DMG together
#   3. ./Scripts/appcast.sh                 # regenerate docs/appcast.xml
#   4. Upload the DMG(s) to the GitHub release; commit + push docs/appcast.xml
#      (GitHub Pages serves /docs at the SUFeedURL baked into the app).
#
# Environment:
#   ZONES_DOWNLOAD_PREFIX   URL prefix prepended to each DMG filename in the feed
#                           (default: the GitHub release-assets download URL).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARCHIVE_DIR="${1:-$ROOT/dist}"
APPCAST="$ROOT/docs/appcast.xml"
DOWNLOAD_PREFIX="${ZONES_DOWNLOAD_PREFIX:-https://github.com/gavdraper/zones/releases/download/downloads/}"

TOOL="$(find "$ROOT/.build/artifacts" -type f -name generate_appcast -path "*bin*" | head -1)"
if [[ -z "$TOOL" ]]; then
    echo "!! generate_appcast not found — run 'swift build' to fetch Sparkle first." >&2
    exit 1
fi

if [[ ! -d "$ARCHIVE_DIR" ]] || ! ls "$ARCHIVE_DIR"/*.dmg >/dev/null 2>&1; then
    echo "!! No .dmg files in '$ARCHIVE_DIR'." >&2
    echo "   Build one with Scripts/release.sh and copy it there first." >&2
    exit 1
fi

echo "==> Generating appcast from $ARCHIVE_DIR"
echo "    download prefix: $DOWNLOAD_PREFIX"
mkdir -p "$(dirname "$APPCAST")"
"$TOOL" \
    --download-url-prefix "$DOWNLOAD_PREFIX" \
    --link "https://github.com/gavdraper/zones" \
    -o "$APPCAST" \
    "$ARCHIVE_DIR"

echo "==> Wrote $APPCAST"
echo "    Commit + push it (GitHub Pages serves /docs) and upload the DMG(s) to the release."
