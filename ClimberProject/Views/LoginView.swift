import SwiftUI

struct LoginView: View {
  @EnvironmentObject var authVM: AuthViewModel
  @State private var email = ""
  @State private var password = ""

  var body: some View {
    NavigationStack {
      VStack(spacing: 20) {
        VStack(spacing: 8) {
          Text("Climber Project")
            .font(.system(size: 32, weight: .bold))
          Text("Coach Login")
            .foregroundColor(.gray)
        }
        .padding(.bottom, 24)

        VStack(spacing: 12) {
          TextField("Email", text: $email)
            .textContentType(.emailAddress)
            .keyboardType(.emailAddress)
            .textInputAutocapitalization(.never)
            .padding(12)
            .background(Color(.systemGray6))
            .cornerRadius(8)

          SecureField("Password", text: $password)
            .textContentType(.password)
            .padding(12)
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }

        Button(action: { Task { await login() } }) {
          if authVM.isLoading {
            ProgressView()
              .tint(.white)
          } else {
            Text("Sign In")
          }
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .foregroundColor(.white)
        .background(Color.blue)
        .cornerRadius(8)
        .disabled(authVM.isLoading)

        if let error = authVM.error {
          Text(error)
            .foregroundColor(.red)
            .font(.caption)
        }

        Spacer()

        NavigationLink("Don't have an account?") {
          SignupView()
            .environmentObject(authVM)
        }
        .foregroundColor(.blue)
      }
      .padding(20)
    }
  }

  private func login() async {
    await authVM.login(email: email, password: password)
  }
}

#Preview {
  LoginView()
    .environmentObject(AuthViewModel())
}
