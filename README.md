# IsLandToken

> **Local-first AI quota monitor for the MacBook notch.**

![Version](https://img.shields.io/badge/version-v0.4.4-0E7CBA)
![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-555555?logo=apple&logoColor=white)
![Apple Silicon](https://img.shields.io/badge/architecture-Apple%20Silicon-555555?logo=apple&logoColor=white)
![Built with](https://img.shields.io/badge/built%20with-Swift%206-F05138?logo=swift&logoColor=white)
![Swift Package Manager](https://img.shields.io/badge/package%20manager-SwiftPM-F05138?logo=swift&logoColor=white)
![Tests](https://img.shields.io/badge/tests-XCTest%20%2B%20regressions-2EA44F)
![Release automation](https://img.shields.io/badge/release-GitHub%20Actions-2088FF?logo=githubactions&logoColor=white)
![Local first](https://img.shields.io/badge/data%20collection-local--first-30B7A3)
![Privacy](https://img.shields.io/badge/privacy-no%20telemetry-30B7A3)
![Security](https://img.shields.io/badge/credentials-local%20sign--in%20state-30B7A3)
![Providers](https://img.shields.io/badge/providers-12%20adapters-7B61FF)

[English](README.md) · [中文](README-zh.md)

![IsLandToken showing Codex and Antigravity quota summaries beside the MacBook notch](docs/images/island-preview.png)

IsLandToken keeps the AI quota windows you care about at the top of your Mac screen: beside the MacBook notch, in the menu bar, or in an expanded detail panel. It is for people who work across Codex, Claude, Antigravity, Gemini, Cursor, Copilot, and other AI tools and need a quick, private view of remaining allowance and reset time.

## Why IsLandToken?

- **Local-first by design** — Codex and Claude are read from existing local sign-in state first. When direct local collection is unavailable, IsLandToken can fall back to a locally installed or bundled CodexBar collector.
- **Made for the notch** — independently configure the left and right sides, choose a quota window, and select a compact visual style that stays visible without stealing screen space.
- **Honest data** — subscription quota, token usage, estimated cost, and available credits are different things. The app presents them separately and shows `—` when a source does not provide a value.
- **Private by default** — no telemetry, no token persistence, no account-email storage, and no raw provider-response archive.
- **Useful beyond one provider** — compare two services or two billing windows from the same service.

## What you can see

| Area | Highlights |
| --- | --- |
| Notch display | Independent left/right provider and quota-window selection; numeric, ring, bar, segmented, trend, and 5-hour / weekly dual-period styles |
| Providers | Codex, Claude, Antigravity, Gemini, Cursor, GitHub Copilot, Windsurf, Kiro, OpenRouter, DeepSeek, Ollama, and OpenCode adapters |
| Detail panel | Remaining allowance, reset time, local sampling trend, recent samples, and available cost/token context when a source provides it |
| Interaction | Click or hover to expand, pin the panel, use a contextual menu, or retain the menu-bar entry as a compact fallback |
| History | Local 30-day readings, CSV export, daily usage chart, and cost/token summaries when local records are available |
| Reliability | Manual, scheduled, wake-up, and activity-aware refreshes; timeouts, stale-state labels, and last-known-good cache retention |

## Data-source priority

1. **Direct local collection** for Codex and Claude, using existing local credentials only.
2. **Local CodexBar fallback** if direct collection fails or a provider needs a CodexBar adapter.
3. A provider is shown only when its adapter can return real data. IsLandToken does not invent model windows, quota percentages, or cost figures.

> Enabling an adapter means the app understands that source. It does not mean every service is signed in or exposes every field on your Mac.

## Privacy and local data

- Settings use the `com.wangxinle.IsLandToken` `UserDefaults` domain.
- Local quota readings and history live in `~/Library/Application Support/IsLandToken/readings.json` and `history.json`.
- The app does not save access tokens, account emails, raw API responses, or conversation content.
- Local collection does not follow redirects and uses a temporary `URLSession`. The optional CodexBar collector retains its own authentication, caching, and network behavior.

## Build

macOS 14+ and Swift 6.0+ Command Line Tools are sufficient. Full Xcode enables the XCTest path.

```sh
./script/build_and_run.sh              # build and launch
./script/build_and_run.sh --build-only # create dist/IsLandToken.app
./script/build_and_run.sh --verify     # launch and check responsiveness
./script/build_and_run.sh --demo       # launch clearly labelled demo data
./script/test.sh                       # XCTest when available, then regressions
```

To bundle an already-installed CodexBar collector into the app package:

```sh
./script/bundle_codexbar.sh /Applications/CodexBar.app
```

Only `Contents/Helpers` is copied; user account configuration is not included. The script applies local ad-hoc signing after bundling. Apple Silicon is the default build architecture; Intel Macs can build from source on their own machine.

## Scope and limitations

Quota percentages are not token totals. A subscription source commonly reports a percentage remaining in a period, while token totals, estimated USD cost, and credits come from separate records. Trends reflect successful samples collected while IsLandToken has been running. Login items, notification permission, multiple displays, and lock-screen behavior should be verified on the target Mac.

The app is currently ad-hoc signed; it is not Developer ID signed or notarized.

## Acknowledgements

The popup layout and interaction patterns incorporate selected, attributed reusable components from [CodexBar](https://github.com/steipete/CodexBar). IsLandToken keeps its own local-first collection flow and SwiftPM macOS application architecture; it does not claim to include all CodexBar features.

Third-party notices are available in [Licenses](Licenses). Architecture, validation notes, and the CodexBar synchronization boundary are documented in [docs](docs).

Before submitting a change, run:

```sh
./script/test.sh
git diff --check
```
