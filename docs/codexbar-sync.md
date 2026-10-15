# CodexBar synchronization

Reviewed upstream snapshot: `a8eb7b8c4cd4ed00f8483831a78a9f4368145c79` (2026-10-15).
Source: https://github.com/steipete/CodexBar/tree/a8eb7b8c4cd4ed00f8483831a78a9f4368145c79

- CLI source selection now uses `auto`, letting CodexBar select available authentication/fallback strategies instead of forcing OAuth.
- Direct Codex parsing follows `CodexAdditionalRateLimitMapper`: Spark session/weekly lanes retain stable IDs, other named limits prefer primary and fall back to secondary, duplicate IDs are omitted and nonpositive reset timestamps remain unknown.
- `RateWindow.nextRegenPercent` survives parsing/cache and is displayed as the percentage after the next recovery. Unknown/synthetic usage is still not rendered as real quota.
- Compared the reused popup components with upstream: UsageProgressBar remains equivalent to
  the current Canvas renderer; MetricRow now carries upstream's optional help text and
  MenuHighlightStyle includes its current accent semantic. New upstream throughput, account,
  credit and billing sections are not copied because they require CodexBarCore services that
  IsLandToken intentionally does not embed.
- Existing custom island layout, multiple-provider popup and reset display preferences are retained.
- CodexBar 0.60.2-0.60.5 adds resilient Codex/Claude cost history, last-known usage
  retention during transient failures, current Antigravity structured-report fallback,
  Cursor Enterprise budgets, Kimi ratio-pool quotas, Copilot seat credits and OpenCode
  Monthly selection. IsLandToken receives these collector fixes through the pinned CLI;
  it does not duplicate the upstream account, billing or settings UI.

The bundled collector is the latest GitHub stable release observed on 2026-09-18,
**0.60.5**, not a build of main. Run `script/update_codexbar_cli.sh` after building a
clean app to install the SHA-256-pinned Apple Silicon CLI and its resource bundle.
The normal build preserves installed helpers.

Validation: parser fixtures, cache round trip, existing store/popup regression suites, app build, CLI version and artifact checksum. Live provider account access is not part of this validation. This is a targeted compatibility update, not a port of all upstream billing/account-management features.
