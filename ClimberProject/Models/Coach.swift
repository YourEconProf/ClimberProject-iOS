import Foundation

struct Coach: Codable, Identifiable {
  let id: String
  let gymId: String
  let name: String
  let email: String
  let role: String // "coach", "head_coach", "admin"
  let unitPreference: String // "metric" | "imperial"

  enum CodingKeys: String, CodingKey {
    case id
    case gymId = "gym_id"
    case name
    case email
    case role
    case unitPreference = "unit_preference"
  }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    id    = try c.decode(String.self, forKey: .id)
    gymId = try c.decode(String.self, forKey: .gymId)
    name  = try c.decode(String.self, forKey: .name)
    email = try c.decode(String.self, forKey: .email)
    role  = try c.decode(String.self, forKey: .role)
    let raw = try c.decodeIfPresent(String.self, forKey: .unitPreference)
    unitPreference = (raw == "imperial") ? "imperial" : "metric"
  }

  init(id: String, gymId: String, name: String, email: String, role: String, unitPreference: String = "metric") {
    self.id = id
    self.gymId = gymId
    self.name = name
    self.email = email
    self.role = role
    self.unitPreference = unitPreference
  }

  var isHeadCoachOrAdmin: Bool {
    role == "head_coach" || role == "admin"
  }
}
