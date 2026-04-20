import Foundation

struct MeasurementRecord: Codable, Identifiable {
  let id: String
  let athleteId: String
  let coachId: String
  let measuredAt: String

  // Morpho
  let heightCm: Double?
  let wingspanCm: Double?
  let reachCm: Double?
  let apeIndexCm: Double?
  let weightKg: Double?
  let fingerLengthMm: Double?

  // Flexibility
  let sitAndReachCm: Double?
  let shoulderFlexCm: Double?

  // Strength
  let gripStrengthLKg: Double?
  let gripStrengthRKg: Double?
  let maxHangboardKg: Double?
  let pullupMax: Int?

  let measurementNotes: String?
  let createdAt: String

  enum CodingKeys: String, CodingKey {
    case id
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
    case createdAt = "created_at"
  }
}
