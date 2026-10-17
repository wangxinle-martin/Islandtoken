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
    let coordinator = SingleInstanceCoordinator()
    let updateHelper = AppUpdateInstaller.validatedUpdateHelperExecutable()
    guard coordinator.claimPrimaryInstance(ignoringLegacyExecutable: updateHelper) else {
      return
    }
    // Only the primary process may recover or delete a staged update. A second
    // launch can otherwise race the real app and disturb its update transaction.
    singleInstance = coordinator
    AppUpdateInstaller.recoverInterruptedTransactionIfNeeded()
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
  private var sidebarControlCleanupScheduled = false

  override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    scheduleAutomaticSidebarControlRemoval()
  }

  override func layout() {
    super.layout()
    // SwiftUI may install its standard sidebar item after attaching the view.
    scheduleAutomaticSidebarControlRemoval()
  }

  private func scheduleAutomaticSidebarControlRemoval() {
    // Resizing and SwiftUI reconciliation can call layout repeatedly in one
    // run-loop turn. Coalesce those passes into one toolbar inspection.
    guard !sidebarControlCleanupScheduled else { return }
    sidebarControlCleanupScheduled = true
    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      self.sidebarControlCleanupScheduled = false
      self.removeAutomaticSidebarControls()
    }
  }

  private func removeAutomaticSidebarControls() {
    guard let toolbar = window?.toolbar else { return }
    for index in toolbar.items.indices.reversed()
    where toolbar.items[index] is NSTrackingSeparatorToolbarItem
      || toolbar.items[index].itemIdentifier == .toggleSidebar
      || toolbar.items[index].itemIdentifier.rawValue == "com.apple.SwiftUI.navigationSplitView.toggleSidebar"
    {
      toolbar.removeItem(at: index)
    }
  }
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
  private var languageObserver: NSObjectProtocol?
  private var verificationTimer: Timer?
  private var resetSubscription: AnyCancellable?
  private var updateSubscription: AnyCancellable?
  private var updateWindow: NSWindow?
  private var notifiedVersions: Set<String> = []
  private var dashboardPresentationPending = false
  private var dashboardPresentationGeneration = 0
  private let confetti = ScreenConfettiOverlayController()
  func applicationDidFinishLaunching(_ notification: Notification) {
    Self.shared = self
    languageObserver = NotificationCenter.default.addObserver(
      forName: UserDefaults.didChangeNotification, object: UserDefaults.standard, queue: .main
    ) { [weak self] _ in
      Task { @MainActor [weak self] in
        self?.updateWindow?.title = T("IsLandToken 更新")
      }
    }
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
      island?.showPopupForVerification()
      DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
        self?.island?.showPopupForVerification()
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
    window.title = T("IsLandToken 更新")
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
      content.title = T("IsLandToken 更新完成")
      content.body = T("已成功安装并启动 IsLandToken %@。", version)
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
    if let languageObserver { NotificationCenter.default.removeObserver(languageObserver) }
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

  private func requestDashboardPresentation(_ dashboard: NSWindow) {
    dashboardPresentationGeneration &+= 1
    let generation = dashboardPresentationGeneration
    presentDashboard(dashboard)
    // Retry only if AppKit has not made this exact presentation key yet. The
    // earlier unconditional retry produced redundant activation and focus work.
    DispatchQueue.main.async { [weak self, weak dashboard] in
      guard let self, let dashboard,
        self.dashboard === dashboard,
        self.dashboardPresentationGeneration == generation,
        dashboard.isVisible,
        !dashboard.isKeyWindow || !NSApp.isActive
      else { return }
      self.presentDashboard(dashboard)
    }
  }

  /// Brings an already-open settings window forward without collapsing the
  /// Island detail popup that initiated the request.
  func focusDashboard() {
    guard let dashboard, dashboard.isVisible else { return }
    requestDashboardPresentation(dashboard)
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
      // Let AppKit draw its adaptive titlebar material. A transparent titlebar
      // with a clear window background leaves the toolbar visually empty.
      window.titlebarAppearsTransparent = false
      window.isOpaque = true
      window.backgroundColor = .windowBackgroundColor
      window.isReleasedWhenClosed = false
      // Keep Settings on the standard application window level so AppKit can
      // make it key and route the first sidebar click normally. The Island
      // panel only accepts hits inside its visible shape.
      window.level = .normal
      // The hosting view must remain the window root: SwiftUI registers this
      // view's toolbar items with the NSWindow. The root DashboardView paints
      // the adaptive system material itself.
      window.contentView = DashboardHostingView(
        rootView: DashboardView(store: .shared, islandState: island.state))
      window.setFrameAutosaveName("IsLandToken.dashboard")
      window.center()
      dashboard = window
    }
    AppStore.shared.dashboardOpen = true
    if let dashboard { requestDashboardPresentation(dashboard) }
  }
  func applicationDidBecomeActive(_ notification: Notification) {
    guard dashboardPresentationPending, let dashboard else { return }
    finishDashboardPresentation(dashboard)
  }
  func windowWillClose(_ notification: Notification) {
    guard let closingDashboard = notification.object as? NSWindow,
      closingDashboard === dashboard
    else { return }
    // Clear our reference before the deferred state update. A reopen that is
    // queued in the same run-loop turn creates a new window and advances the
    // presentation generation, so this old close cannot hide the Island again.
    let generation = dashboardPresentationGeneration
    dashboard = nil
    dashboardPresentationPending = false
    DispatchQueue.main.async { [weak self, weak closingDashboard] in
      guard let self, let closingDashboard,
        self.dashboard == nil,
        !closingDashboard.isVisible,
        self.dashboardPresentationGeneration == generation
      else { return }
      AppStore.shared.dashboardOpen = false
    }
  }
  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
  func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool
  {
    showDashboard()
    return true
  }
}
