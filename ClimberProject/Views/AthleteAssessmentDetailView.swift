import SwiftUI

struct AthleteAssessmentDetailView: View {
  let assessment: AthleteAssessment
  let alerts: [AthleteAlert]
  @EnvironmentObject var authVM: AuthViewModel

  var body: some View {
    List {
      Section("Overview") {
        HStack(spacing: 16) {
          TrendDetailChip(label: "Readiness", value: assessment.readinessTrend)
          TrendDetailChip(label: "Fingers", value: assessment.fingerComfortTrend)
          TrendDetailChip(label: "Load", value: assessment.loadTolerance)
        }
        .padding(.vertical, 4)
        if let focus = assessment.recommendedFocus, !focus.isEmpty {
          LabeledContent("Recommended Focus", value: focus)
        }
        LabeledContent("Assessed", value: assessment.assessedAt.displayDate(in: authVM.gymTimezone))
        LabeledContent("Source", value: assessment.source.capitalized)
      }

      if !alerts.isEmpty {
        Section("Alerts") {
          ForEach(alerts) { alert in
            HStack(alignment: .top, spacing: 10) {
              Circle()
                .fill(alertColor(alert.severity))
                .frame(width: 8, height: 8)
                .padding(.top, 5)
              VStack(alignment: .leading, spacing: 2) {
                Text(alert.message)
                  .font(.subheadline)
                Text(alert.alertType.replacingOccurrences(of: "_", with: " ").capitalized)
                  .font(.caption)
                  .foregroundColor(.secondary)
              }
            }
          }
        }
      }

      if let summary = assessment.summaryMarkdown, !summary.isEmpty {
        Section("Summary") {
          Text(summary)
            .font(.body)
        }
      }
    }
    .navigationTitle("Assessment")
    .navigationBarTitleDisplayMode(.inline)
  }

  private func alertColor(_ severity: String) -> Color {
    switch severity {
    case "critical": return .red
    case "warn":     return .orange
    default:         return .blue
    }
  }
}

private struct TrendDetailChip: View {
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
    VStack(spacing: 4) {
      Image(systemName: icon)
        .font(.title3)
        .foregroundColor(color)
      Text(value?.capitalized ?? "—")
        .font(.caption).bold()
        .foregroundColor(color)
      Text(label)
        .font(.caption2)
        .foregroundColor(.secondary)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 8)
    .background(color.opacity(0.08))
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }
}
