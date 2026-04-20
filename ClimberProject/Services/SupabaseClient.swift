import Foundation
import Supabase

// Named SupabaseService to avoid collision with the SDK's own SupabaseClient type.
class SupabaseService {
  static let shared = SupabaseService()

  let supabase: SupabaseClient

  private init() {
    let url = URL(string: Config.supabaseUrl)!
    let key = Config.supabaseAnonKey
    self.supabase = SupabaseClient(
      supabaseURL: url,
      supabaseKey: key,
      options: SupabaseClientOptions(
        auth: SupabaseClientOptions.AuthOptions(
          emitLocalSessionAsInitialSession: true
        )
      )
    )
  }
}
