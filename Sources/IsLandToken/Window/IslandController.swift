import AppKit
import Combine
import IslandCore
import SwiftUI

@MainActor
final class IslandState: ObservableObject {
  @Published var expanded = false
  @Published var hovering = false
  @Published var headlineRevealed = false
  @Published var pinned = false
  @Published var notchWidth: CGFloat = 100
  @Published var topHeight: CGFloat = 30
  @Published var screenWidth: CGFloat = 1440
  @Published var popupHeight: CGFloat = 360
  func popupWidth(_ settings: Preferences) -> CGFloat {
    width(settings)
  }
  func width(_ settings: Preferences) -> CGFloat {
    let contentWidth =
      notchWidth
      + sideWidth(settings.left, settings: settings)
      + sideWidth(settings.right, settings: settings)
    // Widen the detail columns together with their clipping and hit-test bounds.
    return min(screenWidth - 24, contentWidth * (expanded ? 1.10 : 1))
  }
  func sideWidth(_ side: SideConfiguration, settings: Preferences) -> CGFloat {
    let revealed = headlineRevealed || expanded
    let reading = AppStore.shared.readings[side.provider]
    let headline = side.headlineText(
      reading: reading, remaining: settings.remaining, revealed: revealed)
    let font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
    var content = CGFloat((headline as NSString).size(withAttributes: [.font: font]).width)
    if side.style != .number && side.style != .dualPeriod {
      let gauge: CGFloat =
        side.style == .segments ? 36 : side.style == .bar ? 28 : side.style == .ring ? 19 : 30
      content = revealed ? content + gauge + 4 : gauge
    }
    if revealed {
      if side.showIcon { content += 17 }
      if side.showName {
        let name = side.provider == .antigravity ? "Anti" : side.provider.name
        content +=
          (name as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: 9)]).width + 4
      }
      if side.style != .dualPeriod { content += 10 }
      content += 7  // Stale indicator and spacing.
    }
    // Account for paired spacing and the curved outer corners.
    return ceil(content) + 28
  }

  func leftWidth(_ settings: Preferences) -> CGFloat {
    guard settings.islandSideVisibility != .right else { return 0 }
    return sideWidth(settings.left, settings: settings)
      + (settings.islandSideVisibility == .left ? sideWidth(settings.right, settings: settings) : 0)
  }
  func rightWidth(_ settings: Preferences) -> CGFloat {
    guard settings.islandSideVisibility != .left else { return 0 }
    return sideWidth(settings.right, settings: settings)
      + (settings.islandSideVisibility == .right ? sideWidth(settings.left, settings: settings) : 0)
  }
  func horizontalOffset(_ settings: Preferences) -> CGFloat {
    (rightWidth(settings) - leftWidth(settings)) / 2
  }
  // Hover reveals the extra text horizontally; keep the capsule height aligned
  // with the native macOS notch in every compact state.
  var headlineHeight: CGFloat { topHeight }
  var height: CGFloat { headlineHeight + (expanded ? popupHeight : 0) }

}

private final class IslandPanel: NSPanel {
  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { false }
}

/// AppKit is limited to non-activating panel placement, display changes and shape-aware mouse passthrough.
@MainActor
final class IslandController {
  let state = IslandState()
  let panel: NSPanel
  private let store: AppStore
  private var subscriptions: Set<AnyCancellable> = []
  private var monitors: [Any] = []
  private var observers: [NSObjectProtocol] = []
  private var collapseTask: Task<Void, Never>?
  private var startupTimer: Timer?
  private var locked = false

