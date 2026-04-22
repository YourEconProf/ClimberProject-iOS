import Foundation
import Supabase

@MainActor
class CompetitionViewModel: ObservableObject {
  @Published var results: [CompetitionResult] = []
  @Published var isLoading = false
  @Published var error: String?

  private var supabase: SupabaseClient { SupabaseService.shared.supabase }

  func fetch(athleteId: String) async {
    isLoading = true
    error = nil
    defer { isLoading = false }
    do {
      results = try await supabase
        .from("competition_results")
        .select()
        .eq("athlete_id", value: athleteId)
        .order("competition_date", ascending: false)
        .execute()
        .value
    } catch {
      self.error = error.localizedDescription
    }
  }

  func add(
    athleteId: String,
    coachId: String,
    competitionDate: String,
    location: String,
    ranking: Int?,
    notes: String?
  ) async throws {
    let insert = CompetitionInsert(
      athleteId: athleteId,
      coachId: coachId,
      competitionDate: competitionDate,
      location: location,
      ranking: ranking,
      notes: notes?.isEmpty == true ? nil : notes
    )
    let created: [CompetitionResult] = try await supabase
      .from("competition_results")
      .insert(insert)
      .select()
      .execute()
      .value
    if let result = created.first {
      results.insert(result, at: 0)
    }
  }

  func delete(id: String) async throws {
    try await supabase
      .from("competition_results")
      .delete()
      .eq("id", value: id)
      .execute()
    results.removeAll { $0.id == id }
  }
}

private struct CompetitionInsert: Encodable {
  let athleteId: String
  let coachId: String
  let competitionDate: String
  let location: String
  let ranking: Int?
  let notes: String?

  enum CodingKeys: String, CodingKey {
    case athleteId = "athlete_id"
    case coachId = "coach_id"
    case competitionDate = "competition_date"
    case location
    case ranking
    case notes
  }
}
