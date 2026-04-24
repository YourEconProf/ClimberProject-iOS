import SwiftUI

struct WorkoutsLibraryView: View {
  @StateObject private var vm = WorkoutViewModel()
  @StateObject private var tagVM = TagViewModel()
  @EnvironmentObject var authVM: AuthViewModel

  @State private var previewing: Workout?
  @State private var copying: Workout?
  @State private var creatingTemplate = false
  @State private var showGroupSheet = false
  @State private var expanded: Set<String> = []
  @State private var search: String = ""
  @State private var selectedTagIds: Set<String> = []

  var filtered: [Workout] {
    let searchFiltered = search.isEmpty ? vm.namedWorkouts :
      vm.namedWorkouts.filter { ($0.name ?? "").localizedCaseInsensitiveContains(search) }
    guard !selectedTagIds.isEmpty else { return searchFiltered }
    return searchFiltered.filter { workout in
      tagVM.tagsForWorkout(workout.id).contains(where: { selectedTagIds.contains($0.id) })
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
            if !tagVM.tags.isEmpty {
              Section {
                ScrollView(.horizontal, showsIndicators: false) {
                  HStack(spacing: 8) {
                    ForEach(tagVM.tags) { tag in
                      Button {
                        if selectedTagIds.contains(tag.id) {
                          selectedTagIds.remove(tag.id)
                        } else {
                          selectedTagIds.insert(tag.id)
                        }
                      } label: {
                        Text(tag.name)
                          .font(.caption)
                          .padding(.horizontal, 10).padding(.vertical, 5)
                          .background(selectedTagIds.contains(tag.id) ? Color.accentColor : Color.secondary.opacity(0.15))
                          .foregroundColor(selectedTagIds.contains(tag.id) ? .white : .primary)
                          .clipShape(Capsule())
                      }
                      .buttonStyle(.plain)
                    }
                  }
                  .padding(.vertical, 4)
                }
              }
            }
            ForEach(filtered) { w in
              LibraryCard(
                workout: w,
                isExpanded: expanded.contains(w.id),
                onToggle: { toggle(w.id) },
                onPreview: { previewing = w },
                onCopy: { copying = w },
                workoutTags: tagVM.tagsForWorkout(w.id),
                allTags: tagVM.tags,
                onToggleTag: { tagId in
                  Task { try? await tagVM.toggleWorkoutTag(workoutId: w.id, tagId: tagId) }
                }
              )
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
                description: Text("Create a workout template with the + button, or name a workout on an athlete."))
            }
          }
        }
      }
      .navigationTitle("Workouts")
      .toolbar {
        ToolbarItem(placement: .primaryAction) {
          Button { creatingTemplate = true } label: { Image(systemName: "plus") }
        }
        ToolbarItem(placement: .navigationBarLeading) {
          Button {
            showGroupSheet = true
          } label: {
            Label("Group Workout", systemImage: "person.3")
          }
        }
      }
      .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .automatic))
      .task {
        await vm.fetchNamedWorkouts()
        if let gymId = authVM.currentCoach?.gymId {
          if vm.exercises.isEmpty { await vm.fetchExercises(gymId: gymId) }
          await tagVM.fetch(gymId: gymId)
        }
      }
      .refreshable { await vm.fetchNamedWorkouts() }
      .sheet(item: $previewing) { workout in
        WorkoutPreviewView(
          vm: vm,
          workout: workout,
          onCopy: {
            previewing = nil
            copying = workout
          }
        )
      }
      .sheet(isPresented: $creatingTemplate) {
        AddWorkoutView(
          vm: vm,
          mode: .template(gymId: authVM.currentCoach?.gymId ?? ""),
          coachId: authVM.currentCoach?.id ?? "",
          gymId: authVM.currentCoach?.gymId ?? "",
          editing: nil
        )
      }
      .sheet(item: $copying) { workout in
        CopyWorkoutSheet(vm: vm, source: workout)
      }
      .sheet(isPresented: $showGroupSheet) {
        GroupWorkoutSheet(workoutVM: vm)
          .environmentObject(authVM)
      }
    }
  }
}

// MARK: - Card

