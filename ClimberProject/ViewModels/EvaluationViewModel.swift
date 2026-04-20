import Foundation
import Combine
import Supabase

@MainActor
class EvaluationViewModel: ObservableObject {
  @Published var criteria: [AssessmentCriteria] = []
  @Published var evaluations: [Evaluation] = []
  @Published var isLoading = false
  @Published var error: String?

  private var supabase: SupabaseClient { SupabaseService.shared.supabase }

  func clearEvaluations() {
    evaluations = []
  }

  func fetchCriteria() async {
    do {
      criteria = try await supabase
        .from("assessment_criteria")
        .select()
        .order("name", ascending: true)
        .execute()
        .value
    } catch {
      self.error = error.localizedDescription
    }
  }

  func fetchEvaluations(athleteId: String) async {
    isLoading = true
    error = nil
    defer { isLoading = false }
    do {
      evaluations = try await supabase
        .from("evaluations")
        .select()
        .eq("athlete_id", value: athleteId)
        .order("evaluated_at", ascending: false)
        .execute()
        .value
    } catch {
      self.error = error.localizedDescription
    }
  }

  func addEvaluations(_ inserts: [EvaluationInsert]) async throws {
    let created: [Evaluation] = try await supabase
      .from("evaluations")
      .insert(inserts)
      .select()
      .execute()
      .value
    evaluations.insert(contentsOf: created, at: 0)
  }

  // Most recent value per criteria
  func latestValue(for criteriaId: String) -> Evaluation? {
    evaluations
      .filter { $0.criteriaId == criteriaId }
      .sorted { $0.evaluatedAt > $1.evaluatedAt }
      .first
  }

  // All values for a criteria, newest first
  func history(for criteriaId: String) -> [Evaluation] {
    evaluations
      .filter { $0.criteriaId == criteriaId }
      .sorted { $0.evaluatedAt > $1.evaluatedAt }
  }
}

struct EvaluationInsert: Encodable {
  let athleteId: String
  let coachId: String
  let criteriaId: String
  let evaluatedAt: String
  let value: Double
  let notes: String?

  enum CodingKeys: String, CodingKey {
    case athleteId = "athlete_id"
    case coachId = "coach_id"
    case criteriaId = "criteria_id"
    case evaluatedAt = "evaluated_at"
    case value
    case notes
  }
}
