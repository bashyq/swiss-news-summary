import Foundation

// MARK: - Venue Status

/// Real-time open/closed status for a venue.
enum VenueStatus: Equatable {
    case open
    case closed
    case unknown
}

// MARK: - Opening Hours Parser

/// Client-side parser for OSM `opening_hours` format.
/// Determines real-time open/closed status by checking whether the current day+time
/// falls within any open range defined in the string.
///
/// Supported formats:
/// - Simple: `"09:00-17:00"` (daily)
/// - Day ranges: `"Mo-Fr 09:00-17:00; Sa 10:00-14:00"`
/// - Individual days: `"Mo,We,Fr 09:00-17:00"`
/// - Off rules: `"Su off"`, `"Mo-Fr 09:00-17:00; Sa off"`
/// - Always open: `"24/7"`
/// - Multiple time ranges: `"Mo-Fr 09:00-12:00,14:00-18:00"`
/// - Overnight spans: `"Fr-Sa 18:00-02:00"` (end < start → wraps midnight)
struct OpeningHoursParser {

    /// Determine if a venue is currently open based on its OSM opening_hours string.
    /// Returns `.unknown` if the string is nil, empty, or unparseable.
    static func status(from openingHours: String?, at date: Date = Date()) -> VenueStatus {
        guard let hours = openingHours?.trimmingCharacters(in: .whitespaces),
              !hours.isEmpty else {
            return .unknown
        }

        // 24/7 — always open
        if hours == "24/7" { return .open }

        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date) // 1=Sun, 2=Mon … 7=Sat
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        let currentMinutes = hour * 60 + minute

        // Map to OSM day index: Mo=0, Tu=1, We=2, Th=3, Fr=4, Sa=5, Su=6
        let osmDayIndex = weekday == 1 ? 6 : weekday - 2

        let rules = hours
            .components(separatedBy: ";")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        var foundTodayRule = false
        var isOpen = false

        for rule in rules {
            let lower = rule.lowercased()

            // "off" / "closed" rules
            if lower.contains("off") || lower.contains("closed") {
                if dayApplies(rule: rule, todayIndex: osmDayIndex) {
                    return .closed
                }
                continue
            }

            // Check if this rule applies to today
            guard dayApplies(rule: rule, todayIndex: osmDayIndex) else {
                continue
            }

            foundTodayRule = true

            // Extract and check time ranges
            let timeRanges = extractTimeRanges(from: rule)
            for (start, end) in timeRanges {
                let effectiveEnd = end <= start ? end + 1440 : end
                if currentMinutes >= start && currentMinutes < effectiveEnd {
                    isOpen = true
                }
            }
        }

        // Fallback: check for time-only rules (no day abbreviations)
        if !foundTodayRule {
            for rule in rules {
                let trimmed = rule.trimmingCharacters(in: .whitespaces)
                if isTimeOnlyRule(trimmed) {
                    foundTodayRule = true
                    let timeRanges = extractTimeRanges(from: trimmed)
                    for (start, end) in timeRanges {
                        let effectiveEnd = end <= start ? end + 1440 : end
                        if currentMinutes >= start && currentMinutes < effectiveEnd {
                            isOpen = true
                        }
                    }
                }
            }
        }

