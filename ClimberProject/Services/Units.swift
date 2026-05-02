import Foundation
import Combine
import Supabase

enum UnitSystem: String {
  case metric, imperial
}

// Storage stays metric throughout — height_cm, weight_kg, wingspan_cm, reach_cm.
// Conversion happens only at the UI boundary (display + input parsing).
enum Units {
  static let cmPerIn = 2.54
  static let kgPerLb = 0.45359237

  static func cmToIn(_ cm: Double) -> Double { cm / cmPerIn }
  static func inToCm(_ inches: Double) -> Double { inches * cmPerIn }
  static func kgToLb(_ kg: Double) -> Double { kg / kgPerLb }
  static func lbToKg(_ lb: Double) -> Double { lb * kgPerLb }

  static func formatLength(_ cm: Double?, system: UnitSystem) -> String {
    guard let cm else { return "—" }
    return system == .imperial
      ? String(format: "%.1f in", cmToIn(cm))
      : String(format: "%.1f cm", cm)
  }

  static func formatWeight(_ kg: Double?, system: UnitSystem) -> String {
    guard let kg else { return "—" }
    return system == .imperial
      ? String(format: "%.1f lb", kgToLb(kg))
      : String(format: "%.1f kg", kg)
  }

  static func isLengthCriterion(_ c: AssessmentCriteria) -> Bool {
    c.isHeight || c.isWingspan || c.isReach
  }

  static func isWeightCriterion(_ c: AssessmentCriteria) -> Bool { c.isWeight }

  /// Convert a stored metric value into the value to show in an input field.
  static func displayValue(_ stored: Double, criterion: AssessmentCriteria, system: UnitSystem) -> Double {
    guard system == .imperial else { return stored }
    if isLengthCriterion(criterion) { return cmToIn(stored) }
    if isWeightCriterion(criterion) { return kgToLb(stored) }
    return stored
  }

  /// Convert an input-field value back to the metric value to persist.
  static func parseInput(_ input: Double, criterion: AssessmentCriteria, system: UnitSystem) -> Double {
    guard system == .imperial else { return input }
    if isLengthCriterion(criterion) { return inToCm(input) }
    if isWeightCriterion(criterion) { return lbToKg(input) }
    return input
  }

  /// The unit suffix to show next to an input or value, given the user's preference.
  /// Falls back to the criterion's stored unit (e.g. "kg", "mm") for criteria not flagged as length/weight.
  static func unitSuffix(for criterion: AssessmentCriteria, system: UnitSystem) -> String {
    if system == .imperial {
      if isLengthCriterion(criterion) { return "in" }
      if isWeightCriterion(criterion) { return "lb" }
    }
    return criterion.unit ?? ""
  }
}

@MainActor
final class UnitContext: ObservableObject {
  @Published var system: UnitSystem = .metric

  func hydrate(from coach: Coach?) {
    system = (coach?.unitPreference == "imperial") ? .imperial : .metric
  }

  /// Optimistic — flip locally, persist in the background.
  func setSystem(_ next: UnitSystem, coachId: String) async {
    system = next
    struct Patch: Encodable {
      let unitPreference: String
      enum CodingKeys: String, CodingKey { case unitPreference = "unit_preference" }
    }
    try? await SupabaseService.shared.supabase
      .from("coaches")
      .update(Patch(unitPreference: next.rawValue))
      .eq("id", value: coachId)
      .execute()
  }
}
