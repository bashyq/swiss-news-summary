import Foundation
import CoreLocation

/// Client-side fallback agenda builder used when the Worker /agenda API fails or times out.
/// Selects one of 7 archetypes based on weather, session, and calendar, then fills slots
/// from loaded activity and restaurant data.
final class TemplateEngine {

    // MARK: - Public

    func buildAgenda(
        weather: Weather?,
        session: FamilySession,
        activities: [Activity],
        restaurants: [LunchSpot],
        cityEvents: [CityEvent],
        recentlyShown: Set<String>,
        language: AppLanguage,
        visitStore: VenueVisitStore = .shared,
        planDate: Date = Date()
    ) -> DayAgenda {
        let archetype = selectArchetype(
            weather: weather, session: session, cityEvents: cityEvents,
            planDate: planDate
        )
        return archetype.build(
            weather: weather,
            session: session,
            activities: activities,
            restaurants: restaurants,
            cityEvents: cityEvents,
            recentlyShown: recentlyShown,
            language: language,
            visitStore: visitStore,
            planDate: planDate
        )
    }

    // MARK: - Archetype Selection

    private func selectArchetype(
        weather: Weather?,
        session: FamilySession,
        cityEvents: [CityEvent],
        planDate: Date = Date()
    ) -> Archetype {
        let isBad = isBadWeatherDay(weather: weather)
        let isCold = (weather?.temperature ?? 15) < 10
        let isSunny = weather.map { !isCold && !$0.isBadWeather && $0.temperature >= 15 } ?? false
        let hasEvents = !cityEvents.filter({ $0.overlaps(with: planDate) }).isEmpty
        let isWeekend = Calendar.current.isDateInWeekend(planDate)

        switch (isBad, isCold, isSunny, session.soloParent, session.youngestAge, hasEvents && isWeekend) {
        case (true, _, _, _, _, _):          return .badWeatherHomeDay
        case (_, _, _, _, ..<3, _):          return .toddlerFocused
        case (_, _, _, _, _, true):          return .weekendSpecial
        case (_, true, _, _, _, _):          return .rainyMuseumDay   // Cold (<10°C) → all indoor
        case (_, _, true, _, _, _):          return .sunnyOutdoorDay
        case (_, false, false, _, _, _)
            where weather?.temperature ?? 15 >= 10: return .mixedIndoorOutdoor
        default:                              return .rainyMuseumDay
        }
    }

    // MARK: - Bad Weather Check

    private func isBadWeatherDay(weather: Weather?) -> Bool {
        guard let weather else { return false }
        let cold = weather.temperature < 10
        let badCode = [65, 67, 71, 73, 75, 77, 80, 81, 82, 85, 86, 95, 96, 99]
            .contains(weather.weatherCode)
        return cold && badCode
    }

    /// City events happening today.
    private func todayCityEvents(_ events: [CityEvent]) -> [CityEvent] {
        let today = Date()
        return events.filter { $0.overlaps(with: today) }
    }
}

// MARK: - Archetype

private enum Archetype {
    case sunnyOutdoorDay
    case rainyMuseumDay
    case mixedIndoorOutdoor
    case badWeatherHomeDay
    case freeDay
    case toddlerFocused
    case weekendSpecial

