import Foundation

struct WorkoutSet: Codable, Identifiable {
  let id: String
  let workoutId: String
  let setOrder: Int
  let repeatCount: Int?
  let roundsCount: Int?
  let setTypeId: String?
  var setType: EmbeddedSetType?
  var exercises: [WorkoutSetExercise]?

  enum CodingKeys: String, CodingKey {
    case id
    case workoutId = "workout_id"
    case setOrder = "set_order"
    case repeatCount = "repeat_count"
    case roundsCount = "rounds_count"
    case setTypeId = "set_type_id"
    case setType = "set_types"
    case exercises = "workout_set_exercises"
  }

  var sortedExercises: [WorkoutSetExercise] {
    (exercises ?? []).sorted { $0.exerciseOrder < $1.exerciseOrder }
  }

  var effectiveRoundsCount: Int {
    max(1, roundsCount ?? 1)
  }
}

struct EmbeddedSetType: Codable {
  let name: String?
}
