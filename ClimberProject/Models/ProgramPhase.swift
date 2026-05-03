import Foundation

enum PhaseType: String, CaseIterable, Identifiable {
  case base, skills, strength, power
  case powerEndurance = "power_endurance"
  case competition, peak, transition, deload

  var id: String { rawValue }
  var label: String {
    switch self {
    case .base:          return "Base"
    case .skills:        return "Skills"
    case .strength:      return "Strength"
    case .power:         return "Power"
    case .powerEndurance: return "Power Endurance"
    case .competition:   return "Competition"
    case .peak:          return "Peak"
    case .transition:    return "Transition"
    case .deload:        return "Deload"
    }
  }
}

struct ProgramPhase: Codable, Identifiable {
  let id: String
  let programId: String
  let name: String
  let startWeek: Int
  let endWeek: Int
  let isDeload: Bool
  let notes: String?
  let phaseType: String?

  enum CodingKeys: String, CodingKey {
    case id
    case programId = "program_id"
    case name
    case startWeek = "start_week"
    case endWeek = "end_week"
    case isDeload = "is_deload"
    case notes
    case phaseType = "phase_type"
  }

  var displayLabel: String {
    phaseType.flatMap { PhaseType(rawValue: $0)?.label }
      ?? (name.isEmpty ? "Phase \(startWeek)–\(endWeek)" : name)
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
