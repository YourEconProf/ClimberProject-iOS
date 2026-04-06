import Foundation

class AuthViewModel: ObservableObject {
  @Published var isLoggedIn = false
  @Published var currentCoach: Coach?
  @Published var isLoading = false
  @Published var error: String?

  func login(email: String, password: String) async {
    // TODO: Implement Supabase authentication
    // await supabaseClient.auth.signIn(email: email, password: password)
    print("Login: \(email)")
  }

  func signup(email: String, password: String, name: String, gymCode: String) async {
    // TODO: Implement Supabase signup and coach creation
    print("Signup: \(email)")
  }

  func logout() async {
    // TODO: Implement Supabase signout
    isLoggedIn = false
    currentCoach = nil
  }

  func checkSession() async {
    // TODO: Check if user is already logged in
    // This is called on app launch
  }
}
