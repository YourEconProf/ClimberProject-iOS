import Foundation
import Combine
import Supabase

@MainActor
class TagViewModel: ObservableObject {
  @Published var tags: [Tag] = []
  @Published var exerciseTagRows: [ExerciseTagRow] = []
  @Published var workoutTagRows: [WorkoutTagRow] = []

  private var supabase: SupabaseClient { SupabaseService.shared.supabase }

  func fetch(gymId: String) async {
    do {
      async let fetchedTags: [Tag] = supabase
        .from("tags")
        .select()
        .eq("gym_id", value: gymId)
        .order("name", ascending: true)
        .execute()
        .value
      async let fetchedExerciseTags: [ExerciseTagRow] = supabase
        .from("exercise_tags")
        .select()
        .execute()
        .value
      async let fetchedWorkoutTags: [WorkoutTagRow] = supabase
        .from("workout_tags")
        .select()
        .execute()
        .value
      (tags, exerciseTagRows, workoutTagRows) = try await (fetchedTags, fetchedExerciseTags, fetchedWorkoutTags)
    } catch {}
  }

  func tagsForExercise(_ exerciseId: String) -> [Tag] {
    let tagIds = exerciseTagRows.filter { $0.exerciseId == exerciseId }.map { $0.tagId }
    return tags.filter { tagIds.contains($0.id) }
  }

  func tagsForWorkout(_ workoutId: String) -> [Tag] {
    let tagIds = workoutTagRows.filter { $0.workoutId == workoutId }.map { $0.tagId }
    return tags.filter { tagIds.contains($0.id) }
  }

  func addTag(gymId: String, name: String) async throws {
    struct Insert: Encodable {
      let gymId: String
      let name: String
      enum CodingKeys: String, CodingKey {
        case gymId = "gym_id"
        case name
      }
    }
    let created: [Tag] = try await supabase
      .from("tags")
      .insert(Insert(gymId: gymId, name: name.lowercased().trimmingCharacters(in: .whitespaces)))
      .select()
      .execute()
      .value
    if let t = created.first {
      tags.append(t)
      tags.sort { $0.name < $1.name }
    }
  }

  func deleteTag(id: String) async throws {
    try await supabase
      .from("tags")
      .delete()
      .eq("id", value: id)
      .execute()
    tags.removeAll { $0.id == id }
    exerciseTagRows.removeAll { $0.tagId == id }
    workoutTagRows.removeAll { $0.tagId == id }
  }

  func toggleExerciseTag(exerciseId: String, tagId: String) async throws {
    if exerciseTagRows.contains(where: { $0.exerciseId == exerciseId && $0.tagId == tagId }) {
      try await supabase
        .from("exercise_tags")
        .delete()
        .eq("exercise_id", value: exerciseId)
        .eq("tag_id", value: tagId)
        .execute()
      exerciseTagRows.removeAll { $0.exerciseId == exerciseId && $0.tagId == tagId }
    } else {
      struct Insert: Encodable {
        let exerciseId: String
        let tagId: String
        enum CodingKeys: String, CodingKey {
          case exerciseId = "exercise_id"
          case tagId = "tag_id"
        }
      }
      try await supabase
        .from("exercise_tags")
        .insert(Insert(exerciseId: exerciseId, tagId: tagId))
        .execute()
      exerciseTagRows.append(ExerciseTagRow(exerciseId: exerciseId, tagId: tagId))
    }
  }

  func toggleWorkoutTag(workoutId: String, tagId: String) async throws {
    if workoutTagRows.contains(where: { $0.workoutId == workoutId && $0.tagId == tagId }) {
      try await supabase
        .from("workout_tags")
        .delete()
        .eq("workout_id", value: workoutId)
        .eq("tag_id", value: tagId)
        .execute()
      workoutTagRows.removeAll { $0.workoutId == workoutId && $0.tagId == tagId }
    } else {
      struct Insert: Encodable {
        let workoutId: String
        let tagId: String
        enum CodingKeys: String, CodingKey {
          case workoutId = "workout_id"
          case tagId = "tag_id"
        }
      }
      try await supabase
        .from("workout_tags")
        .insert(Insert(workoutId: workoutId, tagId: tagId))
        .execute()
      workoutTagRows.append(WorkoutTagRow(workoutId: workoutId, tagId: tagId))
    }
  }
}