    func build(
        weather: Weather?,
        session: FamilySession,
        activities: [Activity],
        restaurants: [LunchSpot],
        cityEvents: [CityEvent],
        recentlyShown: Set<String>,
        language: AppLanguage,
        visitStore: VenueVisitStore,
        planDate: Date = Date()
    ) -> DayAgenda {
        let dateISO = ISO8601DateFormatter.string(from: planDate, timeZone: .current, formatOptions: [.withFullDate])
        let dayName = dayOfWeekName(planDate, language: language)
        let childNames = session.children.map(\.name).joined(separator: " & ")

        // Filter available activities (basic eligibility)
        let baseAvailable = activities.filter { activity in
            !activity.isStayHome
                && activity.isAvailable(on: planDate)
                && OpeningHoursParser.status(from: activity.openingHours, at: planDate) != .closed
                && (activity.season == nil || activity.isCurrentSeason)
        }

        // Apply FreshnessScorer to rank and filter the activity pool
        let available: [Activity]
        if let w = weather {
            let scored = baseAvailable
                .map { ($0, FreshnessScorer.scoreActivity($0, visitStore: visitStore, weather: w, date: planDate)) }
                .filter { $0.1.isEligible }
                .sorted { $0.1.compositeScore > $1.1.compositeScore }
                .map { $0.0 }
            // Pool exhaustion reset: if all scored-out, fall back to base pool
            available = scored.count >= 2 ? scored : baseAvailable
        } else {
            // No weather data — fall back to recentlyShown filtering
            let freshActivities = baseAvailable.filter { !recentlyShown.contains($0.id) }
            available = freshActivities.count >= 4 ? freshActivities : baseAvailable
        }

        let stayHome = activities.filter { $0.isStayHome }

        // Apply FreshnessScorer to restaurant pools
        let scoredLunch: [LunchSpot]
        let scoredDinner: [LunchSpot]
        let baseLunchPool = restaurants.filter {
            $0.permanentlyClosed != true && ($0.rating == nil || $0.rating! >= 3.5)
        }
        scoredLunch = baseLunchPool
            .map { ($0, FreshnessScorer.scoreRestaurant($0, slotType: .lunch, visitStore: visitStore, date: planDate)) }
            .filter { $0.1.isEligible }
            .sorted { $0.1.compositeScore > $1.1.compositeScore }
            .map { $0.0 }
        scoredDinner = baseLunchPool
            .map { ($0, FreshnessScorer.scoreRestaurant($0, slotType: .dinner, visitStore: visitStore, date: planDate)) }
            .filter { $0.1.isEligible }
            .sorted { $0.1.compositeScore > $1.1.compositeScore }
            .map { $0.0 }
        // Pool exhaustion reset for restaurants
        let openRestaurants = scoredLunch.count >= 2 ? scoredLunch : baseLunchPool.filter {
            $0.openForLunch == true
                || ($0.openForLunch == nil && OpeningHoursParser.status(from: $0.openingHours, at: planDate) != .closed)
        }
        let allRestaurants = scoredDinner.count >= 2 ? scoredDinner : baseLunchPool.filter {
            $0.openForDinner != false
                && OpeningHoursParser.status(from: $0.openingHours, at: planDate) != .closed
        }

        let weatherDesc = weather.map { "\(Int($0.temperature))° and \($0.description.lowercased())" } ?? "mild"

        switch self {
        case .badWeatherHomeDay:
            return buildBadWeatherDay(
                date: dateISO, dayName: dayName, childNames: childNames,
                weatherDesc: weatherDesc, session: session,
                available: available.filter(\.indoor),
                stayHome: stayHome,
                restaurants: openRestaurants.isEmpty ? allRestaurants : openRestaurants,
                language: language,
                planDate: planDate
            )
        case .sunnyOutdoorDay:
            return buildGoodWeatherDay(
                date: dateISO, dayName: dayName, childNames: childNames,
                weatherDesc: weatherDesc, session: session,
                morningPool: available.filter { !$0.indoor },
                afternoonPool: available.filter { !$0.indoor },
                restaurants: openRestaurants.isEmpty ? allRestaurants : openRestaurants,
                theme: language == .en
                    ? "Sunny \(dayName) with \(childNames)"
                    : "Sonniger \(dayName) mit \(childNames)",
                language: language,
                planDate: planDate
            )
        case .rainyMuseumDay:
            return buildGoodWeatherDay(
                date: dateISO, dayName: dayName, childNames: childNames,
                weatherDesc: weatherDesc, session: session,
                morningPool: available.filter(\.indoor),
                afternoonPool: available.filter(\.indoor),
                restaurants: openRestaurants.isEmpty ? allRestaurants : openRestaurants,
                theme: language == .en
                    ? "Cozy indoor \(dayName) with \(childNames)"
                    : "Gemütlicher Indoor-\(dayName) mit \(childNames)",
                language: language,
                planDate: planDate
            )
        case .mixedIndoorOutdoor:
            return buildGoodWeatherDay(
                date: dateISO, dayName: dayName, childNames: childNames,
                weatherDesc: weatherDesc, session: session,
                morningPool: available.filter { !$0.indoor },
                afternoonPool: available.filter(\.indoor),
                restaurants: openRestaurants.isEmpty ? allRestaurants : openRestaurants,
                theme: language == .en
                    ? "Mixed \(dayName) with \(childNames)"
                    : "\(dayName) mit \(childNames) — Mix",
                language: language,
                planDate: planDate
            )
        case .freeDay:
            let freeActivities = available.filter(\.isFree)
            return buildGoodWeatherDay(
                date: dateISO, dayName: dayName, childNames: childNames,
                weatherDesc: weatherDesc, session: session,
                morningPool: freeActivities,
                afternoonPool: freeActivities,
                restaurants: openRestaurants.isEmpty ? allRestaurants : openRestaurants,
                theme: language == .en
                    ? "Free day with \(childNames)"
                    : "Gratis-Tag mit \(childNames)",
                language: language,
                planDate: planDate
            )
        case .toddlerFocused:
            return buildToddlerDay(
                date: dateISO, dayName: dayName, childNames: childNames,
                weatherDesc: weatherDesc, session: session,
                available: available,
                restaurants: openRestaurants.isEmpty ? allRestaurants : openRestaurants,
                language: language,
                planDate: planDate
            )
        case .weekendSpecial:
            let todayEvents = cityEvents.filter { $0.overlaps(with: planDate) }
            return buildWeekendSpecialDay(
                date: dateISO, dayName: dayName, childNames: childNames,
                weatherDesc: weatherDesc, session: session,
                available: available,
                cityEvents: todayEvents,
                restaurants: openRestaurants.isEmpty ? allRestaurants : openRestaurants,
                language: language,
                planDate: planDate
            )
        }
    }

