import Foundation
import Combine
import Supabase

// MARK: - Draft types used by the Add/Edit form

struct DraftExercise: Identifiable, Equatable {
  let id: UUID
  var exerciseId: String?   // nil => custom/free-text
  var customName: String
  var difficulty: String
  var reps: String          // held as string so the text field can be blank

  init(id: UUID = UUID(), exerciseId: String? = nil, customName: String = "", difficulty: String = "", reps: String = "") {
    self.id = id
    self.exerciseId = exerciseId
    self.customName = customName
    self.difficulty = difficulty
    self.reps = reps
  }
}

struct DraftSet: Identifiable, Equatable {
  let id: UUID
  var repeatCount: Int
  var exercises: [DraftExercise]

  init(id: UUID = UUID(), repeatCount: Int = 1, exercises: [DraftExercise] = []) {
    self.id = id
    self.repeatCount = repeatCount
    self.exercises = exercises
  }
}

// Nested select used for workout reads
private let workoutSelectWithNesting = """
*, coaches(name), athletes(id, first_name, last_name), workout_sets(*, workout_set_exercises(*, exercises(name)))
"""

@MainActor
class WorkoutViewModel: ObservableObject {
  @Published var workouts: [Workout] = []        // current athlete's workouts
  @Published var namedWorkouts: [Workout] = []   // the library (name != null)
  @Published var exercises: [Exercise] = []       // gym's exercise library
  @Published var isLoading = false
  @Published var error: String?

  private var supabase: SupabaseClient { SupabaseService.shared.supabase }

  // MARK: - Reads

  func fetchWorkouts(athleteId: String) async {
    isLoading = true
    error = nil
    defer { isLoading = false }
    do {
      let response = try await supabase
        .from("workouts")
        .select(workoutSelectWithNesting)
        .eq("athlete_id", value: athleteId)
        .order("workout_date", ascending: false)
        .execute()
      do {
        workouts = try decoder.decode([Workout].self, from: response.data)
      } catch {
        let raw = String(data: response.data, encoding: .utf8) ?? "<non-utf8>"
        print("[Workouts] decode error: \(error)")
        print("[Workouts] raw JSON: \(raw)")
        self.error = describe(decodingError: error, raw: raw)
      }
    } catch {
      print("[Workouts] network error: \(error)")
      self.error = error.localizedDescription
    }
  }

  private var decoder: JSONDecoder {
    let d = JSONDecoder()
    return d
  }

  private func describe(decodingError error: Error, raw: String) -> String {
    guard let e = error as? DecodingError else { return error.localizedDescription }
    switch e {
    case .keyNotFound(let key, let ctx):
      return "Missing key '\(key.stringValue)' at \(pathString(ctx.codingPath)): \(ctx.debugDescription)"
    case .typeMismatch(let type, let ctx):
      return "Type mismatch for \(type) at \(pathString(ctx.codingPath)): \(ctx.debugDescription)"
    case .valueNotFound(let type, let ctx):
      return "Null value for non-optional \(type) at \(pathString(ctx.codingPath))"
    case .dataCorrupted(let ctx):
      return "Data corrupted at \(pathString(ctx.codingPath)): \(ctx.debugDescription)"
    @unknown default:
      return error.localizedDescription
    }
  }

  private func pathString(_ path: [CodingKey]) -> String {
    path.map { $0.stringValue }.joined(separator: ".")
  }

  func fetchNamedWorkouts() async {
    isLoading = true
    defer { isLoading = false }
    do {
      let response = try await supabase
        .from("workouts")
        .select(workoutSelectWithNesting)
        .not("name", operator: .is, value: "null")
        .order("name", ascending: true)
        .execute()
      do {
        namedWorkouts = try decoder.decode([Workout].self, from: response.data)
      } catch {
        let raw = String(data: response.data, encoding: .utf8) ?? "<non-utf8>"
        print("[Workouts] named decode error: \(error)")
        print("[Workouts] named raw JSON: \(raw)")
        // Swallow — an empty library shouldn't break the history view.
      }
    } catch {
      print("[Workouts] named network error: \(error)")
    }
  }

