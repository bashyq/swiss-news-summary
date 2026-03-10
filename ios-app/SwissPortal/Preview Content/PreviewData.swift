import Foundation

/// Sample data for SwiftUI Previews — mirrors real API response shapes
enum PreviewData {

    // MARK: - Weather

    private static let sampleHourly: [HourlyWeather] = [
        HourlyWeather(time: "2026-02-21T06:00", temperature: 4, weatherCode: 45),
        HourlyWeather(time: "2026-02-21T08:00", temperature: 6, weatherCode: 45),
        HourlyWeather(time: "2026-02-21T10:00", temperature: 8, weatherCode: 2),
        HourlyWeather(time: "2026-02-21T12:00", temperature: 10, weatherCode: 2),
        HourlyWeather(time: "2026-02-21T14:00", temperature: 10, weatherCode: 2),
        HourlyWeather(time: "2026-02-21T16:00", temperature: 8, weatherCode: 3),
        HourlyWeather(time: "2026-02-21T18:00", temperature: 6, weatherCode: 3),
        HourlyWeather(time: "2026-02-21T20:00", temperature: 4, weatherCode: 3),
    ]

    static let weather = Weather(
        temperature: 5,
        description: "Partly cloudy",
        weatherCode: 2,
        windSpeed: 12,
        hourly: sampleHourly
    )

    // MARK: - Transport

    static let transport = Transport(
        delays: [
            TrainDelay(line: "IC 8", destination: "Bern", delay: 5, scheduledTime: "14:02"),
            TrainDelay(line: "S3", destination: "Effretikon", delay: 12, scheduledTime: "14:15"),
        ],
        summary: TransportSummary(totalDelayed: 2, maxDelay: 12, status: "minor")
    )

    // MARK: - News

    static let newsItem = NewsItem(
        headline: "Swiss National Bank holds rates steady",
        headlineDE: "Schweizerische Nationalbank hält Zinsen stabil",
        summary: "The SNB maintained its key interest rate at 0.5%, citing stable inflation outlook.",
        summaryDE: "Die SNB hält den Leitzins bei 0.5%, unter Berufung auf stabile Inflationsaussichten.",
        detail: "In its quarterly monetary policy assessment, the Swiss National Bank decided to keep rates unchanged.",
        detailDE: nil,
        source: "NZZ",
        url: "https://www.nzz.ch",
        sentiment: "neutral",
        publishedAt: "2026-02-21T10:00:00Z"
    )

    static let categories = NewsCategories(
        topStories: [newsItem],
        disruptions: [
            NewsItem(headline: "A1 blocked near Winterthur", headlineDE: "A1 bei Winterthur gesperrt", summary: "Major accident causes traffic jam.", summaryDE: "Schwerer Unfall verursacht Stau.", detail: nil, detailDE: nil, source: "20 Minuten", url: nil, sentiment: "negative", publishedAt: "2026-02-21T08:30:00Z")
        ],
        events: [],
        politics: [newsItem],
        culture: [],
        local: []
    )

    static let newsResponse = NewsResponse(
        weather: weather,
        transport: transport,
        holidays: [
            Holiday(name: "Easter Monday", nameDE: "Ostermontag", daysUntil: 45, date: "2026-04-06")
        ],
        schoolHolidays: [
            SchoolHoliday(name: "Sport holidays", nameDE: "Sportferien", startDate: "2026-02-09", endDate: "2026-02-21", type: "schoolHoliday")
        ],
        history: HistoryFact(year: 1958, event: "The Swiss Pavilion opened at Expo 58 in Brussels", eventDE: "Der Schweizer Pavillon wurde an der Expo 58 in Brüssel eröffnet"),
        categories: categories,
        trending: TrendingTopic(topic: "SNB Interest Rates", topicDE: "SNB Leitzins", headline: nil, headlineDE: nil, url: nil),
        briefing: Briefing(topStory: BriefingItem(headline: "SNB holds rates", summary: "Summary of top story", source: "NZZ", url: "https://www.nzz.ch", sentiment: "neutral"), dailyPick: DailyPick(activityId: "zoo-zurich", name: "Visit Zoo Zürich", nameDE: "Zoo Zürich besuchen", reason: "Perfect weather for a walk among the animals", reasonDE: "Perfektes Wetter für einen Spaziergang bei den Tieren", emoji: "🦁", indoor: false, category: "animals")),
        weekendBrief: WeekendBrief(saturday: WeekendBriefDay(date: "2026-02-21", weatherCode: 1, tempMax: 8, tempMin: 2, description: "Mostly sunny"), sunday: WeekendBriefDay(date: "2026-02-22", weatherCode: 3, tempMax: 6, tempMin: 1, description: "Overcast"), events: [WeekendBriefEvent(name: "Fasnacht", nameDE: "Fasnacht", startDate: "2026-02-20", endDate: "2026-02-22", toddlerFriendly: true, free: true)], satDate: "2026-02-21", sunDate: "2026-02-22"),
        city: CityInfo(id: "zurich", name: "Zürich"),
        timestamp: "2026-02-21T12:00:00Z"
    )

    // MARK: - Activities

