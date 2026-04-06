import SwiftUI

@main
struct ClimberProjectApp: App {
  @StateObject var authVM = AuthViewModel()

  var body: some Scene {
    WindowGroup {
      if authVM.isLoggedIn {
        MainTabView()
          .environmentObject(authVM)
      } else {
        LoginView()
          .environmentObject(authVM)
      }
    }
  }
}
