import Foundation

/// Sample data for SwiftUI Previews — mirrors real API response shapes
enum PreviewData {

    // MARK: - Weather

    static let weather = Weather(
        temperature: 5,
        description: "Partly cloudy",
        weatherCode: 2,
        windSpeed: 12,
        hourly: (6...22).map { hour in
            HourlyWeather(
                time: "2026-02-21T\(String(format: "%02d", hour)):00",
                temperature: Double(hour < 14 ? hour - 2 : 24 - hour),
                weatherCode: hour < 10 ? 45 : (hour < 17 ? 2 : 3)
            )
        }
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
        trending: TrendingTopic(topic: "SNB Interest Rates", topicDE: "SNB Leitzins", headline: nil, headlineDE: nil),
        briefing: Briefing(topStory: "SNB holds rates", topStoryDE: "SNB hält Zinsen", suggestedActivity: "Visit the Money Museum", suggestedActivityDE: "Besuchen Sie das Geldmuseum"),
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
        subcategory: nil,
        materials: nil,
        materialsDE: nil
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
        subcategory: "sensory",
        materials: ["Rice or pasta", "Small toys", "Container"],
        materialsDE: ["Reis oder Nudeln", "Kleine Spielzeuge", "Behälter"]
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
            SunshineDayForecast(date: "2026-02-20", weatherCode: 1, tempMax: 12, tempMin: 3, sunshineHours: 7.2, precipMm: 0, sunnyHours: [8,9,10,11,12,13,14,15,16], description: SunshineDescription(en: "Mainly sunny", de: "Überwiegend sonnig")),
            SunshineDayForecast(date: "2026-02-21", weatherCode: 2, tempMax: 11, tempMin: 2, sunshineHours: 6.0, precipMm: 0, sunnyHours: [9,10,11,12,13,14,15], description: nil),
            SunshineDayForecast(date: "2026-02-22", weatherCode: 3, tempMax: 9, tempMin: 4, sunshineHours: 3.5, precipMm: 2, sunnyHours: [10,11,12,13], description: nil),
        ],
        sunshineHoursTotal: 16.7,
        isBaseline: false
    )

    // MARK: - Snow

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
        forecast: (0..<7).map { i in
            SnowDayForecast(
                date: "2026-02-\(16 + i)",
                snowfallCm: [5.2, 0, 12.3, 8.1, 0, 3.5, 0][i],
                weatherCode: [73, 2, 75, 73, 1, 71, 2][i],
                tempMax: [-2, 0, -4, -3, 1, -1, 0][i],
                tempMin: [-8, -5, -10, -8, -4, -6, -5][i]
            )
        },
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
        vegetarian: false,
        phone: nil,
        website: "https://www.zeughauskeller.ch"
    )
}
