import Foundation

struct WorkoutSet: Codable, Identifiable {
  let id: String
  let workoutId: String
  let setOrder: Int
  let repeatCount: Int?
  var exercises: [WorkoutSetExercise]?

  enum CodingKeys: String, CodingKey {
    case id
    case workoutId = "workout_id"
    case setOrder = "set_order"
    case repeatCount = "repeat_count"
    case exercises = "workout_set_exercises"
  }

  var sortedExercises: [WorkoutSetExercise] {
    (exercises ?? []).sorted { $0.exerciseOrder < $1.exerciseOrder }
  }
}
