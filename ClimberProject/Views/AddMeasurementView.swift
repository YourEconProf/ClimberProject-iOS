import SwiftUI

struct AddMeasurementView: View {
  let athlete: Athlete
  @ObservedObject var vm: MeasurementViewModel
  @EnvironmentObject var authVM: AuthViewModel
  @Environment(\.dismiss) var dismiss

  @State private var date = Date()
  @State private var useImperial = false
  @State private var notes = ""
  @State private var isSaving = false
  @State private var error: String?

  // Anthropometrics
  @State private var height = ""
  @State private var wingspan = ""
  @State private var reach = ""
  @State private var weight = ""
  @State private var fingerLength = ""

  // Flexibility
  @State private var sitAndReach = ""
  @State private var shoulderFlex = ""

  // Strength
  @State private var gripL = ""
  @State private var gripR = ""
  @State private var hangboard = ""
  @State private var pullups = ""

  private var apeIndexDisplay: String {
    guard let h = Double(height), let w = Double(wingspan), h > 0, w > 0 else { return "—" }
    let val = w - h
    return String(format: "%.1f %@", val, useImperial ? "in" : "cm")
  }

  var body: some View {
    NavigationStack {
      Form {
        Section {
          DatePicker("Date", selection: $date, displayedComponents: .date)
          Toggle("Use Imperial Units", isOn: $useImperial.animation())
        }

        Section("Anthropometrics") {
          metricField("Height",          binding: $height,       unit: useImperial ? "in" : "cm")
          metricField("Wingspan",        binding: $wingspan,     unit: useImperial ? "in" : "cm")
          metricField("Standing Reach",  binding: $reach,        unit: useImperial ? "in" : "cm")
          LabeledContent("Ape Index") {
            Text(apeIndexDisplay).foregroundColor(.secondary)
          }
          metricField("Weight",          binding: $weight,       unit: useImperial ? "lbs" : "kg")
          metricField("Finger Length",   binding: $fingerLength, unit: useImperial ? "in" : "mm")
        }

        Section("Flexibility") {
          metricField("Sit & Reach",     binding: $sitAndReach,  unit: useImperial ? "in" : "cm")
          metricField("Shoulder Flex",   binding: $shoulderFlex, unit: useImperial ? "in" : "cm")
        }

        Section("Strength") {
          metricField("Grip Left",       binding: $gripL,        unit: useImperial ? "lbs" : "kg")
          metricField("Grip Right",      binding: $gripR,        unit: useImperial ? "lbs" : "kg")
          metricField("Max Hangboard",   binding: $hangboard,    unit: useImperial ? "lbs" : "kg")
          LabeledContent("Max Pull-ups") {
            TextField("0", text: $pullups)
              .keyboardType(.numberPad)
              .multilineTextAlignment(.trailing)
          }
        }

        Section("Notes") {
          TextEditor(text: $notes)
            .frame(minHeight: 80)
        }

        if let error {
          Section {
            Text(error).foregroundColor(.red).font(.caption)
          }
        }
      }
      .navigationTitle("Add Measurement")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") { Task { await save() } }
            .disabled(isSaving)
        }
      }
    }
  }

  @ViewBuilder
  private func metricField(_ label: String, binding: Binding<String>, unit: String) -> some View {
    LabeledContent(label) {
      HStack(spacing: 4) {
        TextField("0", text: binding)
          .keyboardType(.decimalPad)
          .multilineTextAlignment(.trailing)
        Text(unit).foregroundColor(.secondary).frame(width: 28, alignment: .leading)
      }
    }
  }

  private func toCm(_ s: String) -> Double? {
    guard let v = Double(s), v > 0 else { return nil }
    return useImperial ? v * 2.54 : v
  }

  private func toKg(_ s: String) -> Double? {
    guard let v = Double(s), v > 0 else { return nil }
    return useImperial ? v * 0.453592 : v
  }

  private func toMm(_ s: String) -> Double? {
    guard let v = Double(s), v > 0 else { return nil }
    return useImperial ? v * 25.4 : v
  }

  private func save() async {
    guard let coachId = authVM.currentCoach?.id else { return }
    isSaving = true
    error = nil
    defer { isSaving = false }

    let fmt = DateFormatter()
    fmt.dateFormat = "yyyy-MM-dd"
    fmt.locale = Locale(identifier: "en_US_POSIX")

    do {
      try await vm.add(
        athleteId: athlete.id,
        coachId: coachId,
        measuredAt: fmt.string(from: date),
        heightCm: toCm(height),
        wingspanCm: toCm(wingspan),
        reachCm: toCm(reach),
        weightKg: toKg(weight),
        fingerLengthMm: toMm(fingerLength),
        sitAndReachCm: toCm(sitAndReach),
        shoulderFlexCm: toCm(shoulderFlex),
        gripStrengthLKg: toKg(gripL),
        gripStrengthRKg: toKg(gripR),
        maxHangboardKg: toKg(hangboard),
        pullupMax: Int(pullups),
        notes: notes.isEmpty ? nil : notes
      )
      dismiss()
    } catch {
      self.error = error.localizedDescription
    }
  }
}
