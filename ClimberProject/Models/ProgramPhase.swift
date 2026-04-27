import Foundation

struct ProgramPhase: Codable, Identifiable {
  let id: String
  let programId: String
  let name: String
  let startWeek: Int
  let endWeek: Int
  let isDeload: Bool
  let notes: String?

  enum CodingKeys: String, CodingKey {
    case id
    case programId = "program_id"
    case name
    case startWeek = "start_week"
    case endWeek = "end_week"
    case isDeload = "is_deload"
    case notes
  }
}

struct ProgramPlanVersion: Codable, Identifiable {
  let id: String
  let programId: String
  let versionNum: Int
  let planMarkdown: String
  let editMessage: String?
  let editedBy: String
  let createdAt: String

  enum CodingKeys: String, CodingKey {
    case id
    case programId = "program_id"
    case versionNum = "version_num"
    case planMarkdown = "plan_markdown"
    case editMessage = "edit_message"
    case editedBy = "edited_by"
    case createdAt = "created_at"
  }
}
