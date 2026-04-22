import SwiftUI

struct AthleteWorkoutHistoryView: View {
  let athlete: Athlete
  @ObservedObject var vm: WorkoutViewModel
  @EnvironmentObject var authVM: AuthViewModel

  @State private var showingAdd = false
  @State private var editingWorkout: Workout?
  @State private var quickNotesWorkout: Workout?
  @State private var expanded: Set<String> = []

  var body: some View {
    Group {
      if vm.isLoading && vm.workouts.isEmpty {
        ProgressView()
      } else if let error = vm.error, vm.workouts.isEmpty {
        VStack(spacing: 12) {
          Text(error).foregroundColor(.red).multilineTextAlignment(.center)
          Button("Retry") { Task { await vm.fetchWorkouts(athleteId: athlete.id) } }
        }
        .padding()
      } else {
        List {
          ForEach(vm.workouts) { workout in
            WorkoutRow(
              workout: workout,
              athleteName: athlete.displayName,
              isExpanded: expanded.contains(workout.id),
              onToggle: { toggle(workout.id) },
              onEdit: { editingWorkout = workout },
              onQuickNote: { quickNotesWorkout = workout }
            )
            .swipeActions(edge: .trailing) {
              Button(role: .destructive) {
                Task { try? await vm.deleteWorkout(id: workout.id) }
              } label: { Label("Delete", systemImage: "trash") }
            }
          }
        }
        .overlay {
          if vm.workouts.isEmpty {
            ContentUnavailableView("No Workouts", systemImage: "dumbbell")
          }
        }
      }
    }
    .navigationTitle("Workout History")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        Button { showingAdd = true } label: { Image(systemName: "plus") }
      }
    }
    .sheet(isPresented: $showingAdd) {
      AddWorkoutView(
        vm: vm,
        mode: .athlete(id: athlete.id),
        coachId: authVM.currentCoach?.id ?? "",
        gymId: authVM.currentCoach?.gymId ?? "",
        editing: nil
      )
    }
    .sheet(item: $editingWorkout) { workout in
      AddWorkoutView(
        vm: vm,
        mode: .athlete(id: athlete.id),
        coachId: authVM.currentCoach?.id ?? "",
        gymId: authVM.currentCoach?.gymId ?? "",
        editing: workout
      )
    }
    .sheet(item: $quickNotesWorkout) { workout in
      QuickNotesSheet(vm: vm, workout: workout)
    }
    .task {
      if let gymId = authVM.currentCoach?.gymId, vm.exercises.isEmpty {
        await vm.fetchExercises(gymId: gymId)
      }
      if vm.namedWorkouts.isEmpty {
        await vm.fetchNamedWorkouts()
      }
    }
  }

  private func toggle(_ id: String) {
    if expanded.contains(id) { expanded.remove(id) } else { expanded.insert(id) }
  }
}

// MARK: - Row

private struct WorkoutRow: View {
  let workout: Workout
  let athleteName: String
  let isExpanded: Bool
  let onToggle: () -> Void
  let onEdit: () -> Void
  let onQuickNote: () -> Void