    // MARK: - Good Weather Day (4 slots)

    private func buildGoodWeatherDay(
        date: String, dayName: String, childNames: String,
        weatherDesc: String, session: FamilySession,
        morningPool: [Activity], afternoonPool: [Activity],
        restaurants: [LunchSpot],
        theme: String, language: AppLanguage,
        planDate: Date
    ) -> DayAgenda {
        let morning = pickActivity(from: morningPool, excluding: [], session: session, language: language)
        let afternoon = pickActivity(
            from: afternoonPool, excluding: [morning?.id].compactMap { $0 },
            session: session, language: language
        )

        let lunchSpot = pickRestaurant(near: morning, from: restaurants, language: language)
        let dinnerSpot = pickRestaurant(near: afternoon, from: restaurants, excluding: lunchSpot?.id, language: language)

        var slots: [AgendaSlot] = []

        if let act = morning {
            let swaps = buildSwaps(from: morningPool, excluding: [act.id, afternoon?.id].compactMap { $0 }, language: language)
            slots.append(makeActivitySlot(
                id: "morning", time: "10:00", activity: act,
                timeLabel: language == .en ? "🌅 Morning · Activity" : "🌅 Morgen · Aktivität",
                travelNote: language == .en ? "From home" : "Von zu Hause",
                swaps: swaps, session: session, language: language, planDate: planDate
            ))
        }

        if let spot = lunchSpot {
            let travel = travelBetween(morning, restaurantLat: spot.lat, restaurantLon: spot.lon)
            let swaps = buildRestaurantSwaps(from: restaurants, excluding: [spot.id, dinnerSpot?.id].compactMap { $0 }, near: morning, language: language)
            slots.append(makeLunchSlot(
                spot: spot, time: "11:45", travelNote: travel, swaps: swaps, language: language, planDate: planDate
            ))
        }

        if let act = afternoon {
            let travel = travelBetweenRestaurant(lunchSpot, activity: act)
            let swaps = buildSwaps(from: afternoonPool, excluding: [morning?.id, act.id].compactMap { $0 }, language: language)
            slots.append(makeActivitySlot(
                id: "afternoon", time: "13:30", activity: act,
                timeLabel: language == .en ? "☀️ Afternoon · Activity" : "☀️ Nachmittag · Aktivität",
                travelNote: travel, swaps: swaps, session: session, language: language, planDate: planDate
            ))
        }

        if let spot = dinnerSpot {
            let travel = travelBetween(afternoon, restaurantLat: spot.lat, restaurantLon: spot.lon)
            let swaps = buildRestaurantSwaps(from: restaurants, excluding: [lunchSpot?.id, spot.id].compactMap { $0 }, near: afternoon, language: language)
            slots.append(makeDinnerSlot(
                spot: spot, time: "18:00", travelNote: travel, swaps: swaps, language: language, planDate: planDate
            ))
        }

        return DayAgenda(
            date: date, theme: theme, weatherNote: weatherDesc,
            badWeatherMode: false, slots: slots, homeActivities: nil
        )
    }

