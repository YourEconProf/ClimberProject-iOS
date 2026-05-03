import Foundation

struct Tag: Codable, Identifiable, Hashable {
  let id: String
  let gymId: String?
  let name: String
  let isSystem: Bool

  enum CodingKeys: String, CodingKey {
    case id
    case gymId = "gym_id"
    case name
    case isSystem = "is_system"
  }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    id       = try c.decode(String.self,        forKey: .id)
    gymId    = try c.decodeIfPresent(String.self, forKey: .gymId)
    name     = try c.decode(String.self,        forKey: .name)
    isSystem = try c.decodeIfPresent(Bool.self, forKey: .isSystem) ?? false
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
