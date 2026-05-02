import SwiftUI

enum EvaluationAddMode: Identifiable {
  case fm, morpho, strength, custom
  var id: Self { self }
}

struct AthleteEvaluationsView: View {
  let athlete: Athlete
  @EnvironmentObject var authVM: AuthViewModel
  @EnvironmentObject var unitContext: UnitContext
  @StateObject private var vm = EvaluationViewModel()
  @State private var addMode: EvaluationAddMode?
  @State private var showTable = false

  // Unique dates for table columns, sorted oldest → newest
  private var tableDates: [String] {
    let dates = Set(vm.evaluations.map { String($0.evaluatedAt.prefix(10)) })
    return dates.sorted()
  }

  // Criteria that have at least one evaluation
  private var criteriaWithData: [AssessmentCriteria] {
    vm.criteria.filter { c in vm.evaluations.contains { $0.criteriaId == c.id } }
  }

  var body: some View {
    Group {
      if vm.isLoading && vm.evaluations.isEmpty && vm.criteria.isEmpty {
        ProgressView()
      } else if showTable {
        tableView
      } else {
        listView
      }
    }
    .navigationTitle("Evaluations")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      if !vm.evaluations.isEmpty {
        ToolbarItem(placement: .secondaryAction) {
          Button {
            showTable.toggle()
          } label: {
            Image(systemName: showTable ? "list.bullet" : "tablecells")
          }
        }
      }
    }
    .task {
      await withTaskGroup(of: Void.self) { g in
        g.addTask { await vm.fetchCriteria() }
        g.addTask { await vm.fetchEvaluations(athleteId: athlete.id) }
      }
    }
    .sheet(item: $addMode) { mode in
      AddEvaluationView(
        vm: vm,
        athleteId: athlete.id,
        coachId: authVM.currentCoach?.id ?? "",
        mode: mode
      )
    }
  }

  // MARK: - List View

  private var listView: some View {
    List {
      Section {
        modeRow("FM Evaluation", icon: "figure.climbing", mode: .fm)
        modeRow("Morpho Evaluation", icon: "ruler", mode: .morpho)
        modeRow("Strength Evaluation", icon: "dumbbell", mode: .strength)
        modeRow("Custom Evaluation", icon: "slider.horizontal.3", mode: .custom)
      }

      if !vm.evaluations.isEmpty {
        Section("History") {
          ForEach(vm.evaluations) { evaluation in
            let c = vm.criteria.first { $0.id == evaluation.criteriaId }
            HStack {
              VStack(alignment: .leading, spacing: 2) {
                Text(c?.name ?? "Unknown").font(.subheadline)
                Text(evaluation.evaluatedAt.displayDate)
                  .font(.caption).foregroundColor(.secondary)
              }
              Spacer()
              Text(formatValue(evaluation.value, criteria: c))
                .font(.subheadline).foregroundColor(.secondary)
            }
          }
        }
      }
    }
    .overlay {
      if vm.evaluations.isEmpty && !vm.isLoading {
        ContentUnavailableView("No Evaluations", systemImage: "chart.line.uptrend.xyaxis",
          description: Text("Tap an evaluation type above to record the first entry."))
      }
    }
  }

  // MARK: - Table View

  private var tableView: some View {
    ScrollView([.horizontal, .vertical]) {
      VStack(alignment: .leading, spacing: 0) {
        // Header row
        HStack(spacing: 0) {
          Text("Criteria")
            .font(.caption).fontWeight(.semibold)
            .frame(width: 130, alignment: .leading)
            .padding(.horizontal, 8).padding(.vertical, 6)
            .background(Color(UIColor.secondarySystemBackground))
          ForEach(tableDates, id: \.self) { date in
            Text(date.displayDateShort)
              .font(.caption).fontWeight(.semibold)
              .frame(width: 80, alignment: .center)
              .padding(.horizontal, 4).padding(.vertical, 6)
              .background(Color(UIColor.secondarySystemBackground))
          }
        }
        Divider()

        // Data rows
        ForEach(Array(criteriaWithData.enumerated()), id: \.element.id) { idx, c in
          HStack(spacing: 0) {
            Text(c.name)
              .font(.caption)
              .frame(width: 130, alignment: .leading)
              .padding(.horizontal, 8).padding(.vertical, 6)
              .background(idx % 2 == 1 ? Color(UIColor.tertiarySystemBackground) : Color.clear)
            ForEach(tableDates, id: \.self) { date in
              Text(cellValue(criteriaId: c.id, date: date, criteria: c))
                .font(.caption).foregroundColor(.secondary)
                .frame(width: 80, alignment: .center)
                .padding(.horizontal, 4).padding(.vertical, 6)
                .background(idx % 2 == 1 ? Color(UIColor.tertiarySystemBackground) : Color.clear)
            }
          }
          Divider().padding(.leading, 130)
        }
      }
      .padding(.vertical, 8)
    }
  }

  // MARK: - Helpers

  private func modeRow(_ label: String, icon: String, mode: EvaluationAddMode) -> some View {
    Button { addMode = mode } label: {
      Label(label, systemImage: icon)
    }
    .foregroundColor(.primary)
  }

  private func cellValue(criteriaId: String, date: String, criteria: AssessmentCriteria) -> String {
    let matches = vm.evaluations.filter {
      $0.criteriaId == criteriaId && $0.evaluatedAt.hasPrefix(date)
    }
    guard let best = matches.max(by: { $0.evaluatedAt < $1.evaluatedAt }) else { return "—" }
    return formatValue(best.value, criteria: criteria)
  }

  private func formatValue(_ value: Double?, criteria: AssessmentCriteria?) -> String {
    guard let value else { return "—" }
    if let c = criteria {
      if c.isMaxBoulder, let label = GradeScale.label(for: value, type: "boulder") { return label }
      if c.isMaxRope,    let label = GradeScale.label(for: value, type: "rope")    { return label }
    }
    let displayed = criteria.map { Units.displayValue(value, criterion: $0, system: unitContext.system) } ?? value
    let s = displayed.truncatingRemainder(dividingBy: 1) == 0
      ? String(format: "%.0f", displayed)
      : String(format: "%.1f", displayed)
    if let c = criteria {
      let suffix = Units.unitSuffix(for: c, system: unitContext.system)
      if !suffix.isEmpty { return "\(s) \(suffix)" }
    }
    return s
  }
}
