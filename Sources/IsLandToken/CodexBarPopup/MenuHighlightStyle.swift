// Adapted from steipete/CodexBar, MIT, revision 928166f899471bbdcb72210641cdec91324d0154.
import SwiftUI

private struct MenuItemHighlightedKey: EnvironmentKey { static let defaultValue = false }
extension EnvironmentValues {
  var menuItemHighlighted: Bool {
    get { self[MenuItemHighlightedKey.self] }
    set { self[MenuItemHighlightedKey.self] = newValue }
  }

}

enum MenuHighlightStyle {
  static let selectionText = Color(nsColor: .selectedMenuItemTextColor)
  static let normalPrimaryText = Color(nsColor: .controlTextColor)
  static let normalSecondaryText = Color(nsColor: .secondaryLabelColor)

  static func primary(_ highlighted: Bool) -> Color {
    highlighted ? self.selectionText : self.normalPrimaryText
  }

  static func secondary(_ highlighted: Bool) -> Color {
    highlighted ? self.selectionText : self.normalSecondaryText
  }

  static func error(_ highlighted: Bool) -> Color {
    highlighted ? self.selectionText : Color(nsColor: .systemRed)
  }

  /// Accent emphasis for provider-owned status labels while preserving selected-row contrast.
  static func accent(_ highlighted: Bool) -> Color {
    highlighted ? self.selectionText : Color(nsColor: .controlAccentColor)
  }

  static func progressTrack(_ highlighted: Bool) -> Color {
    highlighted
      ? self.selectionText.opacity(0.22) : Color(nsColor: .tertiaryLabelColor).opacity(0.22)
  }

  static func progressTint(_ highlighted: Bool, fallback: Color) -> Color {
    highlighted ? self.selectionText : fallback
  }

  static func selectionBackground(_ highlighted: Bool) -> Color {
    highlighted ? Color(nsColor: .selectedContentBackgroundColor) : .clear
  }
}
