import AppKit
import IslandCore
import SwiftUI

/// Supplies the window with the current bounds of a source or destination.
struct IslandProviderLayoutRegion: NSViewRepresentable {
  enum Role {
    case source(Provider, click: () -> Void, dragging: (Bool) -> Void = { _ in }, previewColor: Color? = nil)
    case destination(hover: (Provider?, CGFloat) -> Void, drop: (Provider, CGFloat) -> Void)
  }

  let role: Role

  func makeNSView(context: Context) -> RegionView { RegionView(role: role) }

  func updateNSView(_ view: RegionView, context: Context) {
    view.role = role
  }

  final class RegionView: NSView {
    var role: Role

    init(role: Role) {
      self.role = role
      super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { nil }

    override func viewDidMoveToWindow() {
      super.viewDidMoveToWindow()
      (window as? DashboardWindow)?.providerLayoutDrag.regions.add(self)
    }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    // SwiftUI may leave an AppKit background view unclipped, so visibleRect
    // can include the surrounding scroll viewport.
    var visibleBounds: NSRect { bounds.intersection(visibleRect) }

    func contains(_ point: NSPoint, in window: NSWindow) -> Bool {
      self.window === window && !isHiddenOrHasHiddenAncestor
        && visibleBounds.contains(convert(point, from: nil))
    }
  }
}

/// Tracks a drag inside the settings window so sidebar selection cannot replace
/// the layout page between mouse-down and mouse-up.
@MainActor
final class IslandProviderLayoutDrag {
  let regions = NSHashTable<IslandProviderLayoutRegion.RegionView>.weakObjects()

  private struct Press {
    let provider: Provider
    let start: NSPoint
    let click: () -> Void
    let showSourcePreview: (Bool) -> Void
    let previewColor: Color?
    var dragging = false
  }

  private final class CursorPreview: NSHostingView<IslandProviderChip> {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
  }

  private var cursorPreview: CursorPreview?
  private var press: Press?
  private var hoverCursorActive = false
  private weak var hoveredRegion: IslandProviderLayoutRegion.RegionView?

  func handle(_ event: NSEvent, in window: NSWindow) -> Bool {
    let point = event.locationInWindow
    switch event.type {
    case .leftMouseDown:
      cancel()
      let visibleRegions = regions.allObjects.filter {
        $0.window === window && !$0.isHiddenOrHasHiddenAncestor && !$0.visibleBounds.isEmpty
      }
      guard visibleRegions.contains(where: {
        if case .destination = $0.role { return true }
        return false
      }) else { return false }
      // The remove button's region nests inside its chip's region; the
      // smallest containing source must win so a click on X removes instead
      // of selecting the chip.
      if let region = sourceRegion(at: point, in: window),
        case .source(let provider, let click, let showSourcePreview, let previewColor) = region.role
      {
        press = Press(provider: provider, start: point, click: click,
          showSourcePreview: showSourcePreview, previewColor: previewColor)
        return true
      }
      return false

    case .mouseMoved:
      guard press == nil else { return false }
      let inside = sourceRegion(at: point, in: window) != nil
      if inside != hoverCursorActive {
        hoverCursorActive = inside
        (inside ? NSCursor.pointingHand : NSCursor.arrow).set()
      }
      return false

    case .leftMouseDragged:
      guard var press else { return false }
      if !press.dragging {
        guard hypot(point.x - press.start.x, point.y - press.start.y) >= 4 else { return true }
        press.dragging = true
        self.press = press
        press.showSourcePreview(true)
        NSCursor.closedHand.set()
        if let color = press.previewColor, let content = window.contentView {
          let view = CursorPreview(rootView: IslandProviderChip(
            provider: press.provider, color: color, floating: true))
          view.setAccessibilityHidden(true)
          view.setFrameSize(view.fittingSize)
          content.addSubview(view, positioned: .above, relativeTo: nil)
          cursorPreview = view
        }
      }
      if let preview = cursorPreview, let content = preview.superview {
        let offset = content.isFlipped ? 12 : -preview.frame.height - 12
        let local = content.convert(point, from: nil)
        preview.setFrameOrigin(NSPoint(x: local.x + 12, y: local.y + offset))
      }
      let region = destination(at: point, in: window)
      if hoveredRegion !== region {
        clearHover()
        hoveredRegion = region
      }
      if let region, case .destination(let hover, _) = region.role {
        hover(press.provider, region.convert(point, from: nil).x)
      }
      return true

    case .leftMouseUp:
      guard let press else { return false }
      cancel()
      if press.dragging {
        if let region = destination(at: point, in: window),
          case .destination(_, let drop) = region.role
        {
          drop(press.provider, region.convert(point, from: nil).x)
        }
      } else {
        press.click()
      }
      return true

    case .keyDown where event.keyCode == 53 && press != nil:
      cancel()
      return true

    default:
      return false
    }
  }

  func cancel() {
    cursorPreview?.removeFromSuperview()
    cursorPreview = nil
    let previous = press
    press = nil
    if let previous, previous.dragging { previous.showSourcePreview(false) }
    if hoverCursorActive || (previous?.dragging ?? false) {
      hoverCursorActive = false
      NSCursor.arrow.set()
    }
    clearHover()
  }

  private func sourceRegion(
    at point: NSPoint, in window: NSWindow
  ) -> IslandProviderLayoutRegion.RegionView? {
    regions.allObjects
      .filter {
        guard $0.contains(point, in: window) else { return false }
        if case .source = $0.role { return true }
        return false
      }
      .min {
        $0.visibleBounds.width * $0.visibleBounds.height
          < $1.visibleBounds.width * $1.visibleBounds.height
      }
  }

  private func destination(
    at point: NSPoint, in window: NSWindow
  ) -> IslandProviderLayoutRegion.RegionView? {
    regions.allObjects.first {
      guard case .destination = $0.role else { return false }
      return $0.contains(point, in: window)
    }
  }

  private func clearHover() {
    if let hoveredRegion, case .destination(let hover, _) = hoveredRegion.role {
      hover(nil, 0)
    }
    hoveredRegion = nil
  }
}
