import SwiftUI

struct CriteriaHistoryView: View {
  let criteria: AssessmentCriteria
  @ObservedObject var vm: EvaluationViewModel
  @EnvironmentObject var unitContext: UnitContext

  var history: [Evaluation] { vm.history(for: criteria.id) }

  var body: some View {
    List {
      if history.isEmpty {
        ContentUnavailableView("No History", systemImage: "chart.line.uptrend.xyaxis")
      } else {
        ForEach(history) { evaluation in
          HStack {
            Text(evaluation.evaluatedAt.displayDate)
            Spacer()
            Text(valueString(evaluation.value))
              .foregroundColor(.secondary)
          }
          if let notes = evaluation.notes, !notes.isEmpty {
            Text(notes)
              .font(.caption)
              .foregroundColor(.secondary)
          }
        }
      }
    }
    .navigationTitle(criteria.name)
    .navigationBarTitleDisplayMode(.inline)
  }

  private func valueString(_ value: Double?) -> String {
    guard let value else { return "—" }
    if criteria.isMaxBoulder, let label = GradeScale.label(for: value, type: "boulder") { return label }
    if criteria.isMaxRope,    let label = GradeScale.label(for: value, type: "rope")    { return label }
    let displayed = Units.displayValue(value, criterion: criteria, system: unitContext.system)
    let formatted = displayed.truncatingRemainder(dividingBy: 1) == 0
      ? String(format: "%.0f", displayed)
      : String(format: "%.1f", displayed)
    let suffix = Units.unitSuffix(for: criteria, system: unitContext.system)
    if !suffix.isEmpty { return "\(formatted) \(suffix)" }
    return formatted
  }
}
