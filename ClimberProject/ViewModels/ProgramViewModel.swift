import Foundation
import Combine
import Supabase

@MainActor
class ProgramViewModel: ObservableObject {
  @Published var programs: [Program] = []
  @Published var enrollments: [AthleteProgram] = []
  @Published var isLoading = false
  @Published var error: String?

  private var supabase: SupabaseClient { SupabaseService.shared.supabase }

  // Fetch all programs visible to this coach (RLS scopes to gym)
  func fetchPrograms() async {
    do {
      programs = try await supabase
        .from("programs")
        .select()
        .order("name", ascending: true)
        .execute()
        .value
    } catch {
      self.error = error.localizedDescription
    }
  }

  func fetchEnrollments(athleteId: String) async {
    do {
      let all: [AthleteProgram] = try await supabase
        .from("athlete_programs")
        .select()
        .eq("athlete_id", value: athleteId)
        .execute()
        .value
      enrollments = all.filter { $0.droppedAt == nil }
    } catch {
      self.error = error.localizedDescription
    }
  }

  // Returns all currently enrolled athlete IDs for a program (for group workouts)
  func fetchEnrolledAthletes(programId: String) async throws -> [String] {
    let all: [AthleteProgram] = try await supabase
      .from("athlete_programs")
      .select()
      .eq("program_id", value: programId)
      .execute()
      .value
    return all.filter { $0.droppedAt == nil }.map { $0.athleteId }
  }

  func enroll(athleteId: String, programId: String) async throws {
    let today = todayString()
    struct Upsert: Encodable {
      let athleteId: String
      let programId: String
      let enrolledAt: String
      enum CodingKeys: String, CodingKey {
        case athleteId = "athlete_id"
        case programId = "program_id"
        case enrolledAt = "enrolled_at"
        case droppedAt = "dropped_at"
      }
      func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(athleteId, forKey: .athleteId)
        try c.encode(programId, forKey: .programId)
        try c.encode(enrolledAt, forKey: .enrolledAt)
        try c.encodeNil(forKey: .droppedAt)  // must be explicit null, not omitted
      }
    }
    try await supabase
      .from("athlete_programs")
      .upsert(Upsert(athleteId: athleteId, programId: programId, enrolledAt: today))
      .execute()
    await fetchEnrollments(athleteId: athleteId)
  }

  func drop(athleteId: String, programId: String) async throws {
    struct Patch: Encodable {
      let droppedAt: String
      enum CodingKeys: String, CodingKey { case droppedAt = "dropped_at" }
    }
    try await supabase
      .from("athlete_programs")
      .update(Patch(droppedAt: todayString()))
      .eq("athlete_id", value: athleteId)
      .eq("program_id", value: programId)
      .execute()
    enrollments.removeAll { $0.programId == programId }
  }

  func addProgram(gymId: String, name: String) async throws {
    struct Insert: Encodable {
      let gymId: String
      let name: String
      enum CodingKeys: String, CodingKey {
        case gymId = "gym_id"
        case name
      }
    }
    let created: [Program] = try await supabase
      .from("programs")
      .insert(Insert(gymId: gymId, name: name.trimmingCharacters(in: .whitespaces)))
      .select()
      .execute()
      .value
    if let p = created.first {
      programs.append(p)
      programs.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
  }

  func deleteProgram(id: String) async throws {
    try await supabase
      .from("programs")
      .delete()
      .eq("id", value: id)
      .execute()
    programs.removeAll { $0.id == id }
  }

  private func todayString() -> String {
    let fmt = DateFormatter()
    fmt.dateFormat = "yyyy-MM-dd"
    fmt.locale = Locale(identifier: "en_US_POSIX")
    return fmt.string(from: Date())
  }
}
