import SwiftUI

struct AthleteDetailView: View {
  let athlete: Athlete
  @StateObject private var noteVM = NoteViewModel()
  @StateObject private var evalVM = EvaluationViewModel()
  @StateObject private var goalVM = GoalViewModel()
  @StateObject private var workoutVM = WorkoutViewModel()

  var fmCriteria: [AssessmentCriteria] {
    evalVM.criteria.filter { $0.isFm && evalVM.latestValue(for: $0.id) != nil }
  }
  var morphoCriteria: [AssessmentCriteria] {
    evalVM.criteria.filter { $0.isMorpho && evalVM.latestValue(for: $0.id) != nil }
  }
  var strengthCriteria: [AssessmentCriteria] {
    evalVM.criteria.filter { $0.isStrength && evalVM.latestValue(for: $0.id) != nil }
  }

  var body: some View {
    List {
      // Notes
      Section {
        if let latest = noteVM.notes.first {
          VStack(alignment: .leading, spacing: 4) {
            Text(latest.note)
              .font(.subheadline)
              .lineLimit(3)
            Text(String(latest.createdAt.prefix(10)))
              .font(.caption)
              .foregroundColor(.secondary)
          }
          .padding(.vertical, 2)
        }
        NavigationLink("All Notes (\(noteVM.notes.count))") {
          AthleteNotesView(athlete: athlete, vm: noteVM)
        }
        NavigationLink("Goals (\(goalVM.activeGoals.count) active)") {
          AthleteGoalsView(athlete: athlete, vm: goalVM)
        }
      }

      // Workouts
      Section {
        if let latest = workoutVM.workouts.first {
          VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
              Text(latest.workoutDate).font(.subheadline).bold()
              if let name = latest.name {
                Text(": \(name)")
                  .font(.subheadline)
                  .foregroundColor(.secondary)
                  .lineLimit(1)
              }
            }
            Text("\(latest.sortedSets.count) sets • \(latest.totalExerciseCount) exercises")
              .font(.caption)
              .foregroundColor(.secondary)
          }
          .padding(.vertical, 2)
        }
        NavigationLink("Workout History (\(workoutVM.workouts.count))") {
          AthleteWorkoutHistoryView(athlete: athlete, vm: workoutVM)
        }
      }

      // Evaluations
      evalSection("FM", criteria: fmCriteria)
      evalSection("Morpho", criteria: morphoCriteria)
      evalSection("Strength", criteria: strengthCriteria)

      // Personal Info
      Section("Personal Info") {
        LabeledContent("Name", value: athlete.displayName)
        if let dob = athlete.dob {
          LabeledContent("Date of Birth", value: dob)
        }
        if let email = athlete.email {
          LabeledContent("Email", value: email)
        }
        if let size = athlete.tshirtSize {
          LabeledContent("T-Shirt Size", value: size)
        }
        LabeledContent("Status", value: athlete.isActive ? "Active" : "Inactive")

        if let contacts = athlete.emergencyContacts, !contacts.isEmpty {
          ForEach(contacts, id: \.phone) { contact in
            VStack(alignment: .leading, spacing: 2) {
              Text("Emergency: \(contact.name)")
                .font(.body)
              Text(contact.phone)
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .padding(.vertical, 2)
          }
        }
      }
    }
    .navigationTitle(athlete.displayName)
    .navigationBarTitleDisplayMode(.inline)
    .task {
      await withTaskGroup(of: Void.self) { group in
        group.addTask { await noteVM.fetchNotes(athleteId: athlete.id) }
        group.addTask { await evalVM.fetchCriteria() }
        group.addTask { await evalVM.fetchEvaluations(athleteId: athlete.id) }
        group.addTask { await goalVM.fetchGoals(athleteId: athlete.id) }
        group.addTask { await workoutVM.fetchWorkouts(athleteId: athlete.id) }
      }
    }
  }

  @ViewBuilder
  private func evalSection(_ title: String, criteria: [AssessmentCriteria]) -> some View {
    if !criteria.isEmpty {
      Section(title) {
        ForEach(criteria) { c in
          NavigationLink(destination: CriteriaHistoryView(criteria: c, vm: evalVM)) {
            HStack {
              Text(c.name)
              Spacer()
              if let latest = evalVM.latestValue(for: c.id) {
                VStack(alignment: .trailing, spacing: 2) {
                  Text(formatValue(latest.value, unit: c.unit))
                    .foregroundColor(.secondary)
                  Text(String(latest.evaluatedAt.prefix(10)))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                }
              }
            }
          }
        }
      }
    }
  }

  private func formatValue(_ value: Double?, unit: String?) -> String {
    guard let value else { return "—" }
    let formatted = value.truncatingRemainder(dividingBy: 1) == 0
      ? String(format: "%.0f", value)
      : String(format: "%.1f", value)
    if let unit { return "\(formatted) \(unit)" }
    return formatted
  }
}
