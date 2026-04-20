import Foundation
import Combine
import Supabase

// MARK: - Draft types used by the Add/Edit form

struct DraftExercise: Identifiable, Equatable {
  let id: UUID
  var exerciseId: String?    // nil => custom/free-text
  var customName: String
  var difficulties: [String] // length == set.roundsCount
  var reps: [String]         // length == set.roundsCount

  init(
    id: UUID = UUID(),
    exerciseId: String? = nil,
    customName: String = "",
    difficulties: [String] = [""],
    reps: [String] = [""]
  ) {
    self.id = id
    self.exerciseId = exerciseId
    self.customName = customName
    self.difficulties = difficulties
    self.reps = reps
  }
}

struct DraftSet: Identifiable, Equatable {
  let id: UUID
  var setTypeId: String?
  var repeatCount: Int
  var roundsCount: Int
  var exercises: [DraftExercise]

  init(
    id: UUID = UUID(),
    setTypeId: String? = nil,
    repeatCount: Int = 1,
    roundsCount: Int = 1,
    exercises: [DraftExercise] = []
  ) {
    self.id = id
    self.setTypeId = setTypeId
    self.repeatCount = repeatCount
    self.roundsCount = roundsCount
    self.exercises = exercises
  }
}

// Nested select used for workout reads
private let workoutSelectWithNesting = """
*, coaches(name), athletes(id, first_name, last_name), workout_sets(*, set_types(name), workout_set_exercises(*, exercises(name)))
"""

@MainActor
class WorkoutViewModel: ObservableObject {
  @Published var workouts: [Workout] = []
  @Published var namedWorkouts: [Workout] = []
  @Published var exercises: [Exercise] = []
  @Published var setTypes: [SetType] = []
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

