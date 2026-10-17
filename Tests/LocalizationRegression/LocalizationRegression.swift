import Foundation

@main
enum LocalizationRegression {
  static func main() {
    let defaults = UserDefaults.standard
    let priorLanguage = defaults.object(forKey: "interfaceLanguage")
    defer {
      if let priorLanguage {
        defaults.set(priorLanguage, forKey: "interfaceLanguage")
      } else {
        defaults.removeObject(forKey: "interfaceLanguage")
      }
    }

    defaults.set(InterfaceLanguage.english.rawValue, forKey: "interfaceLanguage")
    precondition(T("显示") == "Show")
    precondition(T("隐藏") == "Hide")
    precondition(T("预览") == "Preview")
    precondition(T("展开") == "Expand")
    precondition(T("收缩") == "Collapse")
    precondition(T("刷新") == "Refresh")
    precondition(T("详情") == "Details")
    precondition(T("收起") == "Collapse")
    precondition(T("通用") == "General")
    precondition(T("用量") == "Usage")
    precondition(T("灵动岛") == "Island")
    precondition(T("关于") == "About")
    precondition(UserFacingText.quotaTitle("5 小时额度") == "5-hour quota")
    precondition(UserFacingText.quotaTitle("Sonnet · 7 天") == "Sonnet · 7 days")
    precondition(UserFacingText.source("直接读取 · OAuth") == "Direct · OAuth")
    precondition(UserFacingText.source("CodexBar · auto") == "CodexBar · Automatic")
    precondition(
      UserFacingText.refreshDescription("自适应 · 活跃 · 1 分钟")
        == "Adaptive · Active · 1 min")
    precondition(UserFacingText.value("发现新版本 0.4.4") == "New version 0.4.4 available")
    precondition(
      UserFacingText.value("正在下载… 73%") == "Downloading… 73%")
    precondition(
      UserFacingText.value("正在下载并验证 IsLandToken 0.4.4…")
        == "Downloading and verifying IsLandToken 0.4.4…")
    precondition(
      UserFacingText.value("更新辅助程序未能启动：等待更新辅助程序就绪超时。")
        == "The update helper could not start: Timed out waiting for the update helper to become ready.")
    precondition(
      UserFacingText.value("无法设置更新辅助程序权限：Operation not permitted。")
        == "Could not set permissions for the update helper: Operation not permitted.")
    precondition(
      UserFacingText.value("无法原子替换应用：Operation not permitted。")
        == "Could not replace the application atomically: Operation not permitted.")
    precondition(UserFacingText.value("执行 gh 超时。") == "Timed out running gh.")
    precondition(
      UserFacingText.value("gh 执行失败：新版启动验证失败。")
        == "gh failed to run: The new version failed launch verification.")
    precondition(
      UserFacingText.releaseNotes("## IsLandToken 0.4.4\n\n### 中文\n\n- 中文说明\n\n### English\n\n- English notes")
        == "- English notes")
    let englishDate = UserFacingText.dateTime(Date(timeIntervalSince1970: 1_700_000_000))
    precondition(!englishDate.unicodeScalars.contains { (0x4E00...0x9FFF).contains($0.value) })
    print("PASS English toolbar and runtime localization")

    defaults.set(InterfaceLanguage.chinese.rawValue, forKey: "interfaceLanguage")
    precondition(T("显示") == "显示")
    precondition(T("隐藏") == "隐藏")
    precondition(T("展开") == "展开")
    precondition(T("详情") == "详情")
    precondition(UserFacingText.quotaTitle("5 小时额度") == "5 小时额度")
    precondition(UserFacingText.source("CodexBar · auto") == "CodexBar · 自动")
    precondition(UserFacingText.value("发现新版本 0.4.4") == "发现新版本 0.4.4")
    precondition(
      UserFacingText.value("无法原子替换应用：不允许操作。")
        == "无法原子替换应用：不允许操作。")
    precondition(
      UserFacingText.releaseNotes("## IsLandToken 0.4.4\n\n### 中文\n\n- 中文说明\n\n### English\n\n- English notes")
        == "- 中文说明")
    print("PASS Chinese toolbar and runtime localization")
  }
}
