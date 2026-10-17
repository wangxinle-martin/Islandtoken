#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
export CLANG_MODULE_CACHE_PATH="${TMPDIR:-/tmp}/islandtoken-clang-cache"
python3 script/check_localization.py
if [[ "$(xcode-select -p)" == *CommandLineTools* ]]; then
    mkdir -p .build/portable-tests
    swiftc -parse-as-library Sources/IslandCore/*.swift Tests/IslandCoreTests/*.swift -o .build/portable-tests/IslandCoreTests
    .build/portable-tests/IslandCoreTests
else
    swift test --disable-sandbox --cache-path .build/cache
fi

# Exercise the actual ObservableObject and SwiftUI-style key-path writebacks without launching a GUI.
swift build --disable-sandbox --cache-path "$ROOT_DIR/.build/cache"
BIN_DIR="$(swift build --show-bin-path)"
mkdir -p .build/portable-tests
swiftc -parse-as-library -I "$BIN_DIR/Modules" \
    "$BIN_DIR/IslandCore.build/"*.swift.o \
    Sources/IsLandToken/CodexBarPopup/Compatibility.swift \
    Sources/IsLandToken/CodexBarPopup/MenuCardMetricModel.swift \
    Sources/IsLandToken/App/UserFacingText.swift \
    Sources/IsLandToken/Stores/AppStore.swift \
    Sources/IsLandToken/Services/UsageService.swift \
    Sources/IsLandToken/Services/AgentActivityMonitor.swift \
    Sources/IsLandToken/Services/ProcessRunner.swift \
    Tests/StoreRegression/StoreRegression.swift \
    -o .build/portable-tests/StoreRegression
.build/portable-tests/StoreRegression

swiftc -parse-as-library -I "$BIN_DIR/Modules" \
    "$BIN_DIR/IslandCore.build/"*.swift.o \
    Sources/IsLandToken/CodexBarPopup/Compatibility.swift \
    Sources/IsLandToken/CodexBarPopup/MenuCardMetricModel.swift \
    Sources/IsLandToken/App/UserFacingText.swift \
    Tests/LocalizationRegression/LocalizationRegression.swift \
    -o .build/portable-tests/LocalizationRegression
.build/portable-tests/LocalizationRegression

swiftc -parse-as-library -I "$BIN_DIR/Modules" \
    "$BIN_DIR/IslandCore.build/"*.swift.o \
    Sources/IsLandToken/CodexBarPopup/UsagePace.swift \
    Sources/IsLandToken/CodexBarPopup/PaceAdapter.swift \
    Sources/IsLandToken/CodexBarPopup/UsageMenuCardLayout.swift \
    Sources/IsLandToken/Views/IslandShape.swift \
    Tests/PopupRegression/PopupRegression.swift \
    -o .build/portable-tests/PopupRegression
.build/portable-tests/PopupRegression

swiftc -parse-as-library -I "$BIN_DIR/Modules" \
    "$BIN_DIR/IslandCore.build/"*.swift.o \
    Sources/IsLandToken/Services/AppUpdateInstaller.swift \
    Tests/UpdateInstallerRegression/UpdateInstallerRegression.swift \
    -o .build/portable-tests/UpdateInstallerRegression
UPDATER_TEST_HOME="$(mktemp -d "${TMPDIR:-/tmp}/islandtoken-updater-test.XXXXXX")"
trap 'rm -rf "$UPDATER_TEST_HOME"' EXIT
CFFIXED_USER_HOME="$UPDATER_TEST_HOME" .build/portable-tests/UpdateInstallerRegression
