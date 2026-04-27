import Foundation
import Combine
import Supabase

@MainActor
class AthleteCheckinViewModel: ObservableObject {
  @Published var checkins: [AthleteCheckin] = []
  @Published var isLoading = false
  @Published var error: String?

  private var supabase: SupabaseClient { SupabaseService.shared.supabase }

  func fetchCheckins(athleteId: String) async {
    isLoading = true
    defer { isLoading = false }
    do {
      checkins = try await supabase
        .from("athlete_checkins")
        .select()
        .eq("athlete_id", value: athleteId)
        .order("checkin_date", ascending: false)
        .execute()
        .value
    } catch {
      self.error = error.localizedDescription
    }
  }

  func addCheckin(
    athleteId: String,
    date: String,
    readinessScore: Int?,
    fingerComfortScore: Int?,
    sleepHours: Double?,
    mood: String?,
    notes: String?
  ) async throws {
    struct Insert: Encodable {
      let athleteId: String
      let checkinDate: String
      let readinessScore: Int?
      let fingerComfortScore: Int?
      let sleepHours: Double?
      let mood: String?
      let notes: String?
      enum CodingKeys: String, CodingKey {
        case athleteId = "athlete_id"
        case checkinDate = "checkin_date"
        case readinessScore = "readiness_score"
        case fingerComfortScore = "finger_comfort_score"
        case sleepHours = "sleep_hours"
        case mood
        case notes
      }
    }
    try await supabase
      .from("athlete_checkins")
      .insert(Insert(
        athleteId: athleteId,
        checkinDate: date,
        readinessScore: readinessScore,
        fingerComfortScore: fingerComfortScore,
        sleepHours: sleepHours,
        mood: mood,
        notes: notes
      ))
      .execute()
    await fetchCheckins(athleteId: athleteId)
  }
}
