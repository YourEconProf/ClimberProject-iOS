import Foundation

struct Tag: Codable, Identifiable, Hashable {
  let id: String
  let gymId: String
  let name: String

  enum CodingKeys: String, CodingKey {
    case id
    case gymId = "gym_id"
    case name
  }
}

struct ExerciseTagRow: Codable {
  let exerciseId: String
  let tagId: String

  enum CodingKeys: String, CodingKey {
    case exerciseId = "exercise_id"
    case tagId = "tag_id"
  }
}

struct WorkoutTagRow: Codable {
  let workoutId: String
  let tagId: String

  enum CodingKeys: String, CodingKey {
    case workoutId = "workout_id"
    case tagId = "tag_id"
  }
}
