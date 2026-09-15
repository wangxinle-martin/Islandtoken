#!/usr/bin/env bash
# Install the reviewed upstream CLI release; no account data is copied.
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="0.60.1"
SHA256="fe6ba88d297bf1d6b574cd083448f652120126f67220d5a4b6dcc50404e7c4c9"
[[ "$(uname -m)" == arm64 ]] || { echo "This pinned artifact requires Apple Silicon." >&2; exit 1; }
TARGET="$ROOT_DIR/dist/IsLandToken.app"
[[ -d "$TARGET" ]] || { echo "Build the app first." >&2; exit 1; }
STAGING="$(mktemp -d)"
trap 'rm -rf "$STAGING"' EXIT
curl --fail --location --silent --show-error "https://github.com/steipete/CodexBar/releases/download/v$VERSION/CodexBarCLI-v$VERSION-macos-arm64.tar.gz" -o "$STAGING/cli.tar.gz"
ACTUAL="$(shasum -a 256 "$STAGING/cli.tar.gz" | awk '{print $1}')"
[[ "$ACTUAL" == "$SHA256" ]] || { echo "CLI checksum mismatch." >&2; exit 1; }
tar -xzf "$STAGING/cli.tar.gz" -C "$STAGING"
"$STAGING/CodexBarCLI" --version
mkdir -p "$TARGET/Contents/Helpers" "$TARGET/Contents/Resources"
cp "$STAGING/CodexBarCLI" "$TARGET/Contents/Helpers/CodexBarCLI"
# Replace only the collector's resource bundle, avoiding obsolete plugin resources.
rm -rf "$TARGET/Contents/Helpers/CodexBar_CodexBarCore.bundle"
cp -R "$STAGING/CodexBar_CodexBarCore.bundle" "$TARGET/Contents/Helpers/"
printf '%s\n' "$VERSION" > "$TARGET/Contents/Resources/CodexBar-version.txt"
codesign --force --deep --sign - "$TARGET"
codesign --verify --deep --strict "$TARGET"
