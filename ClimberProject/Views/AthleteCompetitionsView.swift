import SwiftUI

struct AthleteCompetitionsView: View {
  let athlete: Athlete
  @ObservedObject var vm: CompetitionViewModel
  @EnvironmentObject var authVM: AuthViewModel
  @State private var showAdd = false
  @State private var editingResult: CompetitionResult? = nil

  var body: some View {
    List {
      ForEach(vm.results) { result in
        HStack {
          CompetitionResultRow(result: result)
          Spacer()
          Button {
            editingResult = result
          } label: {
            Image(systemName: "pencil")
              .foregroundColor(.secondary)
          }
          .buttonStyle(.borderless)
        }
      }
    }
    .navigationTitle("Competitions")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        Button { showAdd = true } label: { Image(systemName: "plus") }
      }
    }
    .sheet(isPresented: $showAdd) {
      AddCompetitionView(athlete: athlete, vm: vm)
        .environmentObject(authVM)
    }
    .sheet(item: $editingResult) { result in
      EditCompetitionNotesView(result: result, vm: vm)
    }
    .overlay {
      if vm.results.isEmpty && !vm.isLoading {
        ContentUnavailableView("No Competitions", systemImage: "trophy",
          description: Text("Tap + to add a competition result."))
      }
    }
  }
}

private struct EditCompetitionNotesView: View {
  let result: CompetitionResult
  @ObservedObject var vm: CompetitionViewModel
  @Environment(\.dismiss) private var dismiss

  @State private var notes: String
  @State private var isSaving = false
  @State private var error: String?

  init(result: CompetitionResult, vm: CompetitionViewModel) {
    self.result = result
    self.vm = vm
    _notes = State(initialValue: result.notes ?? "")
  }

  var body: some View {
    NavigationStack {
      Form {
        Section {
          Text(result.location).font(.subheadline)
          Text(result.competitionDate.displayDate)
            .font(.caption).foregroundColor(.secondary)
        }
        Section("Notes") {
          TextEditor(text: $notes)
            .frame(minHeight: 120)
        }
        if let error {
          Section {
            Text(error).foregroundColor(.red).font(.caption)
          }
        }
      }
      .navigationTitle("Edit Notes")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button(isSaving ? "Saving…" : "Save") { Task { await save() } }
            .disabled(isSaving)
        }
      }
    }
  }

  private func save() async {
    isSaving = true
    error = nil
    defer { isSaving = false }
    do {
      try await vm.updateNotes(id: result.id, notes: notes)
      dismiss()
    } catch {
      self.error = error.localizedDescription
    }
  }
}

private struct CompetitionResultRow: View {
  let result: CompetitionResult

  var body: some View {
    HStack(spacing: 12) {
      rankBadge
      VStack(alignment: .leading, spacing: 2) {
        Text(result.location).font(.subheadline)
        Text(result.competitionDate.displayDate)
          .font(.caption).foregroundColor(.secondary)
        if let notes = result.notes, !notes.isEmpty {
          Text(notes)
            .font(.caption).foregroundColor(.secondary)
            .lineLimit(2)
            .padding(.top, 1)
        }
      }
    }
    .padding(.vertical, 2)
  }

  @ViewBuilder
  private var rankBadge: some View {
    if let n = result.ranking {
      ZStack {
        Circle()
          .fill(rankColor(n).opacity(0.15))
          .frame(width: 44, height: 44)
        Text(ordinal(n))
          .font(.caption2).bold()
          .foregroundColor(rankColor(n))
      }
    } else {
      Image(systemName: "trophy")
        .font(.title3)
        .foregroundColor(.secondary)
        .frame(width: 44, height: 44)
    }
  }

  private func ordinal(_ n: Int) -> String {
    let mod100 = n % 100
    let mod10 = n % 10
    let suffix: String
    if (11...13).contains(mod100) {
      suffix = "th"
    } else {
      switch mod10 {
      case 1: suffix = "st"
      case 2: suffix = "nd"
      case 3: suffix = "rd"
      default: suffix = "th"
      }
    }
    return "\(n)\(suffix)"
  }

  private func rankColor(_ n: Int) -> Color {
    switch n {
    case 1: return .yellow
    case 2: return Color(red: 0.75, green: 0.75, blue: 0.75)
    case 3: return .orange
    default: return .blue
    }
  }
}
