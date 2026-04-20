import Foundation
import Combine
import Supabase

@MainActor
class GoalViewModel: ObservableObject {
  @Published var goals: [Goal] = []
  @Published var isLoading = false
  @Published var error: String?

  private var supabase: SupabaseClient { SupabaseService.shared.supabase }

  var activeGoals: [Goal] { goals.filter { $0.status == .active } }
  var resolvedGoals: [Goal] { goals.filter { $0.status != .active } }

  func fetchGoals(athleteId: String) async {
    isLoading = true
    error = nil
    defer { isLoading = false }
    do {
      goals = try await supabase
        .from("goals")
        .select()
        .eq("athlete_id", value: athleteId)
        .order("set_at", ascending: false)
        .execute()
        .value
    } catch {
      self.error = error.localizedDescription
    }
  }

  func addGoal(athleteId: String, coachId: String, description: String) async throws {
    let insert = GoalInsert(
      athleteId: athleteId,
      coachId: coachId,
      description: description
    )
    let created: Goal = try await supabase
      .from("goals")
      .insert(insert)
      .select()
      .single()
      .execute()
      .value
    goals.insert(created, at: 0)
  }

  func updateStatus(_ goal: Goal, status: GoalStatus) async throws {
    struct StatusUpdate: Encodable {
      let status: String
      let resolvedAt: String?
      enum CodingKeys: String, CodingKey {
        case status
        case resolvedAt = "resolved_at"
      }
    }
    let resolvedAt = status == .active ? nil : ISO8601DateFormatter().string(from: Date())
    let update = StatusUpdate(status: status.rawValue, resolvedAt: resolvedAt)
    try await supabase
      .from("goals")
      .update(update)
      .eq("id", value: goal.id)
      .execute()
    if let idx = goals.firstIndex(where: { $0.id == goal.id }) {
      goals[idx] = Goal(
        id: goal.id, athleteId: goal.athleteId, coachId: goal.coachId,
        description: goal.description, status: status,
        setAt: goal.setAt, resolvedAt: resolvedAt
      )
    }
  }

  func deleteGoal(id: String) async throws {
    try await supabase
      .from("goals")
      .delete()
      .eq("id", value: id)
      .execute()
    goals.removeAll { $0.id == id }
  }
}

private struct GoalInsert: Encodable {
  let athleteId: String
  let coachId: String
  let description: String
  enum CodingKeys: String, CodingKey {
    case athleteId = "athlete_id"
    case coachId = "coach_id"
    case description
  }
}
