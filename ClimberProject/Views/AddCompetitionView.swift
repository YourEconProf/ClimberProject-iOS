import SwiftUI

struct AddCompetitionView: View {
  let athlete: Athlete
  @ObservedObject var vm: CompetitionViewModel
  @EnvironmentObject var authVM: AuthViewModel
  @Environment(\.dismiss) var dismiss

  @State private var date = Date()
  @State private var location = ""
  @State private var ranking: Int? = nil
  @State private var notes = ""
  @State private var isSaving = false
  @State private var error: String?

  var body: some View {
    NavigationStack {
      Form {
        Section {
          DatePicker("Date", selection: $date, displayedComponents: .date)
          TextField("Location", text: $location)
            .textInputAutocapitalization(.words)
        }

        Section("Ranking (optional)") {
          Picker("Ranking", selection: $ranking) {
            Text("No ranking").tag(nil as Int?)
            ForEach(1...20, id: \.self) { n in
              Text(ordinal(n)).tag(n as Int?)
            }
          }
        }

        Section("Notes") {
          TextEditor(text: $notes)
            .frame(minHeight: 80)
        }

        if let error {
          Section {
            Text(error).foregroundColor(.red).font(.caption)
          }
        }
      }
      .navigationTitle("Add Result")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") { Task { await save() } }
            .disabled(location.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
        }
      }
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

  private func save() async {
    guard let coachId = authVM.currentCoach?.id else { return }
    let trimmed = location.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else { return }
    isSaving = true
    error = nil
    defer { isSaving = false }

    let fmt = DateFormatter()
    fmt.dateFormat = "yyyy-MM-dd"
    fmt.locale = Locale(identifier: "en_US_POSIX")

    do {
      try await vm.add(
        athleteId: athlete.id,
        coachId: coachId,
        competitionDate: fmt.string(from: date),
        location: trimmed,
        ranking: ranking,
        notes: notes.isEmpty ? nil : notes
      )
      dismiss()
    } catch {
      self.error = error.localizedDescription
    }
  }
}
