import XCTest
@testable import TodayInSwitzerland

/// Tests that all Codable models decode correctly from JSON
/// matching the actual Cloudflare Worker API response shapes.
final class ModelDecodingTests: XCTestCase {

    // MARK: - News Response

    func testDecodeNewsResponse() throws {
        let json = """
        {
            "weather": {"temperature": 5.2, "description": "Partly cloudy", "weatherCode": 2, "windSpeed": 12.5, "hourly": []},
            "transport": {"delays": [{"line": "IC 8", "destination": "Bern", "delay": 5, "scheduledTime": "14:02"}], "summary": {"totalDelayed": 1, "maxDelay": 5, "status": "minor"}},
            "holidays": [{"name": "Easter", "nameDE": "Ostern", "daysUntil": 45}],
            "schoolHolidays": [{"name": "Sport", "nameDE": "Sportferien", "startDate": "2026-02-09", "endDate": "2026-02-21", "type": "schoolHoliday"}],
            "history": {"year": 1958, "event": "Test event", "eventDE": "Test-Ereignis"},
            "categories": {"topStories": [{"headline": "Test headline", "summary": "Test summary", "source": "NZZ"}], "politics": [], "disruptions": [], "events": [], "culture": [], "local": []},
            "trending": {"topic": "Test topic"},
            "briefing": {"topStory": "Top story text"},
            "city": {"id": "zurich", "name": "Zürich"},
            "timestamp": "2026-02-21T12:00:00Z"
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(NewsResponse.self, from: json)
        XCTAssertEqual(response.weather.temperature, 5.2)
        XCTAssertEqual(response.weather.weatherCode, 2)
        XCTAssertEqual(response.weather.sfSymbol, "cloud.sun.fill")
        XCTAssertEqual(response.transport.delays.count, 1)
        XCTAssertEqual(response.transport.summary.status, "minor")
        XCTAssertEqual(response.holidays.count, 1)
        XCTAssertEqual(response.holidays[0].localizedName(language: .de), "Ostern")
        XCTAssertEqual(response.schoolHolidays.count, 1)
        XCTAssertEqual(response.history.year, 1958)
        XCTAssertEqual(response.categories.items(for: "topStories").count, 1)
        XCTAssertEqual(response.city.id, "zurich")
    }

    func testDecodeNewsResponseWithMissingOptionals() throws {
        let json = """
        {
            "weather": {"temperature": 0, "description": "Clear", "weatherCode": 0, "windSpeed": 0},
            "transport": {"delays": [], "summary": {"totalDelayed": 0, "maxDelay": 0, "status": "none"}},
            "holidays": [],
            "schoolHolidays": [],
            "history": {"year": 2000, "event": "Test"},
            "categories": {},
            "city": {"id": "bern", "name": "Bern"},
            "timestamp": "2026-01-01T00:00:00Z"
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(NewsResponse.self, from: json)
        XCTAssertNil(response.trending)
        XCTAssertNil(response.briefing)
        XCTAssertNil(response.weather.hourly)
        XCTAssertEqual(response.categories.items(for: "topStories").count, 0)
    }

    // MARK: - Activities Response

    func testDecodeActivitiesResponse() throws {
        let json = """
        {
            "activities": [{
                "id": "zoo-zurich",
                "name": "Zoo Zürich",
                "nameDE": "Zoo Zürich",
                "description": "Great zoo",
                "descriptionDE": "Toller Zoo",
                "indoor": false,
                "ageRange": "2-5",
                "duration": "2-4 hours",
                "price": "CHF 29",
                "url": "https://zoo.ch",
                "lat": 47.3849,
                "lon": 8.5743,
                "category": "animals",
                "minAge": 2,
                "maxAge": 5
            }],
            "cityEvents": [{
                "id": "zh-sechselaeuten",
                "name": "Sechseläuten",
                "city": "zurich",
                "startDate": "2026-04-20",
                "endDate": "2026-04-20",
                "toddlerFriendly": true,
                "free": true
            }],
            "weather": {"temperature": 10, "description": "Sunny", "weatherCode": 0, "windSpeed": 5},
            "city": {"id": "zurich", "name": "Zürich"}
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(ActivitiesResponse.self, from: json)
        XCTAssertEqual(response.activities.count, 1)
        XCTAssertEqual(response.activities[0].id, "zoo-zurich")
        XCTAssertFalse(response.activities[0].indoor)
        XCTAssertNotNil(response.activities[0].coordinate)
        XCTAssertEqual(response.cityEvents.count, 1)
        XCTAssertTrue(response.cityEvents[0].toddlerFriendly ?? false)
    }

    // MARK: - Sunshine Response

    func testDecodeSunshineResponse() throws {
        let json = """
        {
            "destinations": [{
                "id": "lugano",
                "name": "Lugano",
                "lat": 46.0037,
                "lon": 8.9511,
                "region": "Ticino",
                "regionDE": "Tessin",
                "driveMinutes": 150,
                "forecast": [{
                    "date": "2026-02-20",
                    "weatherCode": 1,
                    "tempMax": 12,
                    "tempMin": 3,
                    "sunshineHours": 7.2,
                    "precipMm": 0,
                    "sunnyHours": [8,9,10,11,12,13,14,15,16]
                }],
                "sunshineHoursTotal": 18.5,
                "isBaseline": false
            }],
            "weekendDates": {"friday": "2026-02-20", "saturday": "2026-02-21", "sunday": "2026-02-22"},
            "timestamp": "2026-02-20T06:00:00Z"
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(SunshineResponse.self, from: json)
        XCTAssertEqual(response.destinations.count, 1)
        XCTAssertEqual(response.destinations[0].sunshineHoursTotal, 18.5)
        XCTAssertEqual(response.destinations[0].forecast[0].sunnyHours?.count, 9)
        XCTAssertEqual(response.weekendDates.friday, "2026-02-20")
    }

    // MARK: - Snow Response

    func testDecodeSnowResponse() throws {
        let json = """
        {
            "destinations": [{
                "id": "zermatt",
                "name": "Zermatt",
                "lat": 46.0207,
                "lon": 7.7491,
                "region": "Valais",
                "driveMinutes": 195,
                "altitude": 1620,
                "forecast": [{"date": "2026-02-16", "snowfallCm": 5.2, "weatherCode": 73, "tempMax": -2, "tempMin": -8}],
                "snowfallWeekTotal": 28.5,
                "snowDepthCm": 145
            }],
            "weekDates": {"monday": "2026-02-16", "sunday": "2026-02-22"},
            "timestamp": "2026-02-16T06:00:00Z"
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(SnowResponse.self, from: json)
        XCTAssertEqual(response.destinations.count, 1)
        XCTAssertEqual(response.destinations[0].altitude, 1620)
        XCTAssertEqual(response.destinations[0].snowfallWeekTotal, 28.5)
        XCTAssertEqual(response.destinations[0].snowfallLevel, .moderate)
    }

    // MARK: - Lunch Response

    func testDecodeLunchResponse() throws {
        let json = """
        {
            "spots": [{
                "id": "node-123",
                "name": "Zeughauskeller",
                "lat": 47.3715,
                "lon": 8.5393,
                "cuisine": "Swiss",
                "cuisineCategory": "swiss",
                "outdoorSeating": true,
                "openForLunch": true
            }],
            "city": {"id": "zurich", "name": "Zürich"}
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(LunchResponse.self, from: json)
        XCTAssertEqual(response.spots.count, 1)
        XCTAssertEqual(response.spots[0].cuisineDisplay, "Swiss")
        XCTAssertTrue(response.spots[0].outdoorSeating ?? false)
    }

    // MARK: - Weekend Response

    func testDecodeWeekendResponse() throws {
        let json = """
        {
            "saturday": {
                "date": "2026-02-21",
                "weather": {"weatherCode": 2, "tempMax": 8, "tempMin": 1, "description": "Partly cloudy"},
                "plan": {
                    "morning": {"id": "zoo", "name": "Zoo Zürich", "description": "Visit the zoo", "indoor": false, "duration": "2h"},
                    "afternoon": {"id": "museum", "name": "Museum", "description": "Art museum", "indoor": true}
                }
            },
            "sunday": {
                "date": "2026-02-22",
                "weather": {"weatherCode": 61, "tempMax": 5, "tempMin": 0, "description": "Rain"},
                "plan": {
                    "morning": {"id": "indoor-play", "name": "Indoor Play", "description": "Play indoors", "indoor": true}
                }
            },
            "city": {"id": "zurich", "name": "Zürich"}
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(WeekendResponse.self, from: json)
        XCTAssertEqual(response.saturday.date, "2026-02-21")
        XCTAssertNotNil(response.saturday.plan.morning)
        XCTAssertNotNil(response.saturday.plan.afternoon)
        XCTAssertNil(response.sunday.plan.afternoon)
    }

    // MARK: - Weather Helpers

    func testWeatherSFSymbols() {
        let clearWeather = Weather(temperature: 25, description: "Clear", weatherCode: 0, windSpeed: 5, hourly: nil)
        XCTAssertEqual(clearWeather.sfSymbol, "sun.max.fill")
        XCTAssertFalse(clearWeather.isBadWeather)

        let rainyWeather = Weather(temperature: 8, description: "Rain", weatherCode: 61, windSpeed: 15, hourly: nil)
        XCTAssertEqual(rainyWeather.sfSymbol, "cloud.rain.fill")
        XCTAssertTrue(rainyWeather.isBadWeather)

        let coldWeather = Weather(temperature: 2, description: "Clear", weatherCode: 0, windSpeed: 3, hourly: nil)
        XCTAssertTrue(coldWeather.isBadWeather)
    }

    // MARK: - Activity Helpers

    func testActivityFreeDetection() {
        let freeActivity = Activity(id: "test", name: "Test", nameDE: nil, description: "Test", descriptionDE: nil, indoor: false, ageRange: nil, duration: nil, price: "Free entry", priceDE: nil, url: nil, lat: nil, lon: nil, category: nil, minAge: nil, maxAge: nil, season: nil, free: nil, recurring: nil, stayHome: nil, subcategory: nil, materials: nil, materialsDE: nil)
        XCTAssertTrue(freeActivity.isFree)

        let paidActivity = Activity(id: "test2", name: "Test", nameDE: nil, description: "Test", descriptionDE: nil, indoor: false, ageRange: nil, duration: nil, price: "CHF 15", priceDE: nil, url: nil, lat: nil, lon: nil, category: nil, minAge: nil, maxAge: nil, season: nil, free: nil, recurring: nil, stayHome: nil, subcategory: nil, materials: nil, materialsDE: nil)
        XCTAssertFalse(paidActivity.isFree)
    }

    func testActivityAgeFilter() {
        let toddlerActivity = Activity(id: "t", name: "T", nameDE: nil, description: "T", descriptionDE: nil, indoor: false, ageRange: nil, duration: nil, price: nil, priceDE: nil, url: nil, lat: nil, lon: nil, category: nil, minAge: 2, maxAge: 3, season: nil, free: nil, recurring: nil, stayHome: nil, subcategory: nil, materials: nil, materialsDE: nil)

        XCTAssertTrue(toddlerActivity.matchesAge(.all))
        XCTAssertTrue(toddlerActivity.matchesAge(.toddler))
        XCTAssertFalse(toddlerActivity.matchesAge(.preschool))
    }

    // MARK: - Snow/Sunshine Levels

    func testSnowfallLevel() {
        let heavy = SnowDestination(id: "t", name: "T", nameDE: nil, lat: 0, lon: 0, region: "R", regionDE: nil, driveMinutes: 0, altitude: 1000, forecast: [], snowfallWeekTotal: 45, snowDepthCm: nil)
        XCTAssertEqual(heavy.snowfallLevel, .heavy)

        let moderate = SnowDestination(id: "t", name: "T", nameDE: nil, lat: 0, lon: 0, region: "R", regionDE: nil, driveMinutes: 0, altitude: 1000, forecast: [], snowfallWeekTotal: 20, snowDepthCm: nil)
        XCTAssertEqual(moderate.snowfallLevel, .moderate)

        let light = SnowDestination(id: "t", name: "T", nameDE: nil, lat: 0, lon: 0, region: "R", regionDE: nil, driveMinutes: 0, altitude: 1000, forecast: [], snowfallWeekTotal: 5, snowDepthCm: nil)
        XCTAssertEqual(light.snowfallLevel, .light)
    }

    // MARK: - Date Helpers

    func testDateParsing() {
        let date = DateHelpers.parseISO("2026-02-21")
        XCTAssertNotNil(date)

        let iso = DateHelpers.toISO(date!)
        XCTAssertEqual(iso, "2026-02-21")
    }

    func testDatesInMonth() {
        let dates = DateHelpers.datesInMonth(year: 2026, month: 2)
        XCTAssertEqual(dates.count, 28) // February 2026 has 28 days
    }

    // MARK: - City

    func testCityProperties() {
        XCTAssertEqual(City.zurich.displayName, "Zürich")
        XCTAssertEqual(City.geneva.displayNameDE, "Genf")
        XCTAssertEqual(City.zurich.station, "Zürich HB")
        XCTAssertEqual(City.allCases.count, 7)
    }

    // MARK: - Deal

    func testDealFiltering() {
        let deal = Deal(id: "test", name: "T", nameDE: "T", description: "D", descriptionDE: "D", category: "museum", type: .free, city: "zurich", url: nil, validMonths: [6, 7, 8])

        XCTAssertTrue(deal.appliesTo(city: .zurich))
        XCTAssertFalse(deal.appliesTo(city: .bern))

        let allCityDeal = Deal(id: "test2", name: "T", nameDE: "T", description: "D", descriptionDE: "D", category: "transport", type: .deal, city: "all", url: nil, validMonths: nil)
        XCTAssertTrue(allCityDeal.appliesTo(city: .bern))
        XCTAssertTrue(allCityDeal.isCurrentlyValid)
    }

    // MARK: - Static Data Integrity

    func testDealsDataCount() {
        XCTAssertGreaterThan(DealsData.all.count, 20)
        // All deals should have non-empty names
        for deal in DealsData.all {
            XCTAssertFalse(deal.name.isEmpty)
            XCTAssertFalse(deal.nameDE.isEmpty)
        }
    }

    func testSunshineDestinationsCount() {
        XCTAssertEqual(SunshineDestinations.all.count, 29)
        // First should be baseline (Zürich)
        XCTAssertTrue(SunshineDestinations.all[0].isBaseline)
        XCTAssertEqual(SunshineDestinations.all[0].id, "zurich")
    }

    func testSnowResortsCount() {
        XCTAssertEqual(SnowResorts.all.count, 22)
        // All should have altitude > 0
        for resort in SnowResorts.all {
            XCTAssertGreaterThan(resort.altitude, 0)
        }
    }

    func testDestinationHighlights() {
        let lugano = DestinationHighlights.forDestination("lugano")
        XCTAssertEqual(lugano.count, 3)

        let unknown = DestinationHighlights.forDestination("nonexistent")
        XCTAssertTrue(unknown.isEmpty)

        XCTAssertTrue(DestinationHighlights.activityCities.contains("basel"))
        XCTAssertTrue(DestinationHighlights.activityCities.contains("lausanne"))
        XCTAssertTrue(DestinationHighlights.activityCities.contains("luzern"))
    }

    // MARK: - CityEvent Date Overlap

    func testCityEventOverlap() {
        let event = CityEvent(id: "test", name: "Festival", nameDE: nil, city: "zurich", startDate: "2026-02-20", endDate: "2026-02-22", description: nil, descriptionDE: nil, toddlerFriendly: nil, free: nil, url: nil)

        let feb21 = DateHelpers.parseISO("2026-02-21")!
        XCTAssertTrue(event.overlaps(with: feb21))

        let feb23 = DateHelpers.parseISO("2026-02-23")!
        XCTAssertFalse(event.overlaps(with: feb23))
    }

    // MARK: - Distance Formatting

    func testDistanceFormatting() {
        XCTAssertEqual(CLLocation.formattedDistance(500), "500 m")
        XCTAssertEqual(CLLocation.formattedDistance(1500), "1.5 km")
        XCTAssertEqual(CLLocation.formattedDriveTime(45), "45 min")
        XCTAssertEqual(CLLocation.formattedDriveTime(90), "1h 30min")
        XCTAssertEqual(CLLocation.formattedDriveTime(60), "1h")
    }
}
