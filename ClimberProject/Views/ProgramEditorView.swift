import SwiftUI

struct ProgramEditorView: View {
  let program: Program
  @ObservedObject var vm: ProgramViewModel
  let templates: [Workout]

  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject var authVM: AuthViewModel

  @State private var selectedTab = 0

  // Details state
  @State private var draftName: String
  @State private var draftAgeGroup: String?
  @State private var draftDiscipline: String?
  @State private var hasStartDate: Bool
  @State private var startDate: Date
  @State private var hasEndDate: Bool
  @State private var endDate: Date
  @State private var practiceDays: Set<Int>
  @State private var hasPracticeTime: Bool
  @State private var practiceStartTime: Date
  @State private var draftDuration: Int
  @State private var draftLocation: String
  @State private var draftNotes: String
  @State private var draftOpeningTemplateId: String?

  // Plan state
  @State private var draftPlan: String
  @State private var planEditMessage = ""
  @State private var isSavingPlan = false
  @State private var planError: String?

  // Phases state
  @State private var newPhaseType: PhaseType? = nil
  @State private var newPhaseStartWeek = 1
  @State private var newPhaseEndWeek = 4
  @State private var newPhaseIsDeload = false
  @State private var isAddingPhase = false
  @State private var phaseError: String?

  // Save state
  @State private var isSaving = false
  @State private var detailsError: String?

  init(program: Program, vm: ProgramViewModel, templates: [Workout]) {
    self.program = program
    self.vm = vm
    self.templates = templates

    _draftName = State(initialValue: program.name)
    _draftAgeGroup = State(initialValue: program.ageGroup)
    _draftDiscipline = State(initialValue: program.discipline)

    let dateFmt = Self.dateFmt
    _hasStartDate = State(initialValue: program.startDate != nil)
    _startDate = State(initialValue: program.startDate.flatMap { dateFmt.date(from: $0) } ?? Date())
    _hasEndDate = State(initialValue: program.endDate != nil)
    _endDate = State(initialValue: program.endDate.flatMap { dateFmt.date(from: $0) }
      ?? Calendar.current.date(byAdding: .day, value: 90, to: Date()) ?? Date())

    _practiceDays = State(initialValue: Set(program.practiceDays ?? []))
    _hasPracticeTime = State(initialValue: program.practiceStartTime != nil)
    let timeFmt = Self.timeFmt
    _practiceStartTime = State(initialValue: program.practiceStartTime.flatMap { timeFmt.date(from: $0) }
      ?? Calendar.current.date(from: DateComponents(hour: 16, minute: 0)) ?? Date())
    _draftDuration = State(initialValue: program.practiceDurationMinutes ?? 90)
    _draftLocation = State(initialValue: program.practiceLocation ?? "")
    _draftNotes = State(initialValue: program.notes ?? "")
    _draftOpeningTemplateId = State(initialValue: program.openingTemplateId)
    _draftPlan = State(initialValue: program.planMarkdown ?? "")
  }

  var body: some View {
    NavigationStack {
      VStack(spacing: 0) {
        Picker("Tab", selection: $selectedTab) {
          Text("Details").tag(0)
          Text("Plan").tag(1)
          Text("Phases").tag(2)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
        .padding(.vertical, 8)

        Divider()

        switch selectedTab {
        case 1:  planTab
        case 2:  phasesTab
        default: detailsTab
        }
      }
      .navigationTitle(program.name)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
        if selectedTab == 0 {
          ToolbarItem(placement: .confirmationAction) {
            Button(isSaving ? "Saving…" : "Save") { Task { await saveDetails() } }
              .disabled(isSaving || draftName.trimmingCharacters(in: .whitespaces).isEmpty)
          }
        }
      }
      .task {
        async let a: () = vm.fetchPhases(programId: program.id)
        async let b: () = vm.fetchPlanVersions(programId: program.id)
        _ = await (a, b)
      }
    }
  }

  // MARK: - Details Tab

