import SwiftUI

// Host localization/settings adapter; drawing and metric layout remain upstream.
enum WorkdayTickAppearance: String { case hidden, subtle, highContrast }
func L(_ key: String, _ arguments: CVarArg...) -> String {
  let translated =
    [
      "usage_percent_suffix_left": "剩余", "usage_percent_suffix_used": "已用",
      "On pace": "进度正常", "%d%% in deficit": "超额 %d%%", "%d%% in reserve": "结余 %d%%",
      "Projected empty now": "预计即将耗尽", "Projected empty in %@": "预计 %@ 后耗尽",
      "Runs out now": "即将耗尽", "Runs out in %@": "预计 %@ 后耗尽", "(%d%% risk)": "(%d%% 耗尽风险)",
      "Lasts until reset": "可用至重置", "1.5× headroom": "1.5× 余量",
      "Usage remaining": "剩余额度", "Usage used": "已用额度", "%d percent": "%d%%",
      "Limit Reset Credits": "限额重置额度", "Copied": "已复制", "Copy error": "复制错误", "Refreshing": "刷新中",
      "quota_warnings_title": "额度告警", "weekly_progress_work_days_title": "工作日刻度",
    ][key] ?? key
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
