import Foundation

// MARK: - Two formatting rules
//
// Postgres `date` columns (athletes.dob, workouts.workout_date,
// workouts.planned_for, competition_results.competition_date,
// evaluations.evaluated_at, athlete_programs.enrolled_at):
//   → format in UTC. They have no timezone and represent a calendar date in
//     the user's mental model. Formatting in the device's local zone shifts
//     them across the international date line for non-UTC viewers.
//
// Postgres `timestamptz` columns (created_at, assessed_at,
// maxes_updated_at, acknowledged_at, resolved_at, etc.):
//   → format in the gym's IANA timezone (`AuthViewModel.gymTimezone`). Falls
//     back to UTC until the gym row is loaded.

private let isoDateOnly: DateFormatter = {
  let f = DateFormatter()
  f.dateFormat = "yyyy-MM-dd"
  f.locale = Locale(identifier: "en_US_POSIX")
  f.timeZone = TimeZone(identifier: "UTC")
  return f
}()

private let isoTimestamptz: ISO8601DateFormatter = {
  let f = ISO8601DateFormatter()
  f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
  return f
}()

private let isoTimestamptzNoFrac: ISO8601DateFormatter = {
  let f = ISO8601DateFormatter()
  f.formatOptions = [.withInternetDateTime]
  return f
}()

private func parseInstant(_ string: String) -> Date? {
  isoTimestamptz.date(from: string) ?? isoTimestamptzNoFrac.date(from: string)
}

private func zone(_ id: String) -> TimeZone {
  TimeZone(identifier: id) ?? TimeZone(identifier: "UTC") ?? .gmt
}

extension String {
  // MARK: `date` columns — formatted in UTC

  /// "2026-08-17" → "17 Aug 2026"
  var displayDate: String { formattedDateOnly("d MMM yyyy") }

  /// "2026-08-17" → "17 Aug 26" (space-constrained)
  var displayDateShort: String { formattedDateOnly("d MMM yy") }

  /// "2026-08-17" → "Wed, 17 Aug 2026"
  var displayDateWithWeekday: String { formattedDateOnly("EEE, d MMM yyyy") }

  /// "2026-08-17" → "Wednesday, 17 Aug 2026"
  var displayDateLongWeekday: String { formattedDateOnly("EEEE, d MMM yyyy") }

  private func formattedDateOnly(_ format: String) -> String {
    guard let date = isoDateOnly.date(from: String(self.prefix(10))) else {
      return String(self.prefix(10))
    }
    let f = DateFormatter()
    f.dateFormat = format
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = TimeZone(identifier: "UTC")
    return f.string(from: date)
  }

  // MARK: `timestamptz` columns — formatted in the gym's timezone

  /// "2026-04-30T23:14:05Z", "America/New_York" → "30 Apr 2026"
  func displayDate(in tz: String) -> String { formattedInstant("d MMM yyyy", tz: tz) }

  /// "2026-04-30T23:14:05Z", "America/New_York" → "30 Apr 2026, 7:14 PM"
  func displayDateTime(in tz: String) -> String { formattedInstant("d MMM yyyy, h:mm a", tz: tz) }

  /// "2026-04-30T23:14:05Z", "America/New_York" → "7:14 PM"
  func displayTime(in tz: String) -> String { formattedInstant("h:mm a", tz: tz) }

  private func formattedInstant(_ format: String, tz: String) -> String {
    guard let date = parseInstant(self) else {
      return String(self.prefix(10))
    }
    let f = DateFormatter()
    f.dateFormat = format
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = zone(tz)
    return f.string(from: date)
  }
}
