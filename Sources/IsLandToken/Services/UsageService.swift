import Foundation
import IslandCore
import LocalAuthentication
import Security

enum UsageService {
  static func resolveCLI(custom: String = "") -> String? {
    let home = FileManager.default.homeDirectoryForCurrentUser.path
    let candidates = [
      custom, Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/CodexBarCLI").path,
      "/Applications/CodexBar.app/Contents/Helpers/CodexBarCLI",
      home + "/Applications/CodexBar.app/Contents/Helpers/CodexBarCLI",
      "/opt/homebrew/bin/codexbar", "/usr/local/bin/codexbar",
    ]
    return candidates.first {
      !$0.isEmpty
        && FileManager.default.isExecutableFile(atPath: NSString(string: $0).expandingTildeInPath)
    }.map { NSString(string: $0).expandingTildeInPath }
  }
  static func fetch(_ provider: Provider, preferences: Preferences) async throws -> UsageReading {
    if preferences.source == "direct" && provider.supportsDirect {
      return try await direct(provider)
    }
    if let cli = resolveCLI(custom: preferences.cliPath) {
      var arguments = ["usage", "--provider", provider.rawValue, "--format", "json"]
      arguments += ["--source", "auto"]
      let data = try await ProcessRunner.run(cli, arguments: arguments)
      return try UsageParser.codexBar(data, provider: provider)
    }
    if provider.supportsDirect && preferences.source != "codexbar" {
      return try await direct(provider)
    }
    throw UsageError.message("未找到 CodexBar 采集程序，请安装 CodexBar 或配置 CLI 路径。")
  }
  static func cost(_ provider: Provider, preferences: Preferences) async throws -> CostReading {
    guard let cli = resolveCLI(custom: preferences.cliPath) else {
      throw UsageError.message("Token 与费用统计需要 CodexBar 采集程序。")
    }
    let data = try await ProcessRunner.run(
      cli, arguments: ["cost", "--provider", provider.rawValue, "--format", "json"], timeout: 90)
    guard let root = try JSONSerialization.jsonObject(with: data) as? [[String: Any]],
      let entry = root.first(where: { $0["provider"] as? String == provider.rawValue }),
      entry["error"] == nil || entry["error"] is NSNull
    else { throw UsageError.message("尚无可用费用记录，或此版本不支持该平台。") }
    return try JSONDecoder().decode(
      CostReading.self, from: JSONSerialization.data(withJSONObject: entry))
  }
  private static func direct(_ provider: Provider) async throws -> UsageReading {
    let token = try await Task.detached(priority: .utility) { try credentials(provider) }.value
    let endpoint =
      provider == .codex
      ? "https://chatgpt.com/backend-api/wham/usage" : "https://api.anthropic.com/api/oauth/usage"
    var request = URLRequest(url: URL(string: endpoint)!)
    request.timeoutInterval = 30
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    if provider == .claude {
      request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
      request.setValue("claude-code/2.1.121", forHTTPHeaderField: "User-Agent")
    }
    // Ephemeral session: no cookie persistence or credential-bearing URL cache.
    let configuration = URLSessionConfiguration.ephemeral
    configuration.httpCookieStorage = nil
    let session = URLSession(
      configuration: configuration, delegate: NoRedirectDelegate(), delegateQueue: nil)
    defer { session.invalidateAndCancel() }
    let data: Data
    let response: URLResponse
    do { (data, response) = try await session.data(for: request) } catch {
      throw UsageError.message("网络连接失败，请检查网络或代理设置。")
    }
    let status = (response as? HTTPURLResponse)?.statusCode ?? 0
    guard status == 200 else { throw UsageError.message(UsageParser.safeError("HTTP \(status)")) }
    return try provider == .codex ? UsageParser.directCodex(data) : UsageParser.directClaude(data)
  }
  private static func credentials(_ provider: Provider) throws -> String {
    let environment = ProcessInfo.processInfo.environment
    let home = FileManager.default.homeDirectoryForCurrentUser
    if provider == .codex {
      let base =
        environment["CODEX_HOME"].map { URL(fileURLWithPath: $0) }
        ?? home.appendingPathComponent(".codex")
      if let data = try? Data(contentsOf: base.appendingPathComponent("auth.json")),
        let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
        let tokens = root["tokens"] as? [String: Any],
        let token = tokens["access_token"] as? String, !token.isEmpty
      {
        return token
      }
      throw UsageError.message("未找到 Codex OAuth 登录，请先运行 codex login。")
    }
    if let token = environment["CLAUDE_CODE_OAUTH_TOKEN"], !token.isEmpty { return token }
    let base =
      environment["CLAUDE_CONFIG_DIR"].map { URL(fileURLWithPath: $0) }
      ?? home.appendingPathComponent(".claude")
    if let data = try? Data(contentsOf: base.appendingPathComponent(".credentials.json")),
      let token = claudeToken(data)
    {
      return token
    }
    let context = LAContext()
    context.interactionNotAllowed = true
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: "Claude Code-credentials", kSecReturnData as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne, kSecUseAuthenticationContext as String: context,
    ]
    var result: CFTypeRef?
    if SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
      let data = result as? Data, let token = claudeToken(data)
    {
      return token
    }
    throw UsageError.message("未找到可读取的 Claude 登录，请运行 claude 或在 CodexBar 配置账号。")
  }
  private static func claudeToken(_ data: Data) -> String? {
    guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let oauth = root["claudeAiOauth"] as? [String: Any],
      let token = oauth["accessToken"] as? String, !token.isEmpty
    else { return nil }
    return token
  }
}

private final class NoRedirectDelegate: NSObject, URLSessionTaskDelegate {
  func urlSession(
    _ session: URLSession, task: URLSessionTask,
    willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
    completionHandler: @escaping (URLRequest?) -> Void
  ) { completionHandler(nil) }
}
