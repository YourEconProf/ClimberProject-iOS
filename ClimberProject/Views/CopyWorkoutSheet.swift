import SwiftUI

struct CopyWorkoutSheet: View {
  @ObservedObject var vm: WorkoutViewModel
  let source: Workout

  @EnvironmentObject var authVM: AuthViewModel
  @StateObject private var athleteVM = AthleteViewModel()
  @Environment(\.dismiss) private var dismiss

  @State private var selectedAthleteId: String?
  @State private var date: Date = Date()
  @State private var isSaving = false
  @State private var error: String?

  var body: some View {
    NavigationStack {
      Form {
        Section("Template") {
          Text(source.name ?? "—").font(.headline)
          Text("\(source.sortedSets.count) sets • \(source.totalExerciseCount) exercises")
            .font(.caption).foregroundColor(.secondary)
        }

        Section("Target Athlete") {
          if athleteVM.athletes.isEmpty {
            ProgressView()
          } else {
            Picker("Athlete", selection: $selectedAthleteId) {
              Text("Select…").tag(String?.none)
              ForEach(athleteVM.athletes) { a in
                Text(a.displayName).tag(Optional(a.id))
              }
            }
          }
        }

        Section("Date") {
          DatePicker("Date", selection: $date, displayedComponents: .date)
        }

        if let error {
          Section { Text(error).foregroundColor(.red).font(.caption) }
        }
      }
      .navigationTitle("Copy Workout")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
        ToolbarItem(placement: .confirmationAction) {
          Button("Copy") { Task { await copy() } }
            .disabled(selectedAthleteId == nil || isSaving)
        }
      }
      .task { await athleteVM.fetchAthletes() }
    }
  }

  private func copy() async {
    guard let athleteId = selectedAthleteId,
          let coachId = authVM.currentCoach?.id else { return }
    isSaving = true
    error = nil
    let fmt = DateFormatter()
    fmt.dateFormat = "yyyy-MM-dd"
    do {
      _ = try await vm.copyNamedWorkout(
        source,
        toAthleteId: athleteId,
        coachId: coachId,
        date: fmt.string(from: date)
      )
      dismiss()
    } catch {
      self.error = error.localizedDescription
      isSaving = false
    }
  }
}
