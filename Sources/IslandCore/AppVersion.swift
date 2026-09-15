import Foundation

public enum AppVersion {
  public static func components(_ text: String) -> [Int]? {
    let parts = text.split(separator: ".", omittingEmptySubsequences: false)
    guard parts.count == 3,
      parts.allSatisfy({ !$0.isEmpty && $0.utf8.allSatisfy { (48...57).contains($0) } })
    else { return nil }
    let values = parts.compactMap { Int($0) }
    guard values.count == 3, values.allSatisfy({ $0 >= 0 }) else { return nil }
    return values
  }
  public static func isNewer(_ candidate: String, than current: String) -> Bool {
    guard let lhs = components(candidate), let rhs = components(current) else { return false }
    return rhs.lexicographicallyPrecedes(lhs)
  }
}