        return foundTodayRule ? (isOpen ? .open : .closed) : .unknown
    }

    /// Returns today's opening hours as a display string, e.g. "9:00–17:00" or "11:30–14:00, 18:00–22:00".
    /// Returns nil if no hours apply today or the string is unparseable.
    static func todayHours(from openingHours: String?, at date: Date = Date()) -> String? {
        guard let hours = openingHours?.trimmingCharacters(in: .whitespaces),
              !hours.isEmpty else { return nil }

        if hours == "24/7" { return "24/7" }

        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        let osmDayIndex = weekday == 1 ? 6 : weekday - 2

        let rules = hours
            .components(separatedBy: ";")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        var todayRanges: [(start: Int, end: Int)] = []

        for rule in rules {
            let lower = rule.lowercased()
            if lower.contains("off") || lower.contains("closed") {
                if dayApplies(rule: rule, todayIndex: osmDayIndex) { return nil }
                continue
            }
            if dayApplies(rule: rule, todayIndex: osmDayIndex) {
                todayRanges.append(contentsOf: extractTimeRanges(from: rule))
            }
        }

        // Fallback: time-only rules
        if todayRanges.isEmpty {
            for rule in rules {
                let trimmed = rule.trimmingCharacters(in: .whitespaces)
                if isTimeOnlyRule(trimmed) {
                    todayRanges.append(contentsOf: extractTimeRanges(from: trimmed))
                }
            }
        }

        guard !todayRanges.isEmpty else { return nil }

        return todayRanges.map { range in
            let sh = range.start / 60, sm = range.start % 60
            let eh = range.end / 60, em = range.end % 60
            return String(format: "%d:%02d–%d:%02d", sh, sm, eh, em)
        }.joined(separator: ", ")
    }

    // MARK: - Private Helpers

    private static let osmDays = ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]

    /// Check if a rule applies to today's day-of-week (OSM 0-indexed from Monday).
    private static func dayApplies(rule: String, todayIndex: Int) -> Bool {
        // Check day ranges: "Mo-Fr", "Mo-Sa", etc.
        if let rangeRegex = try? NSRegularExpression(
            pattern: #"(Mo|Tu|We|Th|Fr|Sa|Su)\s*[-–]\s*(Mo|Tu|We|Th|Fr|Sa|Su)"#,
            options: .caseInsensitive
        ) {
            let nsRange = NSRange(rule.startIndex..., in: rule)
            if let match = rangeRegex.firstMatch(in: rule, range: nsRange),
               let startRange = Range(match.range(at: 1), in: rule),
               let endRange = Range(match.range(at: 2), in: rule) {
                let startDay = String(rule[startRange])
                let endDay = String(rule[endRange])
                if let si = dayIndex(startDay), let ei = dayIndex(endDay) {
                    if si <= ei {
                        return todayIndex >= si && todayIndex <= ei
                    } else {
                        // Wraps around: e.g. Fr-Mo
                        return todayIndex >= si || todayIndex <= ei
                    }
                }
            }
        }

        // Check individual day mentions: "Mo,We,Fr" or "Mo We Fr"
        if let dayRegex = try? NSRegularExpression(
            pattern: #"\b(Mo|Tu|We|Th|Fr|Sa|Su)\b"#,
            options: .caseInsensitive
        ) {
            let nsRange = NSRange(rule.startIndex..., in: rule)
            let matches = dayRegex.matches(in: rule, range: nsRange)
            if !matches.isEmpty {
                return matches.contains { match in
                    guard let range = Range(match.range, in: rule) else { return false }
                    let found = String(rule[range])
                    return dayIndex(found) == todayIndex
                }
            }
        }

        // No day references at all → applies to all days
        return !containsDayReference(rule)
    }

    /// Map an OSM day abbreviation to 0-based index (Mo=0 … Su=6).
    private static func dayIndex(_ abbr: String) -> Int? {
        osmDays.firstIndex { $0.caseInsensitiveCompare(abbr) == .orderedSame }
    }

    /// Extract all "HH:MM-HH:MM" time ranges from a rule string.
    private static func extractTimeRanges(from rule: String) -> [(start: Int, end: Int)] {
        guard let regex = try? NSRegularExpression(
            pattern: #"(\d{1,2}):(\d{2})\s*[-–]\s*(\d{1,2}):(\d{2})"#
        ) else { return [] }

        let nsRange = NSRange(rule.startIndex..., in: rule)
        let matches = regex.matches(in: rule, range: nsRange)

        return matches.compactMap { match in
            guard match.numberOfRanges == 5,
                  let h1Range = Range(match.range(at: 1), in: rule),
                  let m1Range = Range(match.range(at: 2), in: rule),
                  let h2Range = Range(match.range(at: 3), in: rule),
                  let m2Range = Range(match.range(at: 4), in: rule),
                  let h1 = Int(rule[h1Range]), let m1 = Int(rule[m1Range]),
                  let h2 = Int(rule[h2Range]), let m2 = Int(rule[m2Range])
            else { return nil }
            return (h1 * 60 + m1, h2 * 60 + m2)
        }
    }

    /// Check if a rule is time-only (no day abbreviations).
    private static func isTimeOnlyRule(_ rule: String) -> Bool {
        !containsDayReference(rule) && rule.contains(":")
    }

    /// Whether the string contains any OSM day abbreviation.
    private static func containsDayReference(_ text: String) -> Bool {
        guard let regex = try? NSRegularExpression(
            pattern: #"\b(Mo|Tu|We|Th|Fr|Sa|Su)\b"#,
            options: .caseInsensitive
        ) else { return false }
        let nsRange = NSRange(text.startIndex..., in: text)
        return regex.firstMatch(in: text, range: nsRange) != nil
    }
}
