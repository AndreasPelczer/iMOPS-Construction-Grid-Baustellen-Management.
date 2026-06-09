#!/usr/bin/env bash
#
# Codis Augen — reproduzierbare UI-Screenshots ohne Navigations-Zirkus.
#
# Baut die App, startet sie im DEBUG-Snapshot-Mode (siehe App/SnapshotHostView.swift)
# und fängt pro State einen Screenshot per `simctl io` ab. PNGs landen in /tmp/imops-shots.
#
# Usage:
#   scripts/snapshot.sh                         # AufmassSheet, alle 4 States
#   scripts/snapshot.sh AufmassSheet rot        # nur der rot-State
#   scripts/snapshot.sh NeuesAufmassSheet leer  # anderes Ziel
#
set -euo pipefail
cd "$(dirname "$0")/.."

PROJ="iMOPS-Construction-Grid-Baustellen-Management..xcodeproj"
SCHEME="iMOPS-Construction-Grid-Baustellen-Management."
SIM="iPhone 17 Pro Max"
OUT="/tmp/imops-shots"

TARGET="${1:-AufmassSheet}"
if [ "$#" -ge 2 ]; then STATES=("${@:2}"); else STATES=(leer gruen rot schaetzkarte); fi

mkdir -p "$OUT"
echo "== Build ($SCHEME) =="
xcodebuild build -project "$PROJ" -scheme "$SCHEME" \
  -destination "platform=iOS Simulator,name=$SIM" >/dev/null

DD="$HOME/Library/Developer/Xcode/DerivedData"
APP=$(find "$DD" -path "*Debug-iphonesimulator/*.app" -name "${SCHEME}.app" -type d | head -1)
BID=$(/usr/libexec/PlistBuddy -c "Print CFBundleIdentifier" "$APP/Info.plist")
UDID=$(xcrun simctl list devices available | grep "$SIM" | grep -oE "[0-9A-F-]{36}" | head -1)

xcrun simctl boot "$UDID" 2>/dev/null || true
sleep 3
xcrun simctl install "$UDID" "$APP"

for S in "${STATES[@]}"; do
  xcrun simctl terminate "$UDID" "$BID" 2>/dev/null || true
  xcrun simctl launch "$UDID" "$BID" --snapshot-mode --target="$TARGET" --state="$S" >/dev/null
  sleep 4
  xcrun simctl io "$UDID" screenshot "$OUT/${TARGET}_${S}.png" >/dev/null
  echo "→ $OUT/${TARGET}_${S}.png"
done
