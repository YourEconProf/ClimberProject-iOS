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
  @State private var newSetTypeName = ""
  @State private var newExerciseName = ""
  @State private var addError: String?

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
                catch { addError = error.localizedDescription }
              }
            }
          }
          HStack {
            TextField("Add set type…", text: $newSetTypeName)
            Button("Add") {
              Task { await addSetType() }
            }
            .disabled(newSetTypeName.trimmingCharacters(in: .whitespaces).isEmpty)
          }
        }

        // Exercises
        Section("Exercises") {
          ForEach(workoutVM.exercises) { ex in
            Text(ex.name)
          }
          .onDelete { indices in
            Task {
              for i in indices {
                let id = workoutVM.exercises[i].id
                do { try await workoutVM.deleteExercise(id: id) }
                catch { addError = error.localizedDescription }
              }
            }
          }
          HStack {
            TextField("Add exercise…", text: $newExerciseName)
            Button("Add") {
              Task { await addExercise() }
            }
            .disabled(newExerciseName.trimmingCharacters(in: .whitespaces).isEmpty)
          }
        }

        if let addError {
          Section { Text(addError).foregroundColor(.red).font(.caption) }
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
      .task {
        await loadGym()
        if let gymId = authVM.currentCoach?.gymId {
          await setTypeVM.fetch(gymId: gymId)
          await workoutVM.fetchExercises(gymId: gymId)
        }
      }
    }
  }

  private func addSetType() async {
    guard let gymId = authVM.currentCoach?.gymId else { return }
    addError = nil
    do {
      try await setTypeVM.add(gymId: gymId, name: newSetTypeName)
      newSetTypeName = ""
    } catch {
      addError = error.localizedDescription
    }
  }

  private func addExercise() async {
    guard let gymId = authVM.currentCoach?.gymId else { return }
    addError = nil
    do {
      _ = try await workoutVM.addExercise(gymId: gymId, name: newExerciseName)
      newExerciseName = ""
    } catch {
      addError = error.localizedDescription
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
