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
      .task { await loadGym() }
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
