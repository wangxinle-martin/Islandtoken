import AppKit
import Combine
import IslandCore
import SwiftUI

@MainActor
final class IslandState: ObservableObject {
  static let pairedHeadlineSpacing: CGFloat = 12

  @Published var expanded = false
  @Published var hovering = false
  @Published var headlineRevealed = false
  @Published var pinned = false
  @Published var notchWidth: CGFloat = 100
  @Published var notchCenterOffset: CGFloat = 0
  @Published var topHeight: CGFloat = 30
  @Published var screenWidth: CGFloat = 1440
  @Published var screenHeight: CGFloat = 900
  @Published var popupHeight: CGFloat = 360
  @Published var popupWidth: CGFloat = 580  // 弹窗内容宽度，由内容自动计算
  @Published var refreshAnimationActive = false
  @Published var randomRefreshAnimation: RefreshAnimationStyle = .sparkle
  var displaysRevealedHeadline: Bool { headlineRevealed || expanded }
  func showDetailsFromHeadline() {
    let keepPinned = expanded && pinned
    headlineRevealed = true
    expanded = true
    pinned = keepPinned
  }
  func width(_ settings: Preferences) -> CGFloat {
    let contentWidth = compactWidth(settings)
    // The detail card may be narrower than a long model headline. The island
    // must contain both instead of letting the headline draw past its shape.
    let desiredWidth = expanded ? max(contentWidth, popupWidth) : contentWidth
    return min(screenWidth - 48, desiredWidth)
  }
  private func compactWidth(_ settings: Preferences) -> CGFloat {
    notchWidth + leftWidth(settings) + rightWidth(settings)
  }
  private func expandedHeaderWidth(_ settings: Preferences) -> CGFloat {
    max(0, width(settings) - compactWidth(settings))
  }
  func leftHeaderExpansion(_ settings: Preferences) -> CGFloat {
    guard expanded else { return 0 }
    switch settings.islandSideVisibility {
    case .left: return expandedHeaderWidth(settings)
    case .both: return expandedHeaderWidth(settings) / 2
    case .right: return 0
    }
  }
  func rightHeaderExpansion(_ settings: Preferences) -> CGFloat {
    guard expanded else { return 0 }
    switch settings.islandSideVisibility {
    case .right: return expandedHeaderWidth(settings)
    case .both: return expandedHeaderWidth(settings) / 2
    case .left: return 0
    }
  }
  func sideWidth(
    _ side: SideConfiguration, settings: Preferences, horizontalPadding: CGFloat = 0
  ) -> CGFloat {
    let revealed = displaysRevealedHeadline
    let store = AppStore.shared
    let reading = store.readings[side.provider]
    return Self.measuredSideWidth(
      side, reading: reading, remaining: settings.remaining, revealed: revealed,
      horizontalPadding: horizontalPadding,
      showsStatusDot: revealed && !store.demoMode
        && (reading?.stale(refreshMinutes: store.effectiveRefreshMinutes) ?? true))
  }

