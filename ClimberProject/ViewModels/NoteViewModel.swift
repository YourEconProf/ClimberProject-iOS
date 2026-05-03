import Foundation
import Combine
import Supabase

@MainActor
class NoteViewModel: ObservableObject {
  @Published var notes: [Note] = []
  @Published var isLoading = false
  @Published var error: String?

  private var supabase: SupabaseClient { SupabaseService.shared.supabase }

  func fetchNotes(athleteId: String) async {
    isLoading = true
    error = nil
    defer { isLoading = false }
    do {
      notes = try await supabase
        .from("notes")
        .select()
        .eq("athlete_id", value: athleteId)
        .neq("category", value: "ai")
        .order("created_at", ascending: false)
        .execute()
        .value
    } catch {
      self.error = error.localizedDescription
    }
  }

  func addNote(athleteId: String, coachId: String, text: String, category: NoteCategory, isPrivate: Bool) async throws {
    let insert = NoteInsert(
      athleteId: athleteId,
      coachId: coachId,
      note: text,
      category: category.rawValue,
      isPrivate: isPrivate
    )
    let created: Note = try await supabase
      .from("notes")
      .insert(insert)
      .select()
      .single()
      .execute()
      .value
    notes.insert(created, at: 0)
  }

  func updateNote(id: String, text: String, category: NoteCategory, isPrivate: Bool) async throws {
    struct Patch: Encodable {
      let note: String
      let category: String
      let isPrivate: Bool
      enum CodingKeys: String, CodingKey {
        case note
        case category
        case isPrivate = "is_private"
      }
    }
    try await supabase
      .from("notes")
      .update(Patch(note: text, category: category.rawValue, isPrivate: isPrivate))
      .eq("id", value: id)
      .execute()
    if let i = notes.firstIndex(where: { $0.id == id }) {
      let n = notes[i]
      notes[i] = Note(id: n.id, athleteId: n.athleteId, coachId: n.coachId,
                      note: text, category: category, isPrivate: isPrivate,
                      createdAt: n.createdAt)
    }
  }
}

private struct NoteInsert: Encodable {
  let athleteId: String
  let coachId: String
  let note: String
  let category: String
  let isPrivate: Bool

  enum CodingKeys: String, CodingKey {
    case athleteId = "athlete_id"
    case coachId = "coach_id"
    case note
    case category
    case isPrivate = "is_private"
  }
}
