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

    enum CacheTTL: TimeInterval {
        case news = 7200       // 2 hours
        case activities = 7200 // 2 hours
        case lunch = 1800      // 30 min
        case sunshine = 1800   // 30 min
        case snow = 1800       // 30 min
        case weekend = 3600    // 1 hour
    }

    // MARK: - Public API

    /// Get cached data if it exists and hasn't expired
    func get<T: Decodable>(_ type: T.Type, key: String, ttl: CacheTTL) -> T? {
        let fileURL = cacheDirectory.appendingPathComponent(sanitize(key) + ".json")

        guard fileManager.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL) else {
            return nil
        }

        guard let wrapper = try? JSONDecoder().decode(CacheWrapper<T>.self, from: data) else {
            return nil
        }

        // Check TTL
        if Date().timeIntervalSince(wrapper.cachedAt) > ttl.rawValue {
            try? fileManager.removeItem(at: fileURL)
            return nil
        }

        return wrapper.data
    }

    /// Store data in cache
    func set<T: Encodable>(_ data: T, key: String) {
        let wrapper = CacheWrapper(data: data, cachedAt: Date())
        let fileURL = cacheDirectory.appendingPathComponent(sanitize(key) + ".json")

        if let encoded = try? JSONEncoder().encode(wrapper) {
            try? encoded.write(to: fileURL)
        }
    }

    /// Remove a specific cache entry
    func remove(key: String) {
        let fileURL = cacheDirectory.appendingPathComponent(sanitize(key) + ".json")
        try? fileManager.removeItem(at: fileURL)
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

/// Wrapper that stores cached data with a timestamp
private struct CacheWrapper<T: Codable>: Codable {
    let data: T
    let cachedAt: Date
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

    static let sunshine = "sunshine-v2"
    static let snow = "snow-v1"
}
