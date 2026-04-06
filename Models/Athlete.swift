import Foundation

struct Athlete: Codable, Identifiable {
  let id: String
  let gymId: String
  let firstName: String
  let lastName: String
  let dob: String?
  let email: String?
  let tshirtSize: String?
  let isActive: Bool
  let createdAt: String

  enum CodingKeys: String, CodingKey {
    case id
    case gymId = "gym_id"
    case firstName = "first_name"
    case lastName = "last_name"
    case dob
    case email
    case tshirtSize = "tshirt_size"
    case isActive = "is_active"
    case createdAt = "created_at"
  }

  var displayName: String {
    "\(firstName) \(lastName)"
  }
}
