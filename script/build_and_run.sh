#!/usr/bin/env bash
set -euo pipefail
MODE="${1:-run}"
APP_NAME="IsLandToken"
BUNDLE_ID="com.wangxinle.IsLandToken"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
APP_VERSION="$(tr -d '[:space:]' < "$ROOT_DIR/VERSION")"
BUILD_NUMBER="$(tr -d '[:space:]' < "$ROOT_DIR/BUILD_NUMBER")"
[[ "$APP_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "Invalid VERSION" >&2; exit 1; }
[[ "$BUILD_NUMBER" =~ ^[1-9][0-9]*$ ]] || { echo "Invalid BUILD_NUMBER" >&2; exit 1; }
case "$MODE" in run|--verify|--verify-popup|--demo|--build-only|--debug|--logs|--telemetry) ;; *) echo "usage: $0 [--build-only|--verify|--demo|--debug|--logs|--telemetry]" >&2; exit 2;; esac
if [[ "$MODE" != "--build-only" ]]; then pkill -x "$APP_NAME" >/dev/null 2>&1 || true; fi
export CLANG_MODULE_CACHE_PATH="${TMPDIR:-/tmp}/islandtoken-clang-cache"
swift build --disable-sandbox --cache-path "$ROOT_DIR/.build/cache"
BIN_DIR="$(swift build --show-bin-path)"
APP_BUNDLE="$ROOT_DIR/dist/$APP_NAME.app"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"
cp "$BIN_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
if [[ -d "$BIN_DIR/IsLandToken_IsLandToken.bundle" ]]; then
    rm -rf "$APP_BUNDLE/IsLandToken_IsLandToken.bundle"
    rm -rf "$APP_BUNDLE/Contents/Resources/IsLandToken_IsLandToken.bundle"
    cp -R "$BIN_DIR/IsLandToken_IsLandToken.bundle" "$APP_BUNDLE/Contents/Resources/"
fi
cp "$ROOT_DIR/Assets/AppIcon/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
if [[ -d "$BIN_DIR/Vortex_Vortex.bundle" ]]; then
    cp -R "$BIN_DIR/Vortex_Vortex.bundle" "$APP_BUNDLE/Contents/Resources/"
fi
# Replace, rather than merge, legal notices so deleted upstream notices cannot
# survive in a previously staged app bundle.
rm -rf "$APP_BUNDLE/Contents/Resources/Licenses"
cp -R "$ROOT_DIR/Licenses" "$APP_BUNDLE/Contents/Resources/"
cat > "$APP_BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>$APP_NAME</string>
<key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundleIconName</key><string>AppIcon</string>
<key>CFBundleIcons</key>
<dict>
<key>CFBundlePrimaryIcon</key>
<dict>
<key>CFBundleIconFiles</key>
<array><string>AppIcon</string></array>
<key>CFBundleIconName</key><string>AppIcon</string>
</dict>
</dict>
<key>CFBundleName</key><string>$APP_NAME</string>
<key>CFBundleDisplayName</key><string>$APP_NAME</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>$APP_VERSION</string>
<key>CFBundleVersion</key><string>$BUILD_NUMBER</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>LSUIElement</key><false/>
<key>NSPrincipalClass</key><string>NSApplication</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --deep --sign - "$APP_BUNDLE" >/dev/null
case "$MODE" in
    --build-only) echo "Built: $APP_BUNDLE" ;;
    --demo) /usr/bin/open -n "$APP_BUNDLE" --args --demo ;;
    --debug) lldb -- "$APP_BUNDLE/Contents/MacOS/$APP_NAME" ;;
    --logs) /usr/bin/open -n "$APP_BUNDLE"; /usr/bin/log stream --info --style compact --predicate 'process == "IsLandToken"' ;;
    --telemetry) /usr/bin/open -n "$APP_BUNDLE"; /usr/bin/log stream --info --style compact --predicate 'subsystem == "com.wangxinle.IsLandToken"' ;;
    --verify|--verify-popup)
        VERIFY_DIR="$(mktemp -d "${TMPDIR:-/tmp}/islandtoken-verify.XXXXXX")"
        VERIFY_FILE="$VERIFY_DIR/ready"
        /usr/bin/open -n "$APP_BUNDLE" --args --verify-launch "$VERIFY_FILE" "$MODE"
        for attempt in {1..20}; do
            if [[ -f "$VERIFY_FILE" ]]; then
                pgrep -x "$APP_NAME" >/dev/null
                echo "IsLandToken dashboard is visible, ready for first-mouse events, and its main run loop is responsive."
                exit 0
            fi
            sleep 1
        done
        echo "Launch verification failed: no responsive main-loop acknowledgement within 20 seconds." >&2
        exit 1
        ;;
    run) /usr/bin/open -n "$APP_BUNDLE" ;;
esac
