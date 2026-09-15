# CodexBar synchronization

Reviewed upstream HEAD: `86a47f80a71e74c59dd2d4dd14de397348d36546`.
Source: https://github.com/steipete/CodexBar/tree/86a47f80a71e74c59dd2d4dd14de397348d36546

- CLI source selection now uses `auto`, letting CodexBar select available authentication/fallback strategies instead of forcing OAuth.
- Direct Codex parsing follows `CodexAdditionalRateLimitMapper`: Spark session/weekly lanes retain stable IDs, other named limits prefer primary and fall back to secondary, duplicate IDs are omitted and nonpositive reset timestamps remain unknown.
- `RateWindow.nextRegenPercent` survives parsing/cache and is displayed as the percentage after the next recovery. Unknown/synthetic usage is still not rendered as real quota.
- Compared vendored UsageProgressBar and UsagePace with upstream: unchanged. No replacement needed.
- Existing custom island layout, multiple-provider popup and reset display preferences are retained.

The bundled collector is the latest GitHub stable release observed during this update, **0.60.1**, not a build of main. Run `script/update_codexbar_cli.sh` after building a clean app to install the SHA-256-pinned Apple Silicon CLI and its resource bundle. The normal build preserves installed helpers.

Validation: parser fixtures, cache round trip, existing store/popup regression suites, app build, CLI version and artifact checksum. Live provider account access is not part of this validation. This is a targeted compatibility update, not a port of all upstream billing/account-management features.
