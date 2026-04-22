import SwiftUI
import Charts

struct EvaluationHistoryView: View {
  let athlete: Athlete
  @ObservedObject var vm: EvaluationViewModel

  @State private var selectedCriteriaId: String = ""
  @State private var showTable = false

  private var criteriaWithData: [AssessmentCriteria] {
    vm.criteria.filter { !vm.history(for: $0.id).isEmpty }
  }

  private var selectedCriteria: AssessmentCriteria? {
    vm.criteria.first { $0.id == selectedCriteriaId }
  }

  private var recentHistory: [Evaluation] {
    Array(vm.history(for: selectedCriteriaId).prefix(3))
  }

  private var chartData: [Evaluation] { recentHistory.reversed() }

  // Unique dates oldest → newest (table view)
  private var tableDates: [String] {
    Set(vm.evaluations.map { String($0.evaluatedAt.prefix(10)) }).sorted()
  }

  var body: some View {
    Group {
      if showTable {
        tableView
      } else {
        listView
      }
    }
    .navigationTitle("History")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      if !vm.evaluations.isEmpty {
        ToolbarItem(placement: .secondaryAction) {
          Button {
            showTable.toggle()
          } label: {
            Image(systemName: showTable ? "chart.line.uptrend.xyaxis" : "tablecells")
          }
        }
      }
    }
    .onAppear {
      if selectedCriteriaId.isEmpty, let first = criteriaWithData.first {
        selectedCriteriaId = first.id
      }
    }
  }

  // MARK: - Chart / List View

  private var listView: some View {
    List {
      // Criteria picker
      Section {
        Picker("Criteria", selection: $selectedCriteriaId) {
          Text("Select…").tag("")
          ForEach(criteriaWithData) { c in
            Text(c.name).tag(c.id)
          }
        }
        .pickerStyle(.menu)
      }

      // Chart
      if chartData.count >= 2, let criteria = selectedCriteria {
        Section {
          Chart(chartData) { evaluation in
            LineMark(
              x: .value("Date", evaluation.evaluatedAt.displayDateShort),
              y: .value(criteria.name, evaluation.value ?? 0)
            )
            .interpolationMethod(.catmullRom)
            PointMark(
              x: .value("Date", evaluation.evaluatedAt.displayDateShort),
              y: .value(criteria.name, evaluation.value ?? 0)
            )
          }
          .frame(height: 160)
          .chartYAxisLabel(criteria.unit ?? "")
          .padding(.vertical, 8)
        }
      }

      // Recent evaluations
      if !recentHistory.isEmpty, let criteria = selectedCriteria {
        Section("Last \(recentHistory.count) Evaluations") {
          ForEach(recentHistory) { evaluation in
            HStack {
              Text(evaluation.evaluatedAt.displayDate)
                .foregroundColor(.secondary)
              Spacer()
              Text(formatValue(evaluation.value, unit: criteria.unit))
                .fontWeight(.medium)
            }
          }
        }
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
              Text(cellValue(criteriaId: c.id, date: date, unit: c.unit))
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

  private func cellValue(criteriaId: String, date: String, unit: String?) -> String {
    let matches = vm.evaluations.filter {
      $0.criteriaId == criteriaId && $0.evaluatedAt.hasPrefix(date)
    }
    guard let best = matches.max(by: { $0.evaluatedAt < $1.evaluatedAt }) else { return "—" }
    return formatValue(best.value, unit: unit)
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
