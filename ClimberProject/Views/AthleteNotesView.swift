import SwiftUI

struct AthleteNotesView: View {
  let athlete: Athlete
  @ObservedObject var vm: NoteViewModel
  @EnvironmentObject var authVM: AuthViewModel
  @State private var showingAdd = false
  @State private var selectedFilter: NoteCategory? = nil
  @State private var editingNote: Note? = nil

  private var filteredNotes: [Note] {
    guard let filter = selectedFilter else { return vm.notes }
    return vm.notes.filter { $0.category == filter }
  }

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
          Section {
            ScrollView(.horizontal, showsIndicators: false) {
              HStack(spacing: 8) {
                FilterChip(label: "All", isSelected: selectedFilter == nil) {
                  selectedFilter = nil
                }
                ForEach(NoteCategory.allCases, id: \.self) { cat in
                  FilterChip(label: cat.rawValue.capitalized, isSelected: selectedFilter == cat) {
                    selectedFilter = selectedFilter == cat ? nil : cat
                  }
                }
              }
              .padding(.vertical, 4)
            }
          }
          .listRowInsets(EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12))
          .listRowBackground(Color.clear)

          ForEach(filteredNotes) { note in
            HStack(alignment: .top) {
              NoteRow(note: note, currentCoach: authVM.currentCoach, gymTimezone: authVM.gymTimezone)
              if canEdit(note) {
                Button {
                  editingNote = note
                } label: {
                  Image(systemName: "pencil")
                    .foregroundColor(.secondary)
                }
                .buttonStyle(.borderless)
                .padding(.top, 2)
              }
            }
          }
        }
        .overlay {
          if filteredNotes.isEmpty {
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
    .sheet(item: $editingNote) { note in
      EditNoteView(note: note, vm: vm)
    }
  }

  private func canEdit(_ note: Note) -> Bool {
    guard let coach = authVM.currentCoach else { return false }
    return note.coachId == coach.id || coach.isHeadCoachOrAdmin
  }
}

private struct NoteRow: View {
  let note: Note
  let currentCoach: Coach?
  let gymTimezone: String

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
        Text(note.createdAt.displayDate(in: gymTimezone))
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

private struct EditNoteView: View {
  let note: Note
  @ObservedObject var vm: NoteViewModel
  @Environment(\.dismiss) private var dismiss

  @State private var text: String
  @State private var category: NoteCategory
  @State private var isPrivate: Bool
  @State private var isSaving = false
  @State private var error: String?

  init(note: Note, vm: NoteViewModel) {
    self.note = note
    self.vm = vm
    _text = State(initialValue: note.note)
    _category = State(initialValue: note.category)
    _isPrivate = State(initialValue: note.isPrivate)
  }

  var body: some View {
    NavigationStack {
      Form {
        Section {
          Picker("Category", selection: $category) {
            ForEach(NoteCategory.allCases, id: \.self) { c in
              Text(c.rawValue.capitalized).tag(c)
            }
          }
          Toggle("Private", isOn: $isPrivate)
        }
        Section("Note") {
          TextField("Note…", text: $text, axis: .vertical)
            .lineLimit(4...10)
        }
        if let error {
          Section {
            Text(error).foregroundColor(.red).font(.caption)
          }
        }
      }
      .navigationTitle("Edit Note")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button(isSaving ? "Saving…" : "Save") { Task { await save() } }
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
        }
      }
    }
  }

  private func save() async {
    isSaving = true
    error = nil
    defer { isSaving = false }
    do {
      try await vm.updateNote(
        id: note.id,
        text: text.trimmingCharacters(in: .whitespacesAndNewlines),
        category: category,
        isPrivate: isPrivate
      )
      dismiss()
    } catch {
      self.error = error.localizedDescription
    }
  }
}

private struct FilterChip: View {
  let label: String
  let isSelected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Text(label)
        .font(.caption)
        .fontWeight(isSelected ? .semibold : .regular)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(isSelected ? Color.accentColor.opacity(0.15) : Color(.systemGray5))
        .foregroundColor(isSelected ? .accentColor : .primary)
        .clipShape(Capsule())
    }
    .buttonStyle(.plain)
  }
}
