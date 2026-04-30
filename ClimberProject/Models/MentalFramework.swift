import Foundation

struct MentalFramework: Codable, Identifiable {
  let id: String
  let athleteId: String
  let component: String
  let content: String
  let version: Int
  let isCurrent: Bool
  let authoredBy: String?
  let createdAt: String

  enum CodingKeys: String, CodingKey {
    case id
    case athleteId = "athlete_id"
    case component
    case content
    case version
    case isCurrent = "is_current"
    case authoredBy = "authored_by"
    case createdAt = "created_at"
  }
}

enum MentalComponent: String, CaseIterable {
  case preCompRoutine = "pre_comp_routine"
  case observationProtocol = "observation_protocol"
  case leadCue = "lead_cue"
  case postAttemptReset = "post_attempt_reset"
  case postCompReview = "post_comp_review"

  var displayName: String {
    switch self {
    case .preCompRoutine: return "Pre-Comp Routine"
    case .observationProtocol: return "Observation Protocol"
    case .leadCue: return "Lead Cue"
    case .postAttemptReset: return "Post-Attempt Reset"
    case .postCompReview: return "Post-Comp Review"
    }
  }
}

func isMentalFrameworkEligible(programs: [Program], enrollments: [AthleteProgram]) -> Bool {
  let activeProgIds = Set(enrollments.filter { $0.droppedAt == nil }.map(\.programId))
  return programs.contains { activeProgIds.contains($0.id) && ($0.ageGroup == "U17" || $0.ageGroup == "U19") }
}
