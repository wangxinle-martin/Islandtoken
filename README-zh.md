# IsLandToken

> **面向 MacBook 刘海的本地优先 AI 额度监控工具。**

![版本](https://img.shields.io/badge/%E7%89%88%E6%9C%AC-v0.4.4-0E7CBA)
![平台](https://img.shields.io/badge/%E5%B9%B3%E5%8F%B0-macOS%2014%2B-555555?logo=apple&logoColor=white)
![Apple%20Silicon](https://img.shields.io/badge/%E6%9E%B6%E6%9E%84-Apple%20Silicon-555555?logo=apple&logoColor=white)
![构建技术](https://img.shields.io/badge/%E6%9E%84%E5%BB%BA%E6%8A%80%E6%9C%AF-Swift%206-F05138?logo=swift&logoColor=white)
![包管理器](https://img.shields.io/badge/%E5%8C%85%E7%AE%A1%E7%90%86%E5%99%A8-SwiftPM-F05138?logo=swift&logoColor=white)
![测试](https://img.shields.io/badge/%E6%B5%8B%E8%AF%95-XCTest%20%2B%20%E5%9B%9E%E5%BD%92-2EA44F)
![发布自动化](https://img.shields.io/badge/%E5%8F%91%E5%B8%83-GitHub%20Actions-2088FF?logo=githubactions&logoColor=white)
![本地优先](https://img.shields.io/badge/%E6%95%B0%E6%8D%AE%E9%87%87%E9%9B%86-%E6%9C%AC%E5%9C%B0%E4%BC%98%E5%85%88-30B7A3)
![隐私](https://img.shields.io/badge/%E9%9A%90%E7%A7%81-%E6%97%A0%E9%81%A5%E6%B5%8B-30B7A3)
![凭据](https://img.shields.io/badge/%E5%87%AD%E6%8D%AE-%E6%9C%AC%E6%9C%BA%E7%99%BB%E5%BD%95%E7%8A%B6%E6%80%81-30B7A3)
![平台适配](https://img.shields.io/badge/%E5%B9%B3%E5%8F%B0%E9%80%82%E9%85%8D-12%20%E4%B8%AA-7B61FF)

[English](README.md) · [中文](README-zh.md)

![IsLandToken 在 MacBook 刘海两侧展示 Codex 和 Antigravity 额度摘要](docs/images/island-preview.png)

IsLandToken 将你关心的 AI 额度窗口放在 Mac 屏幕顶部：可以显示在 MacBook 刘海两侧、菜单栏，或展开为详情面板。它适合同时使用 Codex、Claude、Antigravity、Gemini、Cursor、Copilot 等 AI 工具的人，快速查看剩余额度和重置时间，同时尽量让数据留在本机。

## 为什么使用 IsLandToken？

- **本地优先采集**：Codex 和 Claude 优先读取本机已有登录状态；本地直连不可用时，再回退到本机已安装或随应用捆绑的 CodexBar 采集器。
- **为 Mac 刘海而设计**：左右两侧可独立选择平台、额度窗口和展示样式；信息始终可见，却不会占用工作区。
- **如实展示数据**：订阅额度、已消耗 Token、预估费用和可用积分是不同指标；应用会分别展示，数据源未提供时显示 `—`。
- **默认保护隐私**：没有遥测，不保存访问令牌、账号邮箱或原始服务端响应。
- **可同时比较多个服务**：左右两侧分别配置，既能对比两个平台，也能查看同一平台的不同额度周期。

## 功能

| 模块 | 说明 |
| --- | --- |
| 刘海展示 | 左右独立配置平台和额度窗口；支持数字、圆环、进度条、分段、趋势图，以及 5 小时 / 每周双周期样式 |
| 平台适配 | Codex、Claude、Antigravity、Gemini、Cursor、GitHub Copilot、Windsurf、Kiro、OpenRouter、DeepSeek、Ollama、OpenCode |
| 展开详情 | 剩余额度、重置时间、本地采样趋势、最近样本；数据源提供时显示 Token/费用相关信息 |
| 常驻交互 | 点击或悬停展开、图钉固定、右键快捷菜单，以及作为兜底入口的菜单栏图标 |
| 历史与费用 | 本地保留 30 天采样、导出 CSV、每日柱图；本地记录存在时展示 Token 和费用汇总 |
| 刷新与异常 | 手动、定时、唤醒和活动感知刷新；超时保护、过期标记和最近一次成功缓存 |

## 数据源优先级

1. **本机直连采集**：Codex、Claude 仅读取本机已有凭据。
2. **本机 CodexBar 回退**：直连失败，或某个平台需通过 CodexBar 适配器获取时使用。
3. **只展示真实返回数据**：不会虚构模型窗口、额度百分比或费用数值。

> 启用某个入口只表示应用支持该适配器，不代表这台 Mac 已登录该平台，也不代表平台会提供全部字段。

## 隐私与本地数据

- 设置保存在 `UserDefaults` 域 `com.wangxinle.IsLandToken`。
- 额度缓存和历史位于 `~/Library/Application Support/IsLandToken/readings.json` 与 `history.json`。
- 应用不会保存访问令牌、账号邮箱、原始网络响应或会话内容。
- 本地直连请求不跟随重定向，使用临时 `URLSession`。可选 CodexBar 采集器沿用其自身的认证、缓存和网络行为。

## 构建

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

## 边界说明

额度百分比不是 Token 总量。订阅类服务通常只报告某个周期内的剩余比例；Token、美元费用估算和积分来自不同记录。趋势仅代表 IsLandToken 运行期间采集成功的本地样本。登录启动、通知授权、多显示器和锁屏行为请在目标 Mac 上验证。

当前产物为 ad-hoc 签名，尚未进行 Apple Developer ID 签名或公证。

## 致谢

弹窗布局和交互中复用了 [CodexBar](https://github.com/steipete/CodexBar) 的部分具名可复用组件。IsLandToken 保持独立的本地优先采集流程和 SwiftPM macOS 应用架构，并不包含 CodexBar 的全部功能。

第三方声明见 [Licenses](Licenses)；架构、验证记录与 CodexBar 同步边界见 [docs](docs)。

提交改动前，请运行：

```sh
./script/test.sh
git diff --check
```
