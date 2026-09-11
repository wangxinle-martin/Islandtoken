# IsLandToken

原生 macOS 灵动岛额度助手。把 Codex、Claude、Antigravity 等平台的剩余额度放在屏幕顶端，左右两侧分别选择平台、模型额度窗口和显示样式。

实现参考 [CodexIsland](https://github.com/ericjypark/codex-island) 的刘海屏交互，复用 [CodexBar](https://github.com/steipete/CodexBar) 的多平台采集能力。SwiftUI + AppKit + Swift Charts，macOS 14+。

## 使用

打开 `dist/IsLandToken.app`。关闭控制台后灵动岛继续运行，菜单栏胶囊图标可重新打开控制台或退出。也可将 App 拖入「应用程序」。本机交付版本包含 CodexBar 采集程序，不需要额外安装 CodexBar；需要使用平台原本的登录状态。

1. 在「数据源」启用所需平台。在 Codex、Claude、Antigravity 等原应用中完成登录；其他需要 API Key/Cookie 的平台可先用 CodexBar 完成配置。
2. 在「灵动岛」分别选择左右两侧的平台，以及具体额度窗口。Antigravity 可选择 Gemini 和 Claude/GPT 的独立窗口；同一平台也能同时显示不同额度。
3. 每侧可选圆环、进度条、分段、数字、趋势图及「5h / 周」。双周期按 5 小时 / 一周显示，例如 `25/76%`，缺失周期显示 `—`；Antigravity 按同一模型组配对。可独立设置品牌色/自定义预设色、图标与名称。
4. 灵动岛顶部使用向外延伸的圆角，与屏幕刘海衔接。可选择在刘海左侧、两侧或右侧显示。可独立选择点击展开、悬停展开、菜单栏图标，三项至少开启一项；最后一个入口不能关闭。隐藏灵动岛时自动保留菜单栏图标。展开后查看额度、Token/费用、趋势三页；移开自动收起，图钉可保持展开。右键打开快捷菜单。
5. 「历史与费用」读取 Token 消耗和估算费用，导出本机额度采样 CSV。「通用设置」配置刷新、告警、登录启动和明确标注的演示模式。

**额度不是 Token 数量。** 订阅平台通常只报告周期额度百分比，IsLandToken 显示 `100 − usedPercent`。未知值显示 `—`。已消耗 Token、美元估算费用、可用积分分别展示，不把订阅额度换算成不存在的 Token 总数。

## 功能

| 功能 | 实现 |
| --- | --- |
| 平台入口 | Codex、Claude、Antigravity、Gemini、Cursor、GitHub Copilot、Windsurf、Kiro、OpenRouter、DeepSeek、Ollama、OpenCode |
| 左右独立配置 | 平台、额度/模型窗口、六种样式（含 5h / 周）、六种配色选项、图标和名称 |
| 刘海和显示器 | 自动优先刘海屏；指定显示器；无刘海屏降级；宽度和顶部偏移；插拔回退 |
| 常驻交互 | 非激活面板、悬停、点击展开、离开收起、固定、面板外鼠标穿透、全屏空间辅助显示 |
| 额度展示 | 剩余/已用切换、重置时间、额外模型窗口、可用积分（平台有返回时） |
| 历史与费用 | 真实采样趋势、本地 30 天保留、CSV、今日及近 30 天 Token/费用、每日柱图 |
| 刷新与异常 | 5/15/30 分钟、手动刷新、唤醒刷新、并发限制、超时、保留成功缓存、过期标记 |
| 告警 | 自定义橙/红阈值、可选系统通知、告警级别去重；演示和过期值不通知 |
| 系统集成 | 菜单栏、控制台、通用设置窗口、登录启动、锁屏隐藏、减少动态效果跟随系统 |

启用入口表示适配器支持，不表示这台机器的所有平台都已登录。实际能力取决于 CodexBar 版本、平台套餐和提供的字段。

## 构建与测试

不需要第三方 Swift 包，也不必安装完整 Xcode；Command Line Tools 和 Swift 6.0+ 即可构建。

```sh
./script/build_and_run.sh              # 构建并启动
./script/build_and_run.sh --build-only # 仅生成 dist/IsLandToken.app
./script/build_and_run.sh --verify     # 启动并检查进程
./script/build_and_run.sh --demo       # 启动明确标注的演示模式
./script/test.sh                       # Xcode 使用 XCTest，CLT 使用相同测试体的便携入口
```

已配置 `.codex/environments/environment.toml`，Codex 的 Run 按钮调用同一构建脚本。可用 `--debug`、`--logs` 进行调试。

如需将已安装的 CodexBar 采集组件装入交付包：

```sh
./script/bundle_codexbar.sh /Applications/CodexBar.app
```

只复制 `Contents/Helpers`，不会复制用户账号配置。捆绑后会对交付包做本地 ad-hoc 签名。`Contents/Resources/CodexBar-version.txt` 保存采集组件来源版本；CLI 的 `--version` 可能读取宿主 App 的版本号。

默认构建当前机器架构；本次产物是 Apple Silicon arm64。Intel Mac 可从源码在本机构建。应用本身面向 macOS 14+，捆绑的上游组件还需满足其自身系统要求。

## 数据源规则

- 自动模式：优先自定义路径、内置 CodexBarCLI、已安装 CodexBar、Homebrew CLI；不存在时 Codex/Claude 使用直接 OAuth 读取。
- 直接读取模式：Codex/Claude 从本地已有凭据只读获取令牌，请求其用量端点。其他平台仍经 CodexBar。
- CodexBar 模式下，Codex/Claude 使用 `--source oauth`，其他平台使用其自动探测。多账号选择沿用 CodexBar 当前默认配置；本版没有独立账号选择 UI。
- Antigravity 的额外模型窗口按平台实际返回列表显示，不虚构模型，也不在选定窗口缺失时自动切换成另一额度。
- 费用按需读取，重复点击至少间隔 60 秒；不在每次额度刷新时重扫所有本地日志。
- 未安装 CodexBar 时，直接读取支持 `CODEX_HOME`、`CLAUDE_CONFIG_DIR` 和 `CLAUDE_CODE_OAUTH_TOKEN`；Finder 启动的 App 不一定继承终端变量。Claude 钥匙串读取不主动弹出权限请求。

## 本地数据

- 设置：`UserDefaults` 域 `com.wangxinle.IsLandToken`。
- 额度缓存与趋势：`~/Library/Application Support/IsLandToken/readings.json` 和 `history.json`。
- 本 App 不保存访问令牌、账号邮箱、原始网络响应或会话正文，不设置遥测。
- 直接读取请求不跟随重定向；请求使用临时 URLSession。CodexBar 组件沿用它自己的认证、缓存和平台网络行为。
- 演示模式不会写入真实缓存，退出后恢复实时数据。清理历史可退出 App 后删除上述两个缓存文件。

## 验证与边界

测试与人工检查见 [docs/VALIDATION.md](docs/VALIDATION.md)，设计与引用版本见 [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)。

本版没有复制两项目全部功能：未集成 Sparkle 自动升级、交互式账户切换、主动兑换重置信用、全年活动热力图，以及所有 CodexBar 插件的设置面板。趋势只代表本 App 运行期间成功采样，费用只代表可读取的记录。登录启动、通知授权、多显示器/锁屏行为有实现，仍需在目标机器实际验证。

当前交付是本地开发版，已 ad-hoc 签名，未做 Apple Developer ID 签名或公证。

## 开源致谢

- CodexBar — Copyright (c) 2026 Peter Steinberger，MIT；复用采集进程、数据格式和平台 SVG 图标。
- CodexIsland — Copyright (c) 2026 Eric Park，MIT；参考刘海几何、鼠标穿透、额度语义和只读凭据处理。
- 完整声明保留在 [Licenses](Licenses)，并复制到 App 的 Resources 中。

灵动岛默认仅显示额度数字（例如 `25/76`）；鼠标移入时弹动显示 `%` 和已配置的图标、名称及图形，移出后恢复数字。此效果独立于悬停详情开关，并尊重系统“减少动态效果”。

收起时每侧宽度为 48pt（可容纳 `100`），双周期为 80pt（可容纳 `100/100`）。悬停时整个岛以弹簧动画变宽、增高，恢复配置的侧宽及图标、百分号。

刷新间隔支持 1、5、15、30 分钟及自适应。自适应每 15 秒检查已配置平台的本机进程 CPU 活动，最近 2 分钟有活动时按 1 分钟刷新，否则按 5 分钟刷新。仅观察进程名与 CPU 时间，不读取对话；进程活动是推断信号，不代表精确的模型请求事件，无法识别的平台按空闲频率刷新。
