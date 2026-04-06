import Foundation

struct Config {
  static let supabaseUrl: String = {
    guard let url = Bundle.main.infoDictionary?["SUPABASE_URL"] as? String else {
      fatalError("SUPABASE_URL not found in Info.plist")
    }
    return url
  }()

  static let supabaseAnonKey: String = {
    guard let key = Bundle.main.infoDictionary?["SUPABASE_ANON_KEY"] as? String else {
      fatalError("SUPABASE_ANON_KEY not found in Info.plist")
    }
    return key
  }()
}
