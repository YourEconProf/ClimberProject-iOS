import Foundation

struct Exercise: Codable, Identifiable, Hashable {
  let id: String
  let gymId: String
  let name: String

  enum CodingKeys: String, CodingKey {
    case id
    case gymId = "gym_id"
    case name
  }
}
