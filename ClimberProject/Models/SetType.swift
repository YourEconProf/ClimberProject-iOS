import Foundation

struct SetType: Codable, Identifiable, Hashable {
  let id: String
  let gymId: String
  let name: String
  let createdAt: String?

  enum CodingKeys: String, CodingKey {
    case id, name
    case gymId = "gym_id"
    case createdAt = "created_at"
  }
}