  private var detailsTab: some View {
    Form {
      Section("Program") {
        TextField("Name", text: $draftName)
        Picker("Age Group", selection: $draftAgeGroup) {
          Text("Any").tag(nil as String?)
          ForEach(["U11", "U13", "U15", "U17", "U19", "Open"], id: \.self) { g in
            Text(g).tag(g as String?)
          }
        }
        Picker("Discipline", selection: $draftDiscipline) {
          Text("Any").tag(nil as String?)
          Text("Boulder").tag("boulder" as String?)
          Text("Rope").tag("rope" as String?)
          Text("Both").tag("both" as String?)
        }
      }

      Section("Schedule") {
        Toggle("Has Start Date", isOn: $hasStartDate)
        if hasStartDate {
          DatePicker("Start", selection: $startDate, displayedComponents: .date)
        }
        Toggle("Has End Date", isOn: $hasEndDate)
        if hasEndDate {
          DatePicker("End", selection: $endDate, displayedComponents: .date)
        }

        VStack(alignment: .leading, spacing: 8) {
          Text("Practice Days").font(.footnote).foregroundColor(.secondary)
          HStack(spacing: 6) {
            ForEach([7, 1, 2, 3, 4, 5, 6], id: \.self) { day in
              let label = [1: "M", 2: "T", 3: "W", 4: "T", 5: "F", 6: "S", 7: "S"][day]!
              let active = practiceDays.contains(day)
              Button(label) {
                if active { practiceDays.remove(day) } else { practiceDays.insert(day) }
              }
              .font(.caption).bold()
              .frame(width: 34, height: 34)
              .background(active ? Color.accentColor : Color.secondary.opacity(0.15))
              .foregroundColor(active ? .white : .secondary)
              .clipShape(Circle())
              .buttonStyle(.borderless)
            }
          }
        }
        .padding(.vertical, 4)

        Toggle("Practice Time", isOn: $hasPracticeTime)
        if hasPracticeTime {
          DatePicker("Start Time", selection: $practiceStartTime, displayedComponents: .hourAndMinute)
          Stepper("Duration: \(draftDuration) min", value: $draftDuration, in: 30...300, step: 15)
        }
      }

      Section("Location & Notes") {
        TextField("Location", text: $draftLocation)
        TextField("Notes", text: $draftNotes, axis: .vertical)
          .lineLimit(3...8)
      }

      if !templates.isEmpty {
        Section("Opening Block Template") {
          Picker("Template", selection: $draftOpeningTemplateId) {
            Text("None").tag(nil as String?)
            ForEach(templates) { t in
              Text(t.displayTitle).tag(t.id as String?)
            }
          }
          .labelsHidden()
          .pickerStyle(.wheel)
        }
      }

      if let detailsError {
        Section {
          Text(detailsError).foregroundColor(.red).font(.caption)
        }
      }
    }
  }

  // MARK: - Plan Tab

