import SwiftUI

struct AddAthleteView: View {
  @ObservedObject var vm: AthleteViewModel
  let gymId: String
  @Environment(\.dismiss) private var dismiss

  @State private var firstName = ""
  @State private var lastName = ""
  @State private var dob = ""
  @State private var email = ""
  @State private var tshirtSize = ""
  @State private var isSubmitting = false
  @State private var error: String?

  private var canSubmit: Bool {
    !firstName.trimmingCharacters(in: .whitespaces).isEmpty &&
    !lastName.trimmingCharacters(in: .whitespaces).isEmpty
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("Required") {
          TextField("First Name", text: $firstName)
            .textInputAutocapitalization(.words)
          TextField("Last Name", text: $lastName)
            .textInputAutocapitalization(.words)
        }

        Section("Optional") {
          TextField("Email", text: $email)
            .textContentType(.emailAddress)
            .keyboardType(.emailAddress)
            .textInputAutocapitalization(.never)
          TextField("Date of Birth (YYYY-MM-DD)", text: $dob)
            .keyboardType(.numbersAndPunctuation)
          TextField("T-Shirt Size", text: $tshirtSize)
            .textInputAutocapitalization(.characters)
        }

        if let error {
          Section {
            Text(error).foregroundColor(.red).font(.caption)
          }
        }
      }
      .navigationTitle("Add Athlete")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Add") { Task { await submit() } }
            .disabled(!canSubmit || isSubmitting)
        }
      }
    }
  }

  private func submit() async {
    isSubmitting = true
    error = nil
    do {
      try await vm.createAthlete(
        firstName: firstName.trimmingCharacters(in: .whitespaces),
        lastName: lastName.trimmingCharacters(in: .whitespaces),
        gymId: gymId,
        dob: dob,
        email: email,
        tshirtSize: tshirtSize
      )
      dismiss()
    } catch {
      self.error = error.localizedDescription
      isSubmitting = false
    }
  }
}
