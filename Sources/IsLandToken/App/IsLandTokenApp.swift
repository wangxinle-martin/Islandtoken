import AppKit
import Combine
import IslandCore
import SwiftUI
import UserNotifications

@main
@MainActor
enum IsLandTokenLauncher {
  private static var singleInstance: SingleInstanceCoordinator?

  static func main() {
    if AppUpdateInstaller.runHelperIfRequested() { return }
    AppUpdateInstaller.recoverInterruptedTransactionIfNeeded()
    let coordinator = SingleInstanceCoordinator()
    let updateHelper = AppUpdateInstaller.validatedUpdateHelperExecutable()
    guard coordinator.claimPrimaryInstance(ignoringLegacyExecutable: updateHelper) else {
      return
    }
    singleInstance = coordinator
    IsLandTokenApp.main()
  }
}

struct IsLandTokenApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
  @StateObject private var store = AppStore.shared
  @AppStorage("interfaceLanguage") private var interfaceLanguage = InterfaceLanguage.chinese.rawValue
  var body: some Scene {
    MenuBarExtra(isInserted: $store.preferences.showMenuBarIcon) {
      Group {
      Button(T("打开设置")) { delegate.showDashboard() }.keyboardShortcut("o")
      Button(T("展开 / 收起灵动岛")) { delegate.island?.toggleExpanded() }
      Button(T(store.refreshing ? "正在同步…" : "立即刷新")) {
        Task {
          await store.refresh()
          store.schedule()
        }
      }.disabled(store.refreshing || store.demoMode).keyboardShortcut("r")
      Divider()
      ForEach(Array([store.preferences.left, store.preferences.right].enumerated()), id: \.offset) {
        _, side in
        Text(
          "\(side.provider.name)  \(side.headlineText(reading: store.readings[side.provider], remaining: store.preferences.remaining, revealed: true))"
        )
      }
      Divider()
      Toggle(T("显示灵动岛"), isOn: $store.preferences.showIsland)
      Button(T("设置…")) { delegate.showDashboard() }.keyboardShortcut(",")
      Button(T("退出 IsLandToken")) { NSApp.terminate(nil) }.keyboardShortcut("q")
      }
      .id(interfaceLanguage)
    } label: {
      Image(nsImage: IslandIcon.menuBarImage)
        .renderingMode(.template)
        .resizable()
        .scaledToFit()
        .frame(width: 10, height: 9)
        .accessibilityLabel("IsLandToken")
    }
    .commands {
      // Keep the application menu's Settings command on the same presentation
      // path as the menu-bar and Island controls. A SwiftUI Settings scene can
      // be shown without activating a regular menu-bar app on its first open.
      CommandGroup(replacing: .appSettings) {
        Button(T("设置…")) { delegate.showDashboard() }.keyboardShortcut(",")
      }
    }
  }
}

/// Keeps the first control click actionable when a settings window is opened
/// from a non-activating menu-bar-extra menu.
private final class DashboardHostingView: NSHostingView<DashboardView> {
  override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    removeAutomaticSidebarControls()
  }

  override func layout() {
    super.layout()
    // SwiftUI may install its standard sidebar item after attaching the view.
    removeAutomaticSidebarControls()
  }

  private func removeAutomaticSidebarControls() {
    DispatchQueue.main.async { [weak self] in
      guard let toolbar = self?.window?.toolbar else { return }
      for index in toolbar.items.indices.reversed()
      where toolbar.items[index] is NSTrackingSeparatorToolbarItem
        || toolbar.items[index].itemIdentifier == .toggleSidebar
        || toolbar.items[index].itemIdentifier.rawValue == "com.apple.SwiftUI.navigationSplitView.toggleSidebar"
      {
        toolbar.removeItem(at: index)
      }
    }
  }
}

/// Native translucent material behind the settings hierarchy. Keeping the
/// SwiftUI host as a child preserves its first-mouse behavior while the AppKit
/// material supplies the same adaptive vibrancy used by modern macOS windows.
private final class DashboardGlassContainer: NSVisualEffectView {
  init(hostingView: DashboardHostingView) {
    super.init(frame: .zero)
    material = .underWindowBackground
    blendingMode = .behindWindow
    state = .active
    wantsLayer = true
    addSubview(hostingView)
    hostingView.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      hostingView.leadingAnchor.constraint(equalTo: leadingAnchor),
      hostingView.trailingAnchor.constraint(equalTo: trailingAnchor),
      hostingView.topAnchor.constraint(equalTo: topAnchor),
      hostingView.bottomAnchor.constraint(equalTo: bottomAnchor),
    ])
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

