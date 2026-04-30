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
  @StateObject private var assessmentVM = AthleteAssessmentViewModel()
  @StateObject private var mentalVM = MentalFrameworkViewModel()
  @State private var showReassessConfirm = false


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

      // AI Assessment
      Section("AI Assessment") {
        if assessmentVM.isLoading {
          HStack { Spacer(); ProgressView(); Spacer() }
        } else if let a = assessmentVM.latestAssessment {
          if !assessmentVM.alerts.isEmpty {
            HStack(spacing: 6) {
              ForEach(assessmentVM.criticalAlerts.prefix(3)) { alert in
                AlertBadge(message: alert.message, color: .red)
              }
              ForEach(assessmentVM.warnAlerts.prefix(3)) { alert in
                AlertBadge(message: alert.message, color: .orange)
              }
              ForEach(assessmentVM.infoAlerts.prefix(3)) { alert in
                AlertBadge(message: alert.message, color: .blue)
              }
            }
          }
          VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
              TrendChip(label: "Readiness", value: a.readinessTrend)
              TrendChip(label: "Fingers", value: a.fingerComfortTrend)
              TrendChip(label: "Load", value: a.loadTolerance)
            }
            if let focus = a.recommendedFocus, !focus.isEmpty {
              Text("Focus: \(focus)")
                .font(.caption).bold()
                .foregroundColor(.accentColor)
            }
            if let summary = a.summaryMarkdown, !summary.isEmpty {
              Text(summary)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(3)
            }
            Text(a.assessedAt.displayDate)
              .font(.caption2).foregroundColor(.secondary)
          }
          NavigationLink("Full Assessment") {
            AthleteAssessmentDetailView(assessment: a, alerts: assessmentVM.alerts)
          }
          .font(.caption)
        } else {
          Text("No assessment yet")
            .font(.caption).foregroundColor(.secondary)
        }
        Button {
          showReassessConfirm = true
        } label: {
          HStack {
            if assessmentVM.isReassessing {
              ProgressView().scaleEffect(0.75)
            }
            Text(assessmentVM.isReassessing ? "Reassessing…" : "Reassess Now")
              .font(.caption).bold()
          }
          .frame(maxWidth: .infinity)
          .padding(.vertical, 6)
          .background(Color.accentColor.opacity(0.12))
          .foregroundColor(.accentColor)
          .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.borderless)
        .disabled(assessmentVM.isReassessing)
      }

      // Mental Performance Framework (U17/U19 only)
      if isMentalFrameworkEligible(programs: programVM.programs, enrollments: programVM.enrollments) {
        Section("Mental Performance Framework") {
          ForEach(MentalComponent.allCases, id: \.self) { component in
            NavigationLink {
              MentalFrameworkEditorView(
                athleteId: athlete.id,
                component: component,
                vm: mentalVM
              )
              .environmentObject(authVM)
            } label: {
              VStack(alignment: .leading, spacing: 4) {
                Text(component.displayName).font(.subheadline)
                if let row = mentalVM.current[component.rawValue], !row.content.isEmpty {
                  Text(row.content)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                } else {
                  Text("—")
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
              }
              .padding(.vertical, 2)
            }
          }
        }
      }

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

      // Experience
      if athlete.hasExperienceData {
        Section("Experience") {
          if let yr = athlete.yearStartedClimbing {
            LabeledContent("Started Climbing", value: "\(yr)")
          }
          if let yr = athlete.yearStartedTraining {
            LabeledContent("Started Training", value: "\(yr)")
          }
          if let level = athlete.experienceLevel {
            LabeledContent("Level", value: level.replacingOccurrences(of: "_", with: " ").capitalized)
          }
          if let phv = athlete.phvStage {
            LabeledContent("PHV Stage", value: phv.capitalized)
          }
        }
      }

      // Physical
      if athlete.hasPhysicalData {
        Section("Physical") {
          if let h = athlete.heightCm {
            LabeledContent("Height", value: "\(formatDecimal(h)) cm")
          }
          if let w = athlete.weightKg {
            LabeledContent("Weight", value: "\(formatDecimal(w)) kg")
          }
          if let ws = athlete.wingspanCm {
            LabeledContent("Wingspan", value: "\(formatDecimal(ws)) cm")
          }
          if let hand = athlete.dominantHand {
            LabeledContent("Dominant Hand", value: hand.capitalized)
          }
          if let grip = athlete.gripPreference {
            LabeledContent("Grip Preference", value: grip.replacingOccurrences(of: "_", with: " ").capitalized)
          }
          if athlete.fullCrimpReady == true || athlete.campusReady == true {
            HStack(spacing: 8) {
              if athlete.fullCrimpReady == true {
                Text("Full Crimp ✓")
                  .font(.caption).bold()
                  .padding(.horizontal, 8).padding(.vertical, 4)
                  .background(Color.blue.opacity(0.12))
                  .foregroundColor(.blue)
                  .clipShape(Capsule())
              }
              if athlete.campusReady == true {
                Text("Campus Board ✓")
                  .font(.caption).bold()
                  .padding(.horizontal, 8).padding(.vertical, 4)
                  .background(Color.purple.opacity(0.12))
                  .foregroundColor(.purple)
                  .clipShape(Capsule())
              }
            }
          }
        }
      }

      // Training Maxes
      if athlete.hasTrainingMaxes {
        Section("Training Maxes") {
          if let v = athlete.maxHangKg {
            LabeledContent("Max Hang", value: "\(formatDecimal(v)) kg")
          }
          if let v = athlete.maxPullupAddedKg {
            LabeledContent("Max Pull-up Added", value: "+\(formatDecimal(v)) kg")
          }
          if let v = athlete.meEdgeMm {
            LabeledContent("Min Edge", value: "\(v) mm")
          }
          if let v = athlete.lockoffSeconds {
            LabeledContent("Lockoff", value: "\(v) s")
          }
          if let updated = athlete.maxesUpdatedAt {
            Text("Updated \(updated.displayDate)")
              .font(.caption2).foregroundColor(.secondary)
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
    .confirmationDialog("Run AI Reassessment?", isPresented: $showReassessConfirm, titleVisibility: .visible) {
      Button("Reassess Now", role: .destructive) {
        Task { try? await assessmentVM.reassess(athleteId: athlete.id) }
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("This will call the AI to generate a new assessment for \(athlete.displayName). Are you sure?")
    }

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
        group.addTask { await assessmentVM.fetchLatestAssessment(athleteId: athlete.id) }
        group.addTask { await assessmentVM.fetchAlerts(athleteId: athlete.id) }
        group.addTask { await mentalVM.fetchCurrent(athleteId: athlete.id) }
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

  private func formatDecimal(_ v: Double) -> String {
    v.truncatingRemainder(dividingBy: 1) == 0
      ? String(format: "%.0f", v)
      : String(format: "%.1f", v)
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

private struct AlertBadge: View {
  let message: String
  let color: Color
  var body: some View {
    Text(message)
      .font(.caption2).bold()
      .lineLimit(1)
      .padding(.horizontal, 6).padding(.vertical, 3)
      .background(color.opacity(0.15))
      .foregroundColor(color)
      .clipShape(Capsule())
  }
}

private struct TrendChip: View {
  let label: String
  let value: String?

  private var icon: String {
    switch value?.lowercased() {
    case "improving": return "arrow.up"
    case "declining": return "arrow.down"
    case "stable":    return "minus"
    default:          return "questionmark"
    }
  }

  private var color: Color {
    switch value?.lowercased() {
    case "improving": return .green
    case "declining": return .red
    case "stable":    return .orange
    default:          return .secondary
    }
  }

  var body: some View {
    VStack(spacing: 2) {
      Image(systemName: icon)
        .font(.caption2)
        .foregroundColor(color)
      Text(label)
        .font(.caption2)
        .foregroundColor(.secondary)
    }
    .padding(.horizontal, 8).padding(.vertical, 4)
    .background(color.opacity(0.08))
    .clipShape(RoundedRectangle(cornerRadius: 6))
  }
}

