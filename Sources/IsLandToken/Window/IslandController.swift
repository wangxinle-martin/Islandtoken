import AppKit
import Combine
import IslandCore
import SwiftUI

@MainActor
final class IslandState: ObservableObject {
  /// The horizontal shell and vertical viewport are deliberately staged, but
  /// their AppKit timing must stay in lockstep with the SwiftUI animations.
  /// Keep the values here rather than scattering nearly-identical millisecond
  /// sleeps through the controller.
  static let shellAnimationDuration = 0.24
  static let shellCollapseDuration = 0.50
  static var shellCollapseMotion: Animation {
    .timingCurve(0.25, 0.1, 0.25, 1, duration: shellCollapseDuration)
  }
  static let popupRevealDuration = 0.30
  static let shellAnimationDelay: Duration = .milliseconds(240)
  static let popupRevealDelay: Duration = .milliseconds(300)
  // The retract now rides the shell-collapse curve, so hold the host panel just
  // beyond that duration to avoid clipping the final bottom-up frames.
  static let popupFrameHoldDelay: Duration =
    .milliseconds(Int(shellCollapseDuration * 1000) + 20)

  @Published var expanded = false
  /// Visual stages are intentionally separate from the logical expanded state.
  /// The shell widens first, then the popup is revealed below the fixed title.
  @Published var shellExpanded = false
  @Published var popupRevealed = false
  /// Pointer geometry follows the currently drawn shell conservatively while
  /// SwiftUI is animating. Native popup controls remain separately gated.
  @Published var shellHitTestExpanded = false
  @Published var popupInputCaptured = false
  /// Native popup controls become interactive only after the clipped reveal
  /// reaches its full height, so invisible controls never consume a click.
  @Published var popupInteractionEnabled = false
  @Published var hovering = false
  @Published var headlineRevealed = false
  @Published var pinned = false
  /// Screen-local, pixel-aligned edges of the physical camera housing.
  /// Use the edge, rather than a derived center, as the Island's anchor.
  @Published var notchLeft: CGFloat = 670
  @Published var notchRight: CGFloat = 770
  @Published var topHeight: CGFloat = 30
  @Published var screenWidth: CGFloat = 1440
  @Published var screenHeight: CGFloat = 900
  @Published var popupHeight: CGFloat = 360
  @Published var popupWidth: CGFloat = 580  // 弹窗内容宽度基线
  /// Offset from the screen center to the current panel's center. The live
  /// Island offset is derived from this base plus `horizontalOffset(_:)`, so
  /// hover-driven width changes keep their notch-side edge anchored.
  @Published var panelCenterOffsetX: CGFloat = 0
  @Published var musicPlaying = false
  var randomMusicStyle: MusicWaveStyle = .bars
  let musicMeter = MusicAudioMeter()
  @Published var refreshAnimationActive = false
  @Published var randomRefreshAnimation: RefreshAnimationStyle = .sparkle
  var displaysRevealedHeadline: Bool { headlineRevealed || expanded || shellExpanded }
  var popupIsOpening: Bool { expanded && !popupInteractionEnabled }
  var notchWidth: CGFloat { max(0, notchRight - notchLeft) }
  /// The detail body always lays itself out at this final width. Its viewport
  /// can then reveal that stable layout from the top without reflowing text or
  /// cards during an open/close animation.
  func expandedIslandWidth(_ settings: Preferences) -> CGFloat {
    UsageMenuCardLayout.expandedPopupWidth(
      providerCount: settings.visibleIslandSides.count,
      compactWidth: compactWidth(settings),
      screenWidth: screenWidth, baseline: popupWidth)
  }

  func width(_ settings: Preferences) -> CGFloat {
    width(settings, expanded: expanded || shellExpanded)
  }
  func width(_ settings: Preferences, expanded: Bool) -> CGFloat {
    expanded ? expandedIslandWidth(settings) : compactWidth(settings)
  }
  private func compactWidth(_ settings: Preferences) -> CGFloat {
    let widths = headlineWidths(settings)
    return notchWidth + widths.left + widths.right
  }
  private func expandedHeaderWidth(_ settings: Preferences, expanded: Bool) -> CGFloat {
    max(0, width(settings, expanded: expanded) - compactWidth(settings))
  }
  func leftHeaderExpansion(_ settings: Preferences) -> CGFloat {
    leftHeaderExpansion(settings, expanded: expanded || shellExpanded)
  }
  func leftHeaderExpansion(_ settings: Preferences, expanded: Bool) -> CGFloat {
    guard expanded else { return 0 }
    switch settings.islandHeadlinePlacement {
    case .left: return expandedHeaderWidth(settings, expanded: expanded)
    case .both: return expandedHeaderWidth(settings, expanded: expanded) / 2
    case .right, nil: return 0
    }
  }
  func rightHeaderExpansion(_ settings: Preferences) -> CGFloat {
    rightHeaderExpansion(settings, expanded: expanded || shellExpanded)
  }
  func rightHeaderExpansion(_ settings: Preferences, expanded: Bool) -> CGFloat {
    guard expanded else { return 0 }
    switch settings.islandHeadlinePlacement {
    case .right: return expandedHeaderWidth(settings, expanded: expanded)
    case .both: return expandedHeaderWidth(settings, expanded: expanded) / 2
    case .left, nil: return 0
    }
  }
  func headlineLayout(_ settings: Preferences) -> IslandHeadlineLayout {
    headlineLayout(settings, revealed: displaysRevealedHeadline)
  }