    // MARK: - Bad Weather Day

    private func buildBadWeatherDay(
        date: String, dayName: String, childNames: String,
        weatherDesc: String, session: FamilySession,
        available: [Activity], stayHome: [Activity],
        restaurants: [LunchSpot], language: AppLanguage,
        planDate: Date
    ) -> DayAgenda {
        let theme = language == .en
            ? "Stay-home \(dayName) with \(childNames)"
            : "Zuhause-\(dayName) mit \(childNames)"

        // Home activities from stay-home pool
        let homeActivities = buildHomeActivities(from: stayHome, session: session, language: language)

        // Single afternoon outing (indoor)
        let afternoon = pickActivity(from: available, excluding: [], session: session, language: language)
        let dinnerSpot = pickRestaurant(near: afternoon, from: restaurants, language: language)

        var slots: [AgendaSlot] = []

        if let act = afternoon {
            let swaps = buildSwaps(from: available, excluding: [act.id], language: language)
            slots.append(makeActivitySlot(
                id: "afternoon", time: "14:30", activity: act,
                timeLabel: language == .en ? "🌨 Afternoon outing" : "🌨 Nachmittags-Ausflug",
                travelNote: nil, swaps: swaps, session: session, language: language, planDate: planDate
            ))
        }

        if let spot = dinnerSpot {
            let travel = travelBetween(afternoon, restaurantLat: spot.lat, restaurantLon: spot.lon)
            let swaps = buildRestaurantSwaps(from: restaurants, excluding: [spot.id], near: afternoon, language: language)
            slots.append(makeDinnerSlot(
                spot: spot, time: "17:30", travelNote: travel, swaps: swaps, language: language, planDate: planDate
            ))
        }

        return DayAgenda(
            date: date, theme: theme, weatherNote: weatherDesc,
            badWeatherMode: true, slots: slots, homeActivities: homeActivities
        )
    }

    // MARK: - Toddler Day (morning + lunch + afternoon + early dinner)