  init(store: AppStore) {
    self.store = store
    panel = IslandPanel(
      contentRect: NSRect(x: 0, y: 0, width: 580, height: 370),
      styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    panel.backgroundColor = .clear
    panel.isOpaque = false
    panel.hasShadow = false
    panel.level = .popUpMenu
    panel.collectionBehavior = [
      .canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle,
    ]
    panel.hidesOnDeactivate = false
    panel.isReleasedWhenClosed = false
    panel.acceptsMouseMovedEvents = true
    panel.becomesKeyOnlyIfNeeded = false
    let host = IslandHost(
      rootView: IslandView(store: store, state: state), state: state, store: store)
    panel.contentView = host
    store.$storedPreferences.removeDuplicates().receive(on: RunLoop.main).sink {
      [weak self] settings in
      if settings.detailInteraction == .none {
        self?.state.expanded = false
        self?.state.pinned = false
      }
      self?.reposition()
    }.store(in: &subscriptions)
    state.$expanded.receive(on: RunLoop.main).sink { [weak self] _ in self?.updatePointer() }.store(
      in: &subscriptions)
    observers.append(
      NotificationCenter.default.addObserver(
        forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
      ) { [weak self] _ in Task { @MainActor in self?.reposition() } })
    for name in ["com.apple.screenIsLocked", "com.apple.screenIsUnlocked"] {
      observers.append(
        DistributedNotificationCenter.default().addObserver(
          forName: NSNotification.Name(name), object: nil, queue: .main
        ) { [weak self] notification in
          Task { @MainActor in
            self?.locked = notification.name.rawValue.hasSuffix("IsLocked")
            self?.reposition()
          }
        })
    }
    let eventMask: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDown, .rightMouseDown]
    if let monitor = NSEvent.addGlobalMonitorForEvents(
      matching: eventMask,
      handler: { [weak self] _ in
        Task { @MainActor in
          self?.startupTimer?.invalidate()
          self?.updatePointer()
        }
      })
    {
      monitors.append(monitor)
    }
    if let monitor = NSEvent.addLocalMonitorForEvents(
      matching: eventMask.union(.keyDown),
      handler: { [weak self] event in
        if event.type == .keyDown && event.keyCode == 53 {
          self?.state.expanded = false
          self?.state.pinned = false
        }
        self?.updatePointer()
        if event.type == .leftMouseDown, let self,
          event.window === self.panel, self.state.expanded,
          self.panel.frame.maxY - NSEvent.mouseLocation.y > self.state.headlineHeight
        {
          self.panel.makeKey()
        }
        if event.type == .leftMouseDown, event.window === self?.panel,
          let self, self.state.hovering,
          self.panel.frame.maxY - NSEvent.mouseLocation.y <= self.state.headlineHeight,
          self.store.preferences.clickExpand || self.state.expanded
        {
          self.collapseTask?.cancel()
          self.state.expanded.toggle()
          self.state.pinned = self.state.expanded
          return nil
        }
        return event
      })
    {
      monitors.append(monitor)
    }
    startupTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
      Task { @MainActor in self?.updatePointer() }
    }
    reposition()
  }
  func reposition() {
    let screen =
      NSScreen.screens.first { String($0.displayID) == store.preferences.screenID }
      ?? NSScreen.screens.first { $0.safeAreaInsets.top > 0 } ?? NSScreen.main
    guard let screen else { return }
    let safe = screen.safeAreaInsets.top
    let left = screen.auxiliaryTopLeftArea?.width ?? 0
    let right = screen.auxiliaryTopRightArea?.width ?? 0
    state.notchWidth =
      safe > 0 ? (left > 0 && right > 0 ? screen.frame.width - left - right : 200) : 50
    state.topHeight = max(
      26,
      IslandGeometry.menuHeight(
        safeTop: safe, visibleDelta: screen.frame.maxY - screen.visibleFrame.maxY,
        statusBar: NSStatusBar.system.thickness))
    state.screenWidth = screen.frame.width
    let width = screen.frame.width
    panel.setFrame(
      NSRect(
        x: screen.frame.midX - width / 2, y: screen.frame.minY - store.preferences.verticalOffset,
        width: width, height: screen.frame.height), display: true)
    if store.preferences.showIsland && !locked {
      panel.orderFrontRegardless()
    } else {
      panel.orderOut(nil)
    }
    updatePointer()
  }
  func toggleExpanded() {
    guard store.preferences.detailInteraction != .none else { return }
    if !store.preferences.showIsland { store.preferences.showIsland = true }
    state.expanded.toggle()
    state.pinned = state.expanded
    reposition()
  }
  private func updatePointer() {
    let location = NSEvent.mouseLocation
    let local = CGPoint(
      x: location.x - panel.frame.midX - state.horizontalOffset(store.preferences) + state.width(
        store.preferences) / 2, y: panel.frame.maxY - location.y)
    let rect = CGRect(x: 0, y: 0, width: state.width(store.preferences), height: state.height)
    let inside = IslandShape(expanded: state.expanded).path(in: rect).contains(local)
    panel.ignoresMouseEvents = !inside
    guard inside != state.hovering else { return }
    state.hovering = inside
    collapseTask?.cancel()
    if inside {
      state.headlineRevealed = true
      if store.preferences.hoverExpand { state.expanded = true }
    } else if !state.pinned {
      collapseTask = Task { [weak self] in
        try? await Task.sleep(for: .milliseconds(450))
        guard !Task.isCancelled, let self, !self.state.hovering else { return }
        let wasExpanded = self.state.expanded
        self.state.expanded = false
        // Keep the header intact until the detail panel finishes collapsing.
        if wasExpanded && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
          try? await Task.sleep(for: .milliseconds(550))
        }
        guard !Task.isCancelled, !self.state.hovering, !self.state.expanded, !self.state.pinned
        else { return }
        self.state.headlineRevealed = false
      }
    }
  }
}

extension NSScreen {
  var displayID: UInt32 {
    (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0
  }
}

private final class IslandHost: NSHostingView<IslandView> {
  let state: IslandState
  let store: AppStore
  init(rootView: IslandView, state: IslandState, store: AppStore) {
    self.state = state
    self.store = store
    super.init(rootView: rootView)
  }
  @MainActor required init(rootView: IslandView) { fatalError("Use designated initializer") }
  @MainActor required dynamic init?(coder: NSCoder) { fatalError("Not supported") }
  override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
  override func hitTest(_ point: NSPoint) -> NSView? {
    // AppKit supplies this point in the superview's coordinate system.
    // NSHostingView is flipped, while the panel's frame view is not.
    let pointInHost = convert(point, from: superview)
    let width = state.width(store.preferences)
    let rect = CGRect(x: 0, y: 0, width: width, height: state.height)
    let local = CGPoint(
      x: pointInHost.x - bounds.midX - state.horizontalOffset(store.preferences) + width / 2,
      y: isFlipped ? pointInHost.y - bounds.minY : bounds.maxY - pointInHost.y)
    guard IslandShape(expanded: state.expanded).path(in: rect).contains(local) else { return nil }
    return super.hitTest(point)
  }
}