  func fetchExercises(gymId: String) async {
    do {
      exercises = try await supabase
        .from("exercises")
        .select()
        .eq("gym_id", value: gymId)
        .order("name", ascending: true)
        .execute()
        .value
    } catch {
      print("[Workouts] exercises error: \(error)")
    }
  }

  private func fetchWorkout(id: String) async throws -> Workout {
    try await supabase
      .from("workouts")
      .select(workoutSelectWithNesting)
      .eq("id", value: id)
      .single()
      .execute()
      .value
  }

  // MARK: - Create

  func createWorkout(
    athleteId: String,
    coachId: String,
    date: String,
    name: String?,
    notes: String?,
    sets: [DraftSet]
  ) async throws -> Workout {
    let insert = WorkoutInsert(
      athleteId: athleteId,
      coachId: coachId,
      workoutDate: date,
      name: name?.isEmpty == true ? nil : name,
      notes: notes?.isEmpty == true ? nil : notes
    )
    let created: InsertedWorkout = try await supabase
      .from("workouts")
      .insert(insert)
      .select()
      .single()
      .execute()
      .value

    try await insertSetsAndExercises(workoutId: created.id, sets: sets)
    let full = try await fetchWorkout(id: created.id)
    // Keep local caches in sync
    if full.athleteId == athleteId {
      workouts.insert(full, at: 0)
      workouts.sort { $0.workoutDate > $1.workoutDate }
    }
    if full.name != nil {
      namedWorkouts.append(full)
      namedWorkouts.sort { ($0.name ?? "") < ($1.name ?? "") }
    }
    return full
  }

  // MARK: - Update (full rebuild)

  func updateWorkout(
    _ workout: Workout,
    date: String,
    name: String?,
    notes: String?,
    sets: [DraftSet]
  ) async throws {
    let update = WorkoutUpdate(
      workoutDate: date,
      name: name?.isEmpty == true ? nil : name,
      notes: notes?.isEmpty == true ? nil : notes
    )
    try await supabase
      .from("workouts")
      .update(update)
      .eq("id", value: workout.id)
      .execute()

    try await supabase
      .from("workout_sets")
      .delete()
      .eq("workout_id", value: workout.id)
      .execute()

    try await insertSetsAndExercises(workoutId: workout.id, sets: sets)

    let full = try await fetchWorkout(id: workout.id)
    if let idx = workouts.firstIndex(where: { $0.id == workout.id }) {
      workouts[idx] = full
    }
    if let idx = namedWorkouts.firstIndex(where: { $0.id == workout.id }) {
      if full.name == nil {
        namedWorkouts.remove(at: idx)
      } else {
        namedWorkouts[idx] = full
      }
    } else if full.name != nil {
      namedWorkouts.append(full)
      namedWorkouts.sort { ($0.name ?? "") < ($1.name ?? "") }
    }
  }

  // MARK: - Lightweight notes patch

  func updateWorkoutNotes(id: String, notes: String?) async throws {
    let patch = NotesPatch(notes: notes?.isEmpty == true ? nil : notes)
    try await supabase
      .from("workouts")
      .update(patch)
      .eq("id", value: id)
      .execute()
    if let idx = workouts.firstIndex(where: { $0.id == id }) {
      let w = workouts[idx]
      workouts[idx] = Workout(
        id: w.id, athleteId: w.athleteId, coachId: w.coachId,
        workoutDate: w.workoutDate, name: w.name, notes: patch.notes,
        sets: w.sets, coach: w.coach, athlete: w.athlete
      )
    }
    if let idx = namedWorkouts.firstIndex(where: { $0.id == id }) {
      let w = namedWorkouts[idx]
      namedWorkouts[idx] = Workout(
        id: w.id, athleteId: w.athleteId, coachId: w.coachId,
        workoutDate: w.workoutDate, name: w.name, notes: patch.notes,
        sets: w.sets, coach: w.coach, athlete: w.athlete
      )
    }
  }

  // MARK: - Copy

  func copyNamedWorkout(_ source: Workout, toAthleteId: String, coachId: String, date: String) async throws -> Workout {
    let drafts = source.sortedSets.map { s in
      DraftSet(
        repeatCount: s.repeatCount ?? 1,
        exercises: s.sortedExercises.map { ex in
          DraftExercise(
            exerciseId: ex.exerciseId,
            customName: ex.exercise?.name ?? "",
            difficulty: ex.difficulty ?? "",
            reps: ex.reps ?? ""
          )
        }
      )
    }
    return try await createWorkout(
      athleteId: toAthleteId,
      coachId: coachId,
      date: date,
      name: nil,                      // copies drop the name
      notes: source.notes,
      sets: drafts
    )
  }