    private func buildToddlerDay(
        date: String, dayName: String, childNames: String,
        weatherDesc: String, session: FamilySession,
        available: [Activity], restaurants: [LunchSpot],
        language: AppLanguage,
        planDate: Date
    ) -> DayAgenda {
        let theme = language == .en
            ? "Toddler-friendly \(dayName) with \(childNames)"
            : "Kleinkind-\(dayName) mit \(childNames)"

        let isCold = available.allSatisfy(\.indoor)
        let morning = pickActivity(from: available, excluding: [], session: session, language: language)
        let afternoon = pickActivity(
            from: available, excluding: [morning?.id].compactMap { $0 },
            session: session, language: language
        )
        let lunchSpot = pickRestaurant(near: morning, from: restaurants, language: language)
        let dinnerSpot = pickRestaurant(near: afternoon, from: restaurants, excluding: lunchSpot?.id, language: language)

        var slots: [AgendaSlot] = []

        if let act = morning {
            let swaps = buildSwaps(from: available, excluding: [act.id, afternoon?.id].compactMap { $0 }, language: language)
            slots.append(makeActivitySlot(
                id: "morning", time: "09:30", activity: act,
                timeLabel: language == .en ? "🌅 Morning · Activity" : "🌅 Morgen · Aktivität",
                travelNote: nil, swaps: swaps, session: session, language: language, planDate: planDate
            ))
        }

        if let spot = lunchSpot {
            let travel = travelBetween(morning, restaurantLat: spot.lat, restaurantLon: spot.lon)
            let swaps = buildRestaurantSwaps(from: restaurants, excluding: [spot.id, dinnerSpot?.id].compactMap { $0 }, near: morning, language: language)
            slots.append(makeLunchSlot(
                spot: spot, time: "11:30", travelNote: travel, swaps: swaps, language: language, planDate: planDate
            ))
        }

        if let act = afternoon {
            let travel = travelBetweenRestaurant(lunchSpot, activity: act)
            let swaps = buildSwaps(from: available, excluding: [morning?.id, act.id].compactMap { $0 }, language: language)
            slots.append(makeActivitySlot(
                id: "afternoon", time: "14:00", activity: act,
                timeLabel: language == .en ? "☀️ Afternoon · Activity" : "☀️ Nachmittag · Aktivität",
                travelNote: travel, swaps: swaps, session: session, language: language, planDate: planDate
            ))
        }

        if let spot = dinnerSpot {
            let travel = travelBetween(afternoon ?? morning, restaurantLat: spot.lat, restaurantLon: spot.lon)
            let swaps = buildRestaurantSwaps(from: restaurants, excluding: [lunchSpot?.id, spot.id].compactMap { $0 }, near: afternoon, language: language)
            slots.append(makeDinnerSlot(
                spot: spot, time: "17:30", travelNote: travel, swaps: swaps, language: language, planDate: planDate
            ))
        }

        return DayAgenda(
            date: date, theme: theme, weatherNote: weatherDesc,
            badWeatherMode: isCold, slots: slots, homeActivities: nil
        )
    }

    // MARK: - Weekend Special (with city events)

    private func buildWeekendSpecialDay(
        date: String, dayName: String, childNames: String,
        weatherDesc: String, session: FamilySession,
        available: [Activity], cityEvents: [CityEvent],
        restaurants: [LunchSpot], language: AppLanguage,
        planDate: Date
    ) -> DayAgenda {
        let theme = language == .en
            ? "Weekend special with \(childNames)"
            : "Wochenend-Special mit \(childNames)"

        // Use a city event as the morning if one exists
        let event = cityEvents.first { $0.toddlerFriendly || session.youngestAge >= 4 }

        var slots: [AgendaSlot] = []

        if let event {
            slots.append(AgendaSlot(
                id: "morning",
                time: "10:00",
                type: .activity,
                venueName: event.localizedName(language: language),
                venueId: event.id,
                reason: language == .en
                    ? "Special event happening today — don't miss it!"
                    : "Besonderes Event heute — nicht verpassen!",
                durationDisplay: nil,
                travelNote: nil,
                tags: [
                    event.toddlerFriendly ? (language == .en ? "Kid-friendly" : "Kinderfreundlich") : "",
                    event.free ? (language == .en ? "Free" : "Gratis") : ""
                ].filter { !$0.isEmpty },
                swaps: [],
                slotDate: AgendaSlot.resolveSlotDate(time: "10:00", planDate: planDate)
            ))
        } else if let act = pickActivity(from: available, excluding: [], session: session, language: language) {
            let swaps = buildSwaps(from: available, excluding: [act.id], language: language)
            slots.append(makeActivitySlot(
                id: "morning", time: "10:00", activity: act,
                timeLabel: language == .en ? "🌅 Morning · Activity" : "🌅 Morgen · Aktivität",
                travelNote: nil, swaps: swaps, session: session, language: language, planDate: planDate
            ))
        }

        // Lunch near morning
        if let spot = pickRestaurant(near: nil, from: restaurants, language: language) {
            let swaps = buildRestaurantSwaps(from: restaurants, excluding: [spot.id], near: nil, language: language)
            slots.append(makeLunchSlot(
                spot: spot, time: "12:00", travelNote: nil, swaps: swaps, language: language, planDate: planDate
            ))
        }

        // Afternoon activity
        let usedIds = slots.compactMap(\.venueId)
        let afternoon = pickActivity(from: available, excluding: usedIds, session: session, language: language)
        if let act = afternoon {
            let swaps = buildSwaps(from: available, excluding: usedIds + [act.id], language: language)
            slots.append(makeActivitySlot(
                id: "afternoon", time: "14:00", activity: act,
                timeLabel: language == .en ? "☀️ Afternoon · Activity" : "☀️ Nachmittag · Aktivität",
                travelNote: nil, swaps: swaps, session: session, language: language, planDate: planDate
            ))
        }

        // Dinner
        let lunchId = slots.first(where: { $0.type == .lunch })?.venueId
        let dinnerSpot = pickRestaurant(near: afternoon ?? pickActivity(from: available, excluding: [], session: session, language: language), from: restaurants, excluding: lunchId, language: language)
        if let spot = dinnerSpot {
            let travel = travelBetween(afternoon, restaurantLat: spot.lat, restaurantLon: spot.lon)
            let swaps = buildRestaurantSwaps(from: restaurants, excluding: [lunchId, spot.id].compactMap { $0 }, near: afternoon, language: language)
            slots.append(makeDinnerSlot(
                spot: spot, time: "18:00", travelNote: travel, swaps: swaps, language: language, planDate: planDate
            ))
        }

        return DayAgenda(
            date: date, theme: theme, weatherNote: weatherDesc,
            badWeatherMode: false, slots: slots, homeActivities: nil
        )
    }

