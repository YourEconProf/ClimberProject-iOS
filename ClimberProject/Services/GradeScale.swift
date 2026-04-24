import Foundation

enum GradeScale {
  static let boulder = ["V0","V1","V2","V3","V4","V5","V6","V7","V8","V9","V10","V11","V12","V13"]
  static let rope    = ["5.0","5.1","5.2","5.3","5.4","5.5","5.6","5.7","5.8","5.9",
                        "5.10-","5.10","5.10+","5.11-","5.11","5.11+",
                        "5.12-","5.12","5.12+","5.13-","5.13","5.13+",
                        "5.14-","5.14","5.14+"]

  static let flashTokens = ["[flash]", "[flash-1]", "[flash-2]", "[flash-3]"]

  static func isFlashToken(_ s: String) -> Bool { flashTokens.contains(s) }

  // offset: 0=[flash], 1=[flash-1], 2=[flash-2], 3=[flash-3]
  static func resolveFlash(token: String, maxIndex: Double, scale: [String]) -> String {
    let offset: Int
    switch token {
    case "[flash]":   offset = 0
    case "[flash-1]": offset = 1
    case "[flash-2]": offset = 2
    case "[flash-3]": offset = 3
    default:          return token
    }
    let idx = max(0, Int(maxIndex.rounded()) - offset)
    return scale[min(idx, scale.count - 1)]
  }

  static func label(for value: Double, type: String) -> String? {
    switch type {
    case "boulder":
      let idx = Int(value.rounded())
      guard idx >= 0 && idx < boulder.count else { return nil }
      return boulder[idx]
    case "rope":
      let idx = Int(value.rounded())
      guard idx >= 0 && idx < rope.count else { return nil }
      return rope[idx]
    default: return nil
    }
  }
}
