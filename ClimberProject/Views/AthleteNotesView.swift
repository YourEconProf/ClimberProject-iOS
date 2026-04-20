import SwiftUI

struct AthleteNotesView: View {
  let athlete: Athlete
  @ObservedObject var vm: NoteViewModel
  @EnvironmentObject var authVM: AuthViewModel
  @State private var showingAdd = false

  var body: some View {
    Group {
      if vm.isLoading && vm.notes.isEmpty {
        ProgressView()
      } else if let error = vm.error {
        VStack(spacing: 12) {
          Text(error).foregroundColor(.red).multilineTextAlignment(.center)
          Button("Retry") { Task { await vm.fetchNotes(athleteId: athlete.id) } }
        }
        .padding()
      } else {
        List {
          ForEach(vm.notes) { note in
            NoteRow(note: note, currentCoach: authVM.currentCoach)
              .swipeActions(edge: .trailing) {
                if canDelete(note) {
                  Button(role: .destructive) {
                    Task { try? await vm.deleteNote(id: note.id) }
                  } label: {
                    Label("Delete", systemImage: "trash")
                  }
                }
              }
          }
        }
        .overlay {
          if vm.notes.isEmpty {
            ContentUnavailableView("No Notes", systemImage: "note.text")
          }
        }
      }
    }
    .navigationTitle("Notes")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        Button { showingAdd = true } label: {
          Image(systemName: "plus")
        }
      }
    }
    .sheet(isPresented: $showingAdd) {
      AddNoteView(
        vm: vm,
        athleteId: athlete.id,
        coachId: authVM.currentCoach?.id ?? ""
      )
    }
  }

  private func canDelete(_ note: Note) -> Bool {
    guard let coach = authVM.currentCoach else { return false }
    return note.coachId == coach.id || coach.isHeadCoachOrAdmin
  }
}

private struct NoteRow: View {
  let note: Note
  let currentCoach: Coach?

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack {
        Label(note.category.rawValue.capitalized, systemImage: categoryIcon)
          .font(.caption)
          .foregroundColor(categoryColor)
        Spacer()
        if note.isPrivate {
          Image(systemName: "lock.fill")
            .font(.caption)
            .foregroundColor(.secondary)
        }
        Text(String(note.createdAt.prefix(10)))
          .font(.caption)
          .foregroundColor(.secondary)
      }
      Text(note.note)
        .font(.body)
    }
    .padding(.vertical, 2)
    .opacity(note.isPrivate && note.coachId != currentCoach?.id && currentCoach?.isHeadCoachOrAdmin == false ? 0.5 : 1)
  }

  private var categoryIcon: String {
    switch note.category {
    case .technical: return "wrench"
    case .behavioral: return "person.fill"
    case .goal: return "target"
    case .injury: return "cross.fill"
    case .general: return "note.text"
    }
  }

  private var categoryColor: Color {
    switch note.category {
    case .technical: return .blue
    case .behavioral: return .purple
    case .goal: return .green
    case .injury: return .red
    case .general: return .secondary
    }
  }
}
