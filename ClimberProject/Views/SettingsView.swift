import SwiftUI
import Supabase

enum AppearanceMode: String, CaseIterable {
  case system = "Match Phone"
  case light  = "Light"
  case dark   = "Dark"

  var colorScheme: ColorScheme? {
    switch self {
    case .system: return nil
    case .light:  return .light
    case .dark:   return .dark
    }
  }
}

struct SettingsView: View {
  @EnvironmentObject var authVM: AuthViewModel
  @AppStorage("appearanceMode") private var appearanceMode: String = AppearanceMode.system.rawValue
  @State private var timezoneError: String?
  @StateObject private var setTypeVM = SetTypeViewModel()
  @StateObject private var workoutVM = WorkoutViewModel()
  @StateObject private var programVM = ProgramViewModel()
  @StateObject private var evalVM = EvaluationViewModel()
  @StateObject private var tagVM = TagViewModel()

  @State private var newSetTypeName = ""
  @State private var newExerciseName = ""
  @State private var newExerciseDifficultyType = "free_text"
  @State private var newCriteriaName = ""
  @State private var newCriteriaUnit = ""
  @State private var newProgramName = ""

  @State private var newTagName = ""
  @State private var tagError: String?
  @State private var setTypeError: String?
  @State private var exerciseError: String?
  @State private var criteriaError: String?
  @State private var programError: String?

  @State private var editingProgram: Program?
  @State private var generatingProgramId: String?
  @State private var confirmGenerateProgram: Program?
  @State private var generateResult: GeneratePracticeResult?
  @State private var generateError: String?

  @FocusState private var focusedField: Field?

  private enum Field { case tag, setType, exercise, criteria, program }

  private var selectedMode: AppearanceMode {
    AppearanceMode(rawValue: appearanceMode) ?? .system
  }