  static func measuredSideWidth(
    _ side: SideConfiguration, reading: UsageReading?, remaining: Bool, revealed: Bool,
    horizontalPadding: CGFloat = 0, showsStatusDot: Bool = false
  ) -> CGFloat {
    let windowIDs = side.displayWindowIDs(reading: reading)
    let headline = side.headlineText(
      reading: reading, remaining: remaining, revealed: revealed)
    // Match DigitFlipText's rounded system design. The default monospaced
    // AppKit font is narrower and used to underestimate every number group.
    let fallbackFont = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
    let roundedDescriptor = fallbackFont.fontDescriptor.withDesign(.rounded)
    let font = roundedDescriptor.flatMap { NSFont(descriptor: $0, size: 12) } ?? fallbackFont
    var content = CGFloat((headline as NSString).size(withAttributes: [.font: font]).width)
    let count = CGFloat(windowIDs.count)
    content += max(0, count - 1) * 8  // spacing around separators
    if side.style != .number {
      let gauge: CGFloat =
        side.style == .segments ? 36 : side.style == .bar ? 28 : side.style == .ring ? 20 : 30
      let missing = windowIDs.filter { reading?.window($0)?.usedPercent == nil }.count
      content =
        revealed
        ? content + (gauge + 4) * count
        : gauge * count + max(0, count - 1) * 16 + CGFloat(missing) * 16
    }
    if revealed {
      if side.showIcon { content += 17 }
      if side.showName {
        let name = side.provider == .antigravity ? "Anti" : side.provider.name
        content +=
          (name as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: 9)]).width + 4
      }
      if showsStatusDot { content += 7 }
    }
    return ceil(content) + horizontalPadding
  }

  func pairedSideWidths(_ settings: Preferences) -> (left: CGFloat, right: CGFloat) {
    let store = AppStore.shared
    let revealed = displaysRevealedHeadline
    let insets = IslandHeadlineInsets.resolve(
      for: settings.islandSideVisibility, isMinimum: !revealed)
    let paddings = (left: CGFloat(insets.leading), right: CGFloat(insets.trailing))
    func measured(_ side: SideConfiguration, padding: CGFloat) -> CGFloat {
      let reading = store.readings[side.provider]
      return Self.measuredSideWidth(
        side, reading: reading, remaining: settings.remaining, revealed: revealed,
        horizontalPadding: padding,
        showsStatusDot: revealed && !store.demoMode
          && (reading?.stale(refreshMinutes: store.effectiveRefreshMinutes) ?? true))
    }
    let revealedSafety = displaysRevealedHeadline
      ? CGFloat(IslandHeadlineInsets.revealedLeadingContentSafety) : 0
    var left = measured(settings.left, padding: paddings.left)
    var right = measured(settings.right, padding: paddings.right)
    // The outer headline adds this inset at render time. Reserve the same
    // width here so its final value cannot be clipped against the notch.
    if settings.islandSideVisibility == .left { left += revealedSafety }
    if settings.islandSideVisibility == .right { right += revealedSafety }
    let available = max(
      96,
      screenWidth - notchWidth - sparkleWidth(settings) - Self.pairedHeadlineSpacing - 48)
    return constrainedWidths(left: left, right: right, available: available)
  }

  private func pairedWidth(_ settings: Preferences) -> CGFloat {
    let widths = pairedSideWidths(settings)
    return widths.left + Self.pairedHeadlineSpacing + widths.right
  }

  func sparkleWidth(_ settings: Preferences) -> CGFloat {
    let style =
      settings.refreshAnimation == .random ? randomRefreshAnimation : settings.refreshAnimation
    return style == .sparkle && refreshAnimationActive ? 28 : 0
  }

  func leftWidth(_ settings: Preferences) -> CGFloat {
    guard settings.islandSideVisibility != .right else { return 0 }
    if settings.islandSideVisibility == .both {
      return constrainedBothSideWidths(settings).left
    }
    return pairedWidth(settings) + sparkleWidth(settings)
  }
  func rightWidth(_ settings: Preferences) -> CGFloat {
    guard settings.islandSideVisibility != .left else { return 0 }
    if settings.islandSideVisibility == .both {
      return constrainedBothSideWidths(settings).right + sparkleWidth(settings)
    }
    return pairedWidth(settings) + sparkleWidth(settings)
  }
  private func constrainedBothSideWidths(
    _ settings: Preferences
  ) -> (left: CGFloat, right: CGFloat) {
    let insets = IslandHeadlineInsets.resolve(
      for: .both, isMinimum: !displaysRevealedHeadline)
    var left = sideWidth(
      settings.left, settings: settings, horizontalPadding: CGFloat(insets.leading))
    var right = sideWidth(
      settings.right, settings: settings, horizontalPadding: CGFloat(insets.trailing))
    if displaysRevealedHeadline {
      let safety = CGFloat(IslandHeadlineInsets.revealedLeadingContentSafety)
      left += safety
      right += safety
    }
    let available = max(
      96, screenWidth - notchWidth - sparkleWidth(settings) - 48)
    return constrainedWidths(left: left, right: right, available: available)
  }
  private func constrainedWidths(
    left: CGFloat, right: CGFloat, available: CGFloat
  ) -> (left: CGFloat, right: CGFloat) {
    guard left + right > available else { return (left, right) }
    let leftBase = min(left, 96)
    let rightBase = min(right, 96)
    let baseTotal = leftBase + rightBase
    guard baseTotal < available else {
      return (
        available * leftBase / baseTotal,
        available * rightBase / baseTotal
      )
    }
    let flexible = available - baseTotal
    let leftNeed = max(0, left - leftBase)
    let rightNeed = max(0, right - rightBase)
    let totalNeed = leftNeed + rightNeed
    guard totalNeed > 0 else { return (available / 2, available / 2) }
    return (
      leftBase + flexible * leftNeed / totalNeed,
      rightBase + flexible * rightNeed / totalNeed
    )
  }
  func horizontalOffset(_ settings: Preferences) -> CGFloat {
    let actualLeft = leftWidth(settings) + leftHeaderExpansion(settings)
    let actualRight = rightWidth(settings) + rightHeaderExpansion(settings)
    let desired = notchCenterOffset + (actualRight - actualLeft) / 2 + CGFloat(settings.horizontalOffset)
    let maximumShift = max(0, (screenWidth - width(settings)) / 2 - 24)
    return min(maximumShift, max(-maximumShift, desired))
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
  private var collapseGeneration = 0
  private var pointerTimer: Timer?
  private var locked = false
  private var lastShowIsland: Bool

  private func handleHeadlineClick(count: Int) {
    switch count {
    case 1:
      guard store.preferences.detailInteraction == .click else { return }
      cancelCollapse()
      state.showDetailsFromHeadline()
      updatePointer()
      if store.dashboardOpen { AppDelegate.shared?.focusDashboard() }
    case 2:
      cancelCollapse()
      if store.preferences.detailInteraction == .click {
        state.showDetailsFromHeadline()
        updatePointer()
        if store.dashboardOpen { AppDelegate.shared?.focusDashboard() }
      }
      refreshFromIsland()
    default:
      break
    }
  }

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
    lastShowIsland = store.preferences.showIsland
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
      guard let self else { return }
      if settings.showIsland && !self.lastShowIsland {
        // Opening the floating Island from Settings starts in its neutral,
        // compact state. A previous popup pin must not carry across this
        // visibility transition.
        self.cancelCollapse()
        self.state.expanded = false
        self.state.pinned = false
        self.state.headlineRevealed = false
      }
      self.lastShowIsland = settings.showIsland
      if settings.detailInteraction == .none {
        self.state.expanded = false
        self.state.pinned = false
      }
      self.reposition()
    }.store(in: &subscriptions)
    store.$dashboardOpen.removeDuplicates().receive(on: RunLoop.main).sink { [weak self] _ in
      guard let self else { return }
      // `showDashboard()` synchronously calls prepareForDashboardPresentation()
      // before it publishes dashboardOpen. Do not reset the popup here: this
      // Combine delivery can run after a toolbar “详情” click and would undo
      // the newly pinned detail panel.
      self.panel.level = .popUpMenu
      self.reposition()
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
          let x =
            point.x - self.panel.frame.midX - self.state.horizontalOffset(self.store.preferences)
            + width / 2
          let y = self.panel.frame.maxY - point.y
          if x >= 0, x <= width, y >= 0, y <= self.state.headlineHeight {
            self.consumedHeadlinePress = true
            self.handleHeadlineClick(count: event.clickCount)
            return nil
          }
        }
        // Route native popup controls before activation or hover updates can alter their layout.
        if let self, event.window === self.panel {
          let point = self.panel.convertPoint(toScreen: event.locationInWindow)
          let hit = (self.panel.contentView as? IslandHost)?.popupButton(atScreenPoint: point)
          if event.type == .leftMouseDown, let button = hit {
            self.cancelCollapse()
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
          // compact island focused before it handles clicks, so ⌘R
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
    // Keep a lightweight fallback poll active. Global event monitors can omit
    // synthesized events or stop delivering after an input-permission change.
    pointerTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
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
    // Use the actual gap between menu-bar regions, including its center,
    // rather than assuming the hardware notch is exactly screen-centered.
    if safe > 0,
      let left = screen.auxiliaryTopLeftArea,
      let right = screen.auxiliaryTopRightArea,
      right.minX > left.maxX
    {
      // The panel is rendered in points while the physical notch edges are
      // ultimately rasterized in backing pixels. Snap both measured edges to
      // that grid before deriving the width and center, so a fractional screen
      // coordinate cannot leave the overlay one physical pixel off the notch.
      let scale = max(screen.backingScaleFactor, 1)
      func pixelAligned(_ value: CGFloat) -> CGFloat {
        (value * scale).rounded() / scale
      }
      let notchLeft = pixelAligned(left.maxX)
      let notchRight = pixelAligned(right.minX)
      state.notchWidth = notchRight - notchLeft
      state.notchCenterOffset = (notchLeft + notchRight) / 2 - pixelAligned(screen.frame.midX)
    } else {
      state.notchWidth = safe > 0 ? 200 : 50
      state.notchCenterOffset = 0
    }
    state.topHeight = max(
      26,
      IslandGeometry.menuHeight(
        safeTop: safe, visibleDelta: screen.frame.maxY - screen.visibleFrame.maxY,
        statusBar: NSStatusBar.system.thickness))
    state.screenWidth = screen.frame.width
    state.screenHeight = screen.frame.height
    let width = screen.frame.width
    panel.setFrame(
      NSRect(
        x: screen.frame.midX - width / 2, y: screen.frame.minY - store.preferences.verticalOffset,
        width: width, height: screen.frame.height), display: true)
    if store.preferences.showIsland && !locked {
      // Keep the headline visible above Settings, including after preference
      // changes reposition the panel. Hit testing passes through outside it.
      panel.orderFrontRegardless()
    } else {
      panel.orderOut(nil)
    }
    updatePointer()
  }
  /// Toggles the transient detail popup requested from Settings. It never
  /// changes the popup's pin state, so the normal hover-dismiss behavior stays
  /// intact after the detail is shown.
  func toggleDetails() {
    guard store.preferences.detailInteraction != .none else { return }
    if !store.preferences.showIsland { store.preferences.showIsland = true }

    if state.expanded {
      state.expanded = false
      state.pinned = false
    } else {
      cancelCollapse()
      state.headlineRevealed = true
      state.expanded = true
      state.pinned = false
    }
    reposition()
  }

  func toggleExpanded() {
    toggleDetails()
  }
  func prepareForDashboardPresentation() {
    panel.level = .popUpMenu
    // Set passthrough before AppStore publishes dashboardOpen. Without this
    // synchronous handoff, the full-screen panel can consume the first click
    // on the freshly opened Settings sidebar.
    panel.ignoresMouseEvents = true
    cancelCollapse()
    state.expanded = false
    state.pinned = false
    state.hovering = false
  }
  private func cancelCollapse() {
    collapseGeneration &+= 1
    collapseTask?.cancel()
    collapseTask = nil
  }
  private func scheduleCollapse() {
    cancelCollapse()
    let generation = collapseGeneration
    collapseTask = Task { @MainActor [weak self] in
      guard let self else { return }
      defer {
        if self.collapseGeneration == generation { self.collapseTask = nil }
      }
      do { try await Task.sleep(for: .milliseconds(450)) } catch { return }
      guard self.collapseGeneration == generation, !self.state.hovering, !self.state.pinned
      else { return }
      let wasExpanded = self.state.expanded
      self.state.expanded = false
      // Keep the header intact until the detail panel finishes collapsing.
      if wasExpanded && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
        do { try await Task.sleep(for: .milliseconds(550)) } catch { return }
      }
      guard self.collapseGeneration == generation, !self.state.hovering,
        !self.state.expanded, !self.state.pinned
      else { return }
      self.state.headlineRevealed = false
    }
  }
  private func updatePointer() {
    // The panel spans the screen, but only the visible island shape is
    // interactive. This keeps the settings sidebar clickable while allowing
    // the island to react to hover even when Settings is open.
    let location = NSEvent.mouseLocation
    let local = CGPoint(
      x: location.x - panel.frame.midX - state.horizontalOffset(store.preferences) + state.width(
        store.preferences) / 2, y: panel.frame.maxY - location.y)
    let rect = CGRect(x: 0, y: 0, width: state.width(store.preferences), height: state.height)
    let buttonHit = (panel.contentView as? IslandHost)?.popupButton(atScreenPoint: location) != nil
    let inside = buttonHit || IslandShape(expanded: state.expanded).path(in: rect).contains(local)
    // Settings owns all clicks while it is visible. The global mouse monitor
    // still drives `inside`, so hover expansion remains available without the
    // full-screen Island panel intercepting sidebar clicks.
    panel.ignoresMouseEvents = store.dashboardOpen || !inside
    guard inside != state.hovering else {
      if !inside, !state.pinned, collapseTask == nil,
        state.expanded || state.headlineRevealed
      {
        scheduleCollapse()
      }
      return
    }
    state.hovering = inside
    if inside {
      cancelCollapse()
      state.headlineRevealed = true
      if store.preferences.hoverExpand { state.expanded = true }
    } else if !state.pinned {
      scheduleCollapse()
    } else {
      cancelCollapse()
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
      button.bounds.contains(button.convert(windowPoint, from: nil))
    {
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
      let button = popupButton(in: self, windowPoint: convert(pointInHost, to: nil))
    {
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
