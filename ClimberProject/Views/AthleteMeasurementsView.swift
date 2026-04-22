import SwiftUI

struct AthleteMeasurementsView: View {
  let athlete: Athlete
  @ObservedObject var vm: MeasurementViewModel
  @EnvironmentObject var authVM: AuthViewModel
  @State private var showAdd = false

  var body: some View {
    List {
      ForEach(vm.measurements) { m in
        MeasurementRow(record: m)
      }
      .onDelete { indices in
        Task {
          for i in indices {
            try? await vm.delete(id: vm.measurements[i].id)
          }
        }
      }
    }
    .navigationTitle("Measurements")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        Button { showAdd = true } label: { Image(systemName: "plus") }
      }
    }
    .sheet(isPresented: $showAdd) {
      AddMeasurementView(athlete: athlete, vm: vm)
        .environmentObject(authVM)
    }
    .overlay {
      if vm.measurements.isEmpty && !vm.isLoading {
        ContentUnavailableView("No Measurements", systemImage: "ruler",
          description: Text("Tap + to record physical measurements."))
      }
    }
  }
}

private struct MeasurementRow: View {
  let record: MeasurementRecord

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(record.measuredAt.displayDate)
        .font(.subheadline).bold()

      LazyVGrid(
        columns: [GridItem(.flexible()), GridItem(.flexible())],
        alignment: .leading,
        spacing: 4
      ) {
        if let v = record.heightCm        { statChip("Height",    fmt(v), "cm") }
        if let v = record.wingspanCm      { statChip("Wingspan",  fmt(v), "cm") }
        if let v = record.apeIndexCm      { statChip("Ape Index", fmt(v), "cm") }
        if let v = record.weightKg        { statChip("Weight",    fmt(v), "kg") }
        if let v = record.gripStrengthLKg { statChip("Grip L",    fmt(v), "kg") }
        if let v = record.gripStrengthRKg { statChip("Grip R",    fmt(v), "kg") }
        if let v = record.maxHangboardKg  { statChip("Hangboard", fmt(v), "kg") }
        if let v = record.pullupMax       { statChip("Pull-ups",  "\(v)", "")  }
        if let v = record.reachCm         { statChip("Reach",     fmt(v), "cm") }
        if let v = record.fingerLengthMm  { statChip("Finger",    fmt(v), "mm") }
        if let v = record.sitAndReachCm   { statChip("Sit&Reach", fmt(v), "cm") }
        if let v = record.shoulderFlexCm  { statChip("Shld Flex", fmt(v), "cm") }
      }

      if let notes = record.measurementNotes, !notes.isEmpty {
        Text(notes)
          .font(.caption)
          .foregroundColor(.secondary)
          .lineLimit(2)
      }
    }
    .padding(.vertical, 4)
  }

  @ViewBuilder
  private func statChip(_ label: String, _ value: String, _ unit: String) -> some View {
    HStack(spacing: 3) {
      Text(label).font(.caption2).foregroundColor(.secondary)
      Text(unit.isEmpty ? value : "\(value) \(unit)").font(.caption2).bold()
    }
  }

  private func fmt(_ v: Double) -> String {
    v.truncatingRemainder(dividingBy: 1) == 0
      ? String(format: "%.0f", v)
      : String(format: "%.1f", v)
  }
}
