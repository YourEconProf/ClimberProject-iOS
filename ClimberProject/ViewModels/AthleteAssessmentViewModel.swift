import Foundation
import Combine
import Supabase

@MainActor
class AthleteAssessmentViewModel: ObservableObject {
  @Published var latestAssessment: AthleteAssessment?
  @Published var alerts: [AthleteAlert] = []
  @Published var isLoading = false
  @Published var isReassessing = false
  @Published var error: String?

  private var supabase: SupabaseClient { SupabaseService.shared.supabase }

  func fetchLatestAssessment(athleteId: String) async {
    isLoading = true
    defer { isLoading = false }
    do {
      let assessments: [AthleteAssessment] = try await supabase
        .from("athlete_assessments")
        .select()
        .eq("athlete_id", value: athleteId)
        .order("assessed_at", ascending: false)
        .limit(1)
        .execute()
        .value
      latestAssessment = assessments.first
    } catch {
      self.error = error.localizedDescription
    }
  }

  func fetchAlerts(athleteId: String) async {
    do {
      let all: [AthleteAlert] = try await supabase
        .from("athlete_alerts")
        .select()
        .eq("athlete_id", value: athleteId)
        .order("created_at", ascending: false)
        .execute()
        .value
      alerts = all.filter { $0.resolvedAt == nil }
    } catch {
      // alerts are non-critical; suppress error
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
      alerts[i] = AthleteAlert(
        id: a.id, athleteId: a.athleteId, alertType: a.alertType,
        severity: a.severity, message: a.message,
        resolvedAt: a.resolvedAt, acknowledgedAt: now, createdAt: a.createdAt
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

  func reassess(athleteId: String) async throws {
    isReassessing = true
    defer { isReassessing = false }

    let session = try await supabase.auth.session
    let token = session.accessToken

    guard let url = URL(string: "\(Config.apiBaseURL)/api/assess-athlete") else { return }
    var request = URLRequest(url: url, timeoutInterval: 180)
    request.httpMethod = "POST"
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try JSONEncoder().encode(
      ReassessRequest(athlete_id: athleteId, source: "manual", force: true)
    )

    let (_, response) = try await URLSession.shared.data(for: request)
    if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
      throw URLError(.badServerResponse)
    }

    await fetchLatestAssessment(athleteId: athleteId)
    await fetchAlerts(athleteId: athleteId)
  }

  var criticalAlerts: [AthleteAlert] { alerts.filter { $0.severity == "critical" } }
  var warnAlerts: [AthleteAlert]    { alerts.filter { $0.severity == "warn" } }
  var infoAlerts: [AthleteAlert]    { alerts.filter { $0.severity == "info" } }
}

private struct ReassessRequest: Encodable {
  let athlete_id: String
  let source: String
  let force: Bool
}
