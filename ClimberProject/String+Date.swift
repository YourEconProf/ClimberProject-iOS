import Foundation

private let isoInput: DateFormatter = {
  let f = DateFormatter()
  f.dateFormat = "yyyy-MM-dd"
  f.locale = Locale(identifier: "en_US_POSIX")
  return f
}()

extension String {
  /// "2026-08-17" → "17 Aug 2026"
  var displayDate: String { formatted("d MMM yyyy") }

  /// "2026-08-17" → "17 Aug 26"  (space-constrained, e.g. chart axes)
  var displayDateShort: String { formatted("d MMM yy") }

  /// "2026-08-17" → "Wed, 17 Aug 2026"
  var displayDateWithWeekday: String { formatted("EEE, d MMM yyyy") }

  /// "2026-08-17" → "Wednesday, 17 Aug 2026"
  var displayDateLongWeekday: String { formatted("EEEE, d MMM yyyy") }

  private func formatted(_ format: String) -> String {
    guard let date = isoInput.date(from: String(self.prefix(10))) else {
      return String(self.prefix(10))
    }
    let f = DateFormatter()
    f.dateFormat = format
    return f.string(from: date)
  }
}
