import Foundation

/// Central API client for all Cloudflare Worker endpoints
actor APIClient {
    static let shared = APIClient()

    private let baseURL = "https://swiss-news-worker.swissnews.workers.dev"
    private let session: URLSession
    private let decoder: JSONDecoder

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.waitsForConnectivity = true
        self.session = URLSession(configuration: config)

        self.decoder = JSONDecoder()
    }

    // MARK: - Public API

    /// Fetch news for a city
    func fetchNews(city: City, language: AppLanguage, forceRefresh: Bool = false) async throws -> NewsResponse {
        var params = ["lang": language.rawValue, "city": city.rawValue]
        if forceRefresh { params["refresh"] = "true" }
        return try await fetch("/", queryParams: params)
    }

    /// Fetch activities for a city
    func fetchActivities(city: City, language: AppLanguage) async throws -> ActivitiesResponse {
        try await fetch("/activities", queryParams: [
            "lang": language.rawValue,
            "city": city.rawValue
        ])
    }

    /// Fetch lunch spots for a city
    func fetchLunch(city: City, language: AppLanguage) async throws -> LunchResponse {
        try await fetch("/lunch", queryParams: [
            "lang": language.rawValue,
            "city": city.rawValue
        ])
    }

    /// Fetch weekend plan for a city
    func fetchWeekend(city: City, language: AppLanguage) async throws -> WeekendResponse {
        try await fetch("/weekend", queryParams: [
            "lang": language.rawValue,
            "city": city.rawValue
        ])
    }

    /// Fetch sunshine forecast (always Zürich-based)
    func fetchSunshine(language: AppLanguage, forceRefresh: Bool = false) async throws -> SunshineResponse {
        var params = ["lang": language.rawValue]
        if forceRefresh { params["refresh"] = "true" }
        return try await fetch("/sunshine", queryParams: params)
    }

    /// Fetch snow forecast (always Zürich-based)
    func fetchSnow(language: AppLanguage, forceRefresh: Bool = false) async throws -> SnowResponse {
        var params = ["lang": language.rawValue]
        if forceRefresh { params["refresh"] = "true" }
        return try await fetch("/snow", queryParams: params)
    }

    // MARK: - Client-Side Fallbacks (Open-Meteo direct)

    /// Client-side sunshine fallback when worker is rate-limited
    func fetchSunshineClientSide(destinations: [SunshineDestinationConfig]) async throws -> SunshineResponse {
        let lats = destinations.map { String($0.lat) }.joined(separator: ",")
        let lons = destinations.map { String($0.lon) }.joined(separator: ",")

        guard let weekend = DateHelpers.weekendDates() else {
            throw APIError.invalidData("Could not calculate weekend dates")
        }

        let startDate = DateHelpers.toISO(weekend.friday)
        let endDate = DateHelpers.toISO(weekend.sunday)

        let urlString = "https://api.open-meteo.com/v1/forecast?"
            + "latitude=\(lats)&longitude=\(lons)"
            + "&daily=weather_code,temperature_2m_max,temperature_2m_min,sunshine_duration,precipitation_sum"
            + "&hourly=sunshine_duration"
            + "&timezone=Europe/Zurich"
            + "&start_date=\(startDate)&end_date=\(endDate)"

        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL(urlString)
        }

        let (data, _) = try await session.data(from: url)
        // Parse Open-Meteo multi-location response into SunshineResponse
        return try parseOpenMeteoSunshine(data: data, destinations: destinations, weekend: weekend)
    }

    /// Client-side snow fallback when worker is rate-limited
    func fetchSnowClientSide(resorts: [SnowResortConfig]) async throws -> SnowResponse {
        let lats = resorts.map { String($0.lat) }.joined(separator: ",")
        let lons = resorts.map { String($0.lon) }.joined(separator: ",")

        let cal = Calendar.current
        let today = Date()
        // Monday of current week
        let weekday = cal.component(.weekday, from: today)
        let daysFromMonday = (weekday + 5) % 7
        guard let monday = cal.date(byAdding: .day, value: -daysFromMonday, to: today),
              let sunday = cal.date(byAdding: .day, value: 6, to: monday) else {
            throw APIError.invalidData("Could not calculate week dates")
        }

        let startDate = DateHelpers.toISO(monday)
        let endDate = DateHelpers.toISO(sunday)

        let urlString = "https://api.open-meteo.com/v1/forecast?"
            + "latitude=\(lats)&longitude=\(lons)"
            + "&daily=snowfall_sum,weather_code,temperature_2m_max,temperature_2m_min"
            + "&hourly=snow_depth"
            + "&timezone=Europe/Zurich"
            + "&start_date=\(startDate)&end_date=\(endDate)"

        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL(urlString)
        }

        let (data, _) = try await session.data(from: url)
        return try parseOpenMeteoSnow(data: data, resorts: resorts, monday: monday, sunday: sunday)
    }

    // MARK: - Generic Fetch

    private func fetch<T: Decodable>(_ endpoint: String, queryParams: [String: String] = [:]) async throws -> T {
        guard var components = URLComponents(string: baseURL + endpoint) else {
            throw APIError.invalidURL(baseURL + endpoint)
        }

        if !queryParams.isEmpty {
            components.queryItems = queryParams.map { URLQueryItem(name: $0.key, value: $0.value) }
        }

        guard let url = components.url else {
            throw APIError.invalidURL(components.string ?? "unknown")
        }

        // Retry with exponential backoff
        var lastError: Error?
        for attempt in 0..<3 {
            do {
                let (data, response) = try await session.data(from: url)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw APIError.invalidResponse
                }

                guard (200...299).contains(httpResponse.statusCode) else {
                    throw APIError.serverError(httpResponse.statusCode)
                }

                return try decoder.decode(T.self, from: data)
            } catch let error as APIError {
                throw error // Don't retry API errors
            } catch let error as DecodingError {
                throw APIError.decodingError(error)
            } catch {
                lastError = error
                if attempt < 2 {
                    let delay = UInt64(pow(2.0, Double(attempt))) * 1_000_000_000
                    try await Task.sleep(nanoseconds: delay)
                }
            }
        }

        throw lastError ?? APIError.unknown
    }

    // MARK: - Open-Meteo Parsing

    private func parseOpenMeteoSunshine(
        data: Data,
        destinations: [SunshineDestinationConfig],
        weekend: (friday: Date, saturday: Date, sunday: Date)
    ) throws -> SunshineResponse {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            // Single location returns object, multi returns array
            if let single = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                return try parseSingleSunshineLocation(json: [single], destinations: destinations, weekend: weekend)
            }
            throw APIError.invalidData("Invalid Open-Meteo response")
        }
        return try parseSingleSunshineLocation(json: json, destinations: destinations, weekend: weekend)
    }

    private func parseSingleSunshineLocation(
        json: [[String: Any]],
        destinations: [SunshineDestinationConfig],
        weekend: (friday: Date, saturday: Date, sunday: Date)
    ) throws -> SunshineResponse {
        var results: [SunshineDestination] = []

        for (index, locationData) in json.enumerated() where index < destinations.count {
            let config = destinations[index]
            guard let daily = locationData["daily"] as? [String: Any],
                  let dates = daily["time"] as? [String],
                  let weatherCodes = daily["weather_code"] as? [Int],
                  let tempMaxes = daily["temperature_2m_max"] as? [Double],
                  let tempMins = daily["temperature_2m_min"] as? [Double],
                  let sunshineDurations = daily["sunshine_duration"] as? [Double],
                  let precipSums = daily["precipitation_sum"] as? [Double] else {
                continue
            }

            var forecasts: [SunshineDayForecast] = []
            var totalHours = 0.0

            for i in 0..<dates.count {
                let hours = sunshineDurations[i] / 3600.0 // seconds to hours
                totalHours += hours
                forecasts.append(SunshineDayForecast(
                    date: dates[i],
                    weatherCode: weatherCodes[i],
                    tempMax: tempMaxes[i],
                    tempMin: tempMins[i],
                    sunshineHours: hours,
                    precipMm: precipSums[i],
                    sunnyHours: nil,
                    description: nil
                ))
            }

            results.append(SunshineDestination(
                id: config.id,
                name: config.name,
                nameDE: config.nameDE,
                lat: config.lat,
                lon: config.lon,
                region: config.region,
                regionDE: config.regionDE,
                driveMinutes: config.driveMinutes,
                forecast: forecasts,
                sunshineHoursTotal: totalHours,
                isBaseline: config.isBaseline
            ))
        }

        // Sort: baseline first, then by sunshine hours descending
        results.sort { a, b in
            if a.isBaseline == true { return true }
            if b.isBaseline == true { return false }
            return a.sunshineHoursTotal > b.sunshineHoursTotal
        }

        return SunshineResponse(
            destinations: results,
            weekendDates: WeekendDates(
                friday: DateHelpers.toISO(weekend.friday),
                saturday: DateHelpers.toISO(weekend.saturday),
                sunday: DateHelpers.toISO(weekend.sunday)
            ),
            timestamp: ISO8601DateFormatter().string(from: Date())
        )
    }

    private func parseOpenMeteoSnow(
        data: Data,
        resorts: [SnowResortConfig],
        monday: Date,
        sunday: Date
    ) throws -> SnowResponse {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            if let single = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                return try parseSingleSnowLocation(json: [single], resorts: resorts, monday: monday, sunday: sunday)
            }
            throw APIError.invalidData("Invalid Open-Meteo response")
        }
        return try parseSingleSnowLocation(json: json, resorts: resorts, monday: monday, sunday: sunday)
    }

    private func parseSingleSnowLocation(
        json: [[String: Any]],
        resorts: [SnowResortConfig],
        monday: Date,
        sunday: Date
    ) throws -> SnowResponse {
        var results: [SnowDestination] = []

        for (index, locationData) in json.enumerated() where index < resorts.count {
            let config = resorts[index]
            guard let daily = locationData["daily"] as? [String: Any],
                  let dates = daily["time"] as? [String],
                  let snowfalls = daily["snowfall_sum"] as? [Double],
                  let weatherCodes = daily["weather_code"] as? [Int],
                  let tempMaxes = daily["temperature_2m_max"] as? [Double],
                  let tempMins = daily["temperature_2m_min"] as? [Double] else {
                continue
            }

            var forecasts: [SnowDayForecast] = []
            var totalSnow = 0.0

            for i in 0..<dates.count {
                totalSnow += snowfalls[i]
                forecasts.append(SnowDayForecast(
                    date: dates[i],
                    snowfallCm: snowfalls[i],
                    weatherCode: weatherCodes[i],
                    tempMax: tempMaxes[i],
                    tempMin: tempMins[i]
                ))
            }

            // Get max snow depth from hourly if available
            var maxDepth: Double? = nil
            if let hourly = locationData["hourly"] as? [String: Any],
               let depths = hourly["snow_depth"] as? [Double] {
                maxDepth = depths.max()
            }

            results.append(SnowDestination(
                id: config.id,
                name: config.name,
                nameDE: config.nameDE,
                lat: config.lat,
                lon: config.lon,
                region: config.region,
                regionDE: config.regionDE,
                driveMinutes: config.driveMinutes,
                altitude: config.altitude,
                forecast: forecasts,
                snowfallWeekTotal: totalSnow,
                snowDepthCm: maxDepth
            ))
        }

        results.sort { $0.snowfallWeekTotal > $1.snowfallWeekTotal }

        return SnowResponse(
            destinations: results,
            weekDates: WeekDates(
                monday: DateHelpers.toISO(monday),
                sunday: DateHelpers.toISO(sunday)
            ),
            timestamp: ISO8601DateFormatter().string(from: Date())
        )
    }
}

// MARK: - API Errors

enum APIError: LocalizedError {
    case invalidURL(String)
    case invalidResponse
    case serverError(Int)
    case decodingError(Error)
    case invalidData(String)
    case unknown

    var errorDescription: String? {
        switch self {
        case .invalidURL(let url): return "Invalid URL: \(url)"
        case .invalidResponse: return "Invalid server response"
        case .serverError(let code): return "Server error (\(code))"
        case .decodingError(let error): return "Data parsing error: \(error.localizedDescription)"
        case .invalidData(let msg): return msg
        case .unknown: return "An unknown error occurred"
        }
    }
}

// MARK: - Client-Side Fallback Configs

/// Configuration for sunshine destinations (used in client-side fallback)
struct SunshineDestinationConfig {
    let id: String
    let name: String
    let nameDE: String?
    let lat: Double
    let lon: Double
    let region: String
    let regionDE: String?
    let driveMinutes: Int
    let isBaseline: Bool
}

/// Configuration for snow resorts (used in client-side fallback)
struct SnowResortConfig {
    let id: String
    let name: String
    let nameDE: String?
    let lat: Double
    let lon: Double
    let region: String
    let regionDE: String?
    let driveMinutes: Int
    let altitude: Int
}
