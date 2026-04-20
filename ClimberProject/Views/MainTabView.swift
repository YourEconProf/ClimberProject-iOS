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

      WorkoutsLibraryView()
        .tabItem {
          Label("Workouts", systemImage: "dumbbell")
        }
        .tag(2)

      SettingsView()
        .tabItem {
          Label("Settings", systemImage: "gear")
        }
        .tag(3)
    }
    .environmentObject(authVM)
  }
}


#Preview {
  MainTabView()
    .environmentObject(AuthViewModel())
}
