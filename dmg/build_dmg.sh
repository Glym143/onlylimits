#!/bin/bash
# Build a styled OnlyLimits .dmg: branded dark background, app on the left,
# Applications on the right, drag-to-install. Uses dmgbuild (writes the layout
# directly — no flaky Finder automation).
#
#   one-time:  python3 -m pip install --user dmgbuild
#   run:       ./build.sh && dmg/build_dmg.sh [version]     (default 1.2)
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:-1.2}"
OUT="OnlyLimits-${VERSION}.dmg"

[ -d OnlyLimits.app ] || { echo "build OnlyLimits.app first: ./build.sh"; exit 1; }
[ -f dmg/background.png ] || python3 dmg/make_bg.py

rm -f "$OUT"
python3 -m dmgbuild -s dmg/settings.py "OnlyLimits" "$OUT"
echo "✓ built $OUT ($(du -h "$OUT" | cut -f1))"
