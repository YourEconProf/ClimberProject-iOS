import SwiftUI

struct CheckinModalView: View {
  let athlete: Athlete
  @ObservedObject var vm: AthleteCheckinViewModel
  @Environment(\.dismiss) private var dismiss

  @State private var checkinDate = Date()
  @State private var readinessScore: Int? = nil
  @State private var fingerComfortScore: Int? = nil
  @State private var sleepHours: Double = 8
  @State private var sleepSet = false
  @State private var mood: String? = nil
  @State private var notes = ""
  @State private var isSubmitting = false
  @State private var error: String?

  private let moods = ["engaged", "excited", "flat", "withdrawn", "frustrated"]
  private let moodLabels = [
    "engaged": "😊 Engaged",
    "excited": "🔥 Excited",
    "flat": "😐 Flat",
    "withdrawn": "😶 Withdrawn",
    "frustrated": "😤 Frustrated"
  ]

  var body: some View {
    NavigationStack {
      Form {
        Section {
          DatePicker("Date", selection: $checkinDate, displayedComponents: .date)
        }

        if !athlete.isYouthRestrictedCheckin {
          Section("Readiness (1–10)") {
            ScorePickerRow(selected: $readinessScore, color: readinessColor)
          }

          Section("Finger Comfort (1–10)") {
            ScorePickerRow(selected: $fingerComfortScore, color: fingerColor)
          }

          Section("Sleep") {
            Toggle("Record sleep hours", isOn: $sleepSet)
            if sleepSet {
              Stepper(
                value: $sleepHours,
                in: 0...14,
                step: 0.5
              ) {
                Text("\(sleepHours, specifier: "%.1f") hrs")
              }
            }
          }
        }

        Section("Mood") {
          LazyVGrid(columns: [GridItem(.adaptive(minimum: 130))], spacing: 8) {
            ForEach(moods, id: \.self) { m in
              Button {
                mood = mood == m ? nil : m
              } label: {
                Text(moodLabels[m] ?? m)
                  .font(.subheadline)
                  .frame(maxWidth: .infinity)
                  .padding(.vertical, 8)
                  .background(mood == m ? Color.accentColor.opacity(0.2) : Color(UIColor.secondarySystemBackground))
                  .foregroundColor(mood == m ? .accentColor : .primary)
                  .clipShape(RoundedRectangle(cornerRadius: 8))
              }
              .buttonStyle(.plain)
            }
          }
          .padding(.vertical, 4)
        }

        Section("Notes") {
          TextField("How did the session feel?", text: $notes, axis: .vertical)
            .lineLimit(3...6)
        }

        if let error {
          Section {
            Text(error).foregroundColor(.red).font(.caption)
          }
        }
      }
      .navigationTitle("Check In — \(athlete.firstName)")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") { Task { await submit() } }
            .disabled(isSubmitting)
        }
      }
    }
  }

  private var readinessColor: Color {
    guard let s = readinessScore else { return .accentColor }
    if s <= 3 { return .red }
    if s <= 6 { return .orange }
    return .green
  }

  private var fingerColor: Color {
    guard let s = fingerComfortScore else { return .accentColor }
    if s <= 3 { return .red }
    if s <= 6 { return .orange }
    return .green
  }

  private func submit() async {
    isSubmitting = true
    error = nil
    let fmt = DateFormatter()
    fmt.dateFormat = "yyyy-MM-dd"
    fmt.locale = Locale(identifier: "en_US_POSIX")
    let dateStr = fmt.string(from: checkinDate)
    do {
      try await vm.addCheckin(
        athleteId: athlete.id,
        date: dateStr,
        readinessScore: athlete.isYouthRestrictedCheckin ? nil : readinessScore,
        fingerComfortScore: athlete.isYouthRestrictedCheckin ? nil : fingerComfortScore,
        sleepHours: (athlete.isYouthRestrictedCheckin || !sleepSet) ? nil : sleepHours,
        mood: mood,
        notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes.trimmingCharacters(in: .whitespacesAndNewlines)
      )
      dismiss()
    } catch {
      self.error = error.localizedDescription
      isSubmitting = false
    }
  }
}

private struct ScorePickerRow: View {
  @Binding var selected: Int?
  let color: Color

  var body: some View {
    HStack(spacing: 4) {
      ForEach(1...10, id: \.self) { n in
        Button {
          selected = selected == n ? nil : n
        } label: {
          Text("\(n)")
            .font(.caption).bold()
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(selected == n ? color.opacity(0.25) : Color(UIColor.secondarySystemBackground))
            .foregroundColor(selected == n ? color : .secondary)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
      }
    }
  }
}
