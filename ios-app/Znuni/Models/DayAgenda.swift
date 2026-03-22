import Foundation
import CoreLocation

// MARK: - Plan Day

/// Which day the user is planning for.
enum PlanDay: Equatable, Hashable {
    case today
    case tomorrow
    case saturday
    case sunday
    case specific(Date)

    /// The actual calendar date for this plan day.
    func date() -> Date {
        let cal = Calendar.current
        let now = Date()
        switch self {
        case .today: return now
        case .tomorrow:
            return cal.date(byAdding: .day, value: 1, to: now) ?? now
        case .saturday:
            return PlanDay.nextWeekendDates().saturday
        case .sunday:
            return PlanDay.nextWeekendDates().sunday
        case .specific(let d):
            return d
        }
    }

    /// ISO date string for API calls.
    var isoDate: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "Europe/Zurich")
        return f.string(from: date())
    }

    /// Short label like "Sat 15" for day picker pills.
    /// `.specific` dates include the month for clarity (e.g. "Mar 28").
    func shortLabel(language: AppLanguage) -> String {
        let f = DateFormatter()
        f.locale = language == .de ? Locale(identifier: "de_CH") : Locale(identifier: "en_US")
        if case .specific = self {
            f.dateFormat = language == .de ? "d. MMM" : "MMM d"
        } else {
            f.dateFormat = language == .de ? "EE d." : "EEE d"
        }
        return f.string(from: date())
    }

    /// Display name for headers.
    func headerTitle(language: AppLanguage) -> String {
        switch self {
        case .today:
            return language == .en ? "Your day" : "Dein Tag"
        case .tomorrow:
            return language == .en ? "Tomorrow's plan" : "Plan für morgen"
        case .saturday, .sunday:
            return language == .en ? "Weekend plan" : "Wochenendplan"
        case .specific:
            let f = DateFormatter()
            f.locale = language == .de ? Locale(identifier: "de_CH") : Locale(identifier: "en_US")
            f.dateFormat = language == .de ? "EEEE, d. MMM" : "EEEE, MMM d"
            return f.string(from: date())
        }
    }

    /// Whether this represents a future date (not today).
    var isFuture: Bool {
        switch self {
        case .today: return false
        default: return true
        }
    }

    /// The quick-pick days shown in the date picker row (today, tomorrow, next Sat, next Sun).
    static var quickPicks: [PlanDay] { [.today, .tomorrow, .saturday, .sunday] }

    /// Get next Saturday and Sunday dates.
    static func nextWeekendDates() -> (saturday: Date, sunday: Date) {
        let cal = Calendar.current
        let now = Date()
        let weekday = cal.component(.weekday, from: now) // 1=Sun, 7=Sat

        let daysToSat: Int
        switch weekday {
        case 7: daysToSat = 0  // Already Saturday
        case 1: daysToSat = 6  // Sunday → next Saturday
        default: daysToSat = 7 - weekday
        }

        let saturday = cal.date(byAdding: .day, value: daysToSat, to: now) ?? now
        let sunday = cal.date(byAdding: .day, value: 1, to: saturday) ?? now
        return (saturday, sunday)
    }

    // MARK: - Hashable

    func hash(into hasher: inout Hasher) {
        switch self {
        case .today: hasher.combine("today")
        case .tomorrow: hasher.combine("tomorrow")
        case .saturday: hasher.combine("saturday")
        case .sunday: hasher.combine("sunday")
        case .specific(let d):
            hasher.combine("specific")
            hasher.combine(Calendar.current.startOfDay(for: d))
        }
    }

    static func == (lhs: PlanDay, rhs: PlanDay) -> Bool {
        switch (lhs, rhs) {
        case (.today, .today), (.tomorrow, .tomorrow),
             (.saturday, .saturday), (.sunday, .sunday):
            return true
        case (.specific(let a), .specific(let b)):
            return Calendar.current.isDate(a, inSameDayAs: b)
        default:
            return false
        }
    }
}

// MARK: - Agenda Mode

/// Execution state for the day agenda.
enum AgendaMode: Codable, Equatable {
    case browsing
    case executing(currentSlotIndex: Int)

    /// The index of the currently active slot, or nil if browsing.
    var currentSlotIndex: Int? {
        if case .executing(let idx) = self { return idx }
        return nil
    }

