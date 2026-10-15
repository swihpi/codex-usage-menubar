#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
MODE="${1:-run}"
case "$MODE" in run|--build|--verify) ;; *) echo "Usage: $0 [--build|--verify]" >&2; exit 2 ;; esac
[[ "$(uname -s)" == Darwin ]] || { echo 'This app requires macOS.' >&2; exit 1; }
swift build -c release
APP="$ROOT_DIR/outputs/Codex Usage.app"
mkdir -p "$APP/Contents/MacOS"
BUILD_DIR="$(swift build -c release --show-bin-path)"
# Replace the binary inode rather than modifying a running executable in place.
cp "$BUILD_DIR/CodexUsage" "$APP/Contents/MacOS/CodexUsage.new"
mv -f "$APP/Contents/MacOS/CodexUsage.new" "$APP/Contents/MacOS/CodexUsage"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>CodexUsage</string>
<key>CFBundleIdentifier</key><string>com.swi.codexusage</string>
<key>CFBundleName</key><string>Codex Usage</string>
<key>CFBundleDisplayName</key><string>Codex Usage</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.0.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>NSPrincipalClass</key><string>NSApplication</string>
<key>LSUIElement</key><true/>
</dict></plist>
PLIST
codesign --force --sign - "$APP"
if [[ "$MODE" == "--build" ]]; then exit 0; fi
pkill -x CodexUsage >/dev/null 2>&1 || true
open -n "$APP"
if [[ "$MODE" == "--verify" ]]; then sleep 2; pgrep -x CodexUsage; fi
