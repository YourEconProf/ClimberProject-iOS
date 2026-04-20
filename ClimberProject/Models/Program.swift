import Foundation

struct Program: Codable, Identifiable {
  let id: String
  let gymId: String
  let name: String

  enum CodingKeys: String, CodingKey {
    case id
    case gymId = "gym_id"
    case name
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
