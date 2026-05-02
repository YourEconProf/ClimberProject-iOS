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

  // USA Climbing Youth Series rule: competition age = seasonEndYear − birthYear,
  // held for the entire Sept 1 → Aug 31 season. See design/age-category-rule.md.
  var competitionAge: Int? {
    guard let dob else { return nil }
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.timeZone = TimeZone(identifier: "UTC")
    guard let birthDate = formatter.date(from: dob) else { return nil }

    var utc = Calendar(identifier: .gregorian)
    utc.timeZone = TimeZone(identifier: "UTC") ?? .gmt
    let birthYear = utc.component(.year, from: birthDate)

    let cal = Calendar.current
    let today = Date()
    let month = cal.component(.month, from: today)        // 1 = Jan, 9 = Sep
    let year = cal.component(.year, from: today)
    let seasonEndYear = month >= 9 ? year + 1 : year       // Sept–Dec → next year
    return seasonEndYear - birthYear
  }

  var ageCategory: String? {
    guard let age = competitionAge else { return nil }
    let isFinal = isFinalYear ?? false
    let arrow = isFinal ? "↑" : "↓"
    if age < 11 { return "U-11 \(arrow)" }
    if age < 13 { return "U-13 \(arrow)" }
    if age < 15 { return "U-15 \(arrow)" }
    if age < 17 { return "U-17 \(arrow)" }
    if age < 19 { return "U-19 \(arrow)" }
    if age == 19 { return "U-20 ↑" }
    return "Adult"
  }

  // True when the athlete is the older of the two birth years in their band —
  // i.e., aging out at the end of the current season.
  var isFinalYear: Bool? {
    guard let age = competitionAge else { return nil }
    return [10, 12, 14, 16, 18, 19].contains(age)
  }

  // true for U11/U13 athletes who get reduced check-in fields
  var isYouthRestrictedCheckin: Bool {
    guard let age = competitionAge else { return false }
    return age < 13
  }

  var hasTrainingMaxes: Bool {
    maxHangKg != nil || maxPullupAddedKg != nil || meEdgeMm != nil || lockoffSeconds != nil
  }

  var hasPhysicalData: Bool {
    heightCm != nil || weightKg != nil || wingspanCm != nil ||
    dominantHand != nil || gripPreference != nil ||
    fullCrimpReady == true || campusReady == true
  }

  var hasExperienceData: Bool {
    yearStartedClimbing != nil || yearStartedTraining != nil || experienceLevel != nil || phvStage != nil
  }
}
