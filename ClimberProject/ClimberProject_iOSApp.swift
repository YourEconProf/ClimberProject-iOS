import SwiftUI

@main
struct ClimberProjectApp: App {
  @StateObject var authVM = AuthViewModel()
  @AppStorage("appearanceMode") private var appearanceMode: String = AppearanceMode.system.rawValue

  var body: some Scene {
    WindowGroup {
      Group {
        if authVM.isLoggedIn {
          MainTabView()
            .environmentObject(authVM)
        } else {
          LoginView()
            .environmentObject(authVM)
        }
      }
      .task { await authVM.checkSession() }
      .preferredColorScheme(AppearanceMode(rawValue: appearanceMode)?.colorScheme ?? nil)
    }
  }
}