  func fetchNamedWorkouts() async {
    isLoading = true
    defer { isLoading = false }
    do {
      // Fetch workouts that have either a name (athlete) or template_name (template)
      let byName = try await supabase
        .from("workouts")
        .select(workoutSelectWithNesting)
        .not("name", operator: .is, value: "null")
        .execute()
      let byTemplateName = try await supabase
        .from("workouts")
        .select(workoutSelectWithNesting)
        .not("template_name", operator: .is, value: "null")
        .execute()
      do {
        let named = try decoder.decode([Workout].self, from: byName.data)
        let templates = try decoder.decode([Workout].self, from: byTemplateName.data)
        var combined = named + templates.filter { t in !named.contains(where: { $0.id == t.id }) }
        combined.sort { $0.displayTitle < $1.displayTitle }
        namedWorkouts = combined
      } catch {
        let raw = String(data: byName.data, encoding: .utf8) ?? "<non-utf8>"
        print("[Workouts] named decode error: \(error)")
        print("[Workouts] named raw JSON: \(raw)")
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

  func fetchSetTypes(gymId: String) async {
    do {
      setTypes = try await supabase
        .from("set_types")
        .select()
        .eq("gym_id", value: gymId)
        .order("name", ascending: true)
        .execute()
        .value
    } catch {
      print("[Workouts] set_types error: \(error)")
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

  // MARK: - Name uniqueness

  /// Returns true if a non-nil name collides with another workout. `excludingId` allows editing the same row.
  func nameIsTaken(_ name: String, excludingId: String? = nil) async -> Bool {
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return false }
    do {
      let rows: [NameRow] = try await supabase
        .from("workouts")
        .select("id, template_name")
        .ilike("template_name", pattern: trimmed)
        .execute()
        .value
      return rows.contains { $0.id != excludingId }
    } catch {
      print("[Workouts] name check error: \(error)")
      return false
    }
  }

  // MARK: - Create

  /// Create a workout. Pass `athleteId` for an athlete workout, or `gymId` (with `athleteId == nil`) for a template.
  func createWorkout(
    athleteId: String?,
    coachId: String,
    gymId: String?,
    date: String,
    name: String?,
    notes: String?,
    sets: [DraftSet]
  ) async throws -> Workout {
    let isTemplate = athleteId == nil && gymId != nil
    let resolvedName = name?.isEmpty == true ? nil : name
    let insert = WorkoutInsert(
      athleteId: athleteId,
      coachId: coachId,
      gymId: gymId,
      workoutDate: date,
      name: isTemplate ? nil : resolvedName,
      templateName: isTemplate ? resolvedName : nil,
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
    if let athleteId, full.athleteId == athleteId {
      workouts.insert(full, at: 0)
      workouts.sort { $0.workoutDate > $1.workoutDate }
    }
    if full.name != nil || full.templateName != nil {
      namedWorkouts.append(full)
      namedWorkouts.sort { $0.displayTitle < $1.displayTitle }
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
    let isTemplate = workout.athleteId == nil && workout.gymId != nil
    let resolvedName = name?.isEmpty == true ? nil : name
    let update = WorkoutUpdate(
      workoutDate: date,
      name: isTemplate ? nil : resolvedName,
      templateName: isTemplate ? resolvedName : nil,
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
      if full.name == nil && full.templateName == nil {
        namedWorkouts.remove(at: idx)
      } else {
        namedWorkouts[idx] = full
        namedWorkouts.sort { $0.displayTitle < $1.displayTitle }
      }
    } else if full.name != nil || full.templateName != nil {
      namedWorkouts.append(full)
      namedWorkouts.sort { $0.displayTitle < $1.displayTitle }
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
        id: w.id, athleteId: w.athleteId, coachId: w.coachId, gymId: w.gymId,
        workoutDate: w.workoutDate, name: w.name, notes: patch.notes,
        sets: w.sets, coach: w.coach, athlete: w.athlete
      )
    }
    if let idx = namedWorkouts.firstIndex(where: { $0.id == id }) {
      let w = namedWorkouts[idx]
      namedWorkouts[idx] = Workout(
        id: w.id, athleteId: w.athleteId, coachId: w.coachId, gymId: w.gymId,
        workoutDate: w.workoutDate, name: w.name, notes: patch.notes,
        sets: w.sets, coach: w.coach, athlete: w.athlete
      )
    }
  }

  // MARK: - Copy

  func copyNamedWorkout(_ source: Workout, toAthleteId: String, coachId: String, date: String) async throws -> Workout {
    let drafts = source.sortedSets.map { s in
      let rc = s.effectiveRoundsCount
      return DraftSet(
        setTypeId: s.setTypeId,
        repeatCount: s.repeatCount ?? 1,
        roundsCount: rc,
        exercises: s.sortedExercises.map { ex in
          DraftExercise(
            exerciseId: ex.exerciseId,
            customName: ex.exercise?.name ?? "",
            difficulties: ex.effectiveDifficulties(roundsCount: rc),
            reps: ex.effectiveReps(roundsCount: rc)
          )
        }
      )
    }
    return try await createWorkout(
      athleteId: toAthleteId,
      coachId: coachId,
      gymId: nil,
      date: date,
      name: nil,
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

  func deleteExercise(id: String) async throws {
    do {
      try await supabase
        .from("exercises")
        .delete()
        .eq("id", value: id)
        .execute()
      exercises.removeAll { $0.id == id }
    } catch {
      let msg = "\(error)".lowercased()
      if msg.contains("23503") || msg.contains("foreign key") {
        throw WorkoutVMError.exerciseInUse
      }
      throw error
    }
  }

  // MARK: - Set type library mgmt

  func addSetType(gymId: String, name: String) async throws -> SetType {
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    let insert = SetTypeInsert(gymId: gymId, name: trimmed)
    let created: SetType = try await supabase
      .from("set_types")
      .insert(insert)
      .select()
      .single()
      .execute()
      .value
    setTypes.append(created)
    setTypes.sort { $0.name.lowercased() < $1.name.lowercased() }
    return created
  }

  func deleteSetType(id: String) async throws {
    do {
      try await supabase
        .from("set_types")
        .delete()
        .eq("id", value: id)
        .execute()
      setTypes.removeAll { $0.id == id }
    } catch {
      // on delete restrict (23503) if set type is in use
      let msg = "\(error)".lowercased()
      if msg.contains("23503") || msg.contains("foreign key") {
        throw WorkoutVMError.setTypeInUse
      }
      throw error
    }
  }

  // MARK: - Private helpers

  private func insertSetsAndExercises(workoutId: String, sets: [DraftSet]) async throws {
    guard !sets.isEmpty else { return }

    let setInserts = sets.enumerated().map { idx, s in
      SetInsert(
        workoutId: workoutId,
        setOrder: idx,
        repeatCount: s.repeatCount,
        roundsCount: max(1, s.roundsCount),
        setTypeId: s.setTypeId
      )
    }
    let createdSets: [InsertedSet] = try await supabase
      .from("workout_sets")
      .insert(setInserts)
      .select()
      .execute()
      .value

    let byOrder = Dictionary(uniqueKeysWithValues: createdSets.map { ($0.setOrder, $0.id) })

    var exerciseInserts: [SetExerciseInsert] = []
    for (idx, draftSet) in sets.enumerated() {
      guard let setId = byOrder[idx] else { continue }
      let rounds = max(1, draftSet.roundsCount)
      for (exIdx, ex) in draftSet.exercises.enumerated() {
        let diffs = resized(ex.difficulties, to: rounds)
        let reps = resized(ex.reps, to: rounds)
        exerciseInserts.append(
          SetExerciseInsert(
            setId: setId,
            exerciseId: ex.exerciseId,
            exerciseOrder: exIdx,
            difficulty: diffs.first?.isEmpty == false ? diffs.first : nil,
            reps: reps.first?.isEmpty == false ? reps.first : nil,
            difficultyRounds: diffs,
            repsRounds: reps
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

  private func resized(_ arr: [String], to count: Int) -> [String] {
    if arr.count == count { return arr }
    if arr.count > count { return Array(arr.prefix(count)) }
    return arr + Array(repeating: "", count: count - arr.count)
  }

  // MARK: - Decoder / error helpers

  private var decoder: JSONDecoder {
    JSONDecoder()
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
}

enum WorkoutVMError: LocalizedError {
  case setTypeInUse
  case exerciseInUse
  case nameTaken

  var errorDescription: String? {
    switch self {
    case .setTypeInUse: return "This set type is used by existing workouts and can't be deleted."
    case .exerciseInUse: return "This exercise is used by existing workouts and can't be deleted."
    case .nameTaken: return "A workout with that name already exists."
    }
  }
}

// MARK: - Encodable / Decodable helpers

private struct WorkoutInsert: Encodable {
  let athleteId: String?
  let coachId: String
  let gymId: String?
  let workoutDate: String
  let name: String?
  let templateName: String?
  let notes: String?

  enum CodingKeys: String, CodingKey {
    case athleteId = "athlete_id"
    case coachId = "coach_id"
    case gymId = "gym_id"
    case workoutDate = "workout_date"
    case name
    case templateName = "template_name"
    case notes
  }
}

private struct WorkoutUpdate: Encodable {
  let workoutDate: String
  let name: String?
  let templateName: String?
  let notes: String?

  enum CodingKeys: String, CodingKey {
    case workoutDate = "workout_date"
    case name
    case templateName = "template_name"
    case notes
  }
}

private struct NotesPatch: Encodable {
  let notes: String?
}

private struct SetInsert: Encodable {
  let workoutId: String
  let setOrder: Int
  let repeatCount: Int?
  let roundsCount: Int
  let setTypeId: String?

  enum CodingKeys: String, CodingKey {
    case workoutId = "workout_id"
    case setOrder = "set_order"
    case repeatCount = "repeat_count"
    case roundsCount = "rounds_count"
    case setTypeId = "set_type_id"
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
  let difficultyRounds: [String]
  let repsRounds: [String]

  enum CodingKeys: String, CodingKey {
    case setId = "set_id"
    case exerciseId = "exercise_id"
    case exerciseOrder = "exercise_order"
    case difficulty, reps
    case difficultyRounds = "difficulty_rounds"
    case repsRounds = "reps_rounds"
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

private struct SetTypeInsert: Encodable {
  let gymId: String
  let name: String

  enum CodingKeys: String, CodingKey {
    case gymId = "gym_id"
    case name
  }
}

private struct NameRow: Decodable {
  let id: String
  let templateName: String?
  enum CodingKeys: String, CodingKey {
    case id; case templateName = "template_name"
  }
}
