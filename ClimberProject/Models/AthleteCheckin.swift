import Foundation

struct AthleteCheckin: Codable, Identifiable {
  let id: String
  let athleteId: String
  let checkinDate: String
  let readinessScore: Int?
  let fingerComfortScore: Int?
  let sleepHours: Double?
  let mood: String?
  let notes: String?
  let createdAt: String

  enum CodingKeys: String, CodingKey {
    case id
    case athleteId = "athlete_id"
    case checkinDate = "checkin_date"
    case readinessScore = "readiness_score"
    case fingerComfortScore = "finger_comfort_score"
    case sleepHours = "sleep_hours"
    case mood
    case notes
    case createdAt = "created_at"
  }
}