private struct LibraryCard: View {
  let workout: Workout
  let isExpanded: Bool
  let onToggle: () -> Void
  let onPreview: () -> Void
  let onCopy: () -> Void
  let workoutTags: [Tag]
  let allTags: [Tag]
  let onToggleTag: (String) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(alignment: .top) {
        Button(action: onPreview) {
          VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
              Text(workout.name ?? "—").font(.headline).foregroundColor(.primary)
              if workout.athleteId == nil {
                Text("Template")
                  .font(.caption2)
                  .padding(.horizontal, 6)
                  .padding(.vertical, 2)
                  .background(Color.accentColor.opacity(0.15))
                  .foregroundColor(.accentColor)
                  .clipShape(Capsule())
              }
            }
            if let athlete = workout.athlete {
              Text("From: \(athlete.displayName)")
                .font(.caption).foregroundColor(.secondary)
            }
            Text("\(workout.sortedSets.count) sets • \(workout.totalExerciseCount) exercises")
              .font(.caption).foregroundColor(.secondary)
          }
        }
        .buttonStyle(.plain)
        Spacer()
        Button(action: onCopy) {
          Label("Copy", systemImage: "doc.on.doc").labelStyle(.iconOnly)
        }
        .buttonStyle(.borderless)
        Button(action: onToggle) {
          Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
            .foregroundColor(.secondary)
        }
        .buttonStyle(.borderless)
      }

      if !allTags.isEmpty {
        HStack(spacing: 6) {
          ForEach(workoutTags) { tag in
            Text(tag.name)
              .font(.caption2)
              .padding(.horizontal, 6).padding(.vertical, 2)
              .background(Color.accentColor.opacity(0.15))
              .foregroundColor(.accentColor)
              .clipShape(Capsule())
          }
          Menu {
            ForEach(allTags) { tag in
              Button {
                onToggleTag(tag.id)
              } label: {
                Label(tag.name, systemImage: workoutTags.contains(tag) ? "checkmark" : "")
              }
            }
          } label: {
            Text("+ tag")
              .font(.caption2)
              .padding(.horizontal, 6).padding(.vertical, 2)
              .background(Color.secondary.opacity(0.1))
              .foregroundColor(.secondary)
              .clipShape(Capsule())
          }
        }
      }

      if isExpanded {
        Divider()
        ForEach(Array(workout.sortedSets.enumerated()), id: \.element.id) { idx, s in
          LibrarySetRow(index: idx, set: s)
        }
        if let notes = workout.notes, !notes.isEmpty {
          Text(notes)
            .font(.caption).foregroundColor(.secondary)
            .lineLimit(3)
            .padding(.top, 2)
        }
      }
    }
    .padding(.vertical, 4)
  }
}

extension WorkoutsLibraryView {
  fileprivate func toggle(_ id: String) {
    if expanded.contains(id) { expanded.remove(id) } else { expanded.insert(id) }
  }
}

private struct LibrarySetRow: View {
  let index: Int
  let set: WorkoutSet

  var body: some View {
    let rounds = set.effectiveRoundsCount
    VStack(alignment: .leading, spacing: 2) {
      HStack {
        if let t = set.setType?.name, !t.isEmpty {
          Text("Set \(index + 1): \(t)").font(.caption2).bold()
        } else {
          Text("Set \(index + 1)").font(.caption2).bold()
        }
        if let r = set.repeatCount, r > 1 {
          Text("×\(r)").font(.caption2).foregroundColor(.secondary)
        }
        if rounds > 1 {
          Text("• \(rounds) rounds").font(.caption2).foregroundColor(.secondary)
        }
      }
      ForEach(set.sortedExercises) { ex in
        LibraryExerciseRow(exercise: ex, rounds: rounds)
      }
    }
    .padding(.vertical, 1)
  }
}

private struct LibraryExerciseRow: View {
  let exercise: WorkoutSetExercise
  let rounds: Int

  var body: some View {
    if rounds > 1 {
      VStack(alignment: .leading, spacing: 1) {
        Text("• \(exercise.displayName)").font(.caption2)
        let diffs = exercise.effectiveDifficulties(roundsCount: rounds)
        let reps = exercise.effectiveReps(roundsCount: rounds)
        ForEach(0..<rounds, id: \.self) { i in
          HStack {
            Text("R\(i + 1)").font(.caption2).foregroundColor(.secondary)
              .frame(width: 24, alignment: .leading)
            Spacer()
            if !diffs[i].isEmpty {
              Text(diffs[i]).font(.caption2).foregroundColor(.secondary)
            }
            if !reps[i].isEmpty {
              Text("\(reps[i]) reps").font(.caption2).foregroundColor(.secondary)
            }
          }
          .padding(.leading, 12)
        }
      }
    } else {
      HStack {
        Text("• \(exercise.displayName)").font(.caption2)
        Spacer()
        if let d = exercise.difficulty, !d.isEmpty {
          Text(d).font(.caption2).foregroundColor(.secondary)
        }
        if let r = exercise.reps, !r.isEmpty {
          Text("\(r) reps").font(.caption2).foregroundColor(.secondary)
        }
      }
    }
  }
}
