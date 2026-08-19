#!/bin/bash
# Render every menu-bar layout to docs/statusbar-preview.png, drawn by the app's
# own StatusBarImage code. The status item can't be screenshotted from a script,
# so this is how you check glyph alignment, gaps and the separator after
# touching the drawing code — no build, no install.
#
#   tools/preview_statusbar.sh                  # fixed values (diffable)
#   tools/preview_statusbar.sh out.png --live   # this Mac's real memory/disk
set -euo pipefail
cd "$(dirname "$0")/.."

BIN="$(mktemp -d)/preview_statusbar"
swiftc -O tools/preview_statusbar.swift \
    Sources/OnlyLimits/StatusBarImage.swift \
    Sources/OnlyLimits/MemoryMonitor.swift \
    Sources/OnlyLimits/DiskMonitor.swift \
    Sources/OnlyLimits/Localization.swift \
    -o "$BIN"

"$BIN" "$@"
