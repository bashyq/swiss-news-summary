import Foundation

/// Describes who is going out today — used by the Agenda Composer to tailor suggestions.
struct FamilySession: Codable, Equatable {
    var soloParent: Bool = true
    var children: [Child] = [Child(name: "Child", age: 3)]

    struct Child: Codable, Identifiable, Equatable {
        let id: UUID
        var name: String
        var age: Int

        init(id: UUID = UUID(), name: String, age: Int) {
            self.id = id
            self.name = name
            self.age = age
        }
    }

    // MARK: - Computed

    var youngestAge: Int { children.map(\.age).min() ?? 3 }
    var oldestAge: Int { children.map(\.age).max() ?? 5 }

    var childrenDisplay: String {
        children.map { "\($0.name) (\($0.age))" }.joined(separator: " & ")
    }

    /// Compact description for the Claude prompt
    var promptDescription: String {
        let parentDesc = soloParent ? "Solo parent" : "Both parents"
        let childDesc = children.map { "\($0.name), age \($0.age)" }.joined(separator: "; ")
        return "\(parentDesc), children: \(childDesc)"
    }

    /// Hash for cache keying — stable across sessions
    var sessionHash: String {
        let data = try? JSONEncoder().encode(self)
        return data.map { "\($0.hashValue)" } ?? "default"
    }

    // MARK: - Persistence

    private static let storageKey = "familySession"

    static func load() -> FamilySession {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let session = try? JSONDecoder().decode(FamilySession.self, from: data) else {
            return FamilySession()
        }
        return session
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }
}