  private var planTab: some View {
    Form {
      Section("Training Plan") {
        TextEditor(text: $draftPlan)
          .font(.system(.caption, design: .monospaced))
          .frame(height: 320)
      }

      Section {
        TextField("Edit message (optional)", text: $planEditMessage)
        Button(isSavingPlan ? "Saving…" : "Save Version") {
          Task { await savePlanVersion() }
        }
        .disabled(isSavingPlan || draftPlan.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        if let planError {
          Text(planError).foregroundColor(.red).font(.caption)
        }
      }

      if !vm.planVersions.isEmpty {
        Section("Version History") {
          ForEach(vm.planVersions) { version in
            HStack(alignment: .top) {
              VStack(alignment: .leading, spacing: 2) {
                Text("v\(version.versionNum)")
                  .font(.caption).bold()
                Text(version.createdAt.displayDate(in: authVM.gymTimezone))
                  .font(.caption2).foregroundColor(.secondary)
                if let msg = version.editMessage, !msg.isEmpty {
                  Text(msg).font(.caption2).foregroundColor(.secondary)
                }
              }
              Spacer()
              Button("Restore") {
                Task { await restorePlanVersion(version) }
              }
              .font(.caption)
              .buttonStyle(.borderless)
              .disabled(isSavingPlan)
            }
            .padding(.vertical, 2)
          }
        }
      }
    }
  }

  // MARK: - Phases Tab

  private var phasesTab: some View {
    Form {
      if !vm.phases.isEmpty {
        Section("Phases") {
          ForEach(vm.phases) { phase in
            VStack(alignment: .leading, spacing: 2) {
              HStack {
                Text(phase.displayLabel).font(.subheadline)
                Spacer()
                if let pt = phase.phaseType, let type = PhaseType(rawValue: pt) {
                  Text(type.label)
                    .font(.caption2).bold()
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color.indigo.opacity(0.15))
                    .foregroundColor(.indigo)
                    .clipShape(Capsule())
                }
                if phase.isDeload {
                  Text("Deload")
                    .font(.caption2).bold()
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color.orange.opacity(0.15))
                    .foregroundColor(.orange)
                    .clipShape(Capsule())
                }
              }
              Text("Weeks \(phase.startWeek)–\(phase.endWeek)")
                .font(.caption).foregroundColor(.secondary)
            }
            .padding(.vertical, 2)
          }
          .onDelete { indices in
            Task {
              for i in indices {
                do { try await vm.deletePhase(id: vm.phases[i].id) }
                catch { phaseError = error.localizedDescription }
              }
            }
          }
        }
      }

      Section("Add Phase") {
        Picker("Phase Type", selection: $newPhaseType) {
          Text("Select phase type…").tag(nil as PhaseType?)
          ForEach(PhaseType.allCases) { type in
            Text(type.label).tag(type as PhaseType?)
          }
        }
        Stepper("Start week: \(newPhaseStartWeek)", value: $newPhaseStartWeek, in: 1...52)
        Stepper("End week: \(newPhaseEndWeek)", value: $newPhaseEndWeek, in: 1...52)
        Toggle("Deload block", isOn: $newPhaseIsDeload)
        Button(isAddingPhase ? "Adding…" : "Add Phase") {
          Task { await addPhase() }
        }
        .disabled(isAddingPhase || newPhaseType == nil)
        if let phaseError {
          Text(phaseError).foregroundColor(.red).font(.caption)
        }
      }
    }
  }

  // MARK: - Actions

  private func saveDetails() async {
    isSaving = true
    detailsError = nil
    defer { isSaving = false }
    do {
      try await vm.updateProgram(
        id: program.id,
        name: draftName.trimmingCharacters(in: .whitespaces),
        ageGroup: draftAgeGroup,
        discipline: draftDiscipline,
        startDate: hasStartDate ? Self.dateFmt.string(from: startDate) : nil,
        endDate: hasEndDate ? Self.dateFmt.string(from: endDate) : nil,
        practiceDays: practiceDays.isEmpty ? nil : practiceDays.sorted(),
        practiceStartTime: hasPracticeTime ? Self.timeFmt.string(from: practiceStartTime) : nil,
        practiceDurationMinutes: hasPracticeTime ? draftDuration : nil,
        practiceLocation: draftLocation.isEmpty ? nil : draftLocation,
        notes: draftNotes.isEmpty ? nil : draftNotes,
        openingTemplateId: draftOpeningTemplateId
      )
      dismiss()
    } catch {
      detailsError = error.localizedDescription
    }
  }

  private func savePlanVersion() async {
    guard let coachId = authVM.currentCoach?.id else { return }
    isSavingPlan = true
    planError = nil
    defer { isSavingPlan = false }
    do {
      try await vm.savePlanVersion(
        programId: program.id,
        planMarkdown: draftPlan,
        editMessage: planEditMessage.isEmpty ? nil : planEditMessage,
        editedBy: coachId
      )
      planEditMessage = ""
    } catch {
      planError = error.localizedDescription
    }
  }

  private func restorePlanVersion(_ version: ProgramPlanVersion) async {
    guard let coachId = authVM.currentCoach?.id else { return }
    isSavingPlan = true
    planError = nil
    defer { isSavingPlan = false }
    do {
      try await vm.restorePlanVersion(version, editedBy: coachId)
      draftPlan = version.planMarkdown
    } catch {
      planError = error.localizedDescription
    }
  }

  private func addPhase() async {
    guard let phaseType = newPhaseType else { return }
    isAddingPhase = true
    phaseError = nil
    defer { isAddingPhase = false }
    do {
      try await vm.addPhase(
        programId: program.id,
        phaseType: phaseType,
        startWeek: newPhaseStartWeek,
        endWeek: newPhaseEndWeek,
        isDeload: newPhaseIsDeload
      )
      newPhaseType = nil
      newPhaseStartWeek = 1
      newPhaseEndWeek = 4
      newPhaseIsDeload = false
    } catch {
      phaseError = error.localizedDescription
    }
  }

  // MARK: - Formatters

  private static let dateFmt: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    f.locale = Locale(identifier: "en_US_POSIX")
    return f
  }()

  private static let timeFmt: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "HH:mm:ss"
    f.locale = Locale(identifier: "en_US_POSIX")
    return f
  }()
}
