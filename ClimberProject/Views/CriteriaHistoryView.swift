import SwiftUI

struct CriteriaHistoryView: View {
  let criteria: AssessmentCriteria
  @ObservedObject var vm: EvaluationViewModel

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
    let formatted = value.truncatingRemainder(dividingBy: 1) == 0
      ? String(format: "%.0f", value)
      : String(format: "%.1f", value)
    if let unit = criteria.unit { return "\(formatted) \(unit)" }
    return formatted
  }
}
