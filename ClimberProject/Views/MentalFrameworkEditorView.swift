import SwiftUI

struct MentalFrameworkEditorView: View {
  let athleteId: String
  let component: MentalComponent
  @ObservedObject var vm: MentalFrameworkViewModel
  @EnvironmentObject var authVM: AuthViewModel
  @Environment(\.dismiss) private var dismiss

  @State private var draft: String = ""
  @State private var showRestoreConfirm: MentalFramework?
  @State private var error: String?

  private var canEdit: Bool { authVM.currentCoach?.isHeadCoachOrAdmin == true }

  var body: some View {
    Form {
      Section("Content") {
        TextEditor(text: $draft)
          .font(.body)
          .frame(minHeight: 280)
          .disabled(!canEdit)
      }

      if let error {
        Section { Text(error).foregroundColor(.red).font(.caption) }
      }

      if !vm.history.isEmpty {
        Section("Version History") {
          ForEach(vm.history) { v in
            HStack {
              VStack(alignment: .leading, spacing: 2) {
                Text("v\(v.version)").font(.subheadline).bold()
                Text(v.createdAt.displayDate(in: authVM.gymTimezone)).font(.caption).foregroundColor(.secondary)
              }
              Spacer()
              if v.isCurrent {
                Text("Current")
                  .font(.caption2).bold()
                  .padding(.horizontal, 6).padding(.vertical, 2)
                  .background(Color.green.opacity(0.15))
                  .foregroundColor(.green)
                  .clipShape(Capsule())
              } else if canEdit {
                Button("Restore") { showRestoreConfirm = v }
                  .font(.caption)
                  .buttonStyle(.borderless)
              }
            }
            .padding(.vertical, 2)
          }
        }
      }
    }
    .navigationTitle(component.displayName)
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      if canEdit {
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") { Task { await save() } }
            .disabled(vm.isSaving || draft == (vm.current[component.rawValue]?.content ?? ""))
        }
      }
    }
    .confirmationDialog(
      "Restore this version?",
      isPresented: Binding(get: { showRestoreConfirm != nil }, set: { if !$0 { showRestoreConfirm = nil } }),
      titleVisibility: .visible,
      presenting: showRestoreConfirm
    ) { v in
      Button("Restore v\(v.version)") { Task { await restore(v) } }
      Button("Cancel", role: .cancel) {}
    } message: { v in
      Text("This will save v\(v.version)'s content as a new current version.")
    }
    .task {
      draft = vm.current[component.rawValue]?.content ?? ""
      await vm.fetchHistory(athleteId: athleteId, component: component.rawValue)
    }
  }

  private func save() async {
    guard let coachId = authVM.currentCoach?.id else { return }
    error = nil
    do {
      try await vm.save(
        athleteId: athleteId,
        component: component.rawValue,
        content: draft,
        authoredBy: coachId
      )
      dismiss()
    } catch {
      self.error = error.localizedDescription
    }
  }

  private func restore(_ v: MentalFramework) async {
    guard let coachId = authVM.currentCoach?.id else { return }
    error = nil
    do {
      try await vm.save(
        athleteId: athleteId,
        component: component.rawValue,
        content: v.content,
        authoredBy: coachId
      )
      draft = v.content
    } catch {
      self.error = error.localizedDescription
    }
  }
}
