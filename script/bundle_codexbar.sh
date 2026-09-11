#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_APP="${1:-/Applications/CodexBar.app}"
TARGET_APP="$ROOT_DIR/dist/IsLandToken.app"
[[ -d "$TARGET_APP" ]] || { echo "Run script/build_and_run.sh --build-only first." >&2; exit 1; }
[[ -x "$SOURCE_APP/Contents/Helpers/CodexBarCLI" ]] || { echo "CodexBar CLI missing in supplied app." >&2; exit 1; }
# Keep the original helper and dependent resources together. Never copy user configuration or credentials.
mkdir -p "$TARGET_APP/Contents/Helpers"
cp -R "$SOURCE_APP/Contents/Helpers/" "$TARGET_APP/Contents/Helpers/"
/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$SOURCE_APP/Contents/Info.plist" > "$TARGET_APP/Contents/Resources/CodexBar-version.txt"
codesign --force --deep --sign - "$TARGET_APP" >/dev/null
echo "Bundled CodexBar helper. User accounts still require platform login."
