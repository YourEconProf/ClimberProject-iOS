import Foundation

struct Coach: Codable, Identifiable {
  let id: String
  let gymId: String
  let name: String
  let email: String
  let role: String // "coach", "head_coach", "admin"

  enum CodingKeys: String, CodingKey {
    case id
    case gymId = "gym_id"
    case name
    case email
    case role
  }

  var isHeadCoachOrAdmin: Bool {
    role == "head_coach" || role == "admin"
  }
}
