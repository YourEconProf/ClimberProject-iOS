import SwiftUI

struct AthletesView: View {
  @EnvironmentObject var authVM: AuthViewModel
  @StateObject private var vm = AthleteViewModel()
  @StateObject private var alertVM = AlertDashboardViewModel()
  @State private var searchText = ""
  @State private var showingAddAthlete = false

  var filtered: [Athlete] {
    let active = vm.athletes.filter { $0.isActive }
    if searchText.isEmpty { return active }
    return active.filter { $0.displayName.localizedCaseInsensitiveContains(searchText) }
  }

  private func athlete(for alert: AthleteAlertWithAthlete) -> Athlete? {
    vm.athletes.first { $0.id == alert.athleteId }
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
          List {
            if !alertVM.alerts.isEmpty {
              Section("Active Alerts") {
                ForEach(alertVM.alerts) { alert in
                  if let a = athlete(for: alert) {
                    NavigationLink(destination: AthleteDetailView(athlete: a)) {
                      DashboardAlertRow(
                        alert: alert,
                        onAck: { Task { try? await alertVM.acknowledge(alertId: alert.id, coachId: authVM.currentCoach?.id ?? "") } },
                        onResolve: { Task { try? await alertVM.resolve(alertId: alert.id) } }
                      )
                    }
                  }
                }
              }
            }
            Section {
              ForEach(filtered) { athlete in
                NavigationLink(destination: AthleteDetailView(athlete: athlete)) {
                  AthleteRow(athlete: athlete)
                }
              }
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
      .task {
        await withTaskGroup(of: Void.self) { group in
          group.addTask { await vm.fetchAthletes() }
          group.addTask { await alertVM.fetchAll() }
        }
      }
      .sheet(isPresented: $showingAddAthlete) {
        AddAthleteView(vm: vm, gymId: authVM.currentCoach?.gymId ?? "")
      }
    }
  }
}

private struct DashboardAlertRow: View {
  let alert: AthleteAlertWithAthlete
  let onAck: () -> Void
  let onResolve: () -> Void

  private var color: Color {
    switch alert.severity {
    case "critical": return .red
    case "warn":     return .orange
    default:         return .blue
    }
  }

  private var dimmed: Bool { alert.acknowledgedAt != nil }

  var body: some View {
    HStack(spacing: 8) {
      Circle().fill(color).frame(width: 8, height: 8)
      VStack(alignment: .leading, spacing: 2) {
        HStack(spacing: 4) {
          Text(alert.alertType.replacingOccurrences(of: "_", with: " ").capitalized)
            .font(.caption).bold()
            .foregroundColor(color)
          if let athlete = alert.athletes {
            Text("· \(athlete.displayName)")
              .font(.caption)
              .foregroundColor(.secondary)
          }
        }
        Text(alert.message)
          .font(.caption)
          .foregroundColor(.secondary)
          .lineLimit(2)
      }
      Spacer()
      if !dimmed {
        Button(action: onAck) {
          Image(systemName: "checkmark.circle").foregroundColor(.secondary)
        }
        .buttonStyle(.borderless)
      }
      Button(action: onResolve) {
        Image(systemName: "xmark.circle").foregroundColor(.secondary)
      }
      .buttonStyle(.borderless)
    }
    .padding(.vertical, 2)
    .opacity(dimmed ? 0.5 : 1)
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
