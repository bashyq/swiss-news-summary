import Foundation

/// Manages cached API responses with TTL-based expiration.
/// Uses file-based caching (Documents directory) for persistence across launches.
actor CacheManager {
    static let shared = CacheManager()

    private let fileManager = FileManager.default

    private var cacheDirectory: URL {
        let paths = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        let cacheDir = paths[0].appendingPathComponent("APICache", isDirectory: true)
        try? fileManager.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        return cacheDir
    }

    // MARK: - Cache TTLs

    enum CacheTTL {
        case news
        case activities
        case lunch
        case sunshine
        case snow
        case weekend
        case deals

        var seconds: TimeInterval {
            switch self {
            case .news, .activities: return 7200   // 2 hours
            case .lunch, .sunshine, .snow: return 1800  // 30 min
            case .weekend, .deals: return 3600     // 1 hour
            }
        }
    }

    // MARK: - Public API

    /// Get cached data if it exists and hasn't expired
    func get<T: Codable>(_ type: T.Type, key: String, ttl: CacheTTL) -> T? {
        let sanitized = sanitize(key)
        let dataURL = cacheDirectory.appendingPathComponent(sanitized + ".json")
        let metaURL = cacheDirectory.appendingPathComponent(sanitized + ".meta")

        guard fileManager.fileExists(atPath: dataURL.path),
              let rawData = try? Data(contentsOf: dataURL) else {
            return nil
        }

        // Check TTL using metadata file (timestamp stored as TimeInterval)
        if let metaData = try? Data(contentsOf: metaURL),
           let timestampString = String(data: metaData, encoding: .utf8),
           let timestamp = TimeInterval(timestampString) {
            let cachedAt = Date(timeIntervalSince1970: timestamp)
            if Date().timeIntervalSince(cachedAt) > ttl.seconds {
                return nil
            }
        } else {
            return nil // No metadata means we can't verify freshness
        }

        return try? JSONDecoder().decode(T.self, from: rawData)
    }

    /// Get cached data regardless of TTL — used as fallback when network fails
    func getStale<T: Codable>(_ type: T.Type, key: String) -> T? {
        let dataURL = cacheDirectory.appendingPathComponent(sanitize(key) + ".json")
        guard let rawData = try? Data(contentsOf: dataURL) else {
            return nil
        }
        return try? JSONDecoder().decode(T.self, from: rawData)
    }

    /// Store data in cache
    func set<T: Codable>(_ data: T, key: String) {
        let sanitized = sanitize(key)
        let dataURL = cacheDirectory.appendingPathComponent(sanitized + ".json")
        let metaURL = cacheDirectory.appendingPathComponent(sanitized + ".meta")

        if let encoded = try? JSONEncoder().encode(data) {
            try? encoded.write(to: dataURL)
        }
        // Store timestamp as plain text TimeInterval
        let timestamp = "\(Date().timeIntervalSince1970)"
        try? timestamp.data(using: .utf8)?.write(to: metaURL)
    }

    /// Remove a specific cache entry
    func remove(key: String) {
        let sanitized = sanitize(key)
        let dataURL = cacheDirectory.appendingPathComponent(sanitized + ".json")
        let metaURL = cacheDirectory.appendingPathComponent(sanitized + ".meta")
        try? fileManager.removeItem(at: dataURL)
        try? fileManager.removeItem(at: metaURL)
    }

    /// Clear all cached data
    func clearAll() {
        try? fileManager.removeItem(at: cacheDirectory)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    // MARK: - Helpers

    private func sanitize(_ key: String) -> String {
        key.replacingOccurrences(of: "/", with: "_")
           .replacingOccurrences(of: "?", with: "_")
           .replacingOccurrences(of: "&", with: "_")
           .replacingOccurrences(of: "=", with: "_")
    }
}

// MARK: - Cache Keys

enum CacheKey {
    static func news(city: City, language: AppLanguage) -> String {
        "news-\(city.rawValue)-\(language.rawValue)"
    }

    static func activities(city: City) -> String {
        "activities-\(city.rawValue)"
    }

    static func lunch(city: City) -> String {
        "lunch-\(city.rawValue)"
    }

    static func weekend(city: City) -> String {
        "weekend-\(city.rawValue)"
    }

    static func deals(city: City) -> String {
        "deals-\(city.rawValue)"
    }

    static let sunshine = "sunshine-v2"
    static let snow = "snow-v1"
}