  var body: some View {
    NavigationStack {
      List {
        // Coach profile
        if let coach = authVM.currentCoach {
          Section("Coach Profile") {
            LabeledContent("Name", value: coach.name)
            LabeledContent("Email", value: coach.email)
            HStack {
              Text("Role")
              Spacer()
              Text(roleName(coach.role))
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(roleColor(coach.role).opacity(0.15))
                .foregroundColor(roleColor(coach.role))
                .clipShape(Capsule())
            }
          }
        }

        // Gym info
        if let gym = authVM.currentGym {
          Section("Gym") {
            LabeledContent("Name", value: gym.name)
            LabeledContent("Gym Code", value: gym.code)
            if authVM.currentCoach?.role == "admin" {
              Picker("Timezone", selection: Binding(
                get: { gym.timezone },
                set: { newValue in
                  Task {
                    timezoneError = nil
                    do { try await authVM.updateGymTimezone(newValue) }
                    catch { timezoneError = error.localizedDescription }
                  }
                }
              )) {
                ForEach(TimeZone.knownTimeZoneIdentifiers, id: \.self) { tz in
                  Text(tz).tag(tz)
                }
              }
            } else {
              LabeledContent("Timezone", value: gym.timezone)
            }
            if let timezoneError {
              Text(timezoneError).foregroundColor(.red).font(.caption)
            }
          }
        }

        // Programs
        Section("Programs") {
          ForEach(programVM.programs) { p in
            ProgramSettingsRow(
              program: p,
              isGenerating: generatingProgramId == p.id,
              onEdit: { editingProgram = p },
              onGenerate: {
                confirmGenerateProgram = p
              }
            )
          }
          .onDelete { indices in
            Task {
              for i in indices {
                let id = programVM.programs[i].id
                try? await programVM.deleteProgram(id: id)
              }
            }
          }
          HStack {
            TextField("New program name…", text: $newProgramName)
              .focused($focusedField, equals: .program)
              .submitLabel(.done)
              .onSubmit { Task { await addProgram() } }
            Button("Add") { Task { await addProgram() } }
              .disabled(newProgramName.trimmingCharacters(in: .whitespaces).isEmpty)
          }
          if let programError {
            Text(programError).foregroundColor(.red).font(.caption)
          }
        }
        .sheet(item: $editingProgram) { p in
          ProgramEditorView(
            program: p,
            vm: programVM,
            templates: workoutVM.namedWorkouts.filter { $0.isTemplate }
          )
        }
        .sheet(item: $generateResult) { result in
          GenerateResultSheet(result: result)
        }
        .confirmationDialog(
          "Generate Practice?",
          isPresented: Binding(get: { confirmGenerateProgram != nil }, set: { if !$0 { confirmGenerateProgram = nil } }),
          titleVisibility: .visible
        ) {
          Button("Generate", role: .destructive) {
            guard let p = confirmGenerateProgram else { return }
            confirmGenerateProgram = nil
            Task {
              generatingProgramId = p.id
              generateError = nil
              do {
                generateResult = try await programVM.generatePractice(programId: p.id)
              } catch {
                generateError = error.localizedDescription
              }
              generatingProgramId = nil
            }
          }
          Button("Cancel", role: .cancel) { confirmGenerateProgram = nil }
        } message: {
          Text("This will use AI to generate today's practice workouts for \(confirmGenerateProgram?.name ?? "this program"). Are you sure?")
        }
        .alert("Generate Failed", isPresented: Binding(
          get: { generateError != nil },
          set: { if !$0 { generateError = nil } }
        )) {
          Button("OK") { generateError = nil }
        } message: {
          Text(generateError ?? "")
        }

        // Assessment Criteria
        Section("Assessment Criteria") {
          ForEach(evalVM.criteria) { c in
            VStack(alignment: .leading, spacing: 6) {
              HStack {
                Text(c.name).font(.subheadline)
                if let unit = c.unit {
                  Text(unit)
                    .font(.caption2)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.15))
                    .clipShape(Capsule())
                }
                Spacer()
              }
              HStack(spacing: 8) {
                flagToggle("FM", active: c.isFm, color: .accentColor) {
                  Task { await evalVM.toggleFlag(.fm, for: c.id) }
                }
                flagToggle("Morpho", active: c.isMorpho, color: .accentColor) {
                  Task { await evalVM.toggleFlag(.morpho, for: c.id) }
                }
                flagToggle("Strength", active: c.isStrength, color: .accentColor) {
                  Task { await evalVM.toggleFlag(.strength, for: c.id) }
                }
              }
            }
            .padding(.vertical, 2)
          }
          .onDelete { indices in
            Task {
              for i in indices {
                let id = evalVM.criteria[i].id
                do { try await evalVM.deleteCriteria(id: id) }
                catch { criteriaError = error.localizedDescription }
              }
            }
          }
          VStack(alignment: .leading, spacing: 8) {
            HStack {
              TextField("Criteria name…", text: $newCriteriaName)
                .focused($focusedField, equals: .criteria)
                .submitLabel(.next)
              TextField("Unit (optional)", text: $newCriteriaUnit)
                .frame(maxWidth: 100)
            }
            Button("Add Criteria") { Task { await addCriteria() } }
              .disabled(newCriteriaName.trimmingCharacters(in: .whitespaces).isEmpty)
          }
          .padding(.vertical, 4)
          if let criteriaError {
            Text(criteriaError).foregroundColor(.red).font(.caption)
          }
        }

        // Set Types
        Section("Set Types") {
          ForEach(setTypeVM.setTypes) { st in
            Text(st.name)
          }
          .onDelete { indices in
            Task {
              for i in indices {
                let id = setTypeVM.setTypes[i].id
                do { try await setTypeVM.delete(id: id) }
                catch { setTypeError = error.localizedDescription }
              }
            }
          }
          HStack {
            TextField("Add set type…", text: $newSetTypeName)
              .focused($focusedField, equals: .setType)
              .submitLabel(.done)
              .onSubmit { Task { await addSetType() } }
            Button("Add") { Task { await addSetType() } }
              .disabled(newSetTypeName.trimmingCharacters(in: .whitespaces).isEmpty)
          }
          if let setTypeError {
            Text(setTypeError).foregroundColor(.red).font(.caption)
          }
        }

        // Tags
        Section("Tags") {
          ForEach(tagVM.tags) { tag in
            Text(tag.name)
          }
          .onDelete { indices in
            Task {
              for i in indices {
                do { try await tagVM.deleteTag(id: tagVM.tags[i].id) }
                catch { tagError = error.localizedDescription }
              }
            }
          }
          HStack {
            TextField("Add tag…", text: $newTagName)
              .focused($focusedField, equals: .tag)
              .submitLabel(.done)
              .onSubmit { Task { await addTag() } }
            Button("Add") { Task { await addTag() } }
              .disabled(newTagName.trimmingCharacters(in: .whitespaces).isEmpty)
          }
          if let tagError {
            Text(tagError).foregroundColor(.red).font(.caption)
          }
        }

        // Exercises
        Section("Exercises") {
          ForEach(workoutVM.exercises) { ex in
            ExerciseSettingsRow(
              exercise: ex,
              exerciseTags: tagVM.tagsForExercise(ex.id),
              allTags: tagVM.tags,
              badge: exerciseTypeBadge(ex.difficultyType),
              onToggleTag: { tagId in
                Task { try? await tagVM.toggleExerciseTag(exerciseId: ex.id, tagId: tagId) }
              }
            )
          }
          .onDelete { indices in
            Task {
              for i in indices {
                let id = workoutVM.exercises[i].id
                do { try await workoutVM.deleteExercise(id: id) }
                catch { exerciseError = error.localizedDescription }
              }
            }
          }
          VStack(alignment: .leading, spacing: 8) {
            HStack {
              TextField("Add exercise…", text: $newExerciseName)
                .focused($focusedField, equals: .exercise)
                .submitLabel(.done)
                .onSubmit { Task { await addExercise() } }
              Button("Add") { Task { await addExercise() } }
                .disabled(newExerciseName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            Picker("Type", selection: $newExerciseDifficultyType) {
              Text("Free Text").tag("free_text")
              Text("Boulder").tag("boulder")
              Text("Rope").tag("rope")
              Text("Weight").tag("weight")
            }
            .pickerStyle(.segmented)
          }
          .padding(.vertical, 4)
          if let exerciseError {
            Text(exerciseError).foregroundColor(.red).font(.caption)
          }
        }

        // Appearance
        Section("Appearance") {
          Picker("Mode", selection: $appearanceMode) {
            ForEach(AppearanceMode.allCases, id: \.rawValue) { mode in
              Text(mode.rawValue).tag(mode.rawValue)
            }
          }
          .pickerStyle(.segmented)
        }

        // Sign out
        Section {
          Button(role: .destructive) {
            Task { await authVM.logout() }
          } label: {
            HStack {
              Spacer()
              Text("Sign Out")
              Spacer()
            }
          }
        }
      }
      .navigationTitle("Settings")
      .toolbar {
        ToolbarItemGroup(placement: .keyboard) {
          Spacer()
          Button("Done") { focusedField = nil }
        }
      }
      .task {
        if let gymId = authVM.currentCoach?.gymId {
          await setTypeVM.fetch(gymId: gymId)
          await workoutVM.fetchExercises(gymId: gymId)
          await workoutVM.fetchNamedWorkouts()
          await tagVM.fetch(gymId: gymId)
        }
        await programVM.fetchPrograms()
        await evalVM.fetchCriteria()
      }
    }
  }

