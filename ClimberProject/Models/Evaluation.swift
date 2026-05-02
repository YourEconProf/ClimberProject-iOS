import Foundation

struct Evaluation: Codable, Identifiable {
  let id: String
  let athleteId: String
  let coachId: String
  let criteriaId: String
  let evaluatedAt: String
  let value: Double?
  let notes: String?
  let createdAt: String

  enum CodingKeys: String, CodingKey {
    case id
    case athleteId = "athlete_id"
    case coachId = "coach_id"
    case criteriaId = "criteria_id"
    case evaluatedAt = "evaluated_at"
    case value
    case notes
    case createdAt = "created_at"
  }
}

struct AssessmentCriteria: Codable, Identifiable {
  let id: String
  let gymId: String
  let name: String
  let unit: String?
  let isFm: Bool
  let isMorpho: Bool
  let isStrength: Bool
  let isMaxBoulder: Bool
  let isMaxRope: Bool
  // Denormalization trigger flags
  let isMaxHang: Bool
  let isMaxPullupLoad: Bool
  let isMeEdge: Bool
  let isLockoff: Bool
  let isHeight: Bool
  let isWeight: Bool
  let isWingspan: Bool
  let isReach: Bool
  let createdAt: String

  enum CodingKeys: String, CodingKey {
    case id
    case gymId = "gym_id"
    case name
    case unit
    case isFm = "is_fm"
    case isMorpho = "is_morpho"
    case isStrength = "is_strength"
    case isMaxBoulder = "is_max_boulder"
    case isMaxRope = "is_max_rope"
    case isMaxHang = "is_max_hang"
    case isMaxPullupLoad = "is_max_pullup_load"
    case isMeEdge = "is_me_edge"
    case isLockoff = "is_lockoff"
    case isHeight = "is_height"
    case isWeight = "is_weight"
    case isWingspan = "is_wingspan"
    case isReach = "is_reach"
    case createdAt = "created_at"
  }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    id              = try c.decode(String.self,          forKey: .id)
    gymId           = try c.decode(String.self,          forKey: .gymId)
    name            = try c.decode(String.self,          forKey: .name)
    unit            = try c.decodeIfPresent(String.self, forKey: .unit)
    isFm            = try c.decodeIfPresent(Bool.self,   forKey: .isFm)            ?? false
    isMorpho        = try c.decodeIfPresent(Bool.self,   forKey: .isMorpho)        ?? false
    isStrength      = try c.decodeIfPresent(Bool.self,   forKey: .isStrength)      ?? false
    isMaxBoulder    = try c.decodeIfPresent(Bool.self,   forKey: .isMaxBoulder)    ?? false
    isMaxRope       = try c.decodeIfPresent(Bool.self,   forKey: .isMaxRope)       ?? false
    isMaxHang       = try c.decodeIfPresent(Bool.self,   forKey: .isMaxHang)       ?? false
    isMaxPullupLoad = try c.decodeIfPresent(Bool.self,   forKey: .isMaxPullupLoad) ?? false
    isMeEdge        = try c.decodeIfPresent(Bool.self,   forKey: .isMeEdge)        ?? false
    isLockoff       = try c.decodeIfPresent(Bool.self,   forKey: .isLockoff)       ?? false
    isHeight        = try c.decodeIfPresent(Bool.self,   forKey: .isHeight)        ?? false
    isWeight        = try c.decodeIfPresent(Bool.self,   forKey: .isWeight)        ?? false
    isWingspan      = try c.decodeIfPresent(Bool.self,   forKey: .isWingspan)      ?? false
    isReach         = try c.decodeIfPresent(Bool.self,   forKey: .isReach)         ?? false
    createdAt       = try c.decode(String.self,          forKey: .createdAt)
  }
}
