#!/usr/bin/env bash
# Assembles a notarisable-shaped Zones.app menu-bar agent from the SwiftPM
# release build and ad-hoc code-signs it so the Accessibility (TCC) grant
# persists across rebuilds.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/build/Zones.app"
BIN_NAME="ZonesApp"

# Version metadata. Overridable so Scripts/release.sh can stamp a real release;
# the defaults keep a plain `./Scripts/bundle.sh` working for local dev.
ZONES_VERSION="${ZONES_VERSION:-0.1.0}"
ZONES_BUILD="${ZONES_BUILD:-1}"

# Sparkle auto-update config baked into Info.plist. The feed URL is the appcast
# served over HTTPS; the public key verifies update signatures (its private half
# lives in your Keychain — see Scripts/appcast.sh). Override the feed for staging.
ZONES_FEED_URL="${ZONES_FEED_URL:-https://gavindraper.com/zones/appcast.xml}"
ZONES_PUBLIC_ED_KEY="1ouprIZl/OqPjiJ/wGojDHSBMHj6xYCfD/KWCE5JxPs="

# Build a universal (arm64 + x86_64) binary so releases run on both Apple Silicon
# and Intel Macs — macOS 14 still supports 2018-era Intel hardware. Override with
# ZONES_ARCHS="arm64" for a faster single-arch local build.
ZONES_ARCHS="${ZONES_ARCHS:-arm64 x86_64}"
ARCH_FLAGS=()
for arch in $ZONES_ARCHS; do ARCH_FLAGS+=(--arch "$arch"); done

echo "==> Building release binary (version $ZONES_VERSION, build $ZONES_BUILD, archs: $ZONES_ARCHS)"
swift build -c release --package-path "$ROOT" "${ARCH_FLAGS[@]}"
BIN_PATH="$(swift build -c release --package-path "$ROOT" "${ARCH_FLAGS[@]}" --show-bin-path)/$BIN_NAME"

echo "==> Assembling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"
cp "$BIN_PATH" "$APP/Contents/MacOS/Zones"

echo "==> Installing app icon"
# Resources/AppIcon.icns is committed; regenerate it with Scripts/make-icon.sh.
ICON_SRC="$ROOT/Resources/AppIcon.icns"
if [[ -f "$ICON_SRC" ]]; then
    cp "$ICON_SRC" "$APP/Contents/Resources/AppIcon.icns"
else
    echo "!! $ICON_SRC missing — run Scripts/make-icon.sh to generate it." >&2
    exit 1
fi

echo "==> Embedding Sparkle.framework"
# Match the universal (arm64 + x86_64) slice explicitly so a single-arch
# framework can never be embedded by accident.
SPARKLE_FW="$(find "$ROOT/.build/artifacts" -type d -name "Sparkle.framework" -path "*macos-arm64_x86_64*" | head -1)"
if [[ -z "$SPARKLE_FW" ]]; then
    echo "!! Universal Sparkle.framework not found under .build/artifacts — resolve it with 'swift build' first." >&2
    exit 1
fi
mkdir -p "$APP/Contents/Frameworks"
cp -R "$SPARKLE_FW" "$APP/Contents/Frameworks/"

FRAMEWORK="$APP/Contents/Frameworks/Sparkle.framework"

# The SwiftPM binary links Sparkle via @rpath; point that rpath at the bundle so
# the framework resolves from inside the .app. Add it only if it's not already there
# (a fresh copy never has it, but stay idempotent and let real failures surface).
if ! otool -l "$APP/Contents/MacOS/Zones" | grep -q "@executable_path/../Frameworks"; then
    install_name_tool -add_rpath "@executable_path/../Frameworks" "$APP/Contents/MacOS/Zones"
fi

cat > "$APP/Contents/Info.plist" <<PLIST
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
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${ZONES_VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${ZONES_BUILD}</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>SUFeedURL</key>
    <string>${ZONES_FEED_URL}</string>
    <key>SUPublicEDKey</key>
    <string>${ZONES_PUBLIC_ED_KEY}</string>
    <key>SUEnableAutomaticChecks</key>
    <true/>
</dict>
</plist>
PLIST

# Prefer the stable self-signed dev identity (see Scripts/create-signing-cert.sh)
# so the Accessibility (TCC) grant survives rebuilds. Fall back to ad-hoc, which
# changes the cdhash every build and forces a re-grant each time.
IDENTITY="${ZONES_SIGN_IDENTITY:-Zones Dev}"
if security find-identity -v -p codesigning | grep -q "$IDENTITY"; then
    echo "==> Code-signing with '$IDENTITY'"
    SIGN_ID="$IDENTITY"
else
    echo "==> '$IDENTITY' not found — ad-hoc signing (TCC grant won't persist across rebuilds)"
    echo "    Run Scripts/create-signing-cert.sh once to fix this."
    SIGN_ID="-"
fi

# Sign with the hardened runtime (required for notarisation) from the inside out:
# nested helpers and XPC services, then the framework, then the app last — an
# enclosing signature is only valid if everything it contains is already signed.
sign() { codesign --force --options runtime --sign "$SIGN_ID" "$@"; }

echo "==> Signing Sparkle helpers + framework"
# Resolve the version dir via the Current symlink instead of hardcoding 'B':
# the dependency floats on Sparkle 2.x and the directory name can change.
FWV="$FRAMEWORK/Versions/Current"
sign "$FWV/XPCServices/Downloader.xpc"
sign "$FWV/XPCServices/Installer.xpc"
sign "$FWV/Updater.app"
sign "$FWV/Autoupdate"
sign "$FRAMEWORK"

# The hardened runtime enforces Library Validation: the app may only load code
# signed by Apple or by its own Team ID. A real "Developer ID" signature shares
# the app's team with the embedded Sparkle.framework, so release builds pass for
# free. Self-signed / ad-hoc dev builds have no team to match, so dyld rejects
# the framework ("different Team IDs") — grant the disable-library-validation
# exception there and ONLY there, keeping release builds at full strength.
echo "==> Signing app"
if [[ "$SIGN_ID" == *"Developer ID"* ]]; then
    sign "$APP"
else
    ENT_FILE="$ROOT/build/dev.entitlements"
    cat > "$ENT_FILE" <<'ENT'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.cs.disable-library-validation</key>
    <true/>
</dict>
</plist>
ENT
    echo "    self-signed build — applying disable-library-validation entitlement"
    codesign --force --options runtime --entitlements "$ENT_FILE" --sign "$SIGN_ID" "$APP"
fi

echo "==> Done: $APP"
echo "    Launch with: open \"$APP\""
echo "    First run will prompt for Accessibility permission."
