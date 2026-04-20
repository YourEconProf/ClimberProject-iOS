import SwiftUI

struct AthleteGoalsView: View {
  let athlete: Athlete
  @ObservedObject var vm: GoalViewModel
  @EnvironmentObject var authVM: AuthViewModel
  @State private var showingAdd = false

  var body: some View {
    List {
      if !vm.activeGoals.isEmpty {
        Section("Active") {
          ForEach(vm.activeGoals) { goal in
            GoalRow(goal: goal, vm: vm)
          }
        }
      }

      if !vm.resolvedGoals.isEmpty {
        Section("Resolved") {
          ForEach(vm.resolvedGoals) { goal in
            GoalRow(goal: goal, vm: vm)
          }
        }
      }
    }
    .overlay {
      if vm.goals.isEmpty {
        ContentUnavailableView("No Goals", systemImage: "target")
      }
    }
    .navigationTitle("Goals")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        Button { showingAdd = true } label: {
          Image(systemName: "plus")
        }
      }
    }
    .sheet(isPresented: $showingAdd) {
      AddGoalView(vm: vm, athleteId: athlete.id, coachId: authVM.currentCoach?.id ?? "")
    }
  }
}

private struct GoalRow: View {
  let goal: Goal
  @ObservedObject var vm: GoalViewModel

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(goal.description)
        .font(.body)
      HStack {
        Text(String(goal.setAt.prefix(10)))
          .font(.caption)
          .foregroundColor(.secondary)
        Spacer()
        statusBadge
      }
    }
    .padding(.vertical, 2)
    .swipeActions(edge: .leading) {
      if goal.status != .achieved {
        Button {
          Task { try? await vm.updateStatus(goal, status: .achieved) }
        } label: {
          Label("Achieved", systemImage: "checkmark.circle")
        }
        .tint(.green)
      }
      if goal.status != .dropped {
        Button {
          Task { try? await vm.updateStatus(goal, status: .dropped) }
        } label: {
          Label("Drop", systemImage: "xmark.circle")
        }
        .tint(.orange)
      }
    }
    .swipeActions(edge: .trailing) {
      Button(role: .destructive) {
        Task { try? await vm.deleteGoal(id: goal.id) }
      } label: {
        Label("Delete", systemImage: "trash")
      }
    }
  }

  private var statusBadge: some View {
    Text(goal.status.rawValue.capitalized)
      .font(.caption)
      .padding(.horizontal, 8)
      .padding(.vertical, 2)
      .background(statusColor.opacity(0.15))
      .foregroundColor(statusColor)
      .clipShape(Capsule())
  }

  private var statusColor: Color {
    switch goal.status {
    case .active:   return .blue
    case .achieved: return .green
    case .dropped:  return .orange
    }
  }
}
