import SwiftUI

struct AddGoalView: View {
  @ObservedObject var vm: GoalViewModel
  let athleteId: String
  let coachId: String
  @Environment(\.dismiss) private var dismiss

  @State private var description = ""
  @State private var isSubmitting = false
  @State private var error: String?

  var body: some View {
    NavigationStack {
      Form {
        Section("Goal") {
          TextField("Describe the goal…", text: $description, axis: .vertical)
            .lineLimit(3...6)
        }
        if let error {
          Section {
            Text(error).foregroundColor(.red).font(.caption)
          }
        }
      }
      .navigationTitle("Add Goal")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") { Task { await submit() } }
            .disabled(description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)
        }
      }
    }
  }

  private func submit() async {
    isSubmitting = true
    error = nil
    do {
      try await vm.addGoal(
        athleteId: athleteId,
        coachId: coachId,
        description: description.trimmingCharacters(in: .whitespacesAndNewlines)
      )
      dismiss()
    } catch {
      self.error = error.localizedDescription
      isSubmitting = false
    }
  }
}
