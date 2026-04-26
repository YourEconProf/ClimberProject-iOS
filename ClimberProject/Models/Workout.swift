import Foundation

struct Workout: Codable, Identifiable {
  let id: String
  let athleteId: String?
  let coachId: String
  let gymId: String?
  let workoutDate: String
  let name: String?
  let templateName: String?
  let notes: String?
  let status: String?      // draft | approved | completed; nil = pre-feature rows
  let plannedFor: String?  // date the AI generated this workout for
  var sets: [WorkoutSet]?
  var coach: EmbeddedCoach?
  var athlete: EmbeddedAthlete?

  enum CodingKeys: String, CodingKey {
    case id
    case athleteId = "athlete_id"
    case coachId = "coach_id"
    case gymId = "gym_id"
    case workoutDate = "workout_date"
    case name
    case templateName = "template_name"
    case notes
    case status
    case plannedFor = "planned_for"
    case sets = "workout_sets"
    case coach = "coaches"
    case athlete = "athletes"
  }

  var sortedSets: [WorkoutSet] {
    (sets ?? []).sorted { $0.setOrder < $1.setOrder }
  }

  var totalExerciseCount: Int {
    sortedSets.reduce(0) { $0 + ($1.exercises?.count ?? 0) }
  }

  var isTemplate: Bool {
    athleteId == nil && gymId != nil
  }

  var isDraft: Bool { status == "draft" }
  var isCompleted: Bool { status == "completed" }

  var displayTitle: String {
    templateName ?? name ?? (athlete?.displayName ?? (isTemplate ? "Workout Template" : "Workout"))
  }
}

struct EmbeddedCoach: Codable {
  let name: String?
}

struct EmbeddedAthlete: Codable, Identifiable {
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
