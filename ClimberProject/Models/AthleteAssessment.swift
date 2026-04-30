import Foundation

struct AthleteAssessment: Codable, Identifiable {
  let id: String
  let athleteId: String
  let assessedAt: String
  let source: String
  let readinessTrend: String?
  let fingerComfortTrend: String?
  let loadTolerance: String?
  let summaryMarkdown: String?
  let recommendedFocus: String?
  let model: String?
  let promptVersion: String?
  let acknowledgedAt: String?

  enum CodingKeys: String, CodingKey {
    case id
    case athleteId = "athlete_id"
    case assessedAt = "assessed_at"
    case source
    case readinessTrend = "readiness_trend"
    case fingerComfortTrend = "finger_comfort_trend"
    case loadTolerance = "load_tolerance"
    case summaryMarkdown = "summary_markdown"
    case recommendedFocus = "recommended_focus"
    case model
    case promptVersion = "prompt_version"
    case acknowledgedAt = "acknowledged_at"
  }
}

struct AthleteAlert: Codable, Identifiable {
  let id: String
  let athleteId: String
  let alertType: String
  let severity: String   // info | warn | critical
  let message: String
  let resolvedAt: String?
  let acknowledgedAt: String?
  let createdAt: String

  enum CodingKeys: String, CodingKey {
    case id
    case athleteId = "athlete_id"
    case alertType = "alert_type"
    case severity
    case message
    case resolvedAt = "resolved_at"
    case acknowledgedAt = "acknowledged_at"
    case createdAt = "created_at"
  }
}

struct AthleteAlertWithAthlete: Codable, Identifiable {
  let id: String
  let athleteId: String
  let alertType: String
  let severity: String
  let message: String
  let resolvedAt: String?
  let acknowledgedAt: String?
  let createdAt: String
  let athletes: AthleteRef?

  struct AthleteRef: Codable {
    let id: String
    let firstName: String
    let lastName: String

    enum CodingKeys: String, CodingKey {
      case id
      case firstName = "first_name"
      case lastName = "last_name"
    }

    var displayName: String { "\(firstName) \(lastName)" }
  }

  enum CodingKeys: String, CodingKey {
    case id
    case athleteId = "athlete_id"
    case alertType = "alert_type"
    case severity
    case message
    case resolvedAt = "resolved_at"
    case acknowledgedAt = "acknowledged_at"
    case createdAt = "created_at"
    case athletes
  }
}
