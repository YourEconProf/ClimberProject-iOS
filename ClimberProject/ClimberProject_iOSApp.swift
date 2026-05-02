import SwiftUI

@main
struct ClimberProjectApp: App {
  @StateObject var authVM = AuthViewModel()
  @StateObject var unitContext = UnitContext()
  @AppStorage("appearanceMode") private var appearanceMode: String = AppearanceMode.system.rawValue

  var body: some Scene {
    WindowGroup {
      Group {
        if authVM.isLoggedIn {
          MainTabView()
            .environmentObject(authVM)
            .environmentObject(unitContext)
        } else {
          LoginView()
            .environmentObject(authVM)
            .environmentObject(unitContext)
        }
      }
      .task { await authVM.checkSession() }
      .onChange(of: authVM.currentCoach?.id) { _, _ in
        unitContext.hydrate(from: authVM.currentCoach)
      }
      .preferredColorScheme(AppearanceMode(rawValue: appearanceMode)?.colorScheme ?? nil)
    }
  }
}
