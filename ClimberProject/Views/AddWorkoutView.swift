import SwiftUI

enum WorkoutFormMode: Equatable {
  case athlete(id: String)
  case template(gymId: String)

  var isTemplate: Bool {
    if case .template = self { return true }
    return false
  }
}

struct AddWorkoutView: View {
  @ObservedObject var vm: WorkoutViewModel
  let mode: WorkoutFormMode
  let coachId: String
  let gymId: String
  let editing: Workout?

  @Environment(\.dismiss) private var dismiss

  @State private var date: Date = Date()
  @State private var name: String = ""
  @State private var notes: String = ""
  @State private var sets: [DraftSet] = [DraftSet(exercises: [DraftExercise()])]
  @State private var isSaving = false
  @State private var error: String?
  @State private var showingTemplateSuggestions = false
  @State private var templateAppliedFrom: String?
  @State private var nameIsTaken = false

  private let dateFmt: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    return f
  }()

  private var requireName: Bool { mode.isTemplate }
  private var titleString: String {
    if editing != nil {
      return mode.isTemplate ? "Edit Template" : "Edit Workout"
    }
    return mode.isTemplate ? "New Template" : "New Workout"
  }

  private var saveDisabled: Bool {
    if isSaving || sets.isEmpty { return true }
    if sets.contains(where: { $0.setTypeId == nil }) { return true }
    if requireName && name.trimmingCharacters(in: .whitespaces).isEmpty { return true }
    if nameIsTaken { return true }
    return false
  }

  var body: some View {
    NavigationStack {
      Form {
        if !mode.isTemplate {
          Section {
            DatePicker("Date", selection: $date, displayedComponents: .date)
          }
        } else {
          Section {
            Label("Workout Template", systemImage: "doc.plaintext")
              .foregroundColor(.secondary)
          }
        }

        Section {
          TextField(requireName ? "Template name (required)" : "Optional name (makes this a template)", text: $name)
            .onChange(of: name) { _ in
              showingTemplateSuggestions = !name.isEmpty && editing == nil && !mode.isTemplate
              Task { await recheckName() }
            }

          if nameIsTaken {
            Text("A workout with that name already exists.")
              .font(.caption)
              .foregroundColor(.red)
          }

          if let from = templateAppliedFrom {
            Text("Sets loaded from: \(from)")
              .font(.caption)
              .foregroundColor(.secondary)
          }

          if showingTemplateSuggestions {
            let matches = vm.namedWorkouts.filter {
              ($0.name ?? "").localizedCaseInsensitiveContains(name) && $0.name != nil
            }.prefix(5)
            if !matches.isEmpty {
              VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(matches), id: \.id) { template in
                  Button {
                    applyTemplate(template)
                  } label: {
                    HStack {
                      Text(template.name ?? "")
                      Spacer()
                      Text("\(template.sortedSets.count) sets")
                        .font(.caption).foregroundColor(.secondary)
                    }
                    .padding(.vertical, 6)
                  }
                  .buttonStyle(.plain)
                  Divider()
                }
              }
            }
          }
        }

        ForEach($sets) { $draftSet in
          Section {
            HStack {
              Text("Set \((sets.firstIndex(where: { $0.id == draftSet.id }) ?? 0) + 1)")
                .font(.headline)
              Spacer()
              Button(role: .destructive) {
                sets.removeAll { $0.id == draftSet.id }
              } label: {
                Image(systemName: "minus.circle")
              }
              .buttonStyle(.borderless)
            }

            Picker("Type", selection: $draftSet.setTypeId) {
              Text("Select type…").tag(String?.none)
              ForEach(vm.setTypes) { st in
                Text(st.name).tag(Optional(st.id))
              }
            }

            Stepper("Repeat: \(draftSet.repeatCount)×", value: $draftSet.repeatCount, in: 1...20)

            Stepper("Rounds: \(draftSet.roundsCount)", value: $draftSet.roundsCount, in: 1...20)
              .onChange(of: draftSet.roundsCount) { newCount in
                resizeRounds(in: $draftSet, to: newCount)
              }

            ForEach($draftSet.exercises) { $ex in
              ExerciseRowEditor(
                ex: $ex,
                roundsCount: draftSet.roundsCount,
                library: vm.exercises,
                onDelete: {
                  draftSet.exercises.removeAll { $0.id == ex.id }
                }
              )
            }

            Button {
              var newEx = DraftExercise()
              newEx.difficulties = Array(repeating: "", count: draftSet.roundsCount)
              newEx.reps = Array(repeating: "", count: draftSet.roundsCount)
              draftSet.exercises.append(newEx)
            } label: {
              Label("Add Exercise", systemImage: "plus")
            }
          }
        }

        Section {
          Button {
            var new = DraftSet()
            var ex = DraftExercise()
            ex.difficulties = [""]
            ex.reps = [""]
            new.exercises = [ex]
            sets.append(new)
          } label: {
            Label("Add Set", systemImage: "plus.circle.fill")
          }
        }

        Section("Coach's Notes") {
          TextField("Optional…", text: $notes, axis: .vertical)
            .lineLimit(2...8)
        }

        if let error {
          Section { Text(error).foregroundColor(.red).font(.caption) }
        }
      }
      .navigationTitle(titleString)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") { Task { await save() } }
            .disabled(saveDisabled)
        }
      }
      .onAppear(perform: bootstrap)
    }
  }

  // MARK: - Helpers

  private func bootstrap() {
    guard let w = editing else { return }
    if let d = dateFmt.date(from: w.workoutDate) { date = d }
    name = w.name ?? ""
    notes = w.notes ?? ""
    sets = w.sortedSets.map { s in
      let rc = s.effectiveRoundsCount
      return DraftSet(
        setTypeId: s.setTypeId,
        repeatCount: s.repeatCount ?? 1,
        roundsCount: rc,
        exercises: s.sortedExercises.map { ex in
          DraftExercise(
            exerciseId: ex.exerciseId,
            customName: ex.exercise?.name ?? "",
            difficulties: ex.effectiveDifficulties(roundsCount: rc),
            reps: ex.effectiveReps(roundsCount: rc)
          )
        }
      )
    }
    if sets.isEmpty {
      var ex = DraftExercise()
      ex.difficulties = [""]
      ex.reps = [""]
      sets = [DraftSet(exercises: [ex])]
    }
  }

  private func applyTemplate(_ template: Workout) {
    sets = template.sortedSets.map { s in
      let rc = s.effectiveRoundsCount
      return DraftSet(
        setTypeId: s.setTypeId,
        repeatCount: s.repeatCount ?? 1,
        roundsCount: rc,
        exercises: s.sortedExercises.map { ex in
          DraftExercise(
            exerciseId: ex.exerciseId,
            customName: ex.exercise?.name ?? "",
            difficulties: ex.effectiveDifficulties(roundsCount: rc),
            reps: ex.effectiveReps(roundsCount: rc)
          )
        }
      )
    }
    if let tNotes = template.notes, notes.isEmpty { notes = tNotes }
    // Clear the name field so the new workout starts unnamed (avoids uniqueness conflict).
    templateAppliedFrom = template.name
    name = ""
    showingTemplateSuggestions = false
    nameIsTaken = false
  }

  private func resizeRounds(in binding: Binding<DraftSet>, to newCount: Int) {
    let target = max(1, newCount)
    binding.wrappedValue.exercises = binding.wrappedValue.exercises.map { ex in
      var copy = ex
      copy.difficulties = resize(copy.difficulties, to: target)
      copy.reps = resize(copy.reps, to: target)
      return copy
    }
  }

  private func resize(_ arr: [String], to count: Int) -> [String] {
    if arr.count == count { return arr }
    if arr.count > count { return Array(arr.prefix(count)) }
    return arr + Array(repeating: "", count: count - arr.count)
  }

  private func recheckName() async {
    let trimmed = name.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else { nameIsTaken = false; return }
    let taken = await vm.nameIsTaken(trimmed, excludingId: editing?.id)
    await MainActor.run { nameIsTaken = taken }
  }

  private func save() async {
    isSaving = true
    error = nil
    do {
      let dateStr = dateFmt.string(from: date)
      let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
      let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
      let resolvedSets = try await resolveCustomExercises(sets)

      if !trimmedName.isEmpty {
        if await vm.nameIsTaken(trimmedName, excludingId: editing?.id) {
          throw WorkoutVMError.nameTaken
        }
      }

      if let editing {
        try await vm.updateWorkout(editing, date: dateStr, name: trimmedName, notes: trimmedNotes, sets: resolvedSets)
      } else {
        switch mode {
        case .athlete(let athleteId):
          _ = try await vm.createWorkout(
            athleteId: athleteId,
            coachId: coachId,
            gymId: nil,
            date: dateStr,
            name: trimmedName,
            notes: trimmedNotes,
            sets: resolvedSets
          )
        case .template(let gymId):
          _ = try await vm.createWorkout(
            athleteId: nil,
            coachId: coachId,
            gymId: gymId,
            date: dateStr,
            name: trimmedName,
            notes: trimmedNotes,
            sets: resolvedSets
          )
        }
      }
      dismiss()
    } catch {
      self.error = error.localizedDescription
      isSaving = false
    }
  }

  private func resolveCustomExercises(_ input: [DraftSet]) async throws -> [DraftSet] {
    var out: [DraftSet] = []
    for s in input {
      var exs: [DraftExercise] = []
      for var ex in s.exercises {
        let trimmed = ex.customName.trimmingCharacters(in: .whitespacesAndNewlines)
        if ex.exerciseId == nil && !trimmed.isEmpty {
          if let existing = vm.exercises.first(where: { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            ex.exerciseId = existing.id
          } else {
            let created = try await vm.addExercise(gymId: gymId, name: trimmed)
            ex.exerciseId = created.id
          }
        }
        let allEmpty = ex.exerciseId == nil && trimmed.isEmpty
          && ex.difficulties.allSatisfy { $0.isEmpty }
          && ex.reps.allSatisfy { $0.isEmpty }
        if allEmpty { continue }
        exs.append(ex)
      }
      out.append(DraftSet(
        id: s.id,
        setTypeId: s.setTypeId,
        repeatCount: s.repeatCount,
        roundsCount: max(1, s.roundsCount),
        exercises: exs
      ))
    }
    return out.filter { !$0.exercises.isEmpty }
  }
}

