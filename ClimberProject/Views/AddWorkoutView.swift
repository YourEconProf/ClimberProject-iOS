import SwiftUI

struct AddWorkoutView: View {
  @ObservedObject var vm: WorkoutViewModel
  let athleteId: String
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

  private let dateFmt: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    return f
  }()

  var body: some View {
    NavigationStack {
      Form {
        Section {
          DatePicker("Date", selection: $date, displayedComponents: .date)

          ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 0) {
              TextField("Optional name (makes this a template)", text: $name)
                .onChange(of: name) { _ in
                  showingTemplateSuggestions = !name.isEmpty && editing == nil
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
          }
        }

        ForEach($sets) { $draftSet in
          Section {
            HStack {
              Text("Set \((sets.firstIndex(where: { $0.id == draftSet.id }) ?? 0) + 1)")
                .font(.headline)
              Spacer()
              Stepper("Repeat ×\(draftSet.repeatCount)", value: $draftSet.repeatCount, in: 1...20)
                .labelsHidden()
              Text("×\(draftSet.repeatCount)")
                .font(.caption)
                .foregroundColor(.secondary)
              Button(role: .destructive) {
                sets.removeAll { $0.id == draftSet.id }
              } label: {
                Image(systemName: "minus.circle")
              }
              .buttonStyle(.borderless)
            }

            ForEach($draftSet.exercises) { $ex in
              ExerciseRowEditor(ex: $ex, library: vm.exercises, onDelete: {
                draftSet.exercises.removeAll { $0.id == ex.id }
              })
            }

            Button {
              draftSet.exercises.append(DraftExercise())
            } label: {
              Label("Add Exercise", systemImage: "plus")
            }
          }
        }

        Section {
          Button {
            sets.append(DraftSet(exercises: [DraftExercise()]))
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
      .navigationTitle(editing == nil ? "New Workout" : "Edit Workout")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") { Task { await save() } }
            .disabled(isSaving || sets.isEmpty)
        }
      }
      .onAppear(perform: bootstrap)
    }
  }

  private func bootstrap() {
    guard let w = editing else { return }
    if let d = dateFmt.date(from: w.workoutDate) { date = d }
    name = w.name ?? ""
    notes = w.notes ?? ""
    sets = w.sortedSets.map { s in
      DraftSet(
        repeatCount: s.repeatCount ?? 1,
        exercises: s.sortedExercises.map { ex in
          DraftExercise(
            exerciseId: ex.exerciseId,
            customName: ex.exercise?.name ?? "",
            difficulty: ex.difficulty ?? "",
            reps: ex.reps.map { String($0) } ?? ""
          )
        }
      )
    }
    if sets.isEmpty { sets = [DraftSet(exercises: [DraftExercise()])] }
  }

  private func applyTemplate(_ template: Workout) {
    sets = template.sortedSets.map { s in
      DraftSet(
        repeatCount: s.repeatCount ?? 1,
        exercises: s.sortedExercises.map { ex in
          DraftExercise(
            exerciseId: ex.exerciseId,
            customName: ex.exercise?.name ?? "",
            difficulty: ex.difficulty ?? "",
            reps: ex.reps.map { String($0) } ?? ""
          )
        }
      )
    }
    if let tNotes = template.notes, notes.isEmpty { notes = tNotes }
    showingTemplateSuggestions = false
  }

  private func save() async {
    isSaving = true
    error = nil
    do {
      let dateStr = dateFmt.string(from: date)
      let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
      let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
      // Ensure any free-text exercises are persisted to the library so future pickers see them.
      let resolvedSets = try await resolveCustomExercises(sets)
      if let editing {
        try await vm.updateWorkout(editing, date: dateStr, name: trimmedName, notes: trimmedNotes, sets: resolvedSets)
      } else {
        _ = try await vm.createWorkout(
          athleteId: athleteId,
          coachId: coachId,
          date: dateStr,
          name: trimmedName,
          notes: trimmedNotes,
          sets: resolvedSets
        )
      }
      dismiss()
    } catch {
      self.error = error.localizedDescription
      isSaving = false
    }
  }

  /// Any exercise with no `exerciseId` but a non-empty `customName` is created in the gym's library
  /// and its new id is substituted in. Rows left entirely blank are dropped.
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
        // Drop entirely empty rows
        if ex.exerciseId == nil && trimmed.isEmpty && ex.difficulty.isEmpty && ex.reps.isEmpty {
          continue
        }
        exs.append(ex)
      }
      out.append(DraftSet(id: s.id, repeatCount: s.repeatCount, exercises: exs))
    }
    return out.filter { !$0.exercises.isEmpty }
  }
}

// MARK: - Exercise row editor

private struct ExerciseRowEditor: View {
  @Binding var ex: DraftExercise
  let library: [Exercise]
  let onDelete: () -> Void

  var body: some View {
    VStack(spacing: 6) {
      HStack {
        Menu {
          Button("Custom…") {
            ex.exerciseId = nil
          }
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

      HStack {
        TextField("Difficulty (e.g. V4)", text: $ex.difficulty)
          .textFieldStyle(.roundedBorder)
        TextField("Reps", text: $ex.reps)
          .keyboardType(.numberPad)
          .textFieldStyle(.roundedBorder)
          .frame(maxWidth: 80)
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
}
