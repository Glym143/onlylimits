#!/bin/bash
# Build OnlyLimits and assemble a double-clickable, dock-less .app bundle.
set -euo pipefail
cd "$(dirname "$0")"

CONFIG="${1:-release}"
APP="OnlyLimits.app"
BIN="OnlyLimits"

echo "▸ swift build -c $CONFIG"
swift build -c "$CONFIG"

BUILT="$(swift build -c "$CONFIG" --show-bin-path)/$BIN"
[ -f "$BUILT" ] || { echo "build product not found: $BUILT"; exit 1; }

echo "▸ assembling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BUILT" "$APP/Contents/MacOS/$BIN"
cp Info.plist "$APP/Contents/Info.plist"
[ -f icon/AppIcon.icns ] && cp icon/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
printf 'APPL????' > "$APP/Contents/PkgInfo"

echo "▸ ad-hoc code signing"
codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || echo "  (codesign skipped)"

echo "✓ built $(pwd)/$APP"
echo "  run:   open $(pwd)/$APP"
echo "  or:    ./$APP/Contents/MacOS/$BIN   (foreground, for logs)"
