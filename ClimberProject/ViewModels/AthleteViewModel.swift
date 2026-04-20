import Foundation
import Combine
import Supabase

@MainActor
class AthleteViewModel: ObservableObject {
  @Published var athletes: [Athlete] = []
  @Published var isLoading = false
  @Published var error: String?

  private var supabase: SupabaseClient { SupabaseService.shared.supabase }

  func fetchAthletes() async {
    isLoading = true
    error = nil
    defer { isLoading = false }
    do {
      athletes = try await supabase
        .from("athletes")
        .select()
        .order("last_name", ascending: true)
        .execute()
        .value
    } catch {
      self.error = error.localizedDescription
    }
  }

  func createAthlete(
    firstName: String,
    lastName: String,
    gymId: String,
    dob: String?,
    email: String?,
    tshirtSize: String?
  ) async throws {
    let insert = AthleteInsert(
      gymId: gymId,
      firstName: firstName,
      lastName: lastName,
      dob: dob?.isEmpty == true ? nil : dob,
      email: email?.isEmpty == true ? nil : email,
      tshirtSize: tshirtSize?.isEmpty == true ? nil : tshirtSize
    )
    let created: Athlete = try await supabase
      .from("athletes")
      .insert(insert)
      .select()
      .single()
      .execute()
      .value
    athletes.append(created)
    athletes.sort { $0.lastName < $1.lastName }
  }
}

private struct AthleteInsert: Encodable {
  let gymId: String
  let firstName: String
  let lastName: String
  let dob: String?
  let email: String?
  let tshirtSize: String?

  enum CodingKeys: String, CodingKey {
    case gymId = "gym_id"
    case firstName = "first_name"
    case lastName = "last_name"
    case dob
    case email
    case tshirtSize = "tshirt_size"
  }
}
