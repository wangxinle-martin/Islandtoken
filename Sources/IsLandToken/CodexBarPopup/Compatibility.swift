import SwiftUI

// Host localization/settings adapter; drawing and metric layout remain upstream.
enum WorkdayTickAppearance: String { case hidden, subtle, highContrast }
enum InterfaceLanguage: String, CaseIterable, Identifiable {
  case chinese
  case english

  var id: String { rawValue }
  var title: String { self == .chinese ? "简体中文" : "English" }
  var isEnglish: Bool { self == .english }
}

func T(_ key: String, _ arguments: CVarArg...) -> String {
  let english = UserDefaults.standard.string(forKey: "interfaceLanguage") == InterfaceLanguage.english.rawValue
  let translated: String
  if english {
    translated = [
      "通用": "General", "用量": "Usage", "灵动岛": "Island",
      "关于": "About", "设置": "Settings", "打开设置": "Open Settings",
      "提供商": "Providers", "%d 个已启用": "%d enabled", "管理提供商": "Manage Providers",
      "强调色": "Accent Color", "设置提供商强调色": "Set provider accent color",
      "左右互换": "Swap Sides", "每一份额度，心中有数": "Every quota, clearly in view.",
      "展开": "Expand", "收缩": "Collapse",
      "详情": "Details", "收起": "Collapse",
      "显示灵动岛详情": "Show Island Details", "收起灵动岛详情": "Collapse Island Details",
      "展开 / 收起灵动岛": "Expand / Collapse Island", "正在同步…": "Syncing…", "立即刷新": "Refresh Now",
      "显示灵动岛": "Show Island", "显示/隐藏": "Show / Hide", "显示或隐藏灵动岛": "Show or Hide Island",
      "显示": "Show", "隐藏": "Hide",
      "已显示": "Visible", "已隐藏": "Hidden", "设置…": "Settings…", "退出 IsLandToken": "Quit IsLandToken",
      "演示模式": "Demo Mode", "本地优先 · 原生 macOS": "Local-first · Native macOS",
      "演示模式：以下额度和趋势均为示例": "Demo mode: quotas and trends below are examples.",
      "刘海区域": "Notch Area", "Mac 刘海区域": "Mac Notch Area",
      "虚线为 Mac 刘海区域": "Dashed outline: Mac notch area",
      "实时预览": "LIVE PREVIEW", "示例": "Demo", "预览": "Preview", "与你的灵动岛同步": "Synced with your Island",
      "返回实时数据": "Return to Live Data", "刷新": "Refresh", "刷新数据 ⌘R": "Refresh data ⌘R",
      "展开灵动岛": "Expand Island", "下次同步 %@": "Next sync %@",
      "管理提供商 →": "Manage Providers →",
      "订阅平台通常提供额度百分比，不提供可用 Token 总数。这里按平台原始口径显示剩余额度；Token 消耗与费用可在各提供商详情中查看。": "Subscriptions usually provide quota percentages rather than available Token totals. Remaining quota follows each provider's original definition; token usage and costs are available in each provider's details.",
      "位置与屏幕": "Position & Display", "点击与悬停": "Click & Hover", "额度与重置时间": "Quota & Reset Time",
      "刷新动画": "Refresh Animation", "演示预览": "Demo Preview", "左侧": "Left", "右侧": "Right",
      "显示器": "Display", "自动 · 优先刘海屏": "Automatic · Prefer Notched Display", "已断开 · 自动回退": "Disconnected · Fall Back Automatically",
      "水平偏移": "Horizontal Offset", "调整": "Adjust", "重置": "Reset", "偏移值": "Offset",
      "水平偏移负值向左、正值向右，靠近屏幕边缘时自动限位。": "Negative offsets move left; positive offsets move right. Position is limited at screen edges.",
      "顶部偏移": "Top Offset", "详情显示方式": "Detail Display", "额度显示方式": "Quota Display",
      "使用额度": "Used Quota", "剩余额度": "Remaining Quota",
      "重置时间显示方式": "Reset Time Display", "倒计时": "Countdown", "日期与时间": "Date & Time",
      "使用演示数据预览样式": "Preview with Demo Data", "演示剩余额度": "Demo Remaining Quota", "随机数据": "Random Data",
      "平台": "Provider", "额度 / 模型": "Quota / Model", "显示样式": "Display Style", "配色": "Color",
      "显示平台图标": "Show Provider Icon", "显示平台名称": "Show Provider Name",
      "采集引擎": "Collection Engine", "CodexBar 已就绪": "CodexBar Ready", "CodexBar 未找到": "CodexBar Not Found",
      "连接方式": "Connection Method", "自动 · 优先 CodexBar": "Automatic · Prefer CodexBar", "仅使用 CodexBar": "CodexBar Only",
      "Codex / Claude 直接读取": "Direct Codex / Claude", "重新连接": "Reconnect", "打开 CodexBar": "Open CodexBar",
      "安装与平台指南 ↗": "Setup & Provider Guide ↗", "启动与入口": "Startup & Access",
      "外观": "Appearance", "启用": "Enable", "连接状态": "Connection Status", "最近更新": "Last Updated",
      "采集来源": "Collection Source", "套餐": "Plan", "账户": "Account",
      "通过 CodexBar 读取此提供商当前可用的额度数据。": "Reads quota data currently available from this provider through CodexBar.",
      "优先读取本机 Codex 登录；失败时回退到 CodexBar。": "Prefer locally signed-in Codex credentials; fall back to CodexBar.",
      "优先读取本机 Claude 登录；失败时回退到 CodexBar。": "Prefer locally signed-in Claude credentials; fall back to CodexBar.",
      "通过本机安装或捆绑的 CodexBar 采集。": "Collected through locally installed or bundled CodexBar.",
      "灵动岛左右侧正在使用的平台会保持启用": "Providers currently used on either Island side remain enabled.",
      "暂无额度数据。请在 CodexBar 登录或配置此提供商后刷新。": "No quota data yet. Sign in or configure this provider in CodexBar, then refresh.",
      "暂无额度数据。请确认已在本机完成平台登录后刷新。": "No quota data. Sign in on this Mac, then refresh.",
      "尚未采集。启用后点击工具栏的刷新按钮开始同步。": "Not collected yet. Enable it, then use the toolbar refresh button to sync.",
      "采集": "Collection", "采集方式": "Collection Method", "自动": "Automatic",
      "供应商直接读取": "Read Provider Directly", "通过 CodexBar": "Via CodexBar", "立即读取": "Read Now",
      "可直接读取此提供商已登录的本机额度数据。": "Can read quota data directly from this provider's signed-in local credentials.",
      "直接读取此提供商已登录的本机额度数据。": "Reads quota data directly from this provider's signed-in local credentials.",
      "直接读取只使用 %@ 已登录的本机凭据，不会上传密码或 API Key。": "Direct reading only uses %@'s signed-in local credentials and never uploads passwords or API keys.",
      "此提供商由 CodexBar 直接读取已登录的本机数据。": "CodexBar reads this provider's signed-in local data directly.",
      "自定义 CodexBar CLI 路径（可留空）": "Custom CodexBar CLI Path (optional)",
      "搜索提供商": "Search Providers", "排序": "Sort", "按首字母": "Alphabetical",
      "清除搜索": "Clear Search",
      "已开启优先": "Enabled First",
      "当前：按首字母；点击切换为已开启优先": "Current: Alphabetical; click for Enabled First",
      "当前：已开启优先；点击切换为按首字母": "Current: Enabled First; click for Alphabetical",
      "收起提供商": "Collapse Providers", "展开提供商": "Expand Providers",
      "收起左侧菜单": "Hide Sidebar", "展开左侧菜单": "Show Sidebar",
      "额度趋势": "Quota Trend", "额度": "Quota", "等待更多采样": "Waiting for More Samples",
      "保持 App 运行，第二次成功同步后即可看到趋势。": "Keep the app running; the trend appears after a second successful sync.",
      "最多展示最近 144 次采样 · 本地保留 30 天": "Shows up to 144 recent samples · stored locally for 30 days",
      "导出 CSV": "Export CSV", "Token 与费用": "Tokens & Costs", "读取中…": "Loading…", "读取费用记录": "Load Cost Records",
      "这里显示已消耗的 Token 与估算费用，不表示剩余订阅额度。费用由 CodexBar 根据平台或本地会话记录计算；缺失值显示 —。": "Shows consumed Tokens and estimated costs, not remaining subscription quota. CodexBar calculates costs from provider or local session records; missing values show —.",
      "本地额度采集不读取 Token 与费用记录；缺失值显示 —。": "Local quota collection does not read Token or cost records; missing values show —.",
      "额度优先从本机已有登录凭据读取；其他平台可通过 CodexBar 本地采集。": "Quota is read first from credentials already signed in on this Mac; other providers can be collected through CodexBar.",
      "今日 Token": "Today Tokens", "今日估算 USD": "Today Est. USD", "近 30 天 Token": "30-day Tokens", "近 30 天 USD": "30-day USD",
      "此提供商当前未提供 Token 与费用数据。": "This provider currently does not provide Token or cost data.",
      "界面语言": "Interface Language", "登录时启动": "Launch at Login", "启动时打开设置": "Open Settings at Launch",
      "在菜单栏显示图标": "Show Menu Bar Icon", "额度提醒与通知": "Quota Alerts & Notifications",
      "低额度时改变灵动岛颜色": "Change Island Color for Low Quota", "橙色提醒": "Orange Alert", "红色提醒": "Red Alert",
      "系统通知": "System Notifications", "额度重置时播放全屏彩带": "Play Full-screen Confetti on Quota Reset",
      "预览全屏彩带": "Preview Full-screen Confetti", "IsLandToken": "IsLandToken", "版本 %@ · macOS 14+": "Version %@ · macOS 14+",
      "GitHub 项目 ↗": "GitHub Project ↗", "检查更新": "Check for Updates", "检查中…": "Checking…",
      "当前版本更新内容": "What's New in This Version", "版本 %@": "Version %@", "暂无当前版本更新内容。": "No release notes are available for this version.",
      "启动时检查更新": "Check for Updates at Launch", "查看发布说明": "View Release Notes", "下载并安装": "Download & Install",
      "取消更新": "Cancel Update", "正在取消…": "Cancelling…", "更新进度": "Update Progress", "正在处理": "Processing",
      "尚未检查更新": "Not checked yet", "上次自动安装 %@ 失败：%@": "Previous automatic installation of %@ failed: %@",
      "当前版本无需安装此更新。": "This update does not need to be installed for the current version.",
      "该版本缺少当前架构的 DMG 或 SHA-256 校验文件。": "This release is missing the DMG or SHA-256 checksum for the current architecture.",
      "正在下载并验证 IsLandToken %@…": "Downloading and verifying IsLandToken %@…", "正在取消更新…": "Cancelling update…",
      "校验通过，正在退出并自动安装…": "Verified. Quitting and installing automatically…", "更新已取消。": "Update cancelled.",
      "自动安装失败：%@": "Automatic installation failed: %@", "检查失败：请检查网络；私有仓库需先在终端执行 gh auth login。": "Update check failed. Check your network; for a private repository, run gh auth login in Terminal first.",
      "固定": "Pin", "退出": "Quit", "暂无额度数据": "No quota data", "可用积分 %@": "Available credits %@",
      "会话": "Session", "每周": "Weekly", "今日：%@ Token · %@": "Today: %@ Token · %@", "30 天：%@ Token · %@": "30 days: %@ Token · %@",
      "按本机日志估算": "Estimated from local logs", "等待额度数据": "Waiting for quota data", "%d分钟前已更新": "Updated %d min ago",
      "主要额度": "Primary quota", "次要额度": "Secondary quota", "其他额度": "Other quota",
      "5 小时额度": "5-hour quota", "7 天额度": "7-day quota", "Gemini 模型": "Gemini model", "其他模型": "Other model",
      "Sonnet · 7 天": "Sonnet · 7 days", "Opus · 7 天": "Opus · 7 days",
      "圆环": "Ring", "进度条": "Bar", "分段": "Segments", "数字": "Number", "趋势": "Trend",
      "两侧": "Both", "点击时显示详情": "Show details on click", "悬停时显示详情": "Show details on hover", "不显示详情": "Do not show details",
      "版本与更新": "Version & Updates", "当前版本 %@": "Current version %@", "稍后": "Later",
      "发现新版本 %@": "New version %@ available", "当前版本 %@，可自动下载、安装并重启应用。": "Current version %@. It can be downloaded, installed, and restarted automatically.",
      "运行期间每 5 分钟自动检查更新；发现新版本时提示。": "Checks for updates every 5 minutes while running and notifies you when one is available.",
      "下载阶段可取消；进入校验后会自动替换当前应用并重启，已有设置保持不变。": "Downloads can be cancelled. After verification begins, the app is replaced and restarted while your settings remain unchanged.",
      "上次缓存 · 等待同步": "Cached data · Waiting to sync",
      "额度概览": "Quota Overview", "实时数据": "Live Data", "最近本地采样": "Recent Local Samples",
      "当前来源暂无记录": "No records for the current source", "Token 用量与费用": "Token Usage & Costs",
      "品牌色": "Provider", "薄荷绿": "Mint", "天空蓝": "Sky Blue", "紫罗兰": "Violet", "琥珀橙": "Amber", "纯白": "White"
      , "两侧独立配置": "Independent configurations", "点击展开": "Click to expand", "%@同步": "%@ sync",
      "正在读取平台额度…": "Reading provider quotas…", "等待连接": "Waiting for connection", "尚未同步": "Not synced yet",
      "打开平台用量页": "Open provider usage page", "IsLandToken 额度": "IsLandToken quota",
      "IsLandToken 详情已显示": "IsLandToken details shown", "显示 IsLandToken 详情": "Show IsLandToken details",
      "数据待更新": "Data pending update", "时间": "Time", "额度未知": "Quota unknown", "剩余": "Remaining", "已用": "Used",
      "%@ %@": "%@ %@", "%@ · 暂无额度": "%@ · No quota data",
      "未提供重置时间": "No reset time provided", "等待刷新重置状态": "Waiting for reset status refresh",
      "%d 天 %d 小时后重置": "Resets in %dd %dh", "%d 小时 %d 分后重置": "Resets in %dh %dm", "%d 分钟后重置": "Resets in %d min",
      "额度 %": "Quota %", "日期": "Date", "%d 次可用": "%d credits available", "无到期时间": "No expiry",
      "下次恢复后 %.0f%% %@": "After next recovery: %.0f%% %@", "灵动岛显示位置": "Island Position",
      "左侧或右侧模式将两个已选平台并排显示在刘海同一侧，另一侧宽度为零；两侧模式分别显示。": "Left or Right places both selected providers on one side of the notch; Both shows one on each side.",
      "最小状态按所选样式显示圆环、进度条、分段、数字或趋势；鼠标移入时显示数值、百分号及已启用的图标和名称。开启系统减少动态效果时不播放弹动。": "The compact Island uses the selected ring, bar, segments, number, or trend style. Hover to reveal values, percentages, and enabled provider names and icons. Motion is disabled when Reduce Motion is enabled.",
      "无刘海屏也可使用。若与菜单栏内容重叠，可增加顶部偏移；拔出指定显示器后会自动回退。": "Works without a notch. Increase the top offset if it overlaps menu-bar content; disconnected displays automatically fall back.",
      "详情显示方式三选一。选择不显示详情时仍可悬停查看图标和百分号。菜单栏入口可在通用设置中配置。": "Choose one detail interaction. With details hidden, hover still reveals icons and percentages. Configure the menu-bar entry in General.",
      "完整时间按 Mac 当前时区显示，例如 重置于 09月09日 18:30。未提供重置时间的平台仍显示原提示。": "Full times use your Mac time zone. Providers without a reset time keep their original message.",
      "刷新时只能启用一种动画；发光闪烁只作用于灵动岛下方和两侧边框。": "Only one refresh animation can be enabled. Glow affects only the Island bottom and side edges.",
      "橙色、红色档位直接预览对应告警颜色。": "Orange and red presets preview their matching alert colors.",
      "橙色、红色档位直接预览对应告警颜色；选择随机数据可为各平台生成不同的额度与趋势，再次点击可重新生成。": "Orange and red presets preview their matching alert colors. Random Data generates distinct quotas and trends for each provider; click it again to regenerate.",
      "支持多选，按选择顺序显示；至少保留一项。每项使用所选样式，缺失额度显示 —。项目较多时可横向滚动查看。": "Select multiple items in display order; at least one must remain. Each uses the selected style; missing quotas show —. Scroll horizontally when needed.",
      "%@（暂无数据）": "%@ (no data)", "剩余 %d%%": "%d%% remaining",
      "通知仅在进入更高告警级别时触发。过期值和演示数据不触发通知。": "Notifications fire only when entering a higher alert level. Stale and demo data do not trigger notifications.",
      "请在系统设置 → 通用 → 登录项中允许启动。": "Allow launch at login in System Settings → General → Login Items.",
      "启动项设置失败。请先将 App 移到「应用程序」后重试。": "Could not configure the login item. Move the app to Applications and try again.",
      "先在 Codex 登录；支持本地 OAuth 和 CodexBar。": "Sign in to Codex first; local OAuth and CodexBar are supported.",
      "先运行 claude 登录；支持凭据文件、钥匙串和 CodexBar。": "Run claude login first; credential files, Keychain, and CodexBar are supported.",
      "在 Antigravity 登录并保持运行，或在 CodexBar 配置 Google 账号。": "Sign in to Antigravity and keep it running, or configure a Google account in CodexBar.",
      "在 CodexBar 中完成此平台的登录与数据源配置。": "Finish this provider's sign-in and data-source setup in CodexBar.",
      "关闭": "Off", "数字翻页": "Digit Flip", "流星划过": "Meteor", "发光闪烁": "Glow", "呼吸闪点": "Sparkle", "雷达扫描": "Radar", "像素汇聚": "Pixels", "能量波纹": "Waves", "数据雨": "Data Rain", "随机": "Random",
      "%@ 分钟": "%@ min", "自适应 · 活跃 · %@ 分钟": "Adaptive · Active · %@ min",
      "自适应 · 空闲 · %@ 分钟": "Adaptive · Idle · %@ min", "橙色 · 15%": "Orange · 15%", "红色 · 3%": "Red · 3%",
      "未连接": "Not connected", "演示数据": "Demo data", "直接读取 · OAuth": "Direct · OAuth",
      "采集失败，请检查平台配置。": "Collection failed. Check the provider configuration.",
      "费用记录暂不可用。": "Cost records are not available.", "通知未获授权，可在系统设置 → 通知中开启。": "Notifications are not authorized. Enable them in System Settings → Notifications.",
      "本地历史保存失败，本次数据仍可查看。": "Could not save local history; this session's data is still available.", "导出失败：%@": "Export failed: %@",
      "IsLandToken 更新": "IsLandToken Update", "IsLandToken 更新完成": "IsLandToken Update Completed",
      "已成功安装并启动 IsLandToken %@。": "IsLandToken %@ was installed and launched successfully.",
      "%@ 额度提醒": "%@ Quota Alert", "%@剩余 %d%%，请留意重置时间。": "%@ has %d%% remaining. Please note the reset time.",
      "本地采集当前不提供 Token 与费用记录。": "Local collection does not provide Token or cost records.",
      "未找到本地登录或 CodexBar 采集程序。": "No local sign-in or CodexBar collector was found.",
      "网络连接失败，请检查网络或代理设置。": "Network connection failed. Check your network or proxy settings.",
      "未找到 Codex OAuth 登录，请先运行 codex login。": "No Codex OAuth sign-in was found. Run codex login first.",
      "未找到可读取的 Claude 登录，请先在本机运行 claude 登录。": "No readable Claude sign-in was found. Run claude login on this Mac first.",
      "采集超时或响应过大；请检查平台状态后重试。": "Collection timed out or the response was too large. Check the provider and try again.",
      "采集响应过大，请检查平台状态后重试。": "The collection response was too large. Check the provider and try again.",
      "采集程序未返回数据，请检查本机配置。": "The collector returned no data. Check the local configuration.",
      "CodexBar 未返回此平台的数据，请检查版本与配置。": "CodexBar returned no data for this provider. Check its version and configuration.",
      "平台未返回额度数据。": "The provider returned no quota data.",
      "Codex 额度响应格式已变化。": "The Codex quota response format has changed.",
      "Claude 额度响应格式已变化。": "The Claude quota response format has changed.",
      "Claude 暂时限流或登录已过期，请稍后重试。": "Claude is temporarily rate limited or the sign-in has expired. Try again later.",
      "请求受到限流，将在下一刷新周期重试。": "The request was rate limited and will retry during the next refresh.",
      "登录已过期，请在原平台重新登录。": "The sign-in has expired. Sign in again with the original provider.",
      "登录权限不足，请重新登录并授权。": "The sign-in lacks permission. Sign in again and authorize access.",
      "网络连接失败，保留上次成功数据。": "Network connection failed. The last successful data is retained.",
      "采集失败，请检查本机登录状态与网络连接。": "Collection failed. Check the local sign-in and network connection.",
      "发布说明": "Release Notes", "正在准备更新…": "Preparing update…", "当前已是最新版本": "You're up to date", "GitHub 暂无 IsLandToken 正式版本": "No stable IsLandToken release is available on GitHub.",
      "新版本号格式无效。": "The new version number is invalid.", "更新包名称与版本或处理器架构不匹配。": "The update package name does not match the version or processor architecture.",
      "无法定位当前应用程序。": "The current application could not be located.",
      "请先将 IsLandToken 放入应用程序文件夹后再自动更新。": "Move IsLandToken to the Applications folder before updating automatically.",
      "当前安装位置不可写，无法自动替换应用。": "The current installation location is not writable, so the app cannot be replaced automatically.",
      "无法设置更新辅助程序权限": "Could not set permissions for the update helper.",
      "更新辅助程序未能启动。": "The update helper could not start.", "等待更新辅助程序就绪超时。": "Timed out waiting for the update helper to become ready.",
      "无法原子替换应用": "Could not replace the application atomically.",
      "无法下载更新；私有仓库请先安装 GitHub CLI 并执行 gh auth login。": "Could not download the update. For a private repository, install GitHub CLI and run gh auth login first.",
      "正在通过 GitHub CLI 下载…": "Downloading through GitHub CLI…", "GitHub 返回了无效的下载响应。": "GitHub returned an invalid download response.",
      "下载文件大小与 GitHub 发布信息不一致。": "The downloaded file size does not match the GitHub release information.",
      "更新包校验文件格式无效。": "The update package checksum file format is invalid.", "更新包 SHA-256 校验失败，已停止安装。": "The update package SHA-256 check failed; installation stopped.",
      "更新包中的应用身份或版本不正确。": "The application identity or version in the update package is incorrect.",
      "更新包不支持当前 Mac 的处理器架构。": "The update package does not support this Mac's processor architecture.",
      "更新辅助程序拒绝了无效的应用路径。": "The update helper rejected an invalid application path.",
      "旧版本未能按时退出，更新尚未安装。": "The previous version did not quit in time, so the update was not installed.",
      "新版启动验证失败。": "The new version failed launch verification.", "安装后的应用缺少可执行程序。": "The installed application is missing its executable.",
      "无法保存更新事务状态。": "Could not save the update transaction state.",
      "正在下载 IsLandToken %@…": "Downloading IsLandToken %@…", "正在下载… %@%%": "Downloading… %@%%", "正在校验更新包…": "Verifying update package…", "正在准备安装…": "Preparing installation…"
    ][key] ?? key
  } else {
    translated = key
  }
  return arguments.isEmpty ? translated : String(format: translated, arguments: arguments)
}

