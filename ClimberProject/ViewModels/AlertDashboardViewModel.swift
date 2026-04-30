import Foundation
import Combine
import Supabase

@MainActor
class AlertDashboardViewModel: ObservableObject {
  @Published var alerts: [AthleteAlertWithAthlete] = []
  @Published var isLoading = false
  @Published var error: String?

  private var supabase: SupabaseClient { SupabaseService.shared.supabase }

  func fetchAll() async {
    isLoading = true
    defer { isLoading = false }
    do {
      let all: [AthleteAlertWithAthlete] = try await supabase
        .from("athlete_alerts")
        .select("*, athletes(id, first_name, last_name)")
        .is("resolved_at", value: nil)
        .in("severity", values: ["critical", "warn"])
        .order("created_at", ascending: false)
        .execute()
        .value
      alerts = all
    } catch {
      self.error = error.localizedDescription
    }
  }

  func acknowledge(alertId: String, coachId: String) async throws {
    struct Patch: Encodable {
      let acknowledgedAt: String
      let acknowledgedBy: String
      enum CodingKeys: String, CodingKey {
        case acknowledgedAt = "acknowledged_at"
        case acknowledgedBy = "acknowledged_by"
      }
    }
    let now = ISO8601DateFormatter().string(from: Date())
    try await supabase
      .from("athlete_alerts")
      .update(Patch(acknowledgedAt: now, acknowledgedBy: coachId))
      .eq("id", value: alertId)
      .execute()
    if let i = alerts.firstIndex(where: { $0.id == alertId }) {
      let a = alerts[i]
      alerts[i] = AthleteAlertWithAthlete(
        id: a.id, athleteId: a.athleteId, alertType: a.alertType,
        severity: a.severity, message: a.message,
        resolvedAt: a.resolvedAt, acknowledgedAt: now, createdAt: a.createdAt,
        athletes: a.athletes
      )
    }
  }

  func resolve(alertId: String) async throws {
    struct Patch: Encodable {
      let resolvedAt: String
      enum CodingKeys: String, CodingKey { case resolvedAt = "resolved_at" }
    }
    let now = ISO8601DateFormatter().string(from: Date())
    try await supabase
      .from("athlete_alerts")
      .update(Patch(resolvedAt: now))
      .eq("id", value: alertId)
      .execute()
    alerts.removeAll { $0.id == alertId }
  }
}
