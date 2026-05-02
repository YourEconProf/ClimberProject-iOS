import SwiftUI

struct AddEvaluationView: View {
  @ObservedObject var vm: EvaluationViewModel
  let athleteId: String
  let coachId: String
  let mode: EvaluationAddMode
  @EnvironmentObject var unitContext: UnitContext
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
          if c.isMaxBoulder || c.isMaxRope {
            gradePickerRow(for: c)
          } else {
            numberInputRow(for: c)
          }
        }
      }
    }
  }

  @ViewBuilder
  private func gradePickerRow(for c: AssessmentCriteria) -> some View {
    let scale = c.isMaxBoulder ? GradeScale.boulder : GradeScale.rope
    HStack {
      Text(c.name)
      Spacer()
      Picker("", selection: Binding(
        get: { values[c.id] ?? "" },
        set: { values[c.id] = $0 }
      )) {
        Text("—").tag("")
        ForEach(scale.reversed(), id: \.self) { grade in
          Text(grade).tag(grade)
        }
      }
      .labelsHidden()
    }
  }

  @ViewBuilder
  private func numberInputRow(for c: AssessmentCriteria) -> some View {
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
      let suffix = Units.unitSuffix(for: c, system: unitContext.system)
      if !suffix.isEmpty {
        Text(suffix)
          .foregroundColor(.secondary)
          .font(.caption)
          .frame(width: 30, alignment: .leading)
      }
    }
  }

  // MARK: - Custom (individual pickers)

  @ViewBuilder
  private var customSection: some View {
    Section {
      ForEach($customEntries) { $entry in
        CustomEntryRow(entry: $entry, allCriteria: vm.criteria)
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
        guard !text.isEmpty else { return nil }
        let criteria = vm.criteria.first { $0.id == criteriaId }
        let value: Double
        if criteria?.isMaxBoulder == true, let idx = GradeScale.boulder.firstIndex(of: text) {
          value = Double(idx)
        } else if criteria?.isMaxRope == true, let idx = GradeScale.rope.firstIndex(of: text) {
          value = Double(idx)
        } else if let d = Double(text) {
          value = criteria.map { Units.parseInput(d, criterion: $0, system: unitContext.system) } ?? d
        } else {
          return nil
        }
        return EvaluationInsert(
          athleteId: athleteId, coachId: coachId,
          criteriaId: criteriaId, evaluatedAt: dateString,
          value: value, notes: nil
        )
      }
    case .custom:
      inserts = customEntries.compactMap { entry in
        guard !entry.criteriaId.isEmpty, !entry.value.isEmpty else { return nil }
        let criteria = vm.criteria.first { $0.id == entry.criteriaId }
        let value: Double
        if criteria?.isMaxBoulder == true, let idx = GradeScale.boulder.firstIndex(of: entry.value) {
          value = Double(idx)
        } else if criteria?.isMaxRope == true, let idx = GradeScale.rope.firstIndex(of: entry.value) {
          value = Double(idx)
        } else if let d = Double(entry.value) {
          value = criteria.map { Units.parseInput(d, criterion: $0, system: unitContext.system) } ?? d
        } else {
          return nil
        }
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

private struct CustomEntryRow: View {
  @Binding var entry: CustomEntry
  let allCriteria: [AssessmentCriteria]
  @EnvironmentObject var unitContext: UnitContext

  private var selected: AssessmentCriteria? {
    allCriteria.first { $0.id == entry.criteriaId }
  }

  var body: some View {
    HStack {
      Picker("", selection: $entry.criteriaId) {
        Text("Select…").tag("")
        ForEach(allCriteria) { c in
          Text(c.name).tag(c.id)
        }
      }
      .labelsHidden()
      .frame(maxWidth: .infinity, alignment: .leading)
      .onChange(of: entry.criteriaId) { _ in entry.value = "" }

      if let c = selected, c.isMaxBoulder || c.isMaxRope {
        let scale = c.isMaxBoulder ? GradeScale.boulder : GradeScale.rope
        Picker("", selection: $entry.value) {
          Text("—").tag("")
          ForEach(scale.reversed(), id: \.self) { grade in
            Text(grade).tag(grade)
          }
        }
        .labelsHidden()
      } else {
        TextField("Value", text: $entry.value)
          .keyboardType(.decimalPad)
          .multilineTextAlignment(.trailing)
          .frame(width: 70)
        if let c = selected {
          let suffix = Units.unitSuffix(for: c, system: unitContext.system)
          if !suffix.isEmpty {
            Text(suffix)
              .foregroundColor(.secondary)
              .font(.caption)
              .frame(width: 30, alignment: .leading)
          }
        }
      }
    }
  }
}