  // MARK: - Delete

  func deleteWorkout(id: String) async throws {
    try await supabase
      .from("workouts")
      .delete()
      .eq("id", value: id)
      .execute()
    workouts.removeAll { $0.id == id }
    namedWorkouts.removeAll { $0.id == id }
  }

  // MARK: - Exercise library mgmt

  func addExercise(gymId: String, name: String) async throws -> Exercise {
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    let insert = ExerciseInsert(gymId: gymId, name: trimmed)
    let created: Exercise = try await supabase
      .from("exercises")
      .insert(insert)
      .select()
      .single()
      .execute()
      .value
    exercises.append(created)
    exercises.sort { $0.name.lowercased() < $1.name.lowercased() }
    return created
  }

  // MARK: - Private helpers

  private func insertSetsAndExercises(workoutId: String, sets: [DraftSet]) async throws {
    guard !sets.isEmpty else { return }

    let setInserts = sets.enumerated().map { idx, s in
      SetInsert(workoutId: workoutId, setOrder: idx, repeatCount: s.repeatCount)
    }
    let createdSets: [InsertedSet] = try await supabase
      .from("workout_sets")
      .insert(setInserts)
      .select()
      .execute()
      .value

    // Map returned sets back to their draft by set_order
    let byOrder = Dictionary(uniqueKeysWithValues: createdSets.map { ($0.setOrder, $0.id) })

    var exerciseInserts: [SetExerciseInsert] = []
    for (idx, draftSet) in sets.enumerated() {
      guard let setId = byOrder[idx] else { continue }
      for (exIdx, ex) in draftSet.exercises.enumerated() {
        exerciseInserts.append(
          SetExerciseInsert(
            setId: setId,
            exerciseId: ex.exerciseId,
            exerciseOrder: exIdx,
            difficulty: ex.difficulty.isEmpty ? nil : ex.difficulty,
            reps: ex.reps.isEmpty ? nil : ex.reps
          )
        )
      }
    }
    if !exerciseInserts.isEmpty {
      try await supabase
        .from("workout_set_exercises")
        .insert(exerciseInserts)
        .execute()
    }
  }
}

// MARK: - Encodable helpers

private struct WorkoutInsert: Encodable {
  let athleteId: String
  let coachId: String
  let workoutDate: String
  let name: String?
  let notes: String?

  enum CodingKeys: String, CodingKey {
    case athleteId = "athlete_id"
    case coachId = "coach_id"
    case workoutDate = "workout_date"
    case name, notes
  }
}

private struct WorkoutUpdate: Encodable {
  let workoutDate: String
  let name: String?
  let notes: String?

  enum CodingKeys: String, CodingKey {
    case workoutDate = "workout_date"
    case name, notes
  }
}

private struct NotesPatch: Encodable {
  let notes: String?
}

private struct SetInsert: Encodable {
  let workoutId: String
  let setOrder: Int
  let repeatCount: Int?

  enum CodingKeys: String, CodingKey {
    case workoutId = "workout_id"
    case setOrder = "set_order"
    case repeatCount = "repeat_count"
  }
}

private struct InsertedSet: Decodable {
  let id: String
  let setOrder: Int

  enum CodingKeys: String, CodingKey {
    case id
    case setOrder = "set_order"
  }
}

private struct InsertedWorkout: Decodable {
  let id: String
}

private struct SetExerciseInsert: Encodable {
  let setId: String
  let exerciseId: String?
  let exerciseOrder: Int
  let difficulty: String?
  let reps: String?

  enum CodingKeys: String, CodingKey {
    case setId = "set_id"
    case exerciseId = "exercise_id"
    case exerciseOrder = "exercise_order"
    case difficulty, reps
  }
}

private struct ExerciseInsert: Encodable {
  let gymId: String
  let name: String

  enum CodingKeys: String, CodingKey {
    case gymId = "gym_id"
    case name
  }
}
