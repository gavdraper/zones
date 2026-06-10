#!/usr/bin/env bash
# Regenerates Resources/AppIcon.icns from the Swift renderer.
#
# Pipeline: make-icon.swift -> 1024px master PNG -> sips downsamples every iconset
# slot -> iconutil packs the .iconset into a single .icns. Commit the resulting
# Resources/AppIcon.icns so bundle.sh can embed it without re-rendering each build.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RES_DIR="$ROOT/Resources"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

MASTER="$WORK/icon-1024.png"
ICONSET="$WORK/AppIcon.iconset"
mkdir -p "$ICONSET"

echo "==> Rendering master icon"
swift "$ROOT/Scripts/make-icon.swift" "$MASTER"

# The standard macOS iconset slots: each logical size at @1x and @2x.
echo "==> Generating iconset slots"
gen() { # gen <pixels> <filename>
    sips -z "$1" "$1" "$MASTER" --out "$ICONSET/$2" >/dev/null
}
gen 16   icon_16x16.png
gen 32   icon_16x16@2x.png
gen 32   icon_32x32.png
gen 64   icon_32x32@2x.png
gen 128  icon_128x128.png
gen 256  icon_128x128@2x.png
gen 256  icon_256x256.png
gen 512  icon_256x256@2x.png
gen 512  icon_512x512.png
cp "$MASTER" "$ICONSET/icon_512x512@2x.png"

echo "==> Packing AppIcon.icns"
mkdir -p "$RES_DIR"
iconutil --convert icns "$ICONSET" --output "$RES_DIR/AppIcon.icns"

echo "==> Done: $RES_DIR/AppIcon.icns"
