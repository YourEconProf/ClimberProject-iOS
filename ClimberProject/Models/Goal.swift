import Foundation

struct Goal: Codable, Identifiable {
  let id: String
  let athleteId: String
  let coachId: String
  let description: String
  let status: GoalStatus
  let setAt: String
  let resolvedAt: String?

  enum CodingKeys: String, CodingKey {
    case id
    case athleteId = "athlete_id"
    case coachId = "coach_id"
    case description
    case status
    case setAt = "set_at"
    case resolvedAt = "resolved_at"
  }
}

enum GoalStatus: String, Codable {
  case active
  case achieved
  case dropped
}