  @ViewBuilder
  private func flagToggle(_ label: String, active: Bool, color: Color = .accentColor, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Text(label)
        .font(.caption2).bold()
        .padding(.horizontal, 8).padding(.vertical, 3)
        .background(active ? color.opacity(0.2) : Color.secondary.opacity(0.1))
        .foregroundColor(active ? color : .secondary)
        .clipShape(Capsule())
    }
    .buttonStyle(.borderless)
  }

  private func addProgram() async {
    guard let gymId = authVM.currentCoach?.gymId else { return }
    let trimmed = newProgramName.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else { return }
    programError = nil
    do {
      try await programVM.addProgram(gymId: gymId, name: trimmed)
      newProgramName = ""
      focusedField = nil
    } catch {
      programError = error.localizedDescription
    }
  }

  private func addTag() async {
    guard let gymId = authVM.currentCoach?.gymId else { return }
    let trimmed = newTagName.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else { return }
    tagError = nil
    do {
      try await tagVM.addTag(gymId: gymId, name: trimmed)
      newTagName = ""
      focusedField = nil
    } catch {
      tagError = error.localizedDescription
    }
  }


  private func addCriteria() async {
    guard let gymId = authVM.currentCoach?.gymId else { return }
    let trimmed = newCriteriaName.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else { return }
    criteriaError = nil
    do {
      try await evalVM.addCriteria(gymId: gymId, name: trimmed,
                                   unit: newCriteriaUnit.trimmingCharacters(in: .whitespaces))
      newCriteriaName = ""
      newCriteriaUnit = ""
      focusedField = nil
    } catch {
      criteriaError = error.localizedDescription
    }
  }

  private func addSetType() async {
    guard let gymId = authVM.currentCoach?.gymId else { return }
    let trimmed = newSetTypeName.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else { return }
    setTypeError = nil
    do {
      try await setTypeVM.add(gymId: gymId, name: trimmed)
      newSetTypeName = ""
      focusedField = nil
    } catch {
      setTypeError = error.localizedDescription
    }
  }

  private func addExercise() async {
    guard let gymId = authVM.currentCoach?.gymId else { return }
    let trimmed = newExerciseName.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else { return }
    exerciseError = nil
    do {
      _ = try await workoutVM.addExercise(gymId: gymId, name: trimmed, difficultyType: newExerciseDifficultyType)
      newExerciseName = ""
      newExerciseDifficultyType = "free_text"
      focusedField = nil
    } catch {
      exerciseError = error.localizedDescription
    }
  }

  private func exerciseTypeBadge(_ type: String) -> String? {
    switch type {
    case "boulder": return "Boulder"
    case "rope":    return "Rope"
    case "weight":  return "Weight"
    default:        return nil
    }
  }

  private func roleName(_ role: String) -> String {
    switch role {
    case "head_coach": return "Head Coach"
    case "admin":      return "Admin"
    default:           return "Coach"
    }
  }

  private func roleColor(_ role: String) -> Color {
    switch role {
    case "head_coach": return .blue
    case "admin":      return .purple
    default:           return .secondary
    }
  }
}