  func headlineLayout(_ settings: Preferences, revealed: Bool) -> IslandHeadlineLayout {
    IslandHeadlineLayout(
      store: .shared, settings: settings, revealed: revealed,
      availableWidth: screenWidth - notchWidth - accessoryWidth(settings) - 48)
  }

  func headlineWidths(_ settings: Preferences) -> (left: CGFloat, right: CGFloat) {
    let layout = headlineLayout(settings)
    let accessories = accessoryWidth(settings)
    return (
      layout.leadingWidth + (layout.placement == .left ? accessories : 0),
      layout.trailingWidth + (layout.placement != .left ? accessories : 0)
    )
  }

  private func accessoryWidth(_ settings: Preferences) -> CGFloat {
    sparkleWidth(settings)
  }

  func sparkleWidth(_ settings: Preferences) -> CGFloat {
    guard settings.islandHeadlinePlacement != nil else { return 0 }
    let style =
      settings.refreshAnimation == .random ? randomRefreshAnimation : settings.refreshAnimation
    return style == .sparkle && refreshAnimationActive ? 28 : 0
  }

  func horizontalOffset(_ settings: Preferences) -> CGFloat {
    horizontalOffset(settings, expanded: expanded || shellExpanded)
  }

  func horizontalOffset(_ settings: Preferences, expanded: Bool) -> CGFloat {
    let actualLeft = headlineWidths(settings).left + leftHeaderExpansion(settings, expanded: expanded)
    let islandWidth = width(settings, expanded: expanded)
    let islandLeft = IslandGeometry.islandLeft(
      notchLeft: Double(notchLeft), leadingContentWidth: Double(actualLeft),
      horizontalOffset: settings.horizontalOffset, screenWidth: Double(screenWidth),
      islandWidth: Double(islandWidth))
    return CGFloat(islandLeft + Double(islandWidth) / 2 - Double(screenWidth) / 2)
  }

  func contentOffsetX(_ settings: Preferences) -> CGFloat {
    contentOffsetX(settings, expanded: expanded || shellExpanded)
  }

  func contentOffsetX(_ settings: Preferences, expanded: Bool) -> CGFloat {
    panelCenterOffsetX + horizontalOffset(settings, expanded: expanded)
  }
  // Hover reveals the extra text horizontally; keep the capsule height aligned
  // with the native macOS notch in every compact state.
  var headlineHeight: CGFloat { topHeight }
  var height: CGFloat { headlineHeight + (expanded ? popupHeight : 0) }

}

/// Measures and places the same enabled headline items in the Island and its preview.
@MainActor
struct IslandHeadlineLayout {
  struct Item {
    let configuration: SideConfiguration
    let leadingInset: CGFloat
    let trailingInset: CGFloat
    let revealedLeadingInset: CGFloat
    let revealedTrailingInset: CGFloat
    var width: CGFloat
  }

  static let spacing: CGFloat = 12
  let placement: IslandSideVisibility?
  private let items: [Item]

  private let leadingCount: Int
  var leading: ArraySlice<Item> { items.prefix(leadingCount) }
  var trailing: ArraySlice<Item> { items.dropFirst(leadingCount) }

  var leadingWidth: CGFloat { width(of: leading) }
  var trailingWidth: CGFloat { width(of: trailing) }

