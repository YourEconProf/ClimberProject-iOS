import Foundation

struct EmergencyContact: Codable {
  let name: String
  let phone: String
}

struct Athlete: Codable, Identifiable {
  let id: String
  let gymId: String
  let firstName: String
  let lastName: String
  let dob: String?
  let email: String?
  let tshirtSize: String?
  let emergencyContacts: [EmergencyContact]?
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
    case emergencyContacts = "emergency_contacts"
    case isActive = "is_active"
    case createdAt = "created_at"
  }

  var displayName: String {
    "\(firstName) \(lastName)"
  }

  var ageCategory: String? {
    guard let dob else { return nil }
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    guard let birthDate = formatter.date(from: dob) else { return nil }

    let today = Date()
    let calendar = Calendar.current
    let month = calendar.component(.month, from: today) // 1=Jan, 9=Sep
    let year = calendar.component(.year, from: today)
    let cutoffYear = month >= 9 ? year + 1 : year

    var components = DateComponents()
    components.year = cutoffYear
    components.month = 8  // August
    components.day = 31
    guard let cutoff = calendar.date(from: components) else { return nil }

    let age = calendar.dateComponents([.year], from: birthDate, to: cutoff).year ?? 0
    if age < 11 { return "U-11 \(age == 10 ? "↑" : "↓")" }
    if age < 13 { return "U-13 \(age == 12 ? "↑" : "↓")" }
    if age < 15 { return "U-15 \(age == 14 ? "↑" : "↓")" }
    if age < 17 { return "U-17 \(age == 16 ? "↑" : "↓")" }
    if age < 19 { return "U-19 \(age == 18 ? "↑" : "↓")" }
    if age < 20 { return "U-20 \(age == 19 ? "↑" : "↓")" }
    return "Adult"
  }
}
