import Foundation
import Combine
import Supabase

@MainActor
class MentalFrameworkViewModel: ObservableObject {
  @Published var current: [String: MentalFramework] = [:]
  @Published var history: [MentalFramework] = []
  @Published var isLoading = false
  @Published var isSaving = false
  @Published var error: String?

  private var supabase: SupabaseClient { SupabaseService.shared.supabase }

  func fetchCurrent(athleteId: String) async {
    isLoading = true
    defer { isLoading = false }
    do {
      let rows: [MentalFramework] = try await supabase
        .from("mental_frameworks")
        .select()
        .eq("athlete_id", value: athleteId)
        .eq("is_current", value: true)
        .execute()
        .value
      var map: [String: MentalFramework] = [:]
      for row in rows { map[row.component] = row }
      current = map
    } catch {
      self.error = error.localizedDescription
    }
  }

  func fetchHistory(athleteId: String, component: String) async {
    do {
      history = try await supabase
        .from("mental_frameworks")
        .select()
        .eq("athlete_id", value: athleteId)
        .eq("component", value: component)
        .order("version", ascending: false)
        .execute()
        .value
    } catch {
      self.error = error.localizedDescription
    }
  }

  func save(athleteId: String, component: String, content: String, authoredBy: String) async throws {
    isSaving = true
    defer { isSaving = false }

    let params: [String: String] = [
      "p_athlete_id": athleteId,
      "p_component": component,
      "p_content": content,
      "p_authored_by": authoredBy,
    ]
    try await supabase
      .rpc("save_mental_framework", params: params)
      .execute()

    await fetchCurrent(athleteId: athleteId)
    await fetchHistory(athleteId: athleteId, component: component)
  }
}
