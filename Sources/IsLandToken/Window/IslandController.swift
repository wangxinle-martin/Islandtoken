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
  @Published var refreshAnimationActive = false
  @Published var randomRefreshAnimation: RefreshAnimationStyle = .sparkle
  func popupWidth(_ settings: Preferences) -> CGFloat {
    width(settings)
  }
  func width(_ settings: Preferences) -> CGFloat {
    let contentWidth =
      notchWidth
      + leftWidth(settings)
      + rightWidth(settings)
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

  func sparkleWidth(_ settings: Preferences) -> CGFloat {
    let style = settings.refreshAnimation == .random ? randomRefreshAnimation : settings.refreshAnimation
    return style == .sparkle && refreshAnimationActive ? 28 : 0
  }

  func centeredCompactInset(_ settings: Preferences) -> CGFloat {
    settings.islandSideVisibility == .both && !expanded ? 6 : 0
  }

  func singleExpandedInset(_ settings: Preferences) -> CGFloat {
    settings.islandSideVisibility == .left && expanded ? 6 : 0
  }

  func leftWidth(_ settings: Preferences) -> CGFloat {
    guard settings.islandSideVisibility != .right else { return 0 }
    return sideWidth(settings.left, settings: settings)
      + centeredCompactInset(settings)
      - singleExpandedInset(settings)
      + (settings.islandSideVisibility == .left
        ? sideWidth(settings.right, settings: settings) + sparkleWidth(settings) : 0)
  }
  func rightWidth(_ settings: Preferences) -> CGFloat {
    guard settings.islandSideVisibility != .left else { return 0 }
    return sideWidth(settings.right, settings: settings)
      + centeredCompactInset(settings)
      + (settings.islandSideVisibility == .right ? sideWidth(settings.left, settings: settings) : 0)
      + sparkleWidth(settings)
  }
  func horizontalOffset(_ settings: Preferences) -> CGFloat {
    let base = (rightWidth(settings) - leftWidth(settings)) / 2
    let sparkle = sparkleWidth(settings) / 2
    switch settings.islandSideVisibility {
    case .left: return base + sparkle
    case .right: return base - sparkle
    case .both: return base
    }
  }
  // Hover reveals the extra text horizontally; keep the capsule height aligned
  // with the native macOS notch in every compact state.
  var headlineHeight: CGFloat { topHeight }
  var height: CGFloat { headlineHeight + (expanded ? popupHeight : 0) }

}

final class IslandPanel: NSPanel {
  var commandR: (() -> Void)?
  var commandQ: (() -> Void)?
  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { false }

  override func performKeyEquivalent(with event: NSEvent) -> Bool {
    let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
    guard modifiers.contains(.command), let key = event.charactersIgnoringModifiers?.lowercased()
    else { return super.performKeyEquivalent(with: event) }
    switch key {
    case "r":
      commandR?()
      return true
    case "q":
      commandQ?()
      return true
    default: return super.performKeyEquivalent(with: event)
    }
  }
}

/// AppKit is limited to non-activating panel placement, display changes and shape-aware mouse passthrough.
@MainActor
final class IslandController {
  let state = IslandState()
  let panel: IslandPanel
  private let store: AppStore
  private var subscriptions: Set<AnyCancellable> = []
  private var monitors: [Any] = []
  private weak var pressedPopupButton: NSButton?
  private var consumedHeadlinePress = false
  private var observers: [NSObjectProtocol] = []
  private var collapseTask: Task<Void, Never>?
  private var startupTimer: Timer?
  private var locked = false

  private func refreshFromIsland() {
    guard !store.refreshing, !store.demoMode else { return }
    Task { @MainActor [weak self] in
      guard let self else { return }
      await store.refresh()
      store.schedule()
      await store.refreshCosts()
    }
  }

