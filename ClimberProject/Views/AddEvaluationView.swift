import SwiftUI

struct AddEvaluationView: View {
  @ObservedObject var vm: EvaluationViewModel
  let athleteId: String
  let coachId: String
  let mode: EvaluationAddMode
  @Environment(\.dismiss) private var dismiss

  @State private var evaluatedAt = Date()
  @State private var values: [String: String] = [:]  // criteriaId -> text input
  @State private var customEntries: [CustomEntry] = [CustomEntry()]
  @State private var isSubmitting = false
  @State private var error: String?

  private var visibleCriteria: [AssessmentCriteria] {
    switch mode {
    case .fm:       return vm.criteria.filter(\.isFm)
    case .morpho:   return vm.criteria.filter(\.isMorpho)
    case .strength: return vm.criteria.filter(\.isStrength)
    case .custom:   return []
    }
  }

  private var title: String {
    switch mode {
    case .fm:       return "Add FM"
    case .morpho:   return "Add Morpho"
    case .strength: return "Add Strength"
    case .custom:   return "Add Custom"
    }
  }

  private var hasAnyValue: Bool {
    switch mode {
    case .fm, .morpho, .strength:
      return values.values.contains { !$0.isEmpty }
    case .custom:
      return customEntries.contains { !$0.criteriaId.isEmpty && !$0.value.isEmpty }
    }
  }

  var body: some View {
    NavigationStack {
      Form {
        Section {
          DatePicker("Date", selection: $evaluatedAt, displayedComponents: .date)
        }

        if mode == .custom {
          customSection
        } else {
          presetSection
        }

        if let error {
          Section {
            Text(error).foregroundColor(.red).font(.caption)
          }
        }
      }
      .navigationTitle(title)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") { Task { await submit() } }
            .disabled(!hasAnyValue || isSubmitting)
        }
      }
    }
  }

  // MARK: - Preset (FM / Morpho / Strength)

  @ViewBuilder
  private var presetSection: some View {
    if !visibleCriteria.isEmpty {
      Section {
        ForEach(visibleCriteria) { c in
          HStack {
            Text(c.name)
            Spacer()
            TextField("—", text: Binding(
              get: { values[c.id] ?? "" },
              set: { values[c.id] = $0 }
            ))
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.trailing)
            .frame(width: 80)
            if let unit = c.unit {
              Text(unit)
                .foregroundColor(.secondary)
                .font(.caption)
                .frame(width: 30, alignment: .leading)
            }
          }
        }
      }
    }
  }

  // MARK: - Custom (individual pickers)

  @ViewBuilder
  private var customSection: some View {
    Section {
      ForEach($customEntries) { $entry in
        HStack {
          Picker("", selection: $entry.criteriaId) {
            Text("Select…").tag("")
            ForEach(vm.criteria) { c in
              Text(c.name).tag(c.id)
            }
          }
          .labelsHidden()
          .frame(maxWidth: .infinity, alignment: .leading)

          TextField("Value", text: $entry.value)
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.trailing)
            .frame(width: 70)

          if let unit = vm.criteria.first(where: { $0.id == entry.criteriaId })?.unit {
            Text(unit)
              .foregroundColor(.secondary)
              .font(.caption)
              .frame(width: 30, alignment: .leading)
          }
        }
      }
      .onDelete { customEntries.remove(atOffsets: $0) }

      Button {
        customEntries.append(CustomEntry())
      } label: {
        Label("Add Criteria", systemImage: "plus")
      }
    }
  }

  // MARK: - Submit

  private func submit() async {
    isSubmitting = true
    error = nil

    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withFullDate]
    let dateString = formatter.string(from: evaluatedAt)

    var inserts: [EvaluationInsert] = []

    switch mode {
    case .fm, .morpho, .strength:
      inserts = values.compactMap { criteriaId, text in
        guard let value = Double(text), !text.isEmpty else { return nil }
        return EvaluationInsert(
          athleteId: athleteId, coachId: coachId,
          criteriaId: criteriaId, evaluatedAt: dateString,
          value: value, notes: nil
        )
      }
    case .custom:
      inserts = customEntries.compactMap { entry in
        guard !entry.criteriaId.isEmpty, let value = Double(entry.value) else { return nil }
        return EvaluationInsert(
          athleteId: athleteId, coachId: coachId,
          criteriaId: entry.criteriaId, evaluatedAt: dateString,
          value: value, notes: nil
        )
      }
    }

    guard !inserts.isEmpty else {
      error = "Enter at least one value."
      isSubmitting = false
      return
    }

    do {
      try await vm.addEvaluations(inserts)
      dismiss()
    } catch {
      self.error = error.localizedDescription
      isSubmitting = false
    }
  }
}

private struct CustomEntry: Identifiable {
  let id = UUID()
  var criteriaId: String = ""
  var value: String = ""
}
