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
      !$0.isEmpty && FileManager.default.isExecutableFile(atPath: NSString(string: $0).expandingTildeInPath)
    }.map { NSString(string: $0).expandingTildeInPath }
  }
  static func fetch(_ provider: Provider, preferences: Preferences) async throws -> UsageReading {
    if provider.supportsLocalCollection {
      do { return try await direct(provider) } catch {
        if let cli = resolveCLI(custom: preferences.cliPath) {
          return try await codexBar(provider, cli: cli)
        }
        throw error
      }
    }
    guard let cli = resolveCLI(custom: preferences.cliPath) else {
      throw UsageError.message("未找到本地登录或 CodexBar 采集程序。")
    }
    return try await codexBar(provider, cli: cli)
  }
  private static func codexBar(_ provider: Provider, cli: String) async throws -> UsageReading {
    let data = try await ProcessRunner.run(
      cli, arguments: ["usage", "--provider", provider.rawValue, "--format", "json", "--source", "auto"])
    return try UsageParser.codexBar(data, provider: provider)
  }
  private static func direct(_ provider: Provider) async throws -> UsageReading {
    let localCredentials = try await Task.detached(priority: .utility) {
      try credentials(provider)
    }.value
    let endpoint =
      provider == .codex
      ? "https://chatgpt.com/backend-api/wham/usage" : "https://api.anthropic.com/api/oauth/usage"
    var request = URLRequest(url: URL(string: endpoint)!)
    request.timeoutInterval = 30
    request.setValue("Bearer \(localCredentials.accessToken)", forHTTPHeaderField: "Authorization")
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
    var reading = try provider == .codex ? UsageParser.directCodex(data) : UsageParser.directClaude(data)
    // The quota endpoints intentionally omit profile data. Use only the email claim already
    // present in the local OAuth identity token; do not make a second profile request.
    reading.accountEmail = localCredentials.accountEmail
    return reading
  }
  private static func credentials(_ provider: Provider) throws -> LocalCredentials {
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
        return .init(accessToken: token, accountEmail: email(from: tokens["id_token"] as? String))
      }
      throw UsageError.message("未找到 Codex OAuth 登录，请先运行 codex login。")
    }
    if let token = environment["CLAUDE_CODE_OAUTH_TOKEN"], !token.isEmpty {
      return .init(accessToken: token, accountEmail: email(from: token))
    }
    let base =
      environment["CLAUDE_CONFIG_DIR"].map { URL(fileURLWithPath: $0) }
      ?? home.appendingPathComponent(".claude")
    if let data = try? Data(contentsOf: base.appendingPathComponent(".credentials.json")),
      let credentials = claudeCredentials(data)
    {
      return credentials
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
      let data = result as? Data, let credentials = claudeCredentials(data)
    {
      return credentials
    }
    throw UsageError.message("未找到可读取的 Claude 登录，请先在本机运行 claude 登录。")
  }
  private static func claudeCredentials(_ data: Data) -> LocalCredentials? {
    guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let oauth = root["claudeAiOauth"] as? [String: Any],
      let token = oauth["accessToken"] as? String, !token.isEmpty
    else { return nil }
    return .init(accessToken: token, accountEmail: email(from: oauth["idToken"] as? String))
  }
  private static func email(from identityToken: String?) -> String? {
    guard let identityToken else { return nil }
    let parts = identityToken.split(separator: ".")
    guard parts.count >= 2 else { return nil }
    var encoded = String(parts[1])
      .replacingOccurrences(of: "-", with: "+")
      .replacingOccurrences(of: "_", with: "/")
    encoded += String(repeating: "=", count: (4 - encoded.count % 4) % 4)
    guard let data = Data(base64Encoded: encoded),
      let claims = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let value = claims["email"] as? String
    else { return nil }
    let email = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return email.contains("@") && !email.contains(" ") ? email : nil
  }
}

private struct LocalCredentials: Sendable {
  let accessToken: String
  let accountEmail: String?
}

private final class NoRedirectDelegate: NSObject, URLSessionTaskDelegate {
  func urlSession(
    _ session: URLSession, task: URLSessionTask,
    willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
    completionHandler: @escaping (URLRequest?) -> Void
  ) { completionHandler(nil) }
}