  init(store: AppStore) {
    self.store = store
    panel = IslandPanel(
      contentRect: NSRect(x: 0, y: 0, width: 580, height: 370),
      // A regular borderless panel is required for macOS to deliver ⌘R/⌘Q
      // after the compact island receives focus. Mouse passthrough remains
      // controlled by IslandHost.hitTest and updatePointer().
      styleMask: [.borderless], backing: .buffered, defer: false)
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
    panel.commandR = { [weak self] in self?.refreshFromIsland() }
    panel.commandQ = { NSApp.terminate(nil) }
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
    store.$randomRefreshAnimation.receive(on: RunLoop.main)
      .sink { [weak self] style in self?.state.randomRefreshAnimation = style }
      .store(in: &subscriptions)
    Publishers.CombineLatest3(
      store.$refreshing, store.$refreshingCost, store.$animationPreviewActive
    ).map { $0 || $1 || $2 }
      .removeDuplicates()
      .receive(on: RunLoop.main)
      .sink { [weak self] active in self?.state.refreshAnimationActive = active }
      .store(in: &subscriptions)
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
      matching: eventMask.union(.keyDown),
      handler: { [weak self] event in
        Task { @MainActor in
          guard let self else { return }
          self.startupTimer?.invalidate()
          self.updatePointer()
          let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
          if event.type == .keyDown,
            event.keyCode == 15,
            modifiers.contains(.command),
            self.state.hovering || self.panel.isKeyWindow,
            !self.store.refreshing,
            !self.store.demoMode
          {
            self.refreshFromIsland()
          }
        }
      })
    {
      monitors.append(monitor)
    }
    if let monitor = NSEvent.addLocalMonitorForEvents(
      matching: eventMask.union([.keyDown, .leftMouseUp]),
      handler: { [weak self] event in
        if event.type == .leftMouseUp, let self, self.consumedHeadlinePress {
          self.consumedHeadlinePress = false
          return nil
        }
        if event.type == .leftMouseDown, let self, event.window === self.panel {
          let point = self.panel.convertPoint(toScreen: event.locationInWindow)
          let width = self.state.width(self.store.preferences)
          let x = point.x - self.panel.frame.midX - self.state.horizontalOffset(self.store.preferences) + width / 2
          let y = self.panel.frame.maxY - point.y
          if x >= 0, x <= width, y >= 0, y <= self.state.headlineHeight {
            self.consumedHeadlinePress = true
            self.collapseTask?.cancel()
            if event.clickCount == 2 {
              self.refreshFromIsland()
            } else if self.store.preferences.clickExpand || self.state.expanded {
              self.state.expanded.toggle()
              self.state.pinned = self.state.expanded
              self.state.headlineRevealed = true
            }
            return nil
          }
        }
        // Route native popup controls before activation or hover updates can alter their layout.
        if let self, event.window === self.panel {
          let point = self.panel.convertPoint(toScreen: event.locationInWindow)
          let hit = (self.panel.contentView as? IslandHost)?.popupButton(atScreenPoint: point)
          if event.type == .leftMouseDown, let button = hit {
            self.collapseTask?.cancel()
            self.pressedPopupButton = button
            button.highlight(button.isEnabled)
            return nil
          }
          if event.type == .leftMouseUp, let button = self.pressedPopupButton {
            self.pressedPopupButton = nil
            button.highlight(false)
            if hit === button, button.isEnabled { button.performClick(nil) }
            return nil
          }
        }

        if event.type == .keyDown,
          event.keyCode == 15,
          event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.command),
          let self,
          event.window === self.panel,
          !self.store.refreshing,
          !self.store.demoMode
        {
          self.refreshFromIsland()
          return nil
        }
        if event.type == .keyDown && event.keyCode == 53 {
          self?.state.expanded = false
          self?.state.pinned = false
        }
        self?.updatePointer()
        if event.type == .leftMouseDown, let self, event.window === self.panel {
          // A non-activating panel does not become key automatically. Make the
          // compact island focused before it handles expand/collapse, so ⌘R
          // is delivered to the island even while it remains compact.
          NSApp.activate(ignoringOtherApps: true)
          self.panel.makeKeyAndOrderFront(nil)
          self.panel.makeMain()
        }
        if event.type == .leftMouseDown, let self,
          event.window === self.panel, self.state.expanded,
          self.panel.frame.maxY - NSEvent.mouseLocation.y > self.state.headlineHeight
        {
          self.panel.makeKey()
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
    let buttonHit = (panel.contentView as? IslandHost)?.popupButton(atScreenPoint: location) != nil
    let inside = buttonHit || IslandShape(expanded: state.expanded).path(in: rect).contains(local)
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
  func popupButton(atScreenPoint point: NSPoint) -> NSButton? {
    guard state.expanded, let window else { return nil }
    let windowPoint = window.convertPoint(fromScreen: point)
    return popupButton(in: self, windowPoint: windowPoint)
  }

  private func popupButton(in view: NSView, windowPoint: NSPoint) -> NSButton? {
    guard !view.isHidden, view.alphaValue > 0 else { return nil }
    if let button = view as? NSButton,
      button.bounds.contains(button.convert(windowPoint, from: nil)) {
      return button
    }
    for child in view.subviews.reversed() {
      if let button = popupButton(in: child, windowPoint: windowPoint) { return button }
    }
    return nil
  }

  override func hitTest(_ point: NSPoint) -> NSView? {
    // AppKit supplies this point in the superview's coordinate system.
    // NSHostingView is flipped, while the panel's frame view is not.
    let pointInHost = convert(point, from: superview)
    if state.expanded,
      let button = popupButton(in: self, windowPoint: convert(pointInHost, to: nil)) {
      return button
    }
    let width = state.width(store.preferences)
    let rect = CGRect(x: 0, y: 0, width: width, height: state.height)
    let local = CGPoint(
      x: pointInHost.x - bounds.midX - state.horizontalOffset(store.preferences) + width / 2,
      y: isFlipped ? pointInHost.y - bounds.minY : bounds.maxY - pointInHost.y)
    guard IslandShape(expanded: state.expanded).path(in: rect).contains(local) else { return nil }
    return super.hitTest(point)
  }
}
