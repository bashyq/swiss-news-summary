import Foundation
import CryptoKit

/// File-based cache for daily agendas, keyed by date + session hash + anchors hash.
/// Each day + session + anchor configuration combo gets its own cached agenda.
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

    /// Retrieve a cached agenda for the given date, city, session hash, and anchors hash.
    func get(date: String, city: String = "zurich", sessionHash: String, anchorsHash: String = "") -> Data? {
        let url = fileURL(date: date, city: city, sessionHash: sessionHash, anchorsHash: anchorsHash)
        return try? Data(contentsOf: url)
    }

    /// Store agenda data in the cache.
    func store(_ data: Data, date: String, city: String = "zurich", sessionHash: String, anchorsHash: String = "") {
        let url = fileURL(date: date, city: city, sessionHash: sessionHash, anchorsHash: anchorsHash)
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

    // MARK: - Anchors Hash

    /// Compute a short hash from the anchor set for cache keying.
    /// Encodes id + startTime + durationMinutes for each anchor.
    static func hash(anchors: [AnchorEvent]) -> String {
        guard !anchors.isEmpty else { return "" }
        let descriptor = anchors
            .sorted { $0.startTime < $1.startTime }
            .map { "\($0.id)-\(Int($0.startTime.timeIntervalSince1970))-\($0.durationMinutes)" }
            .joined(separator: "|")
        let digest = SHA256.hash(data: Data(descriptor.utf8))
        return digest.prefix(8).map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Private

    private func fileURL(date: String, city: String, sessionHash: String, anchorsHash: String) -> URL {
        let sanitizedDate = date.replacingOccurrences(of: "-", with: "")
        let suffix = anchorsHash.isEmpty ? "" : "-\(anchorsHash)"
        return cacheDir.appendingPathComponent("agenda-\(sanitizedDate)-\(city)-\(sessionHash)\(suffix).json")
    }
}
