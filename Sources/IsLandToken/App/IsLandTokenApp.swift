import AppKit
import Combine
import IslandCore
import SwiftUI

@main
struct IsLandTokenApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
  @StateObject private var store = AppStore.shared
  var body: some Scene {
    MenuBarExtra(
      "IsLandToken", systemImage: "capsule.inset.filled",
      isInserted: $store.preferences.showMenuBarIcon
    ) {
      Button("打开控制台") { delegate.showDashboard() }.keyboardShortcut("o")
      Button("展开 / 收起灵动岛") { delegate.island?.toggleExpanded() }
      Button(store.refreshing ? "正在同步…" : "立即刷新") {
        Task {
          await store.refresh()
          store.schedule()
        }
      }.disabled(store.refreshing || store.demoMode).keyboardShortcut("r")
      Divider()
      ForEach(Array([store.preferences.left, store.preferences.right].enumerated()), id: \.offset) {
        _, side in
        let value = store.readings[side.provider]?.window(side.windowID)?.percent(
          remaining: store.preferences.remaining)
        Text("\(side.provider.name)  \(value.map { String(format: "%.0f%%", $0) } ?? "—")")
      }
      Divider()
      Toggle("显示灵动岛", isOn: $store.preferences.showIsland)
      SettingsLink { Text("设置…") }.keyboardShortcut(",")
      Button("退出 IsLandToken") { NSApp.terminate(nil) }.keyboardShortcut("q")
    }
    Settings {
      ScrollView { GeneralSettingsView(store: store).padding(24) }.frame(width: 580, height: 650)
    }
  }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  static weak var shared: AppDelegate?
  var island: IslandController?
  private var dashboard: NSWindow?
  private var wakeObserver: NSObjectProtocol?
  private var verificationTimer: Timer?
  private var resetSubscription: AnyCancellable?
  private let confetti = ScreenConfettiOverlayController()
  func applicationDidFinishLaunching(_ notification: Notification) {
    Self.shared = self
    // A regular application participates in Command-Tab and the Force Quit list.
    NSApp.setActivationPolicy(.regular)
    if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
      let icon = NSImage(contentsOf: url)
    {
      NSApp.applicationIconImage = icon
    }
    let store = AppStore.shared
    resetSubscription = store.$resetEvent.dropFirst().sink { [weak self] _ in self?.showConfetti() }
    island = IslandController(store: store)
    if CommandLine.arguments.contains("--demo") { store.setDemo(true) }
    store.start()
    showDashboard()
    if CommandLine.arguments.contains("--verify-popup") {
      island?.state.expanded = true
      island?.state.pinned = true
      island?.panel.makeKeyAndOrderFront(nil)
      DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
        self?.island?.state.expanded = true
        self?.island?.state.pinned = true
        self?.island?.panel.makeKeyAndOrderFront(nil)
      }
      DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
        guard let panel = self?.island?.panel, let root = panel.contentView else { return }
        var lines: [String] = []
        func inspect(_ view: NSView) {
          if let button = view as? NSButton {
            let center = NSPoint(x: button.bounds.midX, y: button.bounds.midY)
            let windowPoint = button.convert(center, to: nil)
            let parentPoint = root.superview?.convert(windowPoint, from: nil) ?? windowPoint
            let hit = root.hitTest(parentPoint)
            let screen = panel.convertPoint(toScreen: windowPoint)
            lines.append(
              "\(button.title): screen=\(screen), hit=\(String(describing: hit)), matches=\(hit === button)"
            )
          }
          view.subviews.forEach(inspect)
        }
        inspect(root)
        try? lines.joined(separator: "\n").write(
          toFile: "/tmp/island-hit-test.txt", atomically: true, encoding: .utf8)
      }

    }
    if let index = CommandLine.arguments.firstIndex(of: "--verify-launch"),
      CommandLine.arguments.count > index + 1
    {
      let output = URL(fileURLWithPath: CommandLine.arguments[index + 1])
      // A live process is insufficient: this timer must execute AFTER scene reconciliation.
      verificationTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: false) {
        [weak self] _ in
        MainActor.assumeIsolated {
          guard self?.dashboard?.isVisible == true, NSApp.activationPolicy() == .regular,
            NSApp.applicationIconImage != nil
          else { return }
          try? Data("main-runloop-responsive\n".utf8).write(to: output, options: .atomic)
          self?.verificationTimer = nil
        }
      }
    }
    wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
      forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
    ) { _ in
      Task { @MainActor in AppStore.shared.schedule(immediate: true) }
    }
  }
  func showConfetti() {
    let preferences = AppStore.shared.preferences
    confetti.play(
      originInScreen: nil,
      colors: [preferences.left.provider.color, preferences.right.provider.color])
  }
  func showDashboard() {
    if dashboard == nil {
      let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 1080, height: 790),
        styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered,
        defer: false)
      window.title = "IsLandToken"
      window.titlebarAppearsTransparent = false
      window.isReleasedWhenClosed = false
      window.contentView = NSHostingView(rootView: DashboardView(store: .shared))
      window.setFrameAutosaveName("IsLandToken.dashboard")
      window.center()
      dashboard = window
    }
    dashboard?.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
  }
  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
  func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool
  {
    showDashboard()
    return true
  }
}
