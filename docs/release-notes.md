## IsLandToken 0.4.4

### 中文

- 修复首次打开设置窗口时左侧菜单可能无法点击的问题：灵动岛面板会在设置展示前同步收缩为受限区域，不再短暂覆盖整个屏幕。
- 设置窗口打开期间，灵动岛仍会响应鼠标悬停；左侧菜单、工具栏和详情页可以正常交互。
- 发布说明同时提供中文与英文；应用会按当前界面语言显示对应段落。
- 完善更新进度和安装失败信息的中英文切换，包括辅助程序、下载、启动验证和命令执行错误。
- 新增本地化回归覆盖，检查设置工具栏、侧栏、双语发行说明和动态更新错误。

> 当前产物支持 Apple Silicon、macOS 14+；采用本地临时签名，未进行 Apple 开发者签名或公证。

### English

- Fixed an issue where the Settings sidebar could ignore its first click: the Island panel now synchronously becomes bounded before Settings is presented, so it cannot briefly cover the full screen.
- The Island still responds to hover while Settings is open, while the sidebar, toolbar, and detail page remain interactive.
- Release notes are now published in Chinese and English; the app displays the section that matches the selected interface language.
- Localized update progress and installation failures, including helper, download, launch-verification, and command-execution errors.
- Added localization regression coverage for Settings toolbar and sidebar labels, bilingual release notes, and dynamic update errors.

> This build supports Apple Silicon and macOS 14+. It is ad-hoc signed locally and is not Apple Developer signed or notarized.