/// Ensures the first click on a newly presented Settings window is delivered
/// to the SwiftUI control that was clicked, instead of being consumed only to
/// activate the application.
private final class DashboardWindow: NSWindow {
  override func sendEvent(_ event: NSEvent) {
    if event.type == .leftMouseDown, !isKeyWindow {
      NSApp.activate(ignoringOtherApps: true)
      makeKeyAndOrderFront(nil)
    }
    super.sendEvent(event)
  }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
  static weak var shared: AppDelegate?
  var island: IslandController?
  private var dashboard: NSWindow?
  private var wakeObserver: NSObjectProtocol?
  private var verificationTimer: Timer?
  private var resetSubscription: AnyCancellable?
  private var updateSubscription: AnyCancellable?
  private var updateWindow: NSWindow?
  private var notifiedVersions: Set<String> = []
  private var dashboardPresentationPending = false
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
    updateSubscription = AppUpdater.shared.$available.compactMap { $0 }.sink {
      [weak self] release in
      self?.showUpdateNotice(release)
    }
    if AppUpdateInstaller.isValidatedUpdateRelaunch() {
      notifyUpdateCompleted(version: AppUpdater.currentVersion)
    }
    AppUpdater.shared.startAutomaticChecks()
    if store.preferences.openDashboardOnLaunch {
      showDashboard()
    }
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
      showDashboard()
      // A live process is insufficient: this timer must execute AFTER scene reconciliation.
      verificationTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: false) {
        [weak self] _ in
        MainActor.assumeIsolated {
          guard let dashboard = self?.dashboard, dashboard.isVisible,
            NSApp.activationPolicy() == .regular,
            dashboard.contentView?.acceptsFirstMouse(for: nil) == true,
            NSApp.applicationIconImage != nil,
            dashboard.toolbar?.items.contains(where: { $0 is NSTrackingSeparatorToolbarItem }) == false
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
    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
      if !AppUpdateInstaller.handleLaunchAcknowledgementIfRequested() {
        AppUpdateInstaller.commitRecoveredTransactionIfNeeded()
      }
    }
  }
  func showConfetti() {
    let preferences = AppStore.shared.preferences
    confetti.play(
      originInScreen: nil,
      colors: [
        preferences.providerColor(preferences.left.provider),
        preferences.providerColor(preferences.right.provider),
      ])
  }
  private func showUpdateNotice(_ release: AppUpdater.Release) {
    guard notifiedVersions.insert(release.version).inserted else { return }
    updateWindow?.close()
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 400, height: 230),
      styleMask: [.titled, .closable, .miniaturizable], backing: .buffered,
      defer: false)
    window.title = "IsLandToken 更新"
    window.isReleasedWhenClosed = false
    window.level = .normal
    window.contentView = NSHostingView(
      rootView: UpdateNoticeView(release: release) { [weak window] in
        window?.close()
      })
    window.center()
    updateWindow = window
    window.orderFront(nil)
  }
  private func notifyUpdateCompleted(version: String) {
    let center = UNUserNotificationCenter.current()
    let deliver = {
      let content = UNMutableNotificationContent()
      content.title = "IsLandToken 更新完成"
      content.body = "已成功安装并启动 IsLandToken \(version)。"
      content.sound = .default
      center.add(
        UNNotificationRequest(
          identifier: "islandtoken-update-completed-\(version)", content: content, trigger: nil))
    }
    center.getNotificationSettings { settings in
      switch settings.authorizationStatus {
      case .authorized, .provisional, .ephemeral:
        deliver()
      case .notDetermined:
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
          if granted { deliver() }
        }
      default:
        break
      }
    }
  }
  func applicationWillTerminate(_ notification: Notification) {
    AppUpdater.shared.stopAutomaticChecks()
  }

  private func finishDashboardPresentation(_ dashboard: NSWindow) {
    guard dashboard.isVisible else {
      dashboardPresentationPending = false
      return
    }
    dashboard.makeKeyAndOrderFront(nil)
    dashboardPresentationPending = false
  }

  private func presentDashboard(_ dashboard: NSWindow) {
    // Give the newly presented window key status before it is exposed. This
    // makes the first sidebar press a normal SwiftUI selection event instead
    // of an activation click when Settings is opened from the Island/menu bar.
    dashboardPresentationPending = true
    NSApp.activate(ignoringOtherApps: true)
    dashboard.makeKeyAndOrderFront(nil)
    if NSApp.isActive { finishDashboardPresentation(dashboard) }
  }

  /// Brings an already-open settings window forward without collapsing the
  /// Island detail popup that initiated the request.
  func focusDashboard() {
    guard let dashboard, dashboard.isVisible else { return }
    presentDashboard(dashboard)
    DispatchQueue.main.async { [weak self, weak dashboard] in
      guard let self, let dashboard else { return }
      self.presentDashboard(dashboard)
    }
  }

  func showDashboard() {
    guard let island else { return }
    island.prepareForDashboardPresentation()
    if dashboard == nil {
      let window = DashboardWindow(
        contentRect: NSRect(x: 0, y: 0, width: 1080, height: 790),
        styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered,
        defer: false)
      window.delegate = self
      window.title = "IsLandToken"
      window.titleVisibility = .hidden
      // The unified split toolbar tracks the sidebar divider when resized.
      window.toolbarStyle = .unified
      window.titlebarAppearsTransparent = true
      window.isOpaque = false
      window.backgroundColor = .clear
      window.isReleasedWhenClosed = false
      // Keep Settings on the standard application window level so AppKit can
      // make it key and route the first sidebar click normally. The Island
      // panel only accepts hits inside its visible shape.
      window.level = .normal
      let hostingView = DashboardHostingView(
        rootView: DashboardView(store: .shared, islandState: island.state))
      window.contentView = DashboardGlassContainer(hostingView: hostingView)
      window.setFrameAutosaveName("IsLandToken.dashboard")
      window.center()
      dashboard = window
    }
    AppStore.shared.dashboardOpen = true
    if let dashboard { presentDashboard(dashboard) }
    DispatchQueue.main.async { [weak self] in
      guard let self, let dashboard = self.dashboard else { return }
      self.presentDashboard(dashboard)
    }
  }
  func applicationDidBecomeActive(_ notification: Notification) {
    guard dashboardPresentationPending, let dashboard else { return }
    finishDashboardPresentation(dashboard)
  }
  func windowWillClose(_ notification: Notification) {
    guard notification.object as? NSWindow === dashboard else { return }
    // NSWindowDelegate has no did-close callback. Defer the state change until
    // AppKit has completed the close cycle, so the Island does not surface
    // above the closing settings window.
    DispatchQueue.main.async { AppStore.shared.dashboardOpen = false }
  }
  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
  func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool
  {
    showDashboard()
    return true
  }
}
