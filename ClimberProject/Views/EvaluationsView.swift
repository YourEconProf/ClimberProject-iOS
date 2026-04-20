import SwiftUI

struct EvaluationsView: View {
  @EnvironmentObject var authVM: AuthViewModel
  @StateObject private var athleteVM = AthleteViewModel()
  @StateObject private var evalVM = EvaluationViewModel()

  @State private var searchText = ""
  @State private var selectedAthlete: Athlete?
  @State private var addMode: EvaluationAddMode?

  var suggestions: [Athlete] {
    guard !searchText.isEmpty, selectedAthlete == nil else { return [] }
    return athleteVM.athletes.filter {
      $0.displayName.localizedCaseInsensitiveContains(searchText)
    }
  }

  var body: some View {
    NavigationStack {
      List {
        // Athlete search field
        Section {
          athleteSearchBar
        }

        // Evaluation type links — only after athlete is selected
        if let athlete = selectedAthlete {
          Section {
            modeRow("FM Evaluation", icon: "figure.climbing", mode: .fm)
            modeRow("Morpho Evaluation", icon: "ruler", mode: .morpho)
            modeRow("Strength Evaluation", icon: "dumbbell", mode: .strength)
            modeRow("Custom Evaluation", icon: "slider.horizontal.3", mode: .custom)
          }
          Section {
            NavigationLink(destination: EvaluationHistoryView(athlete: athlete, vm: evalVM)) {
              Label("History", systemImage: "chart.line.uptrend.xyaxis")
            }
          }
        }

        // Autocomplete suggestions
        if !suggestions.isEmpty {
          Section("Athletes") {
            ForEach(suggestions) { athlete in
              Button {
                select(athlete)
              } label: {
                Text(athlete.displayName)
                  .foregroundColor(.primary)
                  .opacity(athlete.isActive ? 1 : 0.5)
              }
            }
          }
        }
      }
      .navigationTitle("Evaluations")
      .sheet(item: $addMode) { mode in
        AddEvaluationView(
          vm: evalVM,
          athleteId: selectedAthlete?.id ?? "",
          coachId: authVM.currentCoach?.id ?? "",
          mode: mode
        )
      }
      .task {
        await withTaskGroup(of: Void.self) { group in
          group.addTask { await athleteVM.fetchAthletes() }
          group.addTask { await evalVM.fetchCriteria() }
        }
      }
    }
  }

  // MARK: - Athlete Search Bar

  @ViewBuilder
  private var athleteSearchBar: some View {
    HStack {
      Image(systemName: "magnifyingglass").foregroundColor(.secondary)
      if let athlete = selectedAthlete {
        Text(athlete.displayName)
          .frame(maxWidth: .infinity, alignment: .leading)
        Button {
          selectedAthlete = nil
          searchText = ""
          evalVM.clearEvaluations()
        } label: {
          Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
        }
      } else {
        TextField("Athlete name…", text: $searchText)
          .autocorrectionDisabled()
          .textInputAutocapitalization(.words)
      }
    }
  }

  // MARK: - Mode Rows

  private func modeRow(_ label: String, icon: String, mode: EvaluationAddMode) -> some View {
    Button {
      guard selectedAthlete != nil else { return }
      addMode = mode
    } label: {
      Label(label, systemImage: icon)
        .foregroundColor(selectedAthlete == nil ? .secondary : .primary)
    }
  }

  // MARK: - Helpers

  private func select(_ athlete: Athlete) {
    selectedAthlete = athlete
    searchText = ""
    Task { await evalVM.fetchEvaluations(athleteId: athlete.id) }
  }
}
