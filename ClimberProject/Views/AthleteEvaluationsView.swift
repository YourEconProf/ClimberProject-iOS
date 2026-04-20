import SwiftUI

enum EvaluationAddMode: Identifiable {
  case fm, morpho, strength, custom
  var id: Self { self }
}

struct AthleteEvaluationsView: View {
  let athlete: Athlete
  @EnvironmentObject var authVM: AuthViewModel
  @StateObject private var vm = EvaluationViewModel()
  @State private var addMode: EvaluationAddMode?

  var body: some View {
    Group {
      if vm.isLoading {
        ProgressView()
      } else {
        List {
          Section {
            modeRow("FM Evaluation", icon: "figure.climbing", mode: .fm)
            modeRow("Morpho Evaluation", icon: "ruler", mode: .morpho)
            modeRow("Strength Evaluation", icon: "dumbbell", mode: .strength)
            modeRow("Custom Evaluation", icon: "slider.horizontal.3", mode: .custom)
          }
        }
      }
    }
    .navigationTitle(athlete.displayName)
    .navigationBarTitleDisplayMode(.inline)
    .task { await vm.fetchCriteria() }
    .sheet(item: $addMode) { mode in
      AddEvaluationView(
        vm: vm,
        athleteId: athlete.id,
        coachId: authVM.currentCoach?.id ?? "",
        mode: mode
      )
    }
  }

  private func modeRow(_ label: String, icon: String, mode: EvaluationAddMode) -> some View {
    Button {
      addMode = mode
    } label: {
      Label(label, systemImage: icon)
    }
    .foregroundColor(.primary)
  }
}
