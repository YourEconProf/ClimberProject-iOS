import SwiftUI

struct LoginView: View {
  @EnvironmentObject var authVM: AuthViewModel
  @State private var email = ""
  @State private var password = ""
  @State private var showReset = false

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
            ProgressView().tint(.white)
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
          Text(error).foregroundColor(.red).font(.caption)
        }

        Button("Forgot password?") { showReset = true }
          .font(.subheadline)
          .foregroundColor(.blue)

        Spacer()

        NavigationLink("Don't have an account?") {
          SignupView().environmentObject(authVM)
        }
        .foregroundColor(.blue)
      }
      .padding(20)
      .sheet(isPresented: $showReset) {
        ForgotPasswordSheet()
          .environmentObject(authVM)
      }
    }
  }

  private func login() async {
    await authVM.login(email: email, password: password)
  }
}

private struct ForgotPasswordSheet: View {
  @EnvironmentObject var authVM: AuthViewModel
  @Environment(\.dismiss) var dismiss
  @State private var email = ""
  @State private var isSending = false
  @State private var sent = false
  @State private var error: String?

  var body: some View {
    NavigationStack {
      Form {
        Section {
          TextField("Email address", text: $email)
            .textContentType(.emailAddress)
            .keyboardType(.emailAddress)
            .textInputAutocapitalization(.never)
        } footer: {
          Text("We'll send a password reset link to this address.")
        }

        if sent {
          Section {
            Label("Reset email sent! Check your inbox.", systemImage: "envelope.badge.checkmark")
              .foregroundColor(.green)
          }
        }

        if let error {
          Section {
            Text(error).foregroundColor(.red).font(.caption)
          }
        }
      }
      .navigationTitle("Reset Password")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Send") { Task { await send() } }
            .disabled(email.trimmingCharacters(in: .whitespaces).isEmpty || isSending || sent)
        }
      }
    }
  }

  private func send() async {
    let trimmed = email.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else { return }
    isSending = true
    error = nil
    defer { isSending = false }
    do {
      try await authVM.resetPassword(email: trimmed)
      sent = true
    } catch {
      self.error = error.localizedDescription
    }
  }
}

#Preview {
  LoginView()
    .environmentObject(AuthViewModel())
}
