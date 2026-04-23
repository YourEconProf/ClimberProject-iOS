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
  @State private var gym: Gym?
  @StateObject private var setTypeVM = SetTypeViewModel()
  @StateObject private var workoutVM = WorkoutViewModel()
  @StateObject private var programVM = ProgramViewModel()
  @StateObject private var evalVM = EvaluationViewModel()

  @State private var newSetTypeName = ""
  @State private var newExerciseName = ""
  @State private var newExerciseDifficultyType = "free_text"
  @State private var newProgramName = ""
  @State private var newCriteriaName = ""
  @State private var newCriteriaUnit = ""

  @State private var setTypeError: String?
  @State private var exerciseError: String?
  @State private var programError: String?
  @State private var criteriaError: String?

  @FocusState private var focusedField: Field?

  private enum Field { case setType, exercise, program, criteria }

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
        if let gym {
          Section("Gym") {
            LabeledContent("Name", value: gym.name)
            LabeledContent("Gym Code", value: gym.code)
          }
        }

        // Programs
        Section("Programs") {
          ForEach(programVM.programs) { p in
            Text(p.name)
          }
          .onDelete { indices in
            Task {
              for i in indices {
                let id = programVM.programs[i].id
                do { try await programVM.deleteProgram(id: id) }
                catch { programError = error.localizedDescription }
              }
            }
          }
          HStack {
            TextField("Add program…", text: $newProgramName)
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
                flagToggle("MaxB", active: c.isMaxBoulder, color: .orange) {
                  Task { await evalVM.toggleFlag(.maxBoulder, for: c.id) }
                }
                flagToggle("MaxR", active: c.isMaxRope, color: .green) {
                  Task { await evalVM.toggleFlag(.maxRope, for: c.id) }
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

        // Exercises
        Section("Exercises") {
          ForEach(workoutVM.exercises) { ex in
            HStack {
              Text(ex.name)
              Spacer()
              if let badge = exerciseTypeBadge(ex.difficultyType) {
                Text(badge)
                  .font(.caption2).bold()
                  .padding(.horizontal, 6).padding(.vertical, 2)
                  .background(Color.secondary.opacity(0.15))
                  .clipShape(Capsule())
              }
            }
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
        await loadGym()
        if let gymId = authVM.currentCoach?.gymId {
          await setTypeVM.fetch(gymId: gymId)
          await workoutVM.fetchExercises(gymId: gymId)
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

  private func loadGym() async {
    guard let gymId = authVM.currentCoach?.gymId else { return }
    do {
      let gyms: [Gym] = try await SupabaseService.shared.supabase
        .from("gyms")
        .select()
        .eq("id", value: gymId)
        .limit(1)
        .execute()
        .value
      gym = gyms.first
    } catch {}
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
