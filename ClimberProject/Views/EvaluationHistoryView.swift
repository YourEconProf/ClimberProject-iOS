import SwiftUI
import Charts

struct EvaluationHistoryView: View {
  let athlete: Athlete
  @ObservedObject var vm: EvaluationViewModel

  @State private var selectedCriteriaId: String = ""

  private var criteriaWithData: [AssessmentCriteria] {
    vm.criteria.filter { !vm.history(for: $0.id).isEmpty }
  }

  private var selectedCriteria: AssessmentCriteria? {
    vm.criteria.first { $0.id == selectedCriteriaId }
  }

  private var recentHistory: [Evaluation] {
    Array(vm.history(for: selectedCriteriaId).prefix(3))
  }

  // Oldest first for the chart so the line goes left→right
  private var chartData: [Evaluation] {
    recentHistory.reversed()
  }

  var body: some View {
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
              x: .value("Date", evaluation.evaluatedAt.prefix(10).description),
              y: .value(criteria.name, evaluation.value ?? 0)
            )
            .interpolationMethod(.catmullRom)
            PointMark(
              x: .value("Date", evaluation.evaluatedAt.prefix(10).description),
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
              Text(String(evaluation.evaluatedAt.prefix(10)))
                .foregroundColor(.secondary)
              Spacer()
              Text(formatValue(evaluation.value, unit: criteria.unit))
                .fontWeight(.medium)
            }
          }
        }
      }
    }
    .navigationTitle("History")
    .navigationBarTitleDisplayMode(.inline)
    .onAppear {
      if selectedCriteriaId.isEmpty, let first = criteriaWithData.first {
        selectedCriteriaId = first.id
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
