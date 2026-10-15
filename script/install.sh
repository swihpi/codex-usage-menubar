#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DESTINATION="$HOME/Applications"
LAUNCH=1
while [[ $# -gt 0 ]]; do
  case "$1" in
    --destination) [[ $# -ge 2 ]] || { echo 'Missing destination.' >&2; exit 2; }; DESTINATION="$2"; shift 2 ;;
    --no-launch) LAUNCH=0; shift ;;
    *) echo 'Usage: ./script/install.sh [--destination DIRECTORY] [--no-launch]' >&2; exit 2 ;;
  esac
done
[[ "$(uname -s)" == Darwin ]] || { echo 'ChatGPT/Codex Usage requires macOS.' >&2; exit 1; }
if ! xcode-select -p >/dev/null 2>&1 || ! xcrun --find swift >/dev/null 2>&1; then
  echo 'Apple Command Line Tools are required. Run xcode-select --install, complete the macOS installer, then try again.' >&2
  exit 1
fi
APP="$DESTINATION/Codex Usage.app"
[[ ! -L "$APP" ]] || { echo 'Refusing to overwrite an app symlink.' >&2; exit 1; }
if [[ -e "$APP" ]]; then
  EXISTING_ID=$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$APP/Contents/Info.plist" 2>/dev/null || true)
  [[ "$EXISTING_ID" == com.swi.codexusage ]] || { echo 'Another app already occupies the installation path. Choose a different destination.' >&2; exit 1; }
fi
"$ROOT_DIR/script/build_and_run.sh" --build
mkdir -p "$DESTINATION"
if [[ "$LAUNCH" == 1 ]]; then pkill -x CodexUsage >/dev/null 2>&1 || true; fi
/usr/bin/ditto "$ROOT_DIR/outputs/Codex Usage.app" "$APP"
/usr/bin/codesign --verify --strict "$APP"
echo "Installed: $APP"
if [[ "$LAUNCH" == 1 ]]; then
  /usr/bin/open "$APP"
  echo 'Look in the right side of your menu bar. Launch at login is optional in its click menu.'
else
  echo 'Not launched. Open the app when ready.'
fi
