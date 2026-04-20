import Foundation

struct WorkoutSetExercise: Codable, Identifiable {
  let id: String
  let setId: String
  let exerciseId: String?
  let exerciseOrder: Int
  let difficulty: String?
  let reps: String?
  var exercise: EmbeddedExercise?

  enum CodingKeys: String, CodingKey {
    case id
    case setId = "set_id"
    case exerciseId = "exercise_id"
    case exerciseOrder = "exercise_order"
    case difficulty
    case reps
    case exercise = "exercises"
  }

  var displayName: String {
    exercise?.name ?? "Custom"
  }
}

struct EmbeddedExercise: Codable {
  let name: String?
}