    /// Whether we're in execution mode.
    var isExecuting: Bool {
        if case .executing = self { return true }
        return false
    }

    /// Number of completed slots (all before currentSlotIndex).
    func completedCount(totalSlots: Int) -> Int {
        guard let idx = currentSlotIndex else { return 0 }
        return min(idx, totalSlots)
    }
}

// MARK: - Slot Source

/// Origin of a slot's content.
enum SlotSource: String, Codable {
    case aiGenerated    // Claude composed this
    case userCustom     // user entered manually
    case userSwapped    // user picked from swap tray
    case userAnchor     // pre-existing commitment entered before compose
    case calendar       // imported from iOS Calendar via CalendarBridge
}

// MARK: - Travel Estimate

enum TravelMode: String, Codable {
    case walking
    case transit
}

struct TravelEstimate: Codable, Equatable {
    let minutes: Int
    let mode: TravelMode

    /// Walk threshold in meters — walk under 2 km, transit above.
    private static let walkThresholdMeters: Double = 2000

    /// Estimate travel from optional lat/lon pairs.
    static func estimate(fromLat: Double?, fromLon: Double?, toLat: Double?, toLon: Double?) -> TravelEstimate {
        guard let fromLat, let fromLon, let toLat, let toLon else {
            return TravelEstimate(minutes: 10, mode: .transit) // sensible default
        }
        return estimateFromDistance(haversine(lat1: fromLat, lon1: fromLon, lat2: toLat, lon2: toLon))
    }

    /// Estimate travel between two CLLocations.
    static func estimate(from origin: CLLocation, to destination: CLLocation) -> TravelEstimate {
        return estimateFromDistance(origin.distance(from: destination))
    }

    private static func estimateFromDistance(_ meters: Double) -> TravelEstimate {
        if meters <= walkThresholdMeters {
            let walkMin = Int(ceil(meters * 1.3 / 83.0))
            return TravelEstimate(minutes: max(walkMin, 2), mode: .walking)
        } else {
            // Transit: 15 km/h = 250 m/min + 5 min base (walk to stop + wait)
            let transitMin = 5 + Int(ceil(meters / 250.0))
            return TravelEstimate(minutes: max(transitMin, 8), mode: .transit)
        }
    }

    /// Haversine distance in meters between two coordinates.
    static func haversine(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let R = 6371000.0
        let dLat = (lat2 - lat1) * .pi / 180
        let dLon = (lon2 - lon1) * .pi / 180
        let a = sin(dLat/2) * sin(dLat/2) + cos(lat1 * .pi / 180) * cos(lat2 * .pi / 180) * sin(dLon/2) * sin(dLon/2)
        return R * 2 * atan2(sqrt(a), sqrt(1-a))
    }
}

// MARK: - Day Agenda

/// A complete day agenda generated by the Agenda Composer.
struct DayAgenda: Codable {
    let date: String                    // ISO date "2026-03-14"
    let theme: String                   // e.g. "Sunny Saturday with Mia"
    let weatherNote: String             // e.g. "14° and partly sunny"
    let badWeatherMode: Bool
    var slots: [AgendaSlot]
    let homeActivities: HomeActivities?

    /// Whether any slot has a pending reflow (stale downstream slots).
    var hasStaleSlots: Bool {
        slots.contains { $0.isStale }
    }

    /// Return a copy with replaced slots array.
    func with(slots newSlots: [AgendaSlot]) -> DayAgenda {
        var copy = self
        copy.slots = newSlots
        return copy
    }
}

/// Forecasted weather at a specific slot's time.
struct SlotWeather: Codable {
    let temp: Int           // °C from hourly forecast
    let code: Int           // WMO weather code
    let rain: Bool          // whether rain is expected

    /// SF Symbol for the WMO weather code.
    var sfSymbol: String {
        switch code {
        case 0: return "sun.max.fill"
        case 1: return "sun.max.fill"
        case 2: return "cloud.sun.fill"
        case 3: return "cloud.fill"
        case 45, 48: return "cloud.fog.fill"
        case 51, 53, 55: return "cloud.drizzle.fill"
        case 56, 57: return "cloud.sleet.fill"
        case 61, 63, 65: return "cloud.rain.fill"
        case 66, 67: return "cloud.sleet.fill"
        case 71, 73, 75, 77: return "cloud.snow.fill"
        case 80, 81, 82: return "cloud.heavyrain.fill"
        case 85, 86: return "cloud.snow.fill"
        case 95, 96, 99: return "cloud.bolt.rain.fill"
        default: return "cloud.fill"
        }
    }
}

