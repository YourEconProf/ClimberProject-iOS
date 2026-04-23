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

  // MARK: - Criteria CRUD (Settings)

  func addCriteria(gymId: String, name: String, unit: String?) async throws {
    struct Insert: Encodable {
      let gymId: String
      let name: String
      let unit: String?
      enum CodingKeys: String, CodingKey {
        case gymId = "gym_id"
        case name
        case unit
      }
    }
    let trimmedUnit = unit?.trimmingCharacters(in: .whitespaces)
    let insert = Insert(gymId: gymId, name: name.trimmingCharacters(in: .whitespaces),
                        unit: trimmedUnit?.isEmpty == true ? nil : trimmedUnit)
    let created: [AssessmentCriteria] = try await supabase
      .from("assessment_criteria")
      .insert(insert)
      .select()
      .execute()
      .value
    if let c = created.first {
      criteria.append(c)
      criteria.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
  }

  func deleteCriteria(id: String) async throws {
    try await supabase
      .from("assessment_criteria")
      .delete()
      .eq("id", value: id)
      .execute()
    criteria.removeAll { $0.id == id }
  }

  func toggleFlag(_ flag: CriteriaFlag, for id: String) async {
    guard let c = criteria.first(where: { $0.id == id }) else { return }
    do {
      switch flag {
      case .fm:
        try await supabase.from("assessment_criteria")
          .update(FmPatch(isFm: !c.isFm)).eq("id", value: id).execute()
      case .morpho:
        try await supabase.from("assessment_criteria")
          .update(MorphoPatch(isMorpho: !c.isMorpho)).eq("id", value: id).execute()
      case .strength:
        try await supabase.from("assessment_criteria")
          .update(StrengthPatch(isStrength: !c.isStrength)).eq("id", value: id).execute()
      case .maxBoulder:
        try await supabase.from("assessment_criteria")
          .update(MaxBoulderPatch(isMaxBoulder: !c.isMaxBoulder)).eq("id", value: id).execute()
      case .maxRope:
        try await supabase.from("assessment_criteria")
          .update(MaxRopePatch(isMaxRope: !c.isMaxRope)).eq("id", value: id).execute()
      }
      await fetchCriteria()
    } catch {
      self.error = error.localizedDescription
    }
  }

  // Returns the athlete's most recent max grade index for boulder or rope.
  // Used by flash token resolution when saving a workout to an athlete.
  func fetchLatestMaxIndex(isMaxBoulder: Bool, athleteId: String) async -> Double? {
    guard let c = criteria.first(where: { isMaxBoulder ? $0.isMaxBoulder : $0.isMaxRope }) else { return nil }
    do {
      struct Row: Decodable { let value: Double? }
      let rows: [Row] = try await supabase
        .from("evaluations")
        .select("value")
        .eq("athlete_id", value: athleteId)
        .eq("criteria_id", value: c.id)
        .order("evaluated_at", ascending: false)
        .limit(1)
        .execute()
        .value
      return rows.first?.value
    } catch {
      return nil
    }
  }
}

private struct FmPatch: Encodable {
  let isFm: Bool
  enum CodingKeys: String, CodingKey { case isFm = "is_fm" }
}

private struct MorphoPatch: Encodable {
  let isMorpho: Bool
  enum CodingKeys: String, CodingKey { case isMorpho = "is_morpho" }
}

private struct StrengthPatch: Encodable {
  let isStrength: Bool
  enum CodingKeys: String, CodingKey { case isStrength = "is_strength" }
}

private struct MaxBoulderPatch: Encodable {
  let isMaxBoulder: Bool
  enum CodingKeys: String, CodingKey { case isMaxBoulder = "is_max_boulder" }
}

private struct MaxRopePatch: Encodable {
  let isMaxRope: Bool
  enum CodingKeys: String, CodingKey { case isMaxRope = "is_max_rope" }
}

enum CriteriaFlag { case fm, morpho, strength, maxBoulder, maxRope }

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