    // MARK: - Slot Builders

    private func makeActivitySlot(
        id: String, time: String, activity: Activity,
        timeLabel: String, travelNote: String?,
        swaps: [AgendaSlot.SwapOption], session: FamilySession,
        language: AppLanguage, planDate: Date = Date()
    ) -> AgendaSlot {
        let name = activity.localizedName(language: language)
        let tags = buildActivityTags(activity, language: language)
        let reason = buildActivityReason(activity, session: session, language: language)

        return AgendaSlot(
            id: id, time: time, type: .activity,
            venueName: name, venueId: activity.id,
            reason: reason, durationDisplay: activity.duration,
            travelNote: travelNote, tags: tags, swaps: swaps,
            durationMinutes: 100,
            slotDate: AgendaSlot.resolveSlotDate(time: time, planDate: planDate)
        )
    }

    private func makeLunchSlot(
        spot: LunchSpot, time: String, travelNote: String?,
        swaps: [AgendaSlot.SwapOption], language: AppLanguage,
        planDate: Date = Date()
    ) -> AgendaSlot {
        let cuisine = spot.cuisineDisplay
        let price = String(repeating: "$", count: spot.priceTier)
        var tags = [language == .en ? "🏠 Indoor" : "🏠 Indoor"]
        tags.append("~CHF \(spot.priceTier * 15)–\(spot.priceTier * 25)")
        if spot.openForLunch == true {
            tags.append(language == .en ? "Open for lunch" : "Zum Mittagessen geöffnet")
        }

        return AgendaSlot(
            id: "lunch", time: time, type: .lunch,
            venueName: spot.name, venueId: spot.id,
            reason: language == .en
                ? "\(cuisine) restaurant, \(price). Good for families."
                : "\(cuisine)-Restaurant, \(price). Gut für Familien.",
            durationDisplay: nil, travelNote: travelNote,
            tags: tags, swaps: swaps,
            durationMinutes: 90,
            slotDate: AgendaSlot.resolveSlotDate(time: time, planDate: planDate)
        )
    }

    private func makeDinnerSlot(
        spot: LunchSpot, time: String, travelNote: String?,
        swaps: [AgendaSlot.SwapOption], language: AppLanguage,
        planDate: Date = Date()
    ) -> AgendaSlot {
        let cuisine = spot.cuisineDisplay
        let price = String(repeating: "$", count: spot.priceTier)

        return AgendaSlot(
            id: "dinner", time: time, type: .dinner,
            venueName: spot.name, venueId: spot.id,
            reason: language == .en
                ? "\(cuisine), \(price). Early seating works well with kids."
                : "\(cuisine), \(price). Früher Tisch passt gut mit Kindern.",
            durationDisplay: nil, travelNote: travelNote,
            tags: ["🏠 Indoor", "~CHF \(spot.priceTier * 20)–\(spot.priceTier * 35)"],
            swaps: swaps,
            durationMinutes: 120,
            slotDate: AgendaSlot.resolveSlotDate(time: time, planDate: planDate)
        )
    }