  init(store: AppStore, settings: Preferences, revealed: Bool, availableWidth: CGFloat? = nil) {
    leadingCount = settings.islandLeftProviders.count
    placement = settings.islandHeadlinePlacement
    guard let placement else {
      items = []
      return
    }
    let sides = settings.visibleIslandSides
    let insets = IslandHeadlineInsets.resolve(for: placement, isMinimum: !revealed)
    let revealedSafety = revealed ? CGFloat(IslandHeadlineInsets.revealedLeadingContentSafety) : 0
    var measured = sides.enumerated().map { index, side in
      let atLeadingEdge = index == 0 && placement != .right
      let atTrailingEdge = index == sides.count - 1 && placement != .left
      let leadingInset = atLeadingEdge ? CGFloat(insets.leading) : 0
      let trailingInset = atTrailingEdge ? CGFloat(insets.trailing) : 0
      let revealedLeadingInset = atLeadingEdge ? revealedSafety : 0
      let revealedTrailingInset = atTrailingEdge ? revealedSafety : 0
      let reading = store.readings[side.provider]
      let width = Self.measuredSideWidth(
        side, reading: reading, remaining: settings.remaining, revealed: revealed,
        horizontalPadding: leadingInset + trailingInset + revealedLeadingInset + revealedTrailingInset,
        showsStatusDot: revealed && !store.demoMode
          && (reading?.stale(refreshMinutes: store.effectiveRefreshMinutes) ?? true))
      return Item(
        configuration: side, leadingInset: leadingInset, trailingInset: trailingInset,
        revealedLeadingInset: revealedLeadingInset, revealedTrailingInset: revealedTrailingInset,
        width: width)
    }
    if let availableWidth {
      if measured.count == 2 {
        let spacing = placement == .both ? 0 : Self.spacing
        let widths = Self.constrainedWidths(
          left: measured[0].width, right: measured[1].width,
          available: max(96, availableWidth - spacing))
        measured[0].width = widths.left
        measured[1].width = widths.right
      } else {
        let gaps = max(0, leadingCount - 1) + max(0, measured.count - leadingCount - 1)
        let budget = max(1, availableWidth - CGFloat(gaps) * Self.spacing)
        let total = measured.reduce(0) { $0 + $1.width }
        if total > budget {
          for index in measured.indices { measured[index].width *= budget / total }
        }
      }
    }
    items = measured
  }

  private func width(of group: ArraySlice<Item>) -> CGFloat {
    group.reduce(0) { $0 + $1.width } + CGFloat(max(0, group.count - 1)) * Self.spacing
  }

