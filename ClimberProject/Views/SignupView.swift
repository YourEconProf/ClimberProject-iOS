import SwiftUI

struct SignupView: View {
  @Environment(\.dismiss) var dismiss
  @EnvironmentObject var authVM: AuthViewModel
  @State private var email = ""
  @State private var password = ""
  @State private var name = ""
  @State private var gymCode = ""

  var body: some View {
    VStack(spacing: 20) {
      VStack(spacing: 8) {
        Text("Create Account")
          .font(.system(size: 24, weight: .bold))
        Text("New coaches")
          .foregroundColor(.gray)
      }
      .padding(.bottom, 24)

      VStack(spacing: 12) {
        TextField("Full Name", text: $name)
          .padding(12)
          .background(Color(.systemGray6))
          .cornerRadius(8)

        TextField("Email", text: $email)
          .textContentType(.emailAddress)
          .keyboardType(.emailAddress)
          .textInputAutocapitalization(.never)
          .padding(12)
          .background(Color(.systemGray6))
          .cornerRadius(8)

        SecureField("Password", text: $password)
          .textContentType(.newPassword)
          .padding(12)
          .background(Color(.systemGray6))
          .cornerRadius(8)

        TextField("Gym Code", text: $gymCode)
          .textInputAutocapitalization(.characters)
          .padding(12)
          .background(Color(.systemGray6))
          .cornerRadius(8)
      }

      Button(action: { Task { await signup() } }) {
        if authVM.isLoading {
          ProgressView()
            .tint(.white)
        } else {
          Text("Sign Up")
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
    }
    .padding(20)
    .navigationBarBackButtonHidden(false)
  }

  private func signup() async {
    await authVM.signup(email: email, password: password, name: name, gymCode: gymCode)
  }
}

#Preview {
  SignupView()
    .environmentObject(AuthViewModel())
}