    // MARK: - Home Activities (Bad Weather)

    private func buildHomeActivities(
        from stayHome: [Activity], session: FamilySession, language: AppLanguage
    ) -> HomeActivities {
        let kitchen = stayHome.filter { $0.subcategory?.lowercased() == "kitchen" }
        let art = stayHome.filter { $0.subcategory?.lowercased() == "art" }
        let sensory = stayHome.filter { $0.subcategory?.lowercased() == "sensory" }
        let pretend = stayHome.filter { $0.subcategory?.lowercased() == "pretend" }

        // Baking — prefer kitchen, fallback to sensory
        let bakingSource = (kitchen + sensory).shuffled().first
        let baking: HomeActivity? = bakingSource.map { act in
            HomeActivity(
                label: language == .en ? "MORNING · BAKING" : "MORGENS · BACKEN",
                idea: act.localizedName(language: language),
                emoji: "🥐",
                reason: act.localizedDescription(language: language),
                durationDisplay: "~45 min",
                ageNote: session.youngestAge < 3 ? (language == .en ? "With help" : "Mit Hilfe") : nil
            )
        }

        // Craft — prefer art, fallback to pretend
        let craftSource = (art + pretend).shuffled().first
        let craft: HomeActivity? = craftSource.map { act in
            HomeActivity(
                label: language == .en ? "AFTERNOON · CRAFT" : "NACHMITTAG · BASTELN",
                idea: act.localizedName(language: language),
                emoji: "✂️",
                reason: act.localizedDescription(language: language),
                durationDisplay: "~30 min",
                ageNote: nil
            )
        }

        // Movie — static pick
        let movie = MoviePick(
            label: language == .en ? "AFTER LUNCH · SCREEN TIME" : "NACH DEM MITTAGESSEN · BILDSCHIRMZEIT",
            title: language == .en ? "Pippi Longstocking (1969)" : "Pippi Langstrumpf (1969)",
            emoji: "🎬",
            reason: language == .en
                ? "A Swiss-dubbed classic, perfect for toddlers."
                : "Ein Schweizer Synchron-Klassiker, perfekt für Kleinkinder.",
            platform: "SRF Play Kids",
            durationMinutes: 99,
            isFree: true
        )

        return HomeActivities(baking: baking, movie: movie, craft: craft)
    }

    // MARK: - Picking Helpers

    private func pickActivity(
        from pool: [Activity], excluding: [String],
        session: FamilySession, language: AppLanguage
    ) -> Activity? {
        var filtered = pool.filter { !excluding.contains($0.id) }

        // Age-appropriate first
        let ageFiltered = filtered.filter { act in
            let min = act.minAge ?? 0
            let max = act.maxAge ?? 99
            return session.youngestAge >= min && session.youngestAge <= max
        }
        if !ageFiltered.isEmpty { filtered = ageFiltered }

        // Pool is pre-sorted by FreshnessScorer composite score — pick randomly
        // from top candidates to add variety across rebuilds
        let topCount = min(filtered.count, 5)
        guard topCount > 0 else { return nil }
        return filtered[Int.random(in: 0..<topCount)]
    }

    private func pickRestaurant(
        near activity: Activity?, from restaurants: [LunchSpot],
        excluding: String? = nil, language: AppLanguage
    ) -> LunchSpot? {
        var pool = restaurants
        if let excluding { pool.removeAll { $0.id == excluding } }

        // Sort by distance from activity if available
        if let lat = activity?.lat, let lon = activity?.lon {
            let loc = CLLocation(latitude: lat, longitude: lon)
            pool.sort { a, b in
                let distA = CLLocation(latitude: a.lat, longitude: a.lon).distance(from: loc)
                let distB = CLLocation(latitude: b.lat, longitude: b.lon).distance(from: loc)
                return distA < distB
            }
        } else {
            // Sort by rating
            pool.sort { ($0.rating ?? 0) > ($1.rating ?? 0) }
        }

        // Pick randomly from top candidates for variety
        let topCount = min(pool.count, 5)
        guard topCount > 0 else { return nil }
        return pool[Int.random(in: 0..<topCount)]
    }

