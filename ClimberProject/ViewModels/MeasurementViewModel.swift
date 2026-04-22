import Foundation
import Supabase

@MainActor
class MeasurementViewModel: ObservableObject {
  @Published var measurements: [MeasurementRecord] = []
  @Published var isLoading = false
  @Published var error: String?

  private var supabase: SupabaseClient { SupabaseService.shared.supabase }

  var latest: MeasurementRecord? { measurements.first }

  func fetch(athleteId: String) async {
    isLoading = true
    error = nil
    defer { isLoading = false }
    do {
      measurements = try await supabase
        .from("measurements")
        .select()
        .eq("athlete_id", value: athleteId)
        .order("measured_at", ascending: false)
        .execute()
        .value
    } catch {
      self.error = error.localizedDescription
    }
  }

  func add(
    athleteId: String,
    coachId: String,
    measuredAt: String,
    heightCm: Double?,
    wingspanCm: Double?,
    reachCm: Double?,
    weightKg: Double?,
    fingerLengthMm: Double?,
    sitAndReachCm: Double?,
    shoulderFlexCm: Double?,
    gripStrengthLKg: Double?,
    gripStrengthRKg: Double?,
    maxHangboardKg: Double?,
    pullupMax: Int?,
    notes: String?
  ) async throws {
    let apeIndexCm: Double? = {
      guard let w = wingspanCm, let h = heightCm else { return nil }
      return ((w - h) * 10).rounded() / 10
    }()
    let insert = MeasurementInsert(
      athleteId: athleteId,
      coachId: coachId,
      measuredAt: measuredAt,
      heightCm: heightCm,
      wingspanCm: wingspanCm,
      reachCm: reachCm,
      apeIndexCm: apeIndexCm,
      weightKg: weightKg,
      fingerLengthMm: fingerLengthMm,
      sitAndReachCm: sitAndReachCm,
      shoulderFlexCm: shoulderFlexCm,
      gripStrengthLKg: gripStrengthLKg,
      gripStrengthRKg: gripStrengthRKg,
      maxHangboardKg: maxHangboardKg,
      pullupMax: pullupMax,
      measurementNotes: notes?.isEmpty == true ? nil : notes
    )
    let created: [MeasurementRecord] = try await supabase
      .from("measurements")
      .insert(insert)
      .select()
      .execute()
      .value
    if let record = created.first {
      measurements.insert(record, at: 0)
    }
  }

  func delete(id: String) async throws {
    try await supabase
      .from("measurements")
      .delete()
      .eq("id", value: id)
      .execute()
    measurements.removeAll { $0.id == id }
  }
}

private struct MeasurementInsert: Encodable {
  let athleteId: String
  let coachId: String
  let measuredAt: String
  let heightCm: Double?
  let wingspanCm: Double?
  let reachCm: Double?
  let apeIndexCm: Double?
  let weightKg: Double?
  let fingerLengthMm: Double?
  let sitAndReachCm: Double?
  let shoulderFlexCm: Double?
  let gripStrengthLKg: Double?
  let gripStrengthRKg: Double?
  let maxHangboardKg: Double?
  let pullupMax: Int?
  let measurementNotes: String?

  enum CodingKeys: String, CodingKey {
    case athleteId = "athlete_id"
    case coachId = "coach_id"
    case measuredAt = "measured_at"
    case heightCm = "height_cm"
    case wingspanCm = "wingspan_cm"
    case reachCm = "reach_cm"
    case apeIndexCm = "ape_index_cm"
    case weightKg = "weight_kg"
    case fingerLengthMm = "finger_length_mm"
    case sitAndReachCm = "sit_and_reach_cm"
    case shoulderFlexCm = "shoulder_flex_cm"
    case gripStrengthLKg = "grip_strength_l_kg"
    case gripStrengthRKg = "grip_strength_r_kg"
    case maxHangboardKg = "max_hangboard_kg"
    case pullupMax = "pullup_max"
    case measurementNotes = "measurement_notes"
  }
}
