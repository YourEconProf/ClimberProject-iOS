import Foundation

struct Evaluation: Codable, Identifiable {
  let id: String
  let athleteId: String
  let coachId: String
  let criteriaId: String
  let evaluatedAt: String
  let value: Double?
  let notes: String?
  let createdAt: String

  enum CodingKeys: String, CodingKey {
    case id
    case athleteId = "athlete_id"
    case coachId = "coach_id"
    case criteriaId = "criteria_id"
    case evaluatedAt = "evaluated_at"
    case value
    case notes
    case createdAt = "created_at"
  }
}

struct AssessmentCriteria: Codable, Identifiable {
  let id: String
  let gymId: String
  let name: String
  let unit: String?
  let isFm: Bool
  let isMorpho: Bool
  let isStrength: Bool
  let createdAt: String

  enum CodingKeys: String, CodingKey {
    case id
    case gymId = "gym_id"
    case name
    case unit
    case isFm = "is_fm"
    case isMorpho = "is_morpho"
    case isStrength = "is_strength"
    case createdAt = "created_at"
  }
}