// MARK: - Exercise row editor

private struct ExerciseRowEditor: View {
  @Binding var ex: DraftExercise
  let roundsCount: Int
  let library: [Exercise]
  let onDelete: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack {
        Menu {
          Button("Custom…") { ex.exerciseId = nil }
          Divider()
          ForEach(library) { lib in
            Button(lib.name) {
              ex.exerciseId = lib.id
              ex.customName = lib.name
            }
          }
        } label: {
          HStack {
            Text(currentName.isEmpty ? "Choose exercise" : currentName)
              .foregroundColor(currentName.isEmpty ? .secondary : .primary)
            Spacer()
            Image(systemName: "chevron.down").font(.caption).foregroundColor(.secondary)
          }
        }
        Button(role: .destructive, action: onDelete) {
          Image(systemName: "minus.circle")
        }
        .buttonStyle(.borderless)
      }

      if ex.exerciseId == nil {
        TextField("Exercise name", text: $ex.customName)
          .textFieldStyle(.roundedBorder)
      }

      if roundsCount <= 1 {
        HStack {
          TextField("Difficulty (e.g. V4)", text: bindingForDifficulty(0))
            .textFieldStyle(.roundedBorder)
          TextField("Reps", text: bindingForReps(0))
            .textFieldStyle(.roundedBorder)
            .frame(maxWidth: 100)
        }
      } else {
        VStack(alignment: .leading, spacing: 4) {
          ForEach(0..<roundsCount, id: \.self) { r in
            HStack {
              Text("R\(r + 1)")
                .font(.caption2)
                .foregroundColor(.secondary)
                .frame(width: 28, alignment: .leading)
              TextField("Difficulty", text: bindingForDifficulty(r))
                .textFieldStyle(.roundedBorder)
              TextField("Reps", text: bindingForReps(r))
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 90)
            }
          }
        }
      }
    }
    .padding(.vertical, 4)
  }

  private var currentName: String {
    if let id = ex.exerciseId, let match = library.first(where: { $0.id == id }) {
      return match.name
    }
    return ex.customName
  }

  private func bindingForDifficulty(_ idx: Int) -> Binding<String> {
    Binding(
      get: { idx < ex.difficulties.count ? ex.difficulties[idx] : "" },
      set: { newVal in
        if idx < ex.difficulties.count {
          ex.difficulties[idx] = newVal
        } else {
          while ex.difficulties.count <= idx { ex.difficulties.append("") }
          ex.difficulties[idx] = newVal
        }
      }
    )
  }

  private func bindingForReps(_ idx: Int) -> Binding<String> {
    Binding(
      get: { idx < ex.reps.count ? ex.reps[idx] : "" },
      set: { newVal in
        if idx < ex.reps.count {
          ex.reps[idx] = newVal
        } else {
          while ex.reps.count <= idx { ex.reps.append("") }
          ex.reps[idx] = newVal
        }
      }
    )
  }
}
