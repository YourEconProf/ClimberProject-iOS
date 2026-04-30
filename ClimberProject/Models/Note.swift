import Foundation

struct Note: Codable, Identifiable {
  let id: String
  let athleteId: String
  let coachId: String?
  let note: String
  let category: NoteCategory
  let isPrivate: Bool
  let createdAt: String

  enum CodingKeys: String, CodingKey {
    case id
    case athleteId = "athlete_id"
    case coachId = "coach_id"
    case note
    case category
    case isPrivate = "is_private"
    case createdAt = "created_at"
  }
}

enum NoteCategory: String, Codable, CaseIterable {
  case technical
  case behavioral
  case goal
  case injury
  case general
}
