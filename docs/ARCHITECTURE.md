# 架构与参考来源

## 结构

```text
Sources/IslandCore/
  Models.swift                 平台、额度、配置、采样与纯几何规则
  UsageParser.swift            CodexBar / Codex / Claude 格式归一化
Sources/IsLandToken/
  App/                        应用与菜单栏入口、控制台生命周期
  Services/                   有界子进程、CLI 路径解析、只读 OAuth
  Stores/                     设置、刷新协调、缓存、趋势、通知
  Window/                     非激活 NSPanel、显示器与鼠标穿透
  Views/                      SwiftUI 控制台、配置、图表、灵动岛
  Resources/                  CodexBar 平台图标
Tests/IslandCoreTests/          可同时通过 XCTest/CLT 运行的测试
script/                       构建、启动、测试、采集组件打包
```

SwiftUI 负责界面与状态，AppKit 仅负责窗口生命周期、显示器几何、锁屏与鼠标事件。共享 AppStore 保存一个事实源，避免控制台、菜单栏、左右两侧各自采集。

## 采集与语义

`Provider → UsageService → CodexBarCLI / 直接 OAuth → UsageParser → UsageReading → AppStore → Views`。

主/次/额外额度窗口保留实际 ID。周期名称来自 `windowMinutes`，不会把只有周额度的 `primary` 硬编码成五小时。占位窗口和 `usageKnown=false` 按未知显示。解析器保留原始 usedPercent，展示层才钳制到 0–100；缺失字段不补零。

外部进程不用 shell 拼接，stdout 放在权限受限临时目录，stderr 不进入产品日志；55 秒用量超时、90 秒费用超时、8 MB 输出限制。一个刷新批次最多并发三个平台。任何失败保留上次成功值与时间。每个周期只记录新时间戳的真实读数；最多 30 天 / 60000 个样本。

直接读取 Codex/Claude 使用已有凭据，请求只进入对应平台固定 HTTPS 端点。令牌只在内存中与 Authorization 头中出现，不刷新、不改写凭据。直接读取不跟随重定向。多平台复杂认证交给独立的 CodexBar 进程管理。

## 源码依据

调研时间：2026-09-18。

| 上游 | 本次读取 commit | 参考内容 |
| --- | --- | --- |
| `steipete/CodexBar` | `2ac2323629ce0e3b3759707013aeb4a6c77161c1` (`v0.60.5`) | CLI 参数/JSON 格式、成本历史容错、Antigravity 回退、企业/积分型额度与 SVG 图标 |
| `ericjypark/codex-island` | `810b8ac0c45e1fd191c3b37e6dc37f943b71cba1` | 刘海窗口、Claude 账号切换、历史保留、环形额度对齐、面板自适应与功能边界 |

当前交付包实际采集引擎为经过固定 SHA-256 校验的 **CodexBar CLI 0.60.5**，不是对最新上游源码的全量重新编译。CLI 作为独立 helper 被捆绑；主工程保持零外部 Swift 包依赖，降低两项目 Swift 工具链与 UI 模块耦合。

CodexIsland 的 Claude 凭据监听用于其内存令牌缓存。本项目不缓存 Claude
令牌，每次直连刷新都只读重取凭据，因此账号切换会在下一个刷新周期生效，
无需复制持续钥匙串监听。失败读数保留、环形固定框和内容驱动弹窗宽度也已由
本项目现有实现覆盖。

## 有意保留的边界

1. 左右配置的“模型”指平台实际提供的独立额度窗口；账号共享额度不能推导每个底层模型的可用 Token。
2. 不访问聊天内容，不将费用记录解释为真实扣款账单。
3. 主工程可独立构建；任意上游平台 API 变化都可能要求更新 CodexBar helper。
4. 不执行重置额度、购买积分、切换原平台账号或登录操作。
5. 不修改用户已有父仓库的 Git 状态、不创建嵌套仓库、不自动提交或推送。