private struct GenerateResultSheet: View {
  let result: GeneratePracticeResult
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      List {
        Section {
          HStack {
            Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
            Text("\(result.generated) workout\(result.generated == 1 ? "" : "s") generated")
              .font(.subheadline).bold()
          }
        }
        if let skipped = result.skipped, !skipped.isEmpty {
          Section("Skipped (\(skipped.count))") {
            ForEach(skipped) { item in
              VStack(alignment: .leading, spacing: 2) {
                if let name = item.name { Text(name).font(.subheadline) }
                Text(item.reason).font(.caption).foregroundColor(.secondary)
              }
            }
          }
        }
        if let blocked = result.blocked, !blocked.isEmpty {
          Section("Blocked (\(blocked.count))") {
            ForEach(blocked) { item in
              VStack(alignment: .leading, spacing: 2) {
                if let name = item.name { Text(name).font(.subheadline) }
                Text(item.reason).font(.caption).foregroundColor(.red)
              }
            }
          }
        }
      }
      .navigationTitle("Generate Practice")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") { dismiss() }
        }
      }
    }
  }
}

private struct ProgramSettingsRow: View {
  let program: Program
  let isGenerating: Bool
  let onEdit: () -> Void
  let onGenerate: () -> Void

  var body: some View {
    HStack {
      VStack(alignment: .leading, spacing: 2) {
        Text(program.name).font(.subheadline)
        HStack(spacing: 6) {
          if let ag = program.ageGroup {
            Text(ag)
              .font(.caption2).bold()
              .padding(.horizontal, 6).padding(.vertical, 2)
              .background(Color.blue.opacity(0.12))
              .foregroundColor(.blue)
              .clipShape(Capsule())
          }
          if let disc = program.discipline {
            Text(disc.capitalized)
              .font(.caption2)
              .padding(.horizontal, 6).padding(.vertical, 2)
              .background(Color.secondary.opacity(0.12))
              .foregroundColor(.secondary)
              .clipShape(Capsule())
          }
          if !program.practiceDayNames.isEmpty {
            Text(program.practiceDayNames)
              .font(.caption2)
              .foregroundColor(.secondary)
          }
        }
      }
      Spacer()
      if isGenerating {
        ProgressView().scaleEffect(0.8)
      } else {
        Button { onGenerate() } label: {
          Image(systemName: "bolt.fill").foregroundColor(.orange)
        }
        .buttonStyle(.borderless)
      }
      Button { onEdit() } label: {
        Image(systemName: "pencil").foregroundColor(.accentColor)
      }
      .buttonStyle(.borderless)
    }
    .padding(.vertical, 2)
  }
}

private struct ExerciseSettingsRow: View {
  let exercise: Exercise
  let exerciseTags: [Tag]
  let allTags: [Tag]
  let badge: String?
  let onToggleTag: (String) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack {
        Text(exercise.name)
        Spacer()
        if let badge {
          Text(badge)
            .font(.caption2).bold()
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(Color.secondary.opacity(0.15))
            .clipShape(Capsule())
        }
      }
      if !allTags.isEmpty {
        HStack(spacing: 6) {
          ForEach(exerciseTags) { tag in
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
                Label(tag.name, systemImage: exerciseTags.contains(tag) ? "checkmark" : "")
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
    }
    .padding(.vertical, 2)
  }
}
