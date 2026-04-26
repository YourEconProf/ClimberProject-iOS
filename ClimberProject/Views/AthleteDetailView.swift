import SwiftUI

struct AthleteDetailView: View {
  let athlete: Athlete
  @EnvironmentObject var authVM: AuthViewModel
  @StateObject private var noteVM = NoteViewModel()
  @StateObject private var evalVM = EvaluationViewModel()
  @StateObject private var goalVM = GoalViewModel()
  @StateObject private var workoutVM = WorkoutViewModel()
  @StateObject private var competitionVM = CompetitionViewModel()
  @StateObject private var programVM = ProgramViewModel()


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
      // Notes & Goals
      Section {
        if let latest = noteVM.notes.first {
          VStack(alignment: .leading, spacing: 4) {
            Text(latest.note)
              .font(.subheadline)
              .lineLimit(3)
            Text(latest.createdAt.displayDate)
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
              Text(latest.workoutDate.displayDate).font(.subheadline).bold()
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

      // Competitions
      Section("Competitions") {
        if let latest = competitionVM.results.first {
          HStack {
            VStack(alignment: .leading, spacing: 2) {
              Text(latest.location).font(.subheadline)
              Text(latest.competitionDate.displayDate)
                .font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            if let n = latest.ranking {
              Text(ordinal(n))
                .font(.caption).bold()
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(Color.blue.opacity(0.12))
                .foregroundColor(.blue)
                .clipShape(Capsule())
            }
          }
          .padding(.vertical, 2)
        }
        NavigationLink("All Competitions (\(competitionVM.results.count))") {
          AthleteCompetitionsView(athlete: athlete, vm: competitionVM)
            .environmentObject(authVM)
        }
      }

      // Evaluations
      Section("Evaluations") {
        NavigationLink("All Evaluations (\(evalVM.evaluations.count))") {
          AthleteEvaluationsView(athlete: athlete)
            .environmentObject(authVM)
        }
      }
      evalSection("FM", criteria: fmCriteria)
      evalSection("Morpho", criteria: morphoCriteria)
      evalSection("Strength", criteria: strengthCriteria)

      // Programs
      Section("Programs") {
        ForEach(programVM.enrollments) { enrollment in
          let name = programVM.programs.first { $0.id == enrollment.programId }?.name ?? "Unknown"
          VStack(alignment: .leading, spacing: 2) {
            Text(name).font(.subheadline)
            Text("Since \(enrollment.enrolledAt.displayDate)")
              .font(.caption).foregroundColor(.secondary)
          }
        }
      }

      // Personal Info
      Section("Personal Info") {
        LabeledContent("Name", value: athlete.displayName)
        if let dob = athlete.dob {
          LabeledContent("Date of Birth", value: dob.displayDate)
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
              Text("Emergency: \(contact.name)").font(.body)
              Text(contact.phone).font(.caption).foregroundColor(.secondary)
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
        group.addTask { await competitionVM.fetch(athleteId: athlete.id) }
        group.addTask { await programVM.fetchPrograms() }
        group.addTask { await programVM.fetchEnrollments(athleteId: athlete.id) }
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
                  Text(formatValue(latest.value, criteria: c))
                    .foregroundColor(.secondary)
                  Text(latest.evaluatedAt.displayDate)
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

  private func formatValue(_ value: Double?, criteria: AssessmentCriteria) -> String {
    guard let value else { return "—" }
    if criteria.isMaxBoulder, let label = GradeScale.label(for: value, type: "boulder") { return label }
    if criteria.isMaxRope,    let label = GradeScale.label(for: value, type: "rope")    { return label }
    let formatted = value.truncatingRemainder(dividingBy: 1) == 0
      ? String(format: "%.0f", value)
      : String(format: "%.1f", value)
    if let unit = criteria.unit { return "\(formatted) \(unit)" }
    return formatted
  }

  private func ordinal(_ n: Int) -> String {
    let mod100 = n % 100
    let mod10 = n % 10
    if (11...13).contains(mod100) { return "\(n)th" }
    switch mod10 {
    case 1: return "\(n)st"
    case 2: return "\(n)nd"
    case 3: return "\(n)rd"
    default: return "\(n)th"
    }
  }
}

