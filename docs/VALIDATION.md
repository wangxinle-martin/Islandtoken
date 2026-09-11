# 验证记录

日期：2026-09-07。环境：Apple Silicon，Swift 6.1.2，macOS Command Line Tools。

## 已完成

- `script/build_and_run.sh --build-only`：SwiftUI/AppKit 主应用编译、资源装配、ad-hoc 签名通过。
- `script/build_and_run.sh --verify`：真实 `.app` 启动并通过进程检查。
- `script/test.sh`：15 项核心测试全部通过（含双周期配对、入口保护、旧设置迁移和左/两侧/右侧位置持久化）。当前机器没有 XCTest，使用便携执行器运行同一套测试体。
- `codesign --verify --deep --strict dist/IsLandToken.app`：含 CodexBar helper 的完整包结构通过检查。
- `plutil -lint`：Info.plist 通过。
- 真机 UI 画面检查：用量总览、原生侧栏、实时灵动岛预览、紧凑灵动岛、展开额度面板、通用配置页、左右独立平台/样式设置页。实际观察到左侧 Codex、右侧 Antigravity 与数字样式的配置结果。
- 真实用量：Codex OAuth、Antigravity 本机采集成功。Antigravity 提供 Gemini / Claude-GPT 独立额外额度窗口。
- 真实费用：捆绑 CodexBarCLI 成功返回 Codex 今日 Token、今日估算费用及 25 个日记录。
- Claude 未取得可用登录数据；App 正确显示连接失败，不显示伪造额度。
- 原始用量响应只保留在临时目录中作验证，没有加入源码、文档或交付包。

## 测试场景

1. 0.5% 已用应显示 99.5% 剩余。
2. 合成占位窗口和 usageKnown=false 不能显示为真实 0% 或 100%。
3. 只有 primary 周额度的 Codex 套餐按 7 天标注。
4. Claude null 窗口不生成虚假额度。
5. 错误/畸形 JSON 不变成零用量，错误消息不暴露原始敏感串。
6. usedPercent 缺失保持未知。
7. 超限数值仅在展示时钳制，非有限数值保持未知。
8. 左右配置序列化往返和安全范围修正。
9. 刘海、缩放和自动隐藏菜单栏几何规则。
10. 缓存过期和精确窗口选择。
11. 缺失费用不补零。
12. 双周期按 5 小时 / 一周展示 `25/76%`，反向槽位仍正确配对；周期缺失显示 `—`；Antigravity 不跨模型组配对。
13. 点击、悬停、菜单栏图标的八种组合始终保留可用入口，隐藏灵动岛时恢复菜单栏图标。
14. 旧设置缺少新开关时正确补默认值，保留左右平台、双周期样式和悬停偏好。
15. 灵动岛显示位置左侧、两侧、右侧可序列化并恢复。

## 未宣称验证通过

- 未登录的其他平台、Claude 成功态、不同账户/套餐组合。
- Intel 架构、macOS 14 真机、多显示器热插拔、缩放组合和全屏应用矩阵。
- 系统通知授权和送达、登录启动授权、锁屏解锁的长期运行。
- Apple Developer ID 签名、公证、App Store 发布、自动更新。
- 全年历史热力图、重置信用兑换和独立多账号切换未实现。

本记录区分代码实现、核心测试、真实接口读数和实际画面检查；不将其中一项等同于所有环境验收。
