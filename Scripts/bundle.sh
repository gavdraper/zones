#!/usr/bin/env bash
# Assembles a notarisable-shaped Zones.app menu-bar agent from the SwiftPM
# release build and ad-hoc code-signs it so the Accessibility (TCC) grant
# persists across rebuilds.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/build/Zones.app"
BIN_NAME="ZonesApp"

echo "==> Building release binary"
swift build -c release --package-path "$ROOT"
BIN_PATH="$(swift build -c release --package-path "$ROOT" --show-bin-path)/$BIN_NAME"

echo "==> Assembling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"
cp "$BIN_PATH" "$APP/Contents/MacOS/Zones"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>Zones</string>
    <key>CFBundleDisplayName</key>
    <string>Zones</string>
    <key>CFBundleIdentifier</key>
    <string>co.uk.vindraper.zones</string>
    <key>CFBundleExecutable</key>
    <string>Zones</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
PLIST

# Prefer the stable self-signed dev identity (see Scripts/create-signing-cert.sh)
# so the Accessibility (TCC) grant survives rebuilds. Fall back to ad-hoc, which
# changes the cdhash every build and forces a re-grant each time.
IDENTITY="${ZONES_SIGN_IDENTITY:-Zones Dev}"
if security find-identity -v -p codesigning | grep -q "$IDENTITY"; then
    echo "==> Code-signing with '$IDENTITY'"
    codesign --force --sign "$IDENTITY" --options runtime "$APP"
else
    echo "==> '$IDENTITY' not found — ad-hoc signing (TCC grant won't persist across rebuilds)"
    echo "    Run Scripts/create-signing-cert.sh once to fix this."
    codesign --force --sign - --options runtime "$APP"
fi

echo "==> Done: $APP"
echo "    Launch with: open \"$APP\""
echo "    First run will prompt for Accessibility permission."
