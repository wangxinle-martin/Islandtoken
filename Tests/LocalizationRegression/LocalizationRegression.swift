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
    precondition(UserFacingText.quotaTitle("5 小时额度") == "5-hour quota")
    precondition(UserFacingText.quotaTitle("Sonnet · 7 天") == "Sonnet · 7 days")
    precondition(UserFacingText.source("直接读取 · OAuth") == "Direct · OAuth")
    precondition(UserFacingText.source("CodexBar · auto") == "CodexBar · Automatic")
    precondition(
      UserFacingText.refreshDescription("自适应 · 活跃 · 1 分钟")
        == "Adaptive · Active · 1 min")
    precondition(UserFacingText.value("发现新版本 0.4.3") == "New version 0.4.3 available")
    precondition(
      UserFacingText.value("正在下载… 73%") == "Downloading… 73%")
    let englishDate = UserFacingText.dateTime(Date(timeIntervalSince1970: 1_700_000_000))
    precondition(!englishDate.unicodeScalars.contains { (0x4E00...0x9FFF).contains($0.value) })
    print("PASS English toolbar and runtime localization")

    defaults.set(InterfaceLanguage.chinese.rawValue, forKey: "interfaceLanguage")
    precondition(T("显示") == "显示")
    precondition(T("隐藏") == "隐藏")
    precondition(UserFacingText.quotaTitle("5 小时额度") == "5 小时额度")
    precondition(UserFacingText.source("CodexBar · auto") == "CodexBar · 自动")
    precondition(UserFacingText.value("发现新版本 0.4.3") == "发现新版本 0.4.3")
    print("PASS Chinese toolbar and runtime localization")
  }
}
