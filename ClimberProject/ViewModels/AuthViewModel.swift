import Foundation
import Combine
import Supabase

@MainActor
class AuthViewModel: ObservableObject {
  @Published var isLoggedIn = false
  @Published var currentCoach: Coach?
  @Published var currentGym: Gym?
  @Published var isLoading = false
  @Published var error: String?

  /// IANA timezone for the current coach's gym. Defaults to "UTC" until loaded.
  /// Used to format `timestamptz` columns. `date` columns are always formatted in UTC.
  var gymTimezone: String { currentGym?.timezone ?? "UTC" }

  private var supabase: SupabaseClient { SupabaseService.shared.supabase }

  func login(email: String, password: String) async {
    isLoading = true
    error = nil
    defer { isLoading = false }

    do {
      let session = try await supabase.auth.signIn(email: email, password: password)
      try await loadCoach(userId: session.user.id.uuidString)
      isLoggedIn = true
    } catch {
      self.error = error.localizedDescription
    }
  }

  func signup(email: String, password: String, name: String, gymCode: String) async {
    isLoading = true
    error = nil
    defer { isLoading = false }

    do {
      // 1. Look up gym by code
      let gyms: [Gym] = try await supabase
        .from("gyms")
        .select()
        .eq("code", value: gymCode)
        .limit(1)
        .execute()
        .value

      guard let gym = gyms.first else {
        self.error = "Gym code not found."
        return
      }

      // 2. Create auth user
      let session = try await supabase.auth.signUp(email: email, password: password)

      // 3. Insert coach row
      let newCoach = CoachInsert(
        id: session.user.id.uuidString,
        gymId: gym.id,
        name: name,
        email: email,
        role: "coach"
      )
      try await supabase.from("coaches").insert(newCoach).execute()

      try await loadCoach(userId: session.user.id.uuidString)
      isLoggedIn = true
    } catch {
      self.error = error.localizedDescription
    }
  }

  func logout() async {
    do {
      try await supabase.auth.signOut()
    } catch {
      // Ignore signOut errors — clear local state regardless
    }
    isLoggedIn = false
    currentCoach = nil
    currentGym = nil
  }

  /// Persist a new IANA timezone for the current coach's gym.
  /// Optimistic — updates local state first, fires the patch in the background.
  func updateGymTimezone(_ tz: String) async throws {
    guard let gym = currentGym else { return }
    currentGym = Gym(id: gym.id, name: gym.name, code: gym.code, timezone: tz)
    struct Patch: Encodable { let timezone: String }
    try await supabase
      .from("gyms")
      .update(Patch(timezone: tz))
      .eq("id", value: gym.id)
      .execute()
  }

  func resetPassword(email: String) async throws {
    try await supabase.auth.resetPasswordForEmail(email)
  }

  func checkSession() async {
    do {
      let session = try await supabase.auth.session
      try await loadCoach(userId: session.user.id.uuidString)
      isLoggedIn = true
    } catch {
      isLoggedIn = false
    }
  }

  private func loadCoach(userId: String) async throws {
    let coaches: [Coach] = try await supabase
      .from("coaches")
      .select()
      .eq("id", value: userId)
      .limit(1)
      .execute()
      .value

    guard let coach = coaches.first else {
      throw AuthError.coachNotFound
    }
    currentCoach = coach
    try? await loadGym(gymId: coach.gymId)
  }

  private func loadGym(gymId: String) async throws {
    let gyms: [Gym] = try await supabase
      .from("gyms")
      .select()
      .eq("id", value: gymId)
      .limit(1)
      .execute()
      .value
    currentGym = gyms.first
  }
}

private enum AuthError: LocalizedError {
  case coachNotFound

  var errorDescription: String? {
    switch self {
    case .coachNotFound:
      return "No coach profile found for this account."
    }
  }
}

// Encodable struct for inserting a new coach row
private struct CoachInsert: Encodable {
  let id: String
  let gymId: String
  let name: String
  let email: String
  let role: String

  enum CodingKeys: String, CodingKey {
    case id
    case gymId = "gym_id"
    case name
    case email
    case role
  }
}
