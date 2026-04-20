import SwiftUI

struct WorkoutsLibraryView: View {
  @StateObject private var vm = WorkoutViewModel()
  @EnvironmentObject var authVM: AuthViewModel

  @State private var editing: Workout?
  @State private var copying: Workout?
  @State private var search: String = ""

  var filtered: [Workout] {
    guard !search.isEmpty else { return vm.namedWorkouts }
    return vm.namedWorkouts.filter {
      ($0.name ?? "").localizedCaseInsensitiveContains(search)
    }
  }

  var body: some View {
    NavigationStack {
      Group {
        if vm.isLoading && vm.namedWorkouts.isEmpty {
          ProgressView()
        } else if let error = vm.error, vm.namedWorkouts.isEmpty {
          VStack(spacing: 12) {
            Text(error).foregroundColor(.red).multilineTextAlignment(.center)
            Button("Retry") { Task { await vm.fetchNamedWorkouts() } }
          }
          .padding()
        } else {
          List {
            ForEach(filtered) { w in
              LibraryCard(workout: w, onEdit: { editing = w }, onCopy: { copying = w })
                .swipeActions(edge: .trailing) {
                  Button(role: .destructive) {
                    Task { try? await vm.deleteWorkout(id: w.id) }
                  } label: { Label("Delete", systemImage: "trash") }
                }
            }
          }
          .overlay {
            if vm.namedWorkouts.isEmpty {
              ContentUnavailableView("No Named Workouts", systemImage: "dumbbell",
                description: Text("Create a workout on an athlete and give it a name to add it to the library."))
            }
          }
        }
      }
      .navigationTitle("Workouts")
      .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .automatic))
      .task {
        await vm.fetchNamedWorkouts()
        if let gymId = authVM.currentCoach?.gymId, vm.exercises.isEmpty {
          await vm.fetchExercises(gymId: gymId)
        }
      }
      .refreshable { await vm.fetchNamedWorkouts() }
      .sheet(item: $editing) { workout in
        AddWorkoutView(
          vm: vm,
          athleteId: workout.athleteId,
          coachId: authVM.currentCoach?.id ?? "",
          gymId: authVM.currentCoach?.gymId ?? "",
          editing: workout
        )
      }
      .sheet(item: $copying) { workout in
        CopyWorkoutSheet(vm: vm, source: workout)
      }
    }
  }
}

// MARK: - Card

private struct LibraryCard: View {
  let workout: Workout
  let onEdit: () -> Void
  let onCopy: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack {
        Text(workout.name ?? "—").font(.headline)
        Spacer()
        Button(action: onCopy) {
          Label("Copy", systemImage: "doc.on.doc")
            .labelStyle(.iconOnly)
        }
        .buttonStyle(.borderless)
        Button(action: onEdit) {
          Image(systemName: "pencil")
        }
        .buttonStyle(.borderless)
      }
      if let athlete = workout.athlete {
        Text("From: \(athlete.displayName)")
          .font(.caption)
          .foregroundColor(.secondary)
      }
      Text("\(workout.sortedSets.count) sets • \(workout.totalExerciseCount) exercises")
        .font(.caption)
        .foregroundColor(.secondary)
      ForEach(workout.sortedSets) { s in
        VStack(alignment: .leading, spacing: 2) {
          HStack {
            Text("Set \((workout.sortedSets.firstIndex(where: { $0.id == s.id }) ?? 0) + 1)")
              .font(.caption2).bold()
            if let r = s.repeatCount, r > 1 {
              Text("×\(r)").font(.caption2).foregroundColor(.secondary)
            }
          }
          ForEach(s.sortedExercises) { ex in
            HStack {
              Text("• \(ex.displayName)").font(.caption2)
              Spacer()
              if let d = ex.difficulty, !d.isEmpty {
                Text(d).font(.caption2).foregroundColor(.secondary)
              }
              if let r = ex.reps, !r.isEmpty {
                Text("\(r) reps").font(.caption2).foregroundColor(.secondary)
              }
            }
          }
        }
        .padding(.vertical, 1)
      }
      if let notes = workout.notes, !notes.isEmpty {
        Text(notes)
          .font(.caption)
          .foregroundColor(.secondary)
          .lineLimit(3)
          .padding(.top, 2)
      }
    }
    .padding(.vertical, 4)
  }
}
