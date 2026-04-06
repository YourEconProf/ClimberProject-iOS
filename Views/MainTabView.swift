import SwiftUI

struct MainTabView: View {
  @EnvironmentObject var authVM: AuthViewModel
  @State private var selectedTab = 0

  var body: some View {
    TabView(selection: $selectedTab) {
      AthletesView()
        .tabItem {
          Label("Athletes", systemImage: "person.3")
        }
        .tag(0)

      EvaluationsView()
        .tabItem {
          Label("Evaluations", systemImage: "chart.bar")
        }
        .tag(1)

      SettingsView()
        .tabItem {
          Label("Settings", systemImage: "gear")
        }
        .tag(2)
    }
    .environmentObject(authVM)
  }
}

struct AthletesView: View {
  var body: some View {
    NavigationStack {
      VStack {
        Text("Athletes")
          .font(.title)
        Text("TODO: Athlete list")
      }
      .navigationTitle("Athletes")
    }
  }
}

struct EvaluationsView: View {
  var body: some View {
    NavigationStack {
      VStack {
        Text("Evaluations")
          .font(.title)
        Text("TODO: Evaluation management")
      }
      .navigationTitle("Evaluations")
    }
  }
}

struct SettingsView: View {
  @EnvironmentObject var authVM: AuthViewModel

  var body: some View {
    NavigationStack {
      VStack {
        Text("Settings")
          .font(.title)
        Text(authVM.currentCoach?.name ?? "Loading…")

        Button("Sign Out") {
          Task {
            await authVM.logout()
          }
        }
        .foregroundColor(.red)
      }
      .navigationTitle("Settings")
    }
  }
}

#Preview {
  MainTabView()
    .environmentObject(AuthViewModel())
}
