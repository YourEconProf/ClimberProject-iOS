import Foundation

struct CompetitionResult: Codable, Identifiable {
  let id: String
  let athleteId: String
  let coachId: String
  let competitionDate: String
  let location: String
  let ranking: Int?
  let notes: String?
  let createdAt: String

  enum CodingKeys: String, CodingKey {
    case id
    case athleteId = "athlete_id"
    case coachId = "coach_id"
    case competitionDate = "competition_date"
    case location
    case ranking
    case notes
    case createdAt = "created_at"
  }
}
