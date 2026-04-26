import Foundation

struct Program: Codable, Identifiable {
  let id: String
  let gymId: String
  let name: String

  // Scheduling
  let ageGroup: String?                  // U11 | U13 | U15 | U17 | U19 | OPEN
  let discipline: String?                // boulder | rope | both
  let startDate: String?
  let endDate: String?
  let practiceDays: [Int]?               // 1=Mon … 7=Sun
  let practiceStartTime: String?         // HH:MM:SS
  let practiceDurationMinutes: Int?
  let practiceLocation: String?
  let notes: String?

  // Training plan
  let planMarkdown: String?
  let planUpdatedAt: String?
  let planUpdatedBy: String?             // coach uuid
  let openingTemplateId: String?         // workout uuid

  enum CodingKeys: String, CodingKey {
    case id
    case gymId = "gym_id"
    case name
    case ageGroup = "age_group"
    case discipline
    case startDate = "start_date"
    case endDate = "end_date"
    case practiceDays = "practice_days"
    case practiceStartTime = "practice_start_time"
    case practiceDurationMinutes = "practice_duration_minutes"
    case practiceLocation = "practice_location"
    case notes
    case planMarkdown = "plan_markdown"
    case planUpdatedAt = "plan_updated_at"
    case planUpdatedBy = "plan_updated_by"
    case openingTemplateId = "opening_template_id"
  }

  var practiceDayNames: String {
    guard let days = practiceDays, !days.isEmpty else { return "" }
    let names = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    return days.compactMap { i in (1...7).contains(i) ? names[i - 1] : nil }.joined(separator: ", ")
  }
}

struct AthleteProgram: Codable, Identifiable {
  let athleteId: String
  let programId: String
  let enrolledAt: String
  let droppedAt: String?

  // Composite primary key — synthesise a stable id for SwiftUI lists
  var id: String { "\(athleteId)_\(programId)" }

  enum CodingKeys: String, CodingKey {
    case athleteId = "athlete_id"
    case programId = "program_id"
    case enrolledAt = "enrolled_at"
    case droppedAt = "dropped_at"
  }
}