    static let activity = Activity(
        id: "zoo-zurich",
        name: "Zoo Zürich",
        nameDE: "Zoo Zürich",
        description: "One of the best zoos in Europe with Masoala Rainforest hall.",
        descriptionDE: "Einer der besten Zoos Europas mit Masoala-Regenwaldhalle.",
        indoor: false,
        ageRange: "2-5 years",
        duration: "2-4 hours",
        price: "CHF 29 adults, kids under 6 free",
        priceDE: "CHF 29 Erwachsene, Kinder unter 6 gratis",
        url: "https://www.zoo.ch",
        lat: 47.3849,
        lon: 8.5743,
        category: "animals",
        minAge: 2,
        maxAge: 5,
        season: nil,
        free: nil,
        recurring: nil,
        stayHome: nil,
        availableMonths: nil,
        subcategory: nil,
        materials: nil,
        materialsDE: nil,
        featured: true,
        addedDate: nil
    )

    static let stayHomeActivity = Activity(
        id: "sensory-bin",
        name: "Sensory Bin Exploration",
        nameDE: "Sensorik-Kiste",
        description: "Fill a bin with rice, pasta, or beans and hide small toys to find.",
        descriptionDE: "Füllen Sie eine Kiste mit Reis, Nudeln oder Bohnen und verstecken Sie kleine Spielzeuge.",
        indoor: true,
        ageRange: "2-5 years",
        duration: "30-60 min",
        price: "Free",
        priceDE: "Gratis",
        url: nil,
        lat: nil,
        lon: nil,
        category: "sensory",
        minAge: 2,
        maxAge: 5,
        season: nil,
        free: true,
        recurring: nil,
        stayHome: true,
        availableMonths: nil,
        subcategory: "sensory",
        materials: "Rice or pasta, Small toys, Container",
        materialsDE: "Reis oder Nudeln, Kleine Spielzeuge, Behälter",
        featured: nil,
        addedDate: nil
    )

    static let cityEvent = CityEvent(
        id: "zh-sechselaeuten",
        name: "Sechseläuten",
        nameDE: "Sechseläuten",
        city: "zurich",
        startDate: "2026-04-20",
        endDate: "2026-04-20",
        description: "Zürich's spring festival with the burning of the Böögg snowman.",
        descriptionDE: "Zürcher Frühlingsfest mit der Verbrennung des Böögg.",
        toddlerFriendly: true,
        free: true,
        url: "https://www.sechselaeuten.ch/"
    )

    // MARK: - Sunshine

    static let sunshineDestination = SunshineDestination(
        id: "lugano",
        name: "Lugano",
        nameDE: "Lugano",
        lat: 46.0037,
        lon: 8.9511,
        region: "Ticino",
        regionDE: "Tessin",
        driveMinutes: 150,
        forecast: [
            SunshineDayForecast(date: "2026-02-20", weatherCode: 1, tempMax: 12, tempMin: 3, sunshineHours: 7.2, precipMm: 0, sunnyHours: [8,9,10,11,12,13,14,15,16], description: "Mainly sunny"),
            SunshineDayForecast(date: "2026-02-21", weatherCode: 2, tempMax: 11, tempMin: 2, sunshineHours: 6.0, precipMm: 0, sunnyHours: [9,10,11,12,13,14,15], description: "Partly cloudy"),
            SunshineDayForecast(date: "2026-02-22", weatherCode: 3, tempMax: 9, tempMin: 4, sunshineHours: 3.5, precipMm: 2, sunnyHours: [10,11,12,13], description: "Overcast"),
        ],
        sunshineHoursTotal: 16.7,
        isBaseline: false,
        highlights: nil
    )

    // MARK: - Snow

    private static let sampleSnowForecast: [SnowDayForecast] = [
        SnowDayForecast(date: "2026-02-16", snowfallCm: 5.2, weatherCode: 73, tempMax: -2, tempMin: -8, description: "Moderate snow"),
        SnowDayForecast(date: "2026-02-17", snowfallCm: 0, weatherCode: 2, tempMax: 0, tempMin: -5, description: "Partly cloudy"),
        SnowDayForecast(date: "2026-02-18", snowfallCm: 12.3, weatherCode: 75, tempMax: -4, tempMin: -10, description: "Heavy snow"),
        SnowDayForecast(date: "2026-02-19", snowfallCm: 8.1, weatherCode: 73, tempMax: -3, tempMin: -8, description: "Moderate snow"),
        SnowDayForecast(date: "2026-02-20", snowfallCm: 0, weatherCode: 1, tempMax: 1, tempMin: -4, description: "Mainly clear"),
        SnowDayForecast(date: "2026-02-21", snowfallCm: 3.5, weatherCode: 71, tempMax: -1, tempMin: -6, description: "Light snow"),
        SnowDayForecast(date: "2026-02-22", snowfallCm: 0, weatherCode: 2, tempMax: 0, tempMin: -5, description: "Partly cloudy"),
    ]

    static let snowDestination = SnowDestination(
        id: "zermatt",
        name: "Zermatt",
        nameDE: "Zermatt",
        lat: 46.0207,
        lon: 7.7491,
        region: "Valais",
        regionDE: "Wallis",
        driveMinutes: 195,
        altitude: 1620,
        forecast: sampleSnowForecast,
        snowfallWeekTotal: 29.1,
        snowDepthCm: 145
    )

    // MARK: - Lunch

    static let lunchSpot = LunchSpot(
        id: "restaurant-zeughauskeller",
        name: "Zeughauskeller",
        lat: 47.3715,
        lon: 8.5393,
        cuisine: "Swiss",
        cuisineCategory: "swiss",
        wheelchair: "yes",
        outdoorSeating: true,
        takeaway: false,
        openingHours: "Mo-Sa 11:00-23:00",
        openForLunch: true,
        vegetarian: nil,
        vegan: nil,
        phone: nil,
        website: "https://www.zeughauskeller.ch",
        amenity: "restaurant"
    )
}
