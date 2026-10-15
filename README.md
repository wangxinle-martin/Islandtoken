# IsLandToken

> **Local-first AI quota monitor for the MacBook notch.**
>
> **面向 MacBook 刘海的本地优先 AI 额度监控工具。**

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-000000?logo=apple&logoColor=white)
![Swift](https://img.shields.io/badge/Swift-6.0%2B-F05138?logo=swift&logoColor=white)
![Local first](https://img.shields.io/badge/data%20collection-local--first-30B7A3)

[English](#english) · [中文](#中文) · [Features / 功能](#features--功能) · [Build / 构建](#build--构建)

![IsLandToken showing Codex and Antigravity quota summaries beside the MacBook notch](docs/images/island-preview.png)

---

## English

IsLandToken keeps the AI quota windows you care about at the top of your Mac screen: beside the MacBook notch, in the menu bar, or in an expanded detail panel. It is for people who work across Codex, Claude, Antigravity, Gemini, Cursor, Copilot, and other AI tools and need a quick, private view of remaining allowance and reset time.

### Why IsLandToken?

- **Local-first by design** — Codex and Claude are read from existing local sign-in state first. When direct local collection is unavailable, IsLandToken can fall back to a locally installed or bundled CodexBar collector.
- **Made for the notch** — independently configure the left and right sides, choose a quota window, and select a compact visual style that stays visible without stealing screen space.
- **Honest data** — subscription quota, token usage, estimated cost, and available credits are different things. The app presents them separately and shows `—` when a source does not provide a value.
- **Private by default** — no telemetry, no token persistence, no account-email storage, and no raw provider-response archive.
- **Useful beyond one provider** — compare two services or two billing windows from the same service.

### What you can see

| Area | Highlights |
| --- | --- |
| Notch display | Independent left/right provider and quota-window selection; numeric, ring, bar, segmented, trend, and 5-hour / weekly dual-period styles |
| Providers | Codex, Claude, Antigravity, Gemini, Cursor, GitHub Copilot, Windsurf, Kiro, OpenRouter, DeepSeek, Ollama, and OpenCode adapters |
| Detail panel | Remaining allowance, reset time, local sampling trend, recent samples, and available cost/token context when a source provides it |
| Interaction | Click or hover to expand, pin the panel, use a contextual menu, or retain the menu-bar entry as a compact fallback |
| History | Local 30-day readings, CSV export, daily usage chart, and cost/token summaries when local records are available |
| Reliability | Manual, scheduled, wake-up, and activity-aware refreshes; timeouts, stale-state labels, and last-known-good cache retention |

### Data-source priority

1. **Direct local collection** for Codex and Claude, using existing local credentials only.
2. **Local CodexBar fallback** if direct collection fails or a provider needs a CodexBar adapter.
3. A provider is shown only when its adapter can return real data. IsLandToken does not invent model windows, quota percentages, or cost figures.

> Enabling an adapter means the app understands that source. It does not mean every service is signed in or exposes every field on your Mac.

### Privacy and local data

- Settings use the `com.wangxinle.IsLandToken` `UserDefaults` domain.
- Local quota readings and history live in `~/Library/Application Support/IsLandToken/readings.json` and `history.json`.
- The app does not save access tokens, account emails, raw API responses, or conversation content.
- Local collection does not follow redirects and uses a temporary `URLSession`. The optional CodexBar collector retains its own authentication, caching, and network behavior.

### Build

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

### Scope and limitations

Quota percentages are not token totals. A subscription source commonly reports a percentage remaining in a period, while token totals, estimated USD cost, and credits come from separate records. Trends reflect successful samples collected while IsLandToken has been running. Login items, notification permission, multiple displays, and lock-screen behavior should be verified on the target Mac.

The app is currently ad-hoc signed; it is not Developer ID signed or notarized.

---

## 中文

IsLandToken 将你关心的 AI 额度窗口放在 Mac 屏幕顶部：可以显示在 MacBook 刘海两侧、菜单栏，或展开为详情面板。它适合同时使用 Codex、Claude、Antigravity、Gemini、Cursor、Copilot 等 AI 工具的人，快速查看剩余额度和重置时间，同时尽量让数据留在本机。

### 为什么使用 IsLandToken？

- **本地优先采集**：Codex 和 Claude 优先读取本机已有登录状态；本地直连不可用时，再回退到本机已安装或随应用捆绑的 CodexBar 采集器。
- **为 Mac 刘海而设计**：左右两侧可独立选择平台、额度窗口和展示样式；信息始终可见，却不会占用工作区。
- **如实展示数据**：订阅额度、已消耗 Token、预估费用和可用积分是不同指标；应用会分别展示，数据源未提供时显示 `—`。
- **默认保护隐私**：没有遥测，不保存访问令牌、账号邮箱或原始服务端响应。
- **可同时比较多个服务**：左右两侧分别配置，既能对比两个平台，也能查看同一平台的不同额度周期。

### 功能

| 模块 | 说明 |
| --- | --- |
| 刘海展示 | 左右独立配置平台和额度窗口；支持数字、圆环、进度条、分段、趋势图，以及 5 小时 / 每周双周期样式 |
| 平台适配 | Codex、Claude、Antigravity、Gemini、Cursor、GitHub Copilot、Windsurf、Kiro、OpenRouter、DeepSeek、Ollama、OpenCode |
| 展开详情 | 剩余额度、重置时间、本地采样趋势、最近样本；数据源提供时显示 Token/费用相关信息 |
| 常驻交互 | 点击或悬停展开、图钉固定、右键快捷菜单，以及作为兜底入口的菜单栏图标 |
| 历史与费用 | 本地保留 30 天采样、导出 CSV、每日柱图；本地记录存在时展示 Token 和费用汇总 |
| 刷新与异常 | 手动、定时、唤醒和活动感知刷新；超时保护、过期标记和最近一次成功缓存 |

### 数据源优先级

1. **本机直连采集**：Codex、Claude 仅读取本机已有凭据。
2. **本机 CodexBar 回退**：直连失败，或某个平台需通过 CodexBar 适配器获取时使用。
3. **只展示真实返回数据**：不会虚构模型窗口、额度百分比或费用数值。

> 启用某个入口只表示应用支持该适配器，不代表这台 Mac 已登录该平台，也不代表平台会提供全部字段。

### 隐私与本地数据

- 设置保存在 `UserDefaults` 域 `com.wangxinle.IsLandToken`。
- 额度缓存和历史位于 `~/Library/Application Support/IsLandToken/readings.json` 与 `history.json`。
- 应用不会保存访问令牌、账号邮箱、原始网络响应或会话内容。
- 本地直连请求不跟随重定向，使用临时 `URLSession`。可选 CodexBar 采集器沿用其自身的认证、缓存和网络行为。

### 构建

应用面向 macOS 14+；使用 Swift 6.0+ Command Line Tools 即可构建，安装完整 Xcode 后会启用 XCTest 路径。

```sh
./script/build_and_run.sh              # 构建并启动
./script/build_and_run.sh --build-only # 生成 dist/IsLandToken.app
./script/build_and_run.sh --verify     # 启动并检查响应
./script/build_and_run.sh --demo       # 启动明确标注的演示数据
./script/test.sh                       # 有 Xcode 时运行 XCTest，随后运行回归检查
```

若需将已安装的 CodexBar 采集组件装入交付包：

```sh
./script/bundle_codexbar.sh /Applications/CodexBar.app
```

脚本只复制 `Contents/Helpers`，不会复制用户账户配置；捆绑完成后会对本地包进行 ad-hoc 签名。默认按当前机器架构构建，Apple Silicon 为常见目标；Intel Mac 可在本机从源码构建。

### 边界说明

额度百分比不是 Token 总量。订阅类服务通常只报告某个周期内的剩余比例；Token、美元费用估算和积分来自不同记录。趋势仅代表 IsLandToken 运行期间采集成功的本地样本。登录启动、通知授权、多显示器和锁屏行为请在目标 Mac 上验证。

当前产物为 ad-hoc 签名，尚未进行 Apple Developer ID 签名或公证。

---

## Features / 功能

The popup layout and interaction patterns incorporate selected, attributed reusable components from [CodexBar](https://github.com/steipete/CodexBar). IsLandToken keeps its own local-first collection flow and SwiftPM macOS application architecture; it does not claim to include all CodexBar features.

弹窗布局和交互中复用了 [CodexBar](https://github.com/steipete/CodexBar) 的部分具名可复用组件。IsLandToken 保持独立的本地优先采集流程和 SwiftPM macOS 应用架构，并不包含 CodexBar 的全部功能。

Third-party notices are available in [Licenses](Licenses). Architecture, validation notes, and the CodexBar synchronization boundary are documented in [docs](docs).

第三方声明见 [Licenses](Licenses)；架构、验证记录与 CodexBar 同步边界见 [docs](docs)。

## Build / 构建

See the [English build instructions](#build) or [中文构建说明](#构建). Before submitting a change, run:

```sh
./script/test.sh
git diff --check
```