/// One time slot in the day's agenda.
struct AgendaSlot: Codable, Identifiable {
    let id: String                      // "morning", "lunch", "afternoon", "dinner"
    var time: String                    // "10:00"
    let type: SlotType
    var venueName: String
    var venueId: String?
    var reason: String                  // Claude's 1-2 sentence reasoning
    let durationDisplay: String?
    var travelNote: String?             // "8 min walk from home"
    let tags: [String]                  // ["Outdoor", "Free", "Ages 2-5"]
    var lat: Double?                    // Venue latitude for travel estimates
    var lon: Double?                    // Venue longitude for travel estimates
    var travelToNext: TravelEstimate?   // Travel estimate to the next slot
    var weatherAtSlot: SlotWeather?     // Forecasted weather at this slot's time

    /// Expected duration at this venue in minutes (activity: 100, lunch: 90, dinner: 120).
    /// Used to compute `scheduledEndDate` for timeline shift delta calculation.
    var durationMinutes: Int?

    // MARK: - Check-In Tracking

    /// Actual departure time (set when user taps Done ✓ or geofence fires).
    var checkOutTime: Date?

    /// True if geofence triggered, false if manual Done tap.
    var wasAutoCheckedIn: Bool

    // MARK: - Custom Slot / Lock

    /// Origin of this slot's content.
    var source: SlotSource

    /// When true, this slot is never replaced by reflow.
    var isLocked: Bool

    /// Custom venue name (only set when source == .userCustom).
    var customVenueName: String?

    /// Custom neighbourhood (used for travel connector logic when source == .userCustom).
    var customNeighbourhood: String?

    /// Whether downstream AI slots are stale after an upstream custom edit.
    var isStale: Bool

    // MARK: - Anchor Fields

    /// End time for anchor slots — used to show "11:15 – 12:45" time range display.
    var anchorEndTime: String?

    // MARK: - Stored Date

    /// The actual Date for this slot (plan date + time).
    /// Set at creation time — NOT computed from `time` string.
    var slotDate: Date

    /// Scheduled end date = slotDate + durationMinutes (or type default).
    /// Used to compute the departure delta for timeline shifts.
    var scheduledEndDate: Date {
        let dur = durationMinutes ?? defaultDurationMinutes
        return slotDate.addingTimeInterval(TimeInterval(dur * 60))
    }

    /// Fallback duration when `durationMinutes` is nil.
    private var defaultDurationMinutes: Int {
        switch type {
        case .activity: return 100
        case .lunch:    return 90
        case .dinner:   return 120
        case .homeActivity: return 60
        }
    }

    /// Update the time string and slotDate from a Date.
    mutating func updateTime(from date: Date) {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        time = f.string(from: date)
        slotDate = date
    }

