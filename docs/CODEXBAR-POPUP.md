# CodexBar popup source integration

Upstream: https://github.com/steipete/CodexBar/tree/928166f899471bbdcb72210641cdec91324d0154
License: MIT; original files and license retained in Vendor/CodexBarPopup.

The live popup renders the upstream MetricRow, MetricRowHeader, UsageProgressBar,
UsageMenuCardHeaderView, TokenUsageSectionContent, CodexResetCreditsContent,
and UsageMenuCardLayout. The progress Canvas is unchanged, including the pace
and warning-marker geometry. These are copied components, not screenshot imitations.

Host adaptations:
- Extract rendering components from the monolithic app target; use IslandCore data.
- Replace @Entry with equivalent EnvironmentKey for the available Swift toolchain.
- Localize displayed strings and keep the user's reset-time preference.
- Replace the NSMenu-only refresh/copy hooks with SwiftUI host updates and pasteboard.
- The host places both selected providers side-by-side on one page, measures its natural height, and supplies pin and console actions; there are no tabs or scroll container.
- Remove the former dual-column summary from the expanded island. Compact island styles remain separate.
- Show all actual quota windows, excluding headline-only synthetic Antigravity summaries.
- Reuse upstream UsagePace linear-window calculation and UsagePaceText for pace, ETA and pace-tip markers. Unknown, exhausted, expired, early-cycle and demo windows do not fabricate predictions.
- Keep unknown quotas unknown. No invented exhaustion probability, session-equivalent
  estimates or workday markers: these require CodexBar's history/settings services, which are
  not available through the current collector. Reset-credit inventory is read when supplied
  by CodexBar, with expired credits hidden; it does not redeem credits.

This reuses CodexBar's rendering code, but is not the complete CodexBar application
or its account-scoped historical forecast engine. A full feature-identical port requires those services too.

The refresh decoration is a left-to-right interior sweep, active during quota/cost refresh. The footer refresh icon rotates. Reduce Motion uses a stationary highlight/icon. All decorative overlays ignore hit testing so the footer buttons receive clicks. The host panel spans the target screen so content measurement and hit testing do not retain the old 400-point clipping limit.
