import Foundation

/// A contextual nudge to display at the top of the Discover tab.
struct Nudge: Identifiable, Equatable {
    let id: String
    let type: NudgeType
    let title: String
    let subtitle: String
    let ctaLabel: String
    let iconName: String

    enum NudgeType: Equatable {
        case sunshineEscape     // Poor local weather + sunny destination available
        case freshSnow          // Heavy snowfall at a resort
        case upcomingEvent      // Plannable event in the next few days
    }
}

/// Evaluates contextual conditions and returns the highest-priority nudge for the Discover tab.
struct NudgeEngine {

    /// Evaluate all nudge conditions and return the most relevant one (or nil).
    /// - Parameters:
    ///   - weather: Current local weather (from news endpoint)
    ///   - sunshineData: Sunshine destinations with forecasts
    ///   - snowData: Snow resort forecasts
    ///   - events: Upcoming city events
    ///   - language: Current app language
    static func evaluate(
        weather: Weather?,
        sunshineDestinations: [SunshineDestination]?,
        snowDestinations: [SnowDestination]?,
        events: [CityEvent]?,
        language: AppLanguage
    ) -> Nudge? {
        // Priority 1: Sunshine escape (poor local weather + sunny destination)
        if let nudge = sunshineEscapeNudge(
            weather: weather,
            destinations: sunshineDestinations,
            language: language
        ) {
            return nudge
        }

        // Priority 2: Fresh snow alert
        if let nudge = freshSnowNudge(
            destinations: snowDestinations,
            language: language
        ) {
            return nudge
        }

        // Priority 3: Upcoming plannable event
        if let nudge = upcomingEventNudge(
            events: events,
            language: language
        ) {
            return nudge
        }

        return nil
    }

    // MARK: - Sunshine Escape

    private static func sunshineEscapeNudge(
        weather: Weather?,
        destinations: [SunshineDestination]?,
        language: AppLanguage
    ) -> Nudge? {
        guard let w = weather, let dests = destinations else { return nil }

        // Only nudge when local weather is poor (overcast, rainy, cold)
        let poorWeatherCodes: Set<Int> = [3, 45, 48, 51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82, 95, 96, 99]
        let isPoorWeather = poorWeatherCodes.contains(w.weatherCode) || w.temperature < 5

        guard isPoorWeather else { return nil }

        // Find the sunniest destination with > 6 hours of sunshine
        let sunny = dests
            .filter { $0.isBaseline != true && $0.sunshineHoursTotal > 6 }
            .sorted { $0.driveMinutes < $1.driveMinutes }
            .first

        guard let dest = sunny else { return nil }

        let destName = dest.localizedName(language: language)
        return Nudge(
            id: "sunshine-escape",
            type: .sunshineEscape,
            title: language == .de
                ? "Sonne in \(destName)"
                : "Sun in \(destName)",
            subtitle: language == .de
                ? "\(String(format: "%.0f", dest.sunshineHoursTotal)) Sonnenstunden dieses Wochenende · \(dest.driveMinutes) min Fahrt"
                : "\(String(format: "%.0f", dest.sunshineHoursTotal))h of sunshine this weekend · \(dest.driveMinutes) min drive",
            ctaLabel: language == .de ? "Sonnenziele →" : "See sunny spots →",
            iconName: "sun.max.fill"
        )
    }

    // MARK: - Fresh Snow

    private static func freshSnowNudge(
        destinations: [SnowDestination]?,
        language: AppLanguage
    ) -> Nudge? {
        guard let dests = destinations else { return nil }

        // Only nudge when a resort has > 30cm weekly snowfall
        let powdery = dests
            .filter { $0.snowfallWeekTotal > 30 }
            .sorted { $0.snowfallWeekTotal > $1.snowfallWeekTotal }
            .first

        guard let resort = powdery else { return nil }

        let resortName = resort.localizedName(language: language)
        return Nudge(
            id: "fresh-snow",
            type: .freshSnow,
            title: language == .de
                ? "Frischer Schnee in \(resortName)"
                : "Fresh snow in \(resortName)",
            subtitle: language == .de
                ? "\(String(format: "%.0f", resort.snowfallWeekTotal)) cm diese Woche · \(resort.driveMinutes) min Fahrt"
                : "\(String(format: "%.0f", resort.snowfallWeekTotal)) cm this week · \(resort.driveMinutes) min drive",
            ctaLabel: language == .de ? "Skigebiete →" : "See ski resorts →",
            iconName: "snowflake"
        )
    }

    // MARK: - Upcoming Event

    private static func upcomingEventNudge(
        events: [CityEvent]?,
        language: AppLanguage
    ) -> Nudge? {
        guard let events else { return nil }

        let cal = Calendar.current
        let now = Date()
        let threeDaysFromNow = cal.date(byAdding: .day, value: 3, to: now) ?? now

        // Find events starting in the next 3 days that are plannable
        let upcoming = events
            .filter { event in
                guard let startDate = DateHelpers.parseISO(event.startDate) else { return false }
                return startDate >= now && startDate <= threeDaysFromNow
            }
            .first

        guard let event = upcoming else { return nil }

        let eventName = event.localizedName(language: language)
        return Nudge(
            id: "upcoming-event-\(event.id)",
            type: .upcomingEvent,
            title: eventName,
            subtitle: language == .de
                ? "Bald in deiner Stadt"
                : "Coming up in your city",
            ctaLabel: language == .de ? "Events ansehen →" : "View events →",
            iconName: "calendar.badge.clock"
        )
    }
}
