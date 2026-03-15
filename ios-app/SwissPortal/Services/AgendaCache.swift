import Foundation

/// File-based cache for daily agendas, keyed by date + session hash.
/// Each day + session combo gets its own cached agenda.
///
/// Uses raw Data for encode/decode to avoid actor-isolation warnings
/// with @MainActor-implicitly-isolated Codable conformances.
actor AgendaCache {
    static let shared = AgendaCache()

    private let cacheDir: URL

    private init() {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        self.cacheDir = base.appendingPathComponent("AgendaCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
    }

    // MARK: - Public API

    /// Retrieve a cached agenda for the given date, city, and session hash.
    func get(date: String, city: String = "zurich", sessionHash: String) -> Data? {
        let url = fileURL(date: date, city: city, sessionHash: sessionHash)
        return try? Data(contentsOf: url)
    }

    /// Store agenda data in the cache.
    func store(_ data: Data, date: String, city: String = "zurich", sessionHash: String) {
        let url = fileURL(date: date, city: city, sessionHash: sessionHash)
        try? data.write(to: url)
    }

    /// Remove all cached agendas (called when session changes or user requests rebuild).
    func invalidate() {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: nil) else { return }
        for file in files {
            try? fm.removeItem(at: file)
        }
    }

    // MARK: - Private

    private func fileURL(date: String, city: String, sessionHash: String) -> URL {
        let sanitizedDate = date.replacingOccurrences(of: "-", with: "")
        return cacheDir.appendingPathComponent("agenda-\(sanitizedDate)-\(city)-\(sessionHash).json")
    }
}