  private static func measuredSideWidth(
    _ side: SideConfiguration, reading: UsageReading?, remaining: Bool, revealed: Bool,
    horizontalPadding: CGFloat = 0, showsStatusDot: Bool = false
  ) -> CGFloat {
    let windowIDs = side.displayWindowIDs(reading: reading)
    // Match DigitFlipText's rounded system design. The default monospaced
    // AppKit font is narrower and used to underestimate every number group.
    let fallbackFont = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
    let roundedDescriptor = fallbackFont.fontDescriptor.withDesign(.rounded)
    let font = roundedDescriptor.flatMap { NSFont(descriptor: $0, size: 12) } ?? fallbackFont
    let separatorFont = NSFont.systemFont(ofSize: 12, weight: .semibold)
    let separatorWidth = ("|" as NSString).size(withAttributes: [.font: separatorFont]).width
    var content = CGFloat(max(0, windowIDs.count - 1)) * (separatorWidth + 8)
    for id in windowIDs {
      let percent = reading?.window(id)?.percent(remaining: remaining)
      let styles = side.displayStyles(revealed: revealed, hasQuota: percent != nil)
      content += CGFloat(styles.count - 1) * 4
      for style in styles {
        switch style {
        case .number:
          let label = percent.map { String(format: "%.0f", $0) + (revealed ? "%" : "") } ?? "—"
          content += (label as NSString).size(withAttributes: [.font: font]).width
        case .ring: content += 20
        case .bar: content += 28
        case .segments: content += 36
        case .sparkline: content += 30
        }
      }
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

  private static func constrainedWidths(
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
}

class IslandPopupButton: NSButton {
  var usesNativeMouseTracking = false
}

final class IslandPanel: NSPanel {
  var commandR: (() -> Void)?
  var commandQ: (() -> Void)?
  var allowsKeyWindow = true
  override var canBecomeKey: Bool { allowsKeyWindow }
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
  /// A bounded Settings panel would otherwise shrink before SwiftUI can draw
  /// the popup's top-anchored removal transition.
  private var popupFrameHoldTask: Task<Void, Never>?
  private var popupFrameHoldHeight: CGFloat?
  private var popupFrameHoldGeneration = 0
  private var popupRevealTask: Task<Void, Never>?
  private var popupRevealGeneration = 0
  private var shellCollapseTask: Task<Void, Never>?
  private var shellCollapseGeneration = 0
  private var popupInteractionTask: Task<Void, Never>?
  private var popupInteractionGeneration = 0
  private var pendingPopupHeightReposition = false
  private var musicPlaybackTask: Task<Void, Never>?
  private var pointerTimer: Timer?
  private var pointerUpdateScheduled = false
  private var locked = false
  private var wasIslandVisible: Bool
  // Set before presenting Settings so panel geometry is already bounded when
  // AppKit delivers the first sidebar event.
  private var dashboardPresentationActive = false {
    didSet { panel.allowsKeyWindow = !dashboardPresentationActive }
  }

  private func cancelPanelPress() {
    consumedHeadlinePress = false
    pressedPopupButton?.highlight(false)
    pressedPopupButton = nil
  }

  private func handleHeadlineClick(count: Int) {
    switch count {
    case 1:
      showDetailsFromHeadline()
    case 2:
      showDetailsFromHeadline()
      refreshFromIsland()
    default:
      break
    }
  }

  /// Centralizes every headline-open route so the clip reveal, delayed native
  /// hit testing, and hover-collapse cancellation always agree.
  func showDetailsFromHeadline() {
    guard store.preferences.isIslandVisible,
      store.preferences.detailInteraction == .click
    else { return }
    cancelCollapse()
    cancelPopupFrameHold()
    state.headlineRevealed = true
    setExpanded(true)
    updatePointer()
    if store.dashboardOpen { AppDelegate.shared?.focusDashboard() }
  }

  /// Static popup verification intentionally skips the staged transition so
  /// the app's existing `--verify-popup` checks inspect the final, clickable
  /// layout rather than an in-flight visual state.
  func showPopupForVerification() {
    cancelCollapse()
    cancelPopupFrameHold()
    cancelPopupReveal()
    cancelShellCollapse()
    cancelPopupInteraction()
    state.headlineRevealed = true
    state.shellExpanded = true
    state.popupRevealed = true
    state.shellHitTestExpanded = true
    state.popupInputCaptured = true
    state.popupInteractionEnabled = true
    pendingPopupHeightReposition = false
    state.expanded = true
    state.pinned = true
    reposition()
    panel.makeKeyAndOrderFront(nil)
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
    wasIslandVisible = store.preferences.isIslandVisible
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
      if settings.isIslandVisible != self.wasIslandVisible {
        // Start from the compact state after a visibility change.
        self.cancelPanelPress()
        self.cancelCollapse()
        self.setExpanded(false, animatingCollapse: false, collapseHeadline: true)
        self.state.pinned = false
        self.state.hovering = false
      }
      self.wasIslandVisible = settings.isIslandVisible
      if settings.detailInteraction == .none {
        self.setExpanded(false, animatingCollapse: false)
        self.state.pinned = false
      }
      self.reposition()
    }.store(in: &subscriptions)
    // AppStore and this controller are both main-actor isolated. Deliver this
    // state synchronously: queuing the initial `false` can otherwise replay it
    // after `prepareForDashboardPresentation()` has bounded the panel.
    store.$dashboardOpen.removeDuplicates().sink { [weak self] open in
      guard let self else { return }
      self.dashboardPresentationActive = open
      if !open { self.cancelPopupFrameHold() }
      // `showDashboard()` synchronously switches to the bounded panel before
      // this publication arrives. Do not reset detail state here.
      self.panel.level = .popUpMenu
      self.reposition()
    }.store(in: &subscriptions)
    state.$expanded.receive(on: RunLoop.main).sink { [weak self] expanded in
      guard let self else { return }
      if expanded { self.cancelPopupFrameHold() }
      self.reposition()
    }.store(in: &subscriptions)
    state.$shellExpanded.removeDuplicates().receive(on: RunLoop.main).sink { [weak self] _ in
      guard let self else { return }
      self.reposition()
      self.requestPointerUpdate()
    }.store(in: &subscriptions)
    state.$popupRevealed.removeDuplicates().receive(on: RunLoop.main).sink { [weak self] _ in
      self?.requestPointerUpdate()
    }.store(in: &subscriptions)
    state.$shellHitTestExpanded.removeDuplicates().receive(on: RunLoop.main).sink { [weak self] _ in
      self?.requestPointerUpdate()
    }.store(in: &subscriptions)
    state.$popupInputCaptured.removeDuplicates().receive(on: RunLoop.main).sink { [weak self] _ in
      self?.requestPointerUpdate()
    }.store(in: &subscriptions)
    // `headlineRevealed` changes the compact Island width during hover. Reuse
    // the same placement pass so a left/right-only Island stays anchored to
    // its notch edge instead of growing toward the opposite side.
    state.$headlineRevealed.removeDuplicates().receive(on: RunLoop.main).sink { [weak self] _ in
      self?.reposition()
    }.store(in: &subscriptions)
    state.$popupHeight.removeDuplicates().receive(on: RunLoop.main).sink { [weak self] _ in
      guard let self else { return }
      // The detail view stays mounted while compact, so its usual size is
      // already known before an opening transition begins. Ignore a late
      // measurement until the reveal completes to avoid a second panel jump.
      if !self.state.expanded || self.state.popupInteractionEnabled {
        self.pendingPopupHeightReposition = false
        self.reposition()
      } else {
        self.pendingPopupHeightReposition = true
      }
    }.store(in: &subscriptions)
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
          if event.type == .keyDown {
            // Keyboard shortcuts consult `hovering` immediately; keep that
            // one low-frequency path synchronous while pointer movement is
            // coalesced below.
            self.updatePointer()
          } else {
            self.requestPointerUpdate()
          }
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
        // A panel that was dismissed or stopped receiving events can miss its
        // mouse-up. Clear the old press before processing a different window.
        if let self, event.type == .leftMouseDown
          || (event.type == .leftMouseUp && event.window !== self.panel)
        {
          self.cancelPanelPress()
        }
        if event.type == .leftMouseUp, let self, self.consumedHeadlinePress {
          self.consumedHeadlinePress = false
          return nil
        }
        if event.type == .leftMouseDown, let self, event.window === self.panel {
          let point = self.panel.convertPoint(toScreen: event.locationInWindow)
          let expanded = self.state.shellHitTestExpanded
          let width = self.state.width(self.store.preferences, expanded: expanded)
          let offset = self.state.contentOffsetX(self.store.preferences, expanded: expanded)
          let x = point.x - self.panel.frame.midX - offset + width / 2
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
          // AppKit needs the actual Settings press to activate the application
          // before its action transfers focus from the panel to the dashboard.
          if event.type == .leftMouseDown,
            let button = hit as? IslandPopupButton, button.usesNativeMouseTracking
          {
            self.cancelCollapse()
            return event
          }
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
          self?.setExpanded(false)
          self?.state.pinned = false
        }
        self?.requestPointerUpdate()
        if event.type == .leftMouseDown, let self,
          event.window === self.panel, self.panel.canBecomeKey
        {
          // Preserve Island keyboard shortcuts when Settings is closed.
          NSApp.activate(ignoringOtherApps: true)
          self.panel.makeKeyAndOrderFront(nil)
        }
        return event
      })
    {
      monitors.append(monitor)
    }
    // Keep a lightweight fallback poll active. Global event monitors can omit
    // synthesized events or stop delivering after an input-permission change.
    pointerTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
      Task { @MainActor in
        guard let self, self.store.preferences.isIslandVisible, !self.locked else { return }
        self.requestPointerUpdate()
      }
    }
    musicPlaybackTask = Task { @MainActor [weak self] in
      while !Task.isCancelled {
        await self?.updateMusicPlayback()
        do { try await Task.sleep(for: .milliseconds(800)) } catch { return }
      }
    }
    reposition()
  }

  deinit {
    collapseTask?.cancel()
    popupFrameHoldTask?.cancel()
    popupRevealTask?.cancel()
    shellCollapseTask?.cancel()
    popupInteractionTask?.cancel()
    musicPlaybackTask?.cancel()
    pointerTimer?.invalidate()
    monitors.forEach(NSEvent.removeMonitor)
    for observer in observers {
      NotificationCenter.default.removeObserver(observer)
      DistributedNotificationCenter.default().removeObserver(observer)
    }
  }
  private func updateMusicPlayback() async {
    guard store.preferences.isIslandVisible, store.preferences.musicWaveStyle != .off, !locked else {
      state.musicMeter.follow([])
      if state.musicPlaying { state.musicPlaying = false }
      return
    }
    let processes = await Task.detached(priority: .utility) {
      MusicPlaybackMonitor.playingProcesses()
    }.value
    guard !Task.isCancelled, store.preferences.isIslandVisible,
      store.preferences.musicWaveStyle != .off, !locked
    else { return }

    state.musicMeter.follow(
      NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? [] : processes.sorted())
    let playing = !processes.isEmpty
    if state.musicPlaying != playing {
      if playing {
        state.randomMusicStyle = [MusicWaveStyle.bars, .shortLines, .bouncingNotes].randomElement() ?? .bars
      }
      state.musicPlaying = playing
    }
  }

  func reposition() {
    let screen =
      NSScreen.screens.first { String($0.displayID) == store.preferences.screenID }
      ?? NSScreen.screens.first { $0.safeAreaInsets.top > 0 } ?? NSScreen.main
    guard let screen else { return }
    let safe = screen.safeAreaInsets.top
    state.screenWidth = screen.frame.width
    state.screenHeight = screen.frame.height
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
      state.notchLeft = notchLeft - screen.frame.minX
      state.notchRight = notchRight - screen.frame.minX
    } else {
      let fallbackWidth: CGFloat = safe > 0 ? 200 : 50
      state.notchLeft = (screen.frame.width - fallbackWidth) / 2
      state.notchRight = state.notchLeft + fallbackWidth
    }
    state.topHeight = max(
      26,
      IslandGeometry.menuHeight(
        safeTop: safe, visibleDelta: screen.frame.maxY - screen.visibleFrame.maxY,
        statusBar: NSStatusBar.system.thickness))
    // The presentation flag tracks the pending open and the latest published
    // state. During @Published delivery the store still holds its previous value.
    let fullScreenPanel = !dashboardPresentationActive
    // While Settings is open, keep the Island above the window in a small,
    // centered panel. A full-screen transparent panel must either consume the
    // sidebar's first click or ignore all mouse movement. This bounded panel
    // can receive hover directly while leaving the sidebar untouched.
    let widths = state.headlineWidths(store.preferences)
    let actualLeft = widths.left + state.leftHeaderExpansion(store.preferences)
    let actualRight = widths.right + state.rightHeaderExpansion(store.preferences)
    // The bounded panel stays anchored at the physical notch while side-only
    // Islands grow. Its extra width makes room for the content's animated
    // side compensation, so the attaching notch edge never drifts mid-hover.
    let width = fullScreenPanel
      ? screen.frame.width
      : min(
        screen.frame.width,
        max(760, state.width(store.preferences) + abs(actualRight - actualLeft) + 40))
    let targetHeight = fullScreenPanel
      ? screen.frame.height
      : min(screen.frame.height, max(state.headlineHeight, state.height + 12))
    let height: CGFloat
    if !fullScreenPanel, !state.expanded, let popupFrameHoldHeight {
      height = max(targetHeight, popupFrameHoldHeight)
    } else {
      height = targetHeight
    }
    let y = fullScreenPanel
      ? screen.frame.minY - store.preferences.verticalOffset
      : screen.frame.maxY - store.preferences.verticalOffset - height
    let islandCenterX = screen.frame.midX + state.horizontalOffset(store.preferences)
    let hostCenterX = islandCenterX - (actualRight - actualLeft) / 2
    let proposedX = hostCenterX - width / 2
    let x: CGFloat
    if fullScreenPanel {
      x = screen.frame.minX
    } else {
      x = min(max(proposedX, screen.frame.minX), screen.frame.maxX - width)
    }
    let frame = NSRect(x: x, y: y, width: width, height: height)
    // With Settings open the hosting panel is deliberately bounded so it
    // never consumes a sidebar click. Keep it anchored at the notch instead
    // of the changing Island center; SwiftUI then animates width and offset in
    // one transaction while the physical attachment edge remains stationary.
    // If it reaches a screen edge, retain the remaining offset inside the host
    // so rendering and hit testing stay in sync.
    panel.setFrame(frame, display: true)
    state.panelCenterOffsetX = screen.frame.midX - panel.frame.midX
    if store.preferences.isIslandVisible && !locked {
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
    guard store.preferences.islandHeadlinePlacement != nil,
      store.preferences.detailInteraction != .none
    else { return }
    if !store.preferences.showIsland { store.preferences.showIsland = true }

    if state.expanded {
      setExpanded(false)
      state.pinned = false
    } else {
      cancelCollapse()
      cancelPopupFrameHold()
      state.headlineRevealed = true
      setExpanded(true)
      state.pinned = false
    }
    reposition()
  }

  func toggleExpanded() {
    toggleDetails()
  }
  func prepareForDashboardPresentation() {
    panel.level = .popUpMenu
    // Convert to the bounded top panel before Settings is created. This makes
    // the first sidebar click independent of Combine/AppKit scheduling while
    // preserving direct hover delivery to the visible Island.
    panel.ignoresMouseEvents = true
    dashboardPresentationActive = true
    cancelPanelPress()
    cancelCollapse()
    setExpanded(false, animatingCollapse: false)
    state.pinned = false
    state.hovering = false
    reposition()
  }
  private func cancelCollapse() {
    collapseGeneration &+= 1
    collapseTask?.cancel()
    collapseTask = nil
  }

  /// Updates the expanded state while preserving a bounded host panel for the
  /// duration of a real popup removal animation. Programmatic resets (opening
  /// Settings, hiding the Island, disabling details) intentionally skip it.
  private func setExpanded(
    _ expanded: Bool,
    animatingCollapse: Bool = true,
    collapseHeadline: Bool = false
  ) {
    guard state.expanded != expanded else {
      // A programmatic reset may arrive after the state has already become
      // compact but before a previous removal hold expires.
      if !expanded && !animatingCollapse {
        cancelPopupFrameHold()
        cancelPopupReveal()
        cancelShellCollapse()
        state.popupRevealed = false
        state.shellExpanded = false
        state.shellHitTestExpanded = false
        state.popupInputCaptured = false
        state.popupInteractionEnabled = false
        pendingPopupHeightReposition = false
      }
      if !expanded && collapseHeadline { compactShell(collapseHeadline: true) }
      return
    }
    if expanded {
      cancelCollapse()
      cancelPopupFrameHold()
      cancelShellCollapse()
      cancelPopupReveal()
      state.popupInteractionEnabled = false
      state.popupRevealed = false
      state.shellHitTestExpanded = false
      state.popupInputCaptured = false
      state.shellExpanded = true
      state.expanded = true
      beginPopupRevealAfterShellExpansion()
    } else {
      let hadVisiblePopup = state.popupRevealed
      cancelPopupReveal()
      cancelPopupInteraction()
      state.popupInteractionEnabled = false
      state.popupRevealed = false
      if animatingCollapse && hadVisiblePopup {
        beginPopupFrameHoldForCollapse()
        collapseShellAfterPopupRetracts(collapseHeadline: collapseHeadline)
      } else {
        cancelPopupFrameHold()
        cancelShellCollapse()
        state.shellHitTestExpanded = false
        state.popupInputCaptured = false
        compactShell(collapseHeadline: collapseHeadline)
      }
      state.expanded = false
      pendingPopupHeightReposition = false
    }
  }

  /// The horizontal shell finishes first. The detail viewport is then the only
  /// element that changes vertically, so the popup reads as a top-down reveal
  /// instead of a uniformly growing card.
  private func beginPopupRevealAfterShellExpansion() {
    guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
      state.popupRevealed = true
      state.shellHitTestExpanded = true
      state.popupInputCaptured = true
      state.popupInteractionEnabled = true
      if pendingPopupHeightReposition {
        pendingPopupHeightReposition = false
        reposition()
      }
      return
    }
    popupRevealGeneration &+= 1
    let generation = popupRevealGeneration
    popupRevealTask?.cancel()
    popupRevealTask = Task { @MainActor [weak self] in
      do { try await Task.sleep(for: IslandState.shellAnimationDelay) } catch { return }
      guard let self,
        self.popupRevealGeneration == generation,
        self.state.expanded,
        self.state.shellExpanded
      else { return }
      self.popupRevealTask = nil
      // The final content height can arrive asynchronously from SwiftUI. Size
      // the transparent host before the first visible popup frame so its top
      // anchor stays fixed and the final rows never snap into place late.
      if self.pendingPopupHeightReposition {
        self.pendingPopupHeightReposition = false
        self.reposition()
      }
      self.state.popupRevealed = true
      self.state.shellHitTestExpanded = true
      self.state.popupInputCaptured = true
      self.enablePopupInteractionAfterReveal()
    }
  }

  private func cancelPopupReveal() {
    popupRevealGeneration &+= 1
    popupRevealTask?.cancel()
    popupRevealTask = nil
  }

  private func collapseShellAfterPopupRetracts(collapseHeadline: Bool) {
    guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
      state.shellHitTestExpanded = false
      state.popupInputCaptured = false
      compactShell(collapseHeadline: collapseHeadline)
      return
    }
    shellCollapseGeneration &+= 1
    let generation = shellCollapseGeneration
    shellCollapseTask?.cancel()
    shellCollapseTask = Task { @MainActor [weak self] in
      guard let self,
        self.shellCollapseGeneration == generation,
        !self.state.expanded
      else { return }
      // Height, width and headline compact together on one curve so the
      // contraction reads as a single continuous motion instead of stages.
      self.state.popupInputCaptured = false
      self.compactShell(collapseHeadline: collapseHeadline)
      do {
        try await Task.sleep(for: .seconds(IslandState.shellCollapseDuration))
      } catch { return }
      guard self.shellCollapseGeneration == generation, !self.state.expanded else { return }
      self.shellCollapseTask = nil
      self.state.shellHitTestExpanded = false
    }
  }

  private func cancelShellCollapse() {
    shellCollapseGeneration &+= 1
    shellCollapseTask?.cancel()
    shellCollapseTask = nil
  }

  /// The headline must compact on the same curve and duration as the shell
  /// width; placing it instantly makes the content snap while the bar shrinks.
  private func compactShell(collapseHeadline: Bool) {
    let apply = {
      if collapseHeadline { self.state.headlineRevealed = false }
      self.state.shellExpanded = false
    }
    if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
      apply()
    } else {
      withAnimation(IslandState.shellCollapseMotion) { apply() }
    }
  }

  private func enablePopupInteractionAfterReveal() {
    guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
      state.popupInteractionEnabled = true
      updatePointer()
      return
    }
    popupInteractionGeneration &+= 1
    let generation = popupInteractionGeneration
    popupInteractionTask?.cancel()
    popupInteractionTask = Task { @MainActor [weak self] in
      // Do not enable native controls until the full-height viewport is drawn.
      do { try await Task.sleep(for: IslandState.popupRevealDelay) } catch { return }
      guard let self,
        self.popupInteractionGeneration == generation,
        self.state.expanded,
        self.state.popupRevealed
      else { return }
      self.popupInteractionTask = nil
      self.state.popupInteractionEnabled = true
      self.updatePointer()
    }
  }

  private func cancelPopupInteraction() {
    popupInteractionGeneration &+= 1
    popupInteractionTask?.cancel()
    popupInteractionTask = nil
  }

  private func beginPopupFrameHoldForCollapse() {
    guard dashboardPresentationActive,
      !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion,
      popupFrameHoldTask == nil,
      panel.frame.height > state.headlineHeight + 12
    else { return }
    popupFrameHoldGeneration &+= 1
    let generation = popupFrameHoldGeneration
    popupFrameHoldHeight = panel.frame.height
    popupFrameHoldTask = Task { @MainActor [weak self] in
      // Keep the host panel just beyond the viewport animation so Settings
      // never clips the final bottom-up frames.
      do { try await Task.sleep(for: IslandState.popupFrameHoldDelay) } catch { return }
      guard let self, self.popupFrameHoldGeneration == generation else { return }
      self.popupFrameHoldTask = nil
      guard !self.state.expanded else { return }
      self.popupFrameHoldHeight = nil
      self.reposition()
    }
  }

  private func cancelPopupFrameHold() {
    popupFrameHoldGeneration &+= 1
    popupFrameHoldTask?.cancel()
    popupFrameHoldTask = nil
    popupFrameHoldHeight = nil
  }

  private func scheduleCollapse() {
    guard !state.popupIsOpening else { return }
    cancelCollapse()
    let generation = collapseGeneration
    collapseTask = Task { @MainActor [weak self] in
      guard let self else { return }
      defer {
        if self.collapseGeneration == generation { self.collapseTask = nil }
      }
      do { try await Task.sleep(for: .milliseconds(450)) } catch { return }
      guard self.collapseGeneration == generation, !self.state.hovering, !self.state.pinned,
        !self.state.popupIsOpening
      else { return }
      self.setExpanded(false, collapseHeadline: true)
    }
  }
  /// Global monitors, the panel-local monitor, and the fallback timer may all
  /// fire for the same pointer movement. Perform at most one geometric hit test
  /// in a run-loop turn while preserving the direct hover path over Settings.
  private func requestPointerUpdate() {
    guard !pointerUpdateScheduled else { return }
    pointerUpdateScheduled = true
    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      self.pointerUpdateScheduled = false
      self.updatePointer()
    }
  }

  private func updatePointer() {
    guard store.preferences.isIslandVisible, !locked else {
      panel.ignoresMouseEvents = true
      return
    }
    // The panel accepts events only inside the visible Island shape. It can be
    // full-screen or bounded above Settings, so use the panel-local offset
    // established by `reposition()` for the same geometry SwiftUI renders.
    let location = NSEvent.mouseLocation
    let capturesPopupInput = state.popupInputCaptured
    let interactivePopup = state.popupRevealed && state.popupInteractionEnabled
    let shellExpandedForHitTest = state.shellHitTestExpanded
    let width = state.width(store.preferences, expanded: shellExpandedForHitTest)
    let contentOffsetX = state.contentOffsetX(
      store.preferences, expanded: shellExpandedForHitTest)
    let local = CGPoint(
      x: location.x - panel.frame.midX - contentOffsetX + width / 2,
      y: panel.frame.maxY - location.y)
    let height = state.headlineHeight + (capturesPopupInput ? state.popupHeight : 0)
    let rect = CGRect(x: 0, y: 0, width: width, height: height)
    let buttonHit = interactivePopup
      && (panel.contentView as? IslandHost)?.popupButton(atScreenPoint: location) != nil
    let inside = buttonHit || IslandShape(
      expanded: shellExpandedForHitTest,
      notchAttachment: IslandNotchAttachment(store.preferences.islandHeadlinePlacement)
    ).path(in: rect).contains(local)
    panel.ignoresMouseEvents = !inside
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
      if store.preferences.hoverExpand { setExpanded(true) }
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
    guard state.popupRevealed, state.popupInteractionEnabled, let window else { return nil }
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
    guard store.preferences.isIslandVisible else { return nil }
    // AppKit supplies this point in the superview's coordinate system.
    // NSHostingView is flipped, while the panel's frame view is not.
    let pointInHost = convert(point, from: superview)
    let capturesPopupInput = state.popupInputCaptured
    let interactivePopup = state.popupRevealed && state.popupInteractionEnabled
    let shellExpandedForHitTest = state.shellHitTestExpanded
    if interactivePopup,
      let button = popupButton(in: self, windowPoint: convert(pointInHost, to: nil))
    {
      return button
    }
    let width = state.width(store.preferences, expanded: shellExpandedForHitTest)
    let height = state.headlineHeight + (capturesPopupInput ? state.popupHeight : 0)
    let rect = CGRect(x: 0, y: 0, width: width, height: height)
    let local = CGPoint(
      x: pointInHost.x - bounds.midX
        - state.contentOffsetX(store.preferences, expanded: shellExpandedForHitTest) + width / 2,
      y: isFlipped ? pointInHost.y - bounds.minY : bounds.maxY - pointInHost.y)
    guard IslandShape(
      expanded: shellExpandedForHitTest,
      notchAttachment: IslandNotchAttachment(store.preferences.islandHeadlinePlacement)
    ).path(in: rect).contains(local) else { return nil }
    // During the reveal the visible body should keep hover ownership, but its
    // native buttons must not receive the click that opened the detail panel.
    if capturesPopupInput, !interactivePopup, local.y > state.headlineHeight {
      return self
    }
    return super.hitTest(point)
  }
}