  @State private var shareURL: IdentifiableURL?

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 2) {
          HStack(spacing: 6) {
            Text(workout.workoutDate.displayDateWithWeekday)
              .font(.subheadline).bold()
            if let name = workout.name ?? workout.templateName {
              Text(": \(name)")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(1)
            }
          }
          Text("\(workout.sortedSets.count) sets • \(workout.totalExerciseCount) exercises")
            .font(.caption)
            .foregroundColor(.secondary)
          if let coachName = workout.coach?.name {
            Text(coachName)
              .font(.caption2)
              .foregroundColor(.secondary)
          }
        }
        Spacer()
        Button(action: onQuickNote) {
          Image(systemName: (workout.notes?.isEmpty == false) ? "note.text" : "square.and.pencil")
            .foregroundColor(.accentColor)
        }
        .buttonStyle(.borderless)
        Button(action: onEdit) {
          Image(systemName: "pencil").foregroundColor(.accentColor)
        }
        .buttonStyle(.borderless)
        Button { sharePDF() } label: {
          Image(systemName: "square.and.arrow.up").foregroundColor(.accentColor)
        }
        .buttonStyle(.borderless)
        Button(action: onToggle) {
          Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
            .foregroundColor(.secondary)
        }
        .buttonStyle(.borderless)
      }

      if isExpanded {
        Divider()
        ForEach(Array(workout.sortedSets.enumerated()), id: \.element.id) { idx, set in
          let rounds = set.effectiveRoundsCount
          VStack(alignment: .leading, spacing: 4) {
            HStack {
              if let typeName = set.setType?.name, !typeName.isEmpty {
                Text("Set \(idx + 1): \(typeName)").font(.caption).bold()
              } else {
                Text("Set \(idx + 1)").font(.caption).bold()
              }
              if let r = set.repeatCount, r > 1 {
                Text("×\(r)").font(.caption).foregroundColor(.secondary)
              }
              if rounds > 1 {
                Text("• \(rounds) rounds").font(.caption).foregroundColor(.secondary)
              }
            }
            ForEach(set.sortedExercises) { ex in
              if rounds > 1 {
                VStack(alignment: .leading, spacing: 2) {
                  HStack(spacing: 8) {
                    Text("•").foregroundColor(.secondary)
                    Text(ex.displayName).font(.caption)
                    Spacer()
                  }
                  let diffs = ex.effectiveDifficulties(roundsCount: rounds)
                  let reps = ex.effectiveReps(roundsCount: rounds)
                  ForEach(0..<rounds, id: \.self) { i in
                    HStack(spacing: 8) {
                      Text("R\(i + 1)").font(.caption2).foregroundColor(.secondary)
                        .frame(width: 28, alignment: .leading)
                      Spacer()
                      if !diffs[i].isEmpty {
                        Text(diffs[i]).font(.caption2).foregroundColor(.secondary)
                      }
                      if !reps[i].isEmpty {
                        Text("\(reps[i]) reps").font(.caption2).foregroundColor(.secondary)
                      }
                    }
                    .padding(.leading, 16)
                  }
                }
              } else {
                HStack(spacing: 8) {
                  Text("•").foregroundColor(.secondary)
                  Text(ex.displayName).font(.caption)
                  Spacer()
                  if let d = ex.difficulty, !d.isEmpty {
                    Text(d).font(.caption).foregroundColor(.secondary)
                  }
                  if let r = ex.reps, !r.isEmpty {
                    Text("\(r) reps").font(.caption).foregroundColor(.secondary)
                  }
                }
              }
            }
          }
          .padding(.vertical, 2)
        }
        if let notes = workout.notes, !notes.isEmpty {
          Divider()
          Text(notes).font(.caption).foregroundColor(.secondary)
        }
      }
    }
    .padding(.vertical, 4)
    .sheet(item: $shareURL) { item in
      ShareSheet(items: [item.url])
    }
  }

  @MainActor
  private func sharePDF() {
    if let url = WorkoutPDFRenderer.renderPDF(workout, athleteName: athleteName) {
      shareURL = IdentifiableURL(url: url)
    }
  }
}

// MARK: - Quick notes sheet

private struct QuickNotesSheet: View {
  @ObservedObject var vm: WorkoutViewModel
  let workout: Workout
  @Environment(\.dismiss) private var dismiss
  @State private var text: String = ""
  @State private var isSaving = false
  @State private var error: String?

  var body: some View {
    NavigationStack {
      Form {
        Section("Coach's Notes") {
          TextField("Post-workout notes…", text: $text, axis: .vertical)
            .lineLimit(4...12)
        }
        if let error {
          Section { Text(error).foregroundColor(.red).font(.caption) }
        }
      }
      .navigationTitle(workout.name ?? workout.workoutDate.displayDate)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") { Task { await save() } }
            .disabled(isSaving)
        }
      }
      .onAppear { text = workout.notes ?? "" }
    }
  }

  private func save() async {
    isSaving = true
    error = nil
    do {
      try await vm.updateWorkoutNotes(id: workout.id, notes: text.trimmingCharacters(in: .whitespacesAndNewlines))
      dismiss()
    } catch {
      self.error = error.localizedDescription
      isSaving = false
    }
  }
}
