import SwiftUI

struct AthletesView: View {
  @EnvironmentObject var authVM: AuthViewModel
  @StateObject private var vm = AthleteViewModel()
  @State private var searchText = ""
  @State private var showingAddAthlete = false

  var filtered: [Athlete] {
    if searchText.isEmpty { return vm.athletes }
    return vm.athletes.filter {
      $0.displayName.localizedCaseInsensitiveContains(searchText)
    }
  }

  var body: some View {
    NavigationStack {
      Group {
        if vm.isLoading && vm.athletes.isEmpty {
          ProgressView()
        } else if let error = vm.error {
          VStack(spacing: 12) {
            Text(error).foregroundColor(.red).multilineTextAlignment(.center)
            Button("Retry") { Task { await vm.fetchAthletes() } }
          }
          .padding()
        } else {
          List(filtered) { athlete in
            NavigationLink(destination: AthleteDetailView(athlete: athlete)) {
              AthleteRow(athlete: athlete)
            }
          }
          .searchable(text: $searchText, prompt: "Search athletes")
          .overlay {
            if vm.athletes.isEmpty {
              ContentUnavailableView("No Athletes", systemImage: "person.3")
            }
          }
        }
      }
      .navigationTitle("Athletes")
      .toolbar {
        ToolbarItem(placement: .primaryAction) {
          Button { showingAddAthlete = true } label: {
            Image(systemName: "plus")
          }
        }
      }
      .task { await vm.fetchAthletes() }
      .sheet(isPresented: $showingAddAthlete) {
        AddAthleteView(vm: vm, gymId: authVM.currentCoach?.gymId ?? "")
      }
    }
  }
}

private struct AthleteRow: View {
  let athlete: Athlete

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      HStack {
        Text(athlete.displayName)
          .font(.body)
        if let category = athlete.ageCategory {
          Text(category)
            .font(.caption)
            .foregroundColor(.secondary)
        }
      }
    }
    .opacity(athlete.isActive ? 1 : 0.5)
  }
}
