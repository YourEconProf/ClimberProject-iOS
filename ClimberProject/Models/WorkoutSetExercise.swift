import Foundation

struct WorkoutSetExercise: Codable, Identifiable {
  let id: String
  let setId: String
  let exerciseId: String?
  let exerciseOrder: Int
  let difficulty: String?
  let reps: String?
  let difficultyRounds: [String]?
  let repsRounds: [String]?
  var exercise: EmbeddedExercise?

  enum CodingKeys: String, CodingKey {
    case id
    case setId = "set_id"
    case exerciseId = "exercise_id"
    case exerciseOrder = "exercise_order"
    case difficulty
    case reps
    case difficultyRounds = "difficulty_rounds"
    case repsRounds = "reps_rounds"
    case exercise = "exercises"
  }

  var displayName: String { exercise?.name ?? "Custom" }
  var difficultyType: String { exercise?.difficultyType ?? "free_text" }

  /// Always returns at least one element. Falls back to scalar `difficulty` for pre-rounds rows.
  func effectiveDifficulties(roundsCount: Int) -> [String] {
    let arr = difficultyRounds ?? []
    let seed = arr.isEmpty ? [difficulty ?? ""] : arr
    return resize(seed, to: roundsCount)
  }

  /// Always returns at least one element. Falls back to scalar `reps` for pre-rounds rows.
  func effectiveReps(roundsCount: Int) -> [String] {
    let arr = repsRounds ?? []
    let seed = arr.isEmpty ? [reps ?? ""] : arr
    return resize(seed, to: roundsCount)
  }

  private func resize(_ arr: [String], to count: Int) -> [String] {
    let target = max(1, count)
    if arr.count == target { return arr }
    if arr.count > target { return Array(arr.prefix(target)) }
    return arr + Array(repeating: "", count: target - arr.count)
  }
}

struct EmbeddedExercise: Codable {
  let name: String?
  let difficultyType: String?

  enum CodingKeys: String, CodingKey {
    case name
    case difficultyType = "difficulty_type"
  }
}
