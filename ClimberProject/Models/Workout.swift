import Foundation

struct Workout: Codable, Identifiable {
  let id: String
  let athleteId: String?
  let coachId: String
  let gymId: String?
  let workoutDate: String
  let name: String?
  let notes: String?
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
    case notes
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

  var displayTitle: String {
    name ?? (athlete?.displayName ?? (isTemplate ? "Workout Template" : "Workout"))
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
