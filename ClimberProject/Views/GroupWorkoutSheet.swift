import SwiftUI

struct GroupWorkoutSheet: View {
  @ObservedObject var workoutVM: WorkoutViewModel
  @EnvironmentObject var authVM: AuthViewModel
  @Environment(\.dismiss) var dismiss

  @StateObject private var programVM = ProgramViewModel()
  @State private var selectedProgramId: String = ""
  @State private var isLoadingAthletes = false
  @State private var error: String?
  @State private var showWorkoutForm = false
  @State private var pendingAthleteIds: [String] = []
  @State private var pendingProgramName: String = ""

  private var selectedProgram: Program? {
    programVM.programs.first { $0.id == selectedProgramId }
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("Program") {
          if programVM.isLoading {
            ProgressView()
          } else if programVM.programs.isEmpty {
            Text("No programs found.").foregroundColor(.secondary)
          } else {
            Picker("Program", selection: $selectedProgramId) {
              Text("Select a program…").tag("")
              ForEach(programVM.programs) { p in
                Text(p.name).tag(p.id)
              }
            }
          }
        }

        if let error {
          Section {
            Text(error).foregroundColor(.red).font(.caption)
          }
        }
      }
      .navigationTitle("Group Workout")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          if isLoadingAthletes {
            ProgressView()
          } else {
            Button("Next") { Task { await loadAndOpen() } }
              .disabled(selectedProgramId.isEmpty)
          }
        }
      }
      .task {
        await programVM.fetchPrograms()
        if let gymId = authVM.currentCoach?.gymId, workoutVM.exercises.isEmpty {
          await workoutVM.fetchExercises(gymId: gymId)
        }
        if workoutVM.namedWorkouts.isEmpty {
          await workoutVM.fetchNamedWorkouts()
        }
      }
    }
    .sheet(isPresented: $showWorkoutForm) {
      AddWorkoutView(
        vm: workoutVM,
        mode: .group(athleteIds: pendingAthleteIds, programName: pendingProgramName),
        coachId: authVM.currentCoach?.id ?? "",
        gymId: authVM.currentCoach?.gymId ?? "",
        editing: nil
      )
    }
  }

  private func loadAndOpen() async {
    guard let program = selectedProgram else { return }
    isLoadingAthletes = true
    error = nil
    defer { isLoadingAthletes = false }
    do {
      let ids = try await programVM.fetchEnrolledAthletes(programId: selectedProgramId)
      guard !ids.isEmpty else {
        self.error = "No active athletes enrolled in \"\(program.name)\"."
        return
      }
      pendingAthleteIds = ids
      pendingProgramName = program.name
      showWorkoutForm = true
    } catch {
      self.error = error.localizedDescription
    }
  }
}
