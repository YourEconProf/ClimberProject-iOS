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

  // Experience
  let yearStartedClimbing: Int?
  let yearStartedTraining: Int?
  let experienceLevel: String?   // recreational | intermediate | advanced | elite
  let phvStage: String?          // pre | peri | post | unknown

  // Physical
  let heightCm: Double?
  let weightKg: Double?
  let wingspanCm: Double?
  let dominantHand: String?      // left | right
  let gripPreference: String?    // open | half_crimp | full_crimp
  let fullCrimpReady: Bool?
  let campusReady: Bool?

  // Denormalized training maxes (kept in sync by DB trigger)
  let maxHangKg: Double?
  let maxPullupAddedKg: Double?
  let meEdgeMm: Int?
  let lockoffSeconds: Int?
  let maxesUpdatedAt: String?

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
    case yearStartedClimbing = "year_started_climbing"
    case yearStartedTraining = "year_started_training"
    case experienceLevel = "experience_level"
    case phvStage = "phv_stage"
    case heightCm = "height_cm"
    case weightKg = "weight_kg"
    case wingspanCm = "wingspan_cm"
    case dominantHand = "dominant_hand"
    case gripPreference = "grip_preference"
    case fullCrimpReady = "full_crimp_ready"
    case campusReady = "campus_ready"
    case maxHangKg = "max_hang_kg"
    case maxPullupAddedKg = "max_pullup_added_kg"
    case meEdgeMm = "me_edge_mm"
    case lockoffSeconds = "lockoff_seconds"
    case maxesUpdatedAt = "maxes_updated_at"
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

  // true for U11/U13 athletes who get reduced check-in fields
  var isYouthRestrictedCheckin: Bool {
    guard let dob else { return false }
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    guard let birthDate = formatter.date(from: dob) else { return false }
    let calendar = Calendar.current
    let month = calendar.component(.month, from: Date())
    let year = calendar.component(.year, from: Date())
    let cutoffYear = month >= 9 ? year + 1 : year
    var components = DateComponents()
    components.year = cutoffYear; components.month = 8; components.day = 31
    guard let cutoff = calendar.date(from: components) else { return false }
    let age = calendar.dateComponents([.year], from: birthDate, to: cutoff).year ?? 0
    return age < 14
  }

  var hasTrainingMaxes: Bool {
    maxHangKg != nil || maxPullupAddedKg != nil || meEdgeMm != nil || lockoffSeconds != nil
  }

  var hasPhysicalData: Bool {
    heightCm != nil || weightKg != nil || wingspanCm != nil || dominantHand != nil || gripPreference != nil
  }

  var hasExperienceData: Bool {
    yearStartedClimbing != nil || yearStartedTraining != nil || experienceLevel != nil || phvStage != nil
  }
}