    /// Resolve a slot date from a time string and plan date.
    /// Used as fallback for cached data that doesn't have a stored slotDate.
    static func resolveSlotDate(time: String, planDate: Date) -> Date {
        let parts = time.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return planDate }
        var cal = Calendar.current
        cal.timeZone = TimeZone(identifier: "Europe/Zurich") ?? .current
        let dayStart = cal.startOfDay(for: planDate)
        return cal.date(bySettingHour: parts[0], minute: parts[1], second: 0, of: dayStart) ?? planDate
    }

    enum SlotType: String, Codable {
        case activity
        case lunch
        case dinner
        case homeActivity
    }

    enum CodingKeys: String, CodingKey {
        case id, time, type, venueName, venueId, reason, durationDisplay
        case travelNote, tags, lat, lon, travelToNext, weatherAtSlot
        case durationMinutes, checkOutTime, wasAutoCheckedIn
        case source, isLocked, customVenueName, customNeighbourhood, isStale
        case anchorEndTime, slotDate
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        time = try container.decode(String.self, forKey: .time)
        type = try container.decode(SlotType.self, forKey: .type)
        venueName = try container.decode(String.self, forKey: .venueName)
        venueId = try container.decodeIfPresent(String.self, forKey: .venueId)
        reason = try container.decode(String.self, forKey: .reason)
        durationDisplay = try container.decodeIfPresent(String.self, forKey: .durationDisplay)
        travelNote = try container.decodeIfPresent(String.self, forKey: .travelNote)
        tags = try container.decode([String].self, forKey: .tags)
        lat = try container.decodeIfPresent(Double.self, forKey: .lat)
        lon = try container.decodeIfPresent(Double.self, forKey: .lon)
        travelToNext = try container.decodeIfPresent(TravelEstimate.self, forKey: .travelToNext)
        weatherAtSlot = try container.decodeIfPresent(SlotWeather.self, forKey: .weatherAtSlot)
        durationMinutes = try container.decodeIfPresent(Int.self, forKey: .durationMinutes)
        // Check-in fields with defaults for backward compatibility
        checkOutTime = try container.decodeIfPresent(Date.self, forKey: .checkOutTime)
        wasAutoCheckedIn = try container.decodeIfPresent(Bool.self, forKey: .wasAutoCheckedIn) ?? false
        // New fields with defaults for backward compatibility
        source = try container.decodeIfPresent(SlotSource.self, forKey: .source) ?? .aiGenerated
        isLocked = try container.decodeIfPresent(Bool.self, forKey: .isLocked) ?? false
        customVenueName = try container.decodeIfPresent(String.self, forKey: .customVenueName)
        customNeighbourhood = try container.decodeIfPresent(String.self, forKey: .customNeighbourhood)
        isStale = try container.decodeIfPresent(Bool.self, forKey: .isStale) ?? false
        anchorEndTime = try container.decodeIfPresent(String.self, forKey: .anchorEndTime)
        // slotDate: decode if present, fallback to computing from time string for cached data
        if let decoded = try container.decodeIfPresent(Date.self, forKey: .slotDate) {
            slotDate = decoded
        } else {
            slotDate = AgendaSlot.resolveSlotDate(time: time, planDate: Date())
        }
    }

    init(
        id: String, time: String, type: SlotType, venueName: String, venueId: String?,
        reason: String, durationDisplay: String? = nil, travelNote: String? = nil,
        tags: [String], lat: Double? = nil, lon: Double? = nil,
        travelToNext: TravelEstimate? = nil,
        weatherAtSlot: SlotWeather? = nil,
        durationMinutes: Int? = nil,
        checkOutTime: Date? = nil, wasAutoCheckedIn: Bool = false,
        source: SlotSource = .aiGenerated, isLocked: Bool = false,
        customVenueName: String? = nil, customNeighbourhood: String? = nil,
        isStale: Bool = false,
        anchorEndTime: String? = nil,
        slotDate: Date = Date()
    ) {
        self.id = id
        self.time = time
        self.type = type
        self.venueName = venueName
        self.venueId = venueId
        self.reason = reason
        self.durationDisplay = durationDisplay
        self.travelNote = travelNote
        self.tags = tags
        self.lat = lat
        self.lon = lon
        self.travelToNext = travelToNext
        self.weatherAtSlot = weatherAtSlot
        self.durationMinutes = durationMinutes
        self.checkOutTime = checkOutTime
        self.wasAutoCheckedIn = wasAutoCheckedIn
        self.source = source
        self.isLocked = isLocked
        self.customVenueName = customVenueName
        self.customNeighbourhood = customNeighbourhood
        self.isStale = isStale
        self.anchorEndTime = anchorEndTime
        self.slotDate = slotDate
    }
}

/// Home activities for bad weather days.
struct HomeActivities: Codable {
    let baking: HomeActivity?
    let movie: MoviePick?
    let craft: HomeActivity?
}

struct HomeActivity: Codable, Identifiable {
    var id: String { idea }
    let label: String                   // "MORNING · BAKING" / "CRAFT"
    let idea: String                    // "Bürli rolls together"
    let emoji: String                   // "🥐"
    let reason: String                  // why this fits
    let durationDisplay: String         // "~45 min active"
    let ageNote: String?                // "Ages 4+"
}

struct MoviePick: Codable, Identifiable {
    var id: String { title }
    let label: String                   // "AFTER LUNCH · SCREEN TIME"
    let title: String                   // "Pippi Longstocking (1969)"
    let emoji: String                   // "🎬"
    let reason: String                  // "Age-perfect for both kids"
    let platform: String?               // "SRF Play Kids"
    let durationMinutes: Int            // 99
    let isFree: Bool
}
