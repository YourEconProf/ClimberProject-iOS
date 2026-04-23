import Foundation

struct Exercise: Codable, Identifiable, Hashable {
  let id: String
  let gymId: String
  let name: String
  let difficultyType: String  // "free_text" | "boulder" | "rope" | "weight"

  enum CodingKeys: String, CodingKey {
    case id
    case gymId = "gym_id"
    case name
    case difficultyType = "difficulty_type"
  }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    id             = try c.decode(String.self, forKey: .id)
    gymId          = try c.decode(String.self, forKey: .gymId)
    name           = try c.decode(String.self, forKey: .name)
    difficultyType = try c.decodeIfPresent(String.self, forKey: .difficultyType) ?? "free_text"
  }
}
