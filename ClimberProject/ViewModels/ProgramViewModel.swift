import Foundation
import Combine
import Supabase

@MainActor
class ProgramViewModel: ObservableObject {
  @Published var programs: [Program] = []
  @Published var enrollments: [AthleteProgram] = []
  @Published var phases: [ProgramPhase] = []
  @Published var planVersions: [ProgramPlanVersion] = []
  @Published var isLoading = false
  @Published var error: String?

  private var supabase: SupabaseClient { SupabaseService.shared.supabase }

  // MARK: - Programs

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

  func updateProgram(
    id: String,
    name: String,
    ageGroup: String?,
    discipline: String?,
    startDate: String?,
    endDate: String?,
    practiceDays: [Int]?,
    practiceStartTime: String?,
    practiceDurationMinutes: Int?,
    practiceLocation: String?,
    notes: String?,
    openingTemplateId: String?
  ) async throws {
    struct Patch: Encodable {
      let name: String
      let ageGroup: String?
      let discipline: String?
      let startDate: String?
      let endDate: String?
      let practiceDays: [Int]?
      let practiceStartTime: String?
      let practiceDurationMinutes: Int?
      let practiceLocation: String?
      let notes: String?
      let openingTemplateId: String?

      enum CodingKeys: String, CodingKey {
        case name
        case ageGroup = "age_group"
        case discipline
        case startDate = "start_date"
        case endDate = "end_date"
        case practiceDays = "practice_days"
        case practiceStartTime = "practice_start_time"
        case practiceDurationMinutes = "practice_duration_minutes"
        case practiceLocation = "practice_location"
        case notes
        case openingTemplateId = "opening_template_id"
      }

      func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(name, forKey: .name)
        if let v = ageGroup { try c.encode(v, forKey: .ageGroup) } else { try c.encodeNil(forKey: .ageGroup) }
        if let v = discipline { try c.encode(v, forKey: .discipline) } else { try c.encodeNil(forKey: .discipline) }
        if let v = startDate { try c.encode(v, forKey: .startDate) } else { try c.encodeNil(forKey: .startDate) }
        if let v = endDate { try c.encode(v, forKey: .endDate) } else { try c.encodeNil(forKey: .endDate) }
        if let v = practiceDays { try c.encode(v, forKey: .practiceDays) } else { try c.encodeNil(forKey: .practiceDays) }
        if let v = practiceStartTime { try c.encode(v, forKey: .practiceStartTime) } else { try c.encodeNil(forKey: .practiceStartTime) }
        if let v = practiceDurationMinutes { try c.encode(v, forKey: .practiceDurationMinutes) } else { try c.encodeNil(forKey: .practiceDurationMinutes) }
        if let v = practiceLocation { try c.encode(v, forKey: .practiceLocation) } else { try c.encodeNil(forKey: .practiceLocation) }
        if let v = notes { try c.encode(v, forKey: .notes) } else { try c.encodeNil(forKey: .notes) }
        if let v = openingTemplateId { try c.encode(v, forKey: .openingTemplateId) } else { try c.encodeNil(forKey: .openingTemplateId) }
      }
    }
    try await supabase
      .from("programs")
      .update(Patch(
        name: name, ageGroup: ageGroup, discipline: discipline,
        startDate: startDate, endDate: endDate, practiceDays: practiceDays,
        practiceStartTime: practiceStartTime, practiceDurationMinutes: practiceDurationMinutes,
        practiceLocation: practiceLocation, notes: notes, openingTemplateId: openingTemplateId
      ))
      .eq("id", value: id)
      .execute()
    await fetchPrograms()
  }

  func deleteProgram(id: String) async throws {
    try await supabase
      .from("programs")
      .delete()
      .eq("id", value: id)
      .execute()
    programs.removeAll { $0.id == id }
  }

  // MARK: - Enrollments

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
        try c.encodeNil(forKey: .droppedAt)
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

  // MARK: - Phases

  func fetchPhases(programId: String) async {
    do {
      phases = try await supabase
        .from("program_phases")
        .select()
        .eq("program_id", value: programId)
        .order("start_week", ascending: true)
        .execute()
        .value
    } catch {
      self.error = error.localizedDescription
    }
  }

  func addPhase(programId: String, name: String, startWeek: Int, endWeek: Int, isDeload: Bool) async throws {
    struct Insert: Encodable {
      let programId: String
      let name: String
      let startWeek: Int
      let endWeek: Int
      let isDeload: Bool
      enum CodingKeys: String, CodingKey {
        case programId = "program_id"
        case name
        case startWeek = "start_week"
        case endWeek = "end_week"
        case isDeload = "is_deload"
      }
    }
    let created: [ProgramPhase] = try await supabase
      .from("program_phases")
      .insert(Insert(programId: programId, name: name, startWeek: startWeek, endWeek: endWeek, isDeload: isDeload))
      .select()
      .execute()
      .value
    if let phase = created.first {
      phases.append(phase)
      phases.sort { $0.startWeek < $1.startWeek }
    }
  }

  func deletePhase(id: String) async throws {
    try await supabase
      .from("program_phases")
      .delete()
      .eq("id", value: id)
      .execute()
    phases.removeAll { $0.id == id }
  }

  // MARK: - Plan Versions

  func fetchPlanVersions(programId: String) async {
    do {
      planVersions = try await supabase
        .from("program_plan_versions")
        .select()
        .eq("program_id", value: programId)
        .order("version_num", ascending: false)
        .execute()
        .value
    } catch {
      self.error = error.localizedDescription
    }
  }

  func savePlanVersion(programId: String, planMarkdown: String, editMessage: String?, editedBy: String) async throws {
    let nextNum = (planVersions.first?.versionNum ?? 0) + 1
    struct Insert: Encodable {
      let programId: String
      let versionNum: Int
      let planMarkdown: String
      let editMessage: String?
      let editedBy: String
      enum CodingKeys: String, CodingKey {
        case programId = "program_id"
        case versionNum = "version_num"
        case planMarkdown = "plan_markdown"
        case editMessage = "edit_message"
        case editedBy = "edited_by"
      }
    }
    try await supabase
      .from("program_plan_versions")
      .insert(Insert(programId: programId, versionNum: nextNum, planMarkdown: planMarkdown, editMessage: editMessage, editedBy: editedBy))
      .execute()

    struct PlanPatch: Encodable {
      let planMarkdown: String
      let planUpdatedBy: String
      enum CodingKeys: String, CodingKey {
        case planMarkdown = "plan_markdown"
        case planUpdatedBy = "plan_updated_by"
      }
    }
    try await supabase
      .from("programs")
      .update(PlanPatch(planMarkdown: planMarkdown, planUpdatedBy: editedBy))
      .eq("id", value: programId)
      .execute()

    await fetchPlanVersions(programId: programId)
    await fetchPrograms()
  }

  func restorePlanVersion(_ version: ProgramPlanVersion, editedBy: String) async throws {
    let message = "Restored from v\(version.versionNum)"
    try await savePlanVersion(programId: version.programId, planMarkdown: version.planMarkdown, editMessage: message, editedBy: editedBy)
  }

  // MARK: - Generate Practice

  func generatePractice(programId: String) async throws -> GeneratePracticeResult {
    let session = try await supabase.auth.session
    let token = session.accessToken

    guard let url = URL(string: "\(Config.apiBaseURL)/api/generate-practice") else {
      throw URLError(.badURL)
    }
    struct Body: Encodable {
      let programId: String
      let date: String
      let regenerate: Bool
      enum CodingKeys: String, CodingKey {
        case programId = "program_id"
        case date
        case regenerate
      }
    }
    var request = URLRequest(url: url, timeoutInterval: 180)
    request.httpMethod = "POST"
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try JSONEncoder().encode(Body(programId: programId, date: todayString(), regenerate: false))

    let (data, response) = try await URLSession.shared.data(for: request)
    if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
      throw URLError(.badServerResponse)
    }
    return try JSONDecoder().decode(GeneratePracticeResult.self, from: data)
  }

  // MARK: - Helpers

  private func todayString() -> String {
    let fmt = DateFormatter()
    fmt.dateFormat = "yyyy-MM-dd"
    fmt.locale = Locale(identifier: "en_US_POSIX")
    return fmt.string(from: Date())
  }
}

struct GeneratePracticeResult: Decodable, Identifiable {
  let id = UUID()
  let generated: Int
  let skipped: [Item]?
  let blocked: [Item]?

  enum CodingKeys: String, CodingKey {
    case generated, skipped, blocked
  }

  struct Item: Decodable, Identifiable {
    var id: String { athleteId ?? reason }
    let athleteId: String?
    let name: String?
    let reason: String
    enum CodingKeys: String, CodingKey {
      case athleteId = "athlete_id"
      case name
      case reason
    }
  }
}