func L(_ key: String, _ arguments: CVarArg...) -> String {
  let translated =
    [
      "usage_percent_suffix_left": "剩余", "usage_percent_suffix_used": "已用",
      "On pace": "进度正常", "%d%% in deficit": "超额 %d%%", "%d%% in reserve": "结余 %d%%",
      "Projected empty now": "预计即将耗尽", "Projected empty in %@": "预计 %@ 后耗尽",
      "Runs out now": "即将耗尽", "Runs out in %@": "预计 %@ 后耗尽", "(%d%% risk)": "(%d%% 耗尽风险)",
      "Lasts until reset": "可用至重置", "1.5× headroom": "1.5× 余量",
      "Usage remaining": "剩余额度", "Usage used": "已用额度", "%d percent": "%d%%",
      "Limit Reset Credits": "限额重置额度", "Copied": "已复制", "Copy": "复制", "Copy error": "复制错误", "Refreshing": "刷新中",
      "quota_warnings_title": "额度告警", "weekly_progress_work_days_title": "工作日刻度",
      "Pace: %@ · %@": "进度：%@ · %@", "Pace: %@": "进度：%@", "%@ %@": "%@ %@", "%@ · %@": "%@ · %@",
    ][key] ?? key
  if UserDefaults.standard.string(forKey: "interfaceLanguage") == InterfaceLanguage.english.rawValue {
    return arguments.isEmpty ? key : String(format: key, arguments: arguments)
  }
  return arguments.isEmpty ? translated : String(format: translated, arguments: arguments)
}

struct MenuCardLiveSubtitle {
  let text: String
  let style: UsageMenuCardView.Model.SubtitleStyle
}
extension View {
  func menuCardInteractiveControl(isEnabled: Bool = true) -> some View { self.disabled(!isEnabled) }
}
enum MenuPasteboardCopy {
  static func perform(_ text: String, completion: () -> Void) {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(text, forType: .string)
    completion()
  }
}
struct ClickToCopyOverlay: View {
  let copyText: String
  var body: some View {
    Color.clear.contentShape(Rectangle()).onTapGesture { MenuPasteboardCopy.perform(copyText) {} }
  }
}
