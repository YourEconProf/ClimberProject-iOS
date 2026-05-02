import Foundation

struct Gym: Codable, Identifiable {
  let id: String
  let name: String
  let code: String
  let timezone: String

  enum CodingKeys: String, CodingKey {
    case id, name, code, timezone
  }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    id = try c.decode(String.self, forKey: .id)
    name = try c.decode(String.self, forKey: .name)
    code = try c.decode(String.self, forKey: .code)
    timezone = (try? c.decodeIfPresent(String.self, forKey: .timezone)) ?? "UTC"
  }

  init(id: String, name: String, code: String, timezone: String = "UTC") {
    self.id = id
    self.name = name
    self.code = code
    self.timezone = timezone
  }
}
