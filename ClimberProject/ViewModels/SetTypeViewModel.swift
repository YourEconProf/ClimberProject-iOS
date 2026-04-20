import Foundation
import Combine
import Supabase

@MainActor
class SetTypeViewModel: ObservableObject {
  @Published var setTypes: [SetType] = []
  @Published var isLoading = false
  @Published var error: String?

  private var supabase: SupabaseClient { SupabaseService.shared.supabase }

  func fetch(gymId: String) async {
    isLoading = true
    error = nil
    defer { isLoading = false }
    do {
      setTypes = try await supabase
        .from("set_types")
        .select()
        .eq("gym_id", value: gymId)
        .order("name", ascending: true)
        .execute()
        .value
    } catch {
      self.error = error.localizedDescription
    }
  }

  func add(gymId: String, name: String) async throws {
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }
    let insert = Insert(gymId: gymId, name: trimmed)
    let created: SetType = try await supabase
      .from("set_types")
      .insert(insert)
      .select()
      .single()
      .execute()
      .value
    setTypes.append(created)
    setTypes.sort { $0.name.lowercased() < $1.name.lowercased() }
  }

  func delete(id: String) async throws {
    do {
      try await supabase
        .from("set_types")
        .delete()
        .eq("id", value: id)
        .execute()
      setTypes.removeAll { $0.id == id }
    } catch {
      let msg = "\(error)".lowercased()
      if msg.contains("23503") || msg.contains("foreign key") {
        throw WorkoutVMError.setTypeInUse
      }
      throw error
    }
  }
}

private struct Insert: Encodable {
  let gymId: String
  let name: String

  enum CodingKeys: String, CodingKey {
    case gymId = "gym_id"
    case name
  }
}
