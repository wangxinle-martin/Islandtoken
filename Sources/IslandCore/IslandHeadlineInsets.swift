public struct IslandHeadlineInsets: Equatable, Sendable {
  // IslandShape's visible vertical edge starts 12pt inside its rectangular frame.
  // Add the requested 10pt gap from that visible edge, rather than from the
  // transparent shoulder at the frame boundary.
  public static let shapeShoulderSafety = 12.0
  public static let minimumOuterPadding = 10.0
  public static let minimumContentInset = shapeShoulderSafety + minimumOuterPadding
  public static let revealedLeadingContentSafety = 14.0
  public static let zero = IslandHeadlineInsets(leading: 0, trailing: 0)

  public let leading: Double
  public let trailing: Double

  public static func resolve(
    for placement: IslandSideVisibility, isMinimum: Bool
  ) -> IslandHeadlineInsets {
    guard isMinimum else { return .zero }
    switch placement {
    case .left:
      return IslandHeadlineInsets(leading: minimumContentInset, trailing: 0)
    case .both:
      return IslandHeadlineInsets(
        leading: minimumContentInset, trailing: minimumContentInset)
    case .right:
      return IslandHeadlineInsets(leading: 0, trailing: minimumContentInset)
    }
  }
}
