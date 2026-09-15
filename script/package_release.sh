#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="$(tr -d '[:space:]' < "$ROOT_DIR/VERSION")"
APP="$ROOT_DIR/dist/IsLandToken.app"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || exit 1
[[ "$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$APP/Contents/Info.plist")" == "$VERSION" ]] || { echo 'Rebuild app for current VERSION'; exit 1; }
codesign --verify --deep --strict "$APP"
STAGING="$(mktemp -d)"
trap 'rm -rf "$STAGING"' EXIT
ditto "$APP" "$STAGING/IsLandToken.app"
ln -s /Applications "$STAGING/Applications"
DMG="$ROOT_DIR/dist/IsLandToken-$VERSION-$(uname -m).dmg"
hdiutil create -volname "IsLandToken $VERSION" -srcfolder "$STAGING" -format UDZO -ov "$DMG"
(cd "$ROOT_DIR/dist" && shasum -a 256 "$(basename "$DMG")" > "$(basename "$DMG").sha256")
