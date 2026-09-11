# 全屏彩带来源

已删除旧的 Canvas 礼花/彩带实现。全屏预览和额度重置使用同一个
`ScreenConfettiOverlayController`，移植自：
https://github.com/steipete/CodexBar/blob/main/Sources/CodexBar/ScreenConfettiOverlayController.swift

源码获取日期：2026-09-09。保留原版两组扇形发射器、60ms 阶段间隔、
全部 Vortex 粒子参数、彩纸形状、5 秒窗口生命周期及全显示器点击穿透行为。
适配仅去除 CodexBar 日志依赖，并将 ProviderColor 输入替换为本应用两侧平台颜色。
播放期间忽略重复触发，结束关闭全部窗口。

Vortex 使用 CodexBar 锁定的 fork 和版本，随项目保存用于离线构建：
https://github.com/zats/Vortex/tree/ef5392088d4aeb255c4eee83157dbdafcd31bf07

许可证：Licenses/CodexBar-MIT.txt、Licenses/Vortex-MIT.txt。