    // MARK: - Swap Builders

    private func buildSwaps(
        from pool: [Activity], excluding: [String], language: AppLanguage
    ) -> [AgendaSlot.SwapOption] {
        let candidates = pool.filter { !excluding.contains($0.id) }.shuffled()
        return Array(candidates.prefix(3)).map { act in
            let freeTag = act.isFree ? (language == .en ? "Free" : "Gratis") : ""
            let indoorTag = act.indoor ? "Indoor" : "Outdoor"
            let detail = [freeTag, indoorTag].filter { !$0.isEmpty }.joined(separator: " · ")
            return AgendaSlot.SwapOption(
                id: act.id,
                venueName: act.localizedName(language: language),
                detail: detail,
                venueId: act.id
            )
        }
    }

    private func buildRestaurantSwaps(
        from restaurants: [LunchSpot], excluding: [String],
        near activity: Activity?, language: AppLanguage
    ) -> [AgendaSlot.SwapOption] {
        var pool = restaurants.filter { !excluding.contains($0.id) }

        if let lat = activity?.lat, let lon = activity?.lon {
            let loc = CLLocation(latitude: lat, longitude: lon)
            pool.sort { a, b in
                CLLocation(latitude: a.lat, longitude: a.lon).distance(from: loc) <
                CLLocation(latitude: b.lat, longitude: b.lon).distance(from: loc)
            }
        }

        return Array(pool.prefix(3)).map { spot in
            let price = String(repeating: "$", count: spot.priceTier)
            return AgendaSlot.SwapOption(
                id: spot.id,
                venueName: spot.name,
                detail: "\(spot.cuisineDisplay) · \(price)",
                venueId: spot.id
            )
        }
    }

    // MARK: - Tag Builders

    private func buildActivityTags(_ activity: Activity, language: AppLanguage) -> [String] {
        var tags: [String] = []
        tags.append(activity.indoor
            ? (language == .en ? "🏠 Indoor" : "🏠 Indoor")
            : (language == .en ? "🌿 Outdoor" : "🌿 Outdoor"))
        if !activity.duration.isEmpty {
            tags.append("⏱ \(activity.duration)")
        }
        if activity.isFree {
            tags.append(language == .en ? "Free" : "Gratis")
        }
        if !activity.ageRange.isEmpty {
            tags.append(activity.ageRange)
        }
        return tags
    }

    private func buildActivityReason(
        _ activity: Activity, session: FamilySession, language: AppLanguage
    ) -> String {
        let desc = activity.localizedDescription(language: language)
        // Truncate to ~100 chars for the reason field
        if desc.count > 120 {
            let idx = desc.index(desc.startIndex, offsetBy: 117)
            return String(desc[..<idx]) + "..."
        }
        return desc
    }

    // MARK: - Travel Helpers

    private func travelBetween(_ activity: Activity?, restaurantLat: Double, restaurantLon: Double) -> String? {
        guard let lat = activity?.lat, let lon = activity?.lon else { return nil }
        return ZurichArea.travelDescription(fromLat: lat, fromLon: lon, toLat: restaurantLat, toLon: restaurantLon)
    }

    private func travelBetweenRestaurant(_ restaurant: LunchSpot?, activity: Activity?) -> String? {
        guard let restaurant, let lat = activity?.lat, let lon = activity?.lon else { return nil }
        return ZurichArea.travelDescription(fromLat: restaurant.lat, fromLon: restaurant.lon, toLat: lat, toLon: lon)
    }

    private func dayOfWeekName(_ date: Date, language: AppLanguage) -> String {
        let formatter = DateFormatter()
        formatter.locale = language == .de ? Locale(identifier: "de_CH") : Locale(identifier: "en_US")
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }
}
