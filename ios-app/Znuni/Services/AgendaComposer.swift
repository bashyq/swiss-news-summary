import Foundation

/// Calls the Anthropic Messages API directly from iOS to compose
/// gap-aware day agendas using a pre-qualified venue pool.
struct AgendaComposer {

    // MARK: - Errors

    enum ComposerError: LocalizedError {
        case noAPIKey
        case httpError(Int, String?)
        case emptyResponse
        case jsonParsingFailed(String)

        var errorDescription: String? {
            switch self {
            case .noAPIKey:
                return "Anthropic API key not configured"
            case .httpError(let code, let msg):
                return "API error \(code): \(msg ?? "unknown")"
            case .emptyResponse:
                return "Empty response from API"
            case .jsonParsingFailed(let detail):
                return "JSON parse failed: \(detail)"
            }
        }
    }

    // MARK: - Public

    /// Compose agenda slots by calling the Anthropic API with gap + pool context.
    /// Returns one `AgendaSlot` per fillable gap, with `source: .aiGenerated`.
    static func compose(
        gaps: [FreeGap],
        activities: [Activity],
        lunches: [LunchSpot],
        dinners: [LunchSpot],
        weather: Weather?,
        session: FamilySession,
        language: AppLanguage,
        apiKey: String,
        planDate: Date = Date()
    ) async throws -> [AgendaSlot] {
        guard !apiKey.isEmpty else { throw ComposerError.noAPIKey }

        let system = systemPrompt(language: language)
        let user = buildUserPrompt(
            gaps: gaps,
            activities: activities,
            lunches: lunches,
            dinners: dinners,
            weather: weather,
            session: session,
            language: language
        )

        #if DEBUG
        print("📝 AgendaComposer prompt (\(gaps.count) gaps, \(activities.count) activities, \(lunches.count) lunches, \(dinners.count) dinners)")
        #endif

        let responseText = try await callAnthropic(system: system, user: user, apiKey: apiKey)
        let slots = try parseSlots(json: responseText, gaps: gaps, planDate: planDate)

        #if DEBUG
        print("✅ AgendaComposer returned \(slots.count) slots")
        #endif

        return slots
    }

    // MARK: - System Prompt

    private static func systemPrompt(language: AppLanguage) -> String {
        """
        You are Znüni, a Swiss family day planner for toddlers (ages 2-5).

        Rules:
        1. Return ONLY a JSON array — no markdown, no explanation.
        2. Each object: { "id": "slot-id", "time": "HH:MM", "type": "activity|lunch|dinner", "venueId": "exact-id-from-list", "venueName": "exact-name", "reason": "1-2 sentences why this fits", "durationMinutes": 90, "tags": ["Indoor","Free",...] }
        The "durationMinutes" field is how long the family should spend there. Defaults: activity=100, lunch=90, dinner=120. Adjust based on venue type and gap size.
        3. You MUST produce exactly one slot per gap line provided.
        4. For lunch gaps → pick from the lunch restaurant pool. For dinner gaps → pick from the dinner restaurant pool.
        5. Prefer outdoor activities when temp ≥ 15°C and no rain; prefer indoor when temp < 8°C or rain.
        6. Never repeat a venueId within the same response.
        7. The "time" field must fall within the gap's window.
        8. Keep "reason" personal — mention the child's name and reference the weather or gap context.
        9. "tags" should include relevant attributes: Indoor/Outdoor, Free if price mentions "free", age range.
        10. If no suitable venue exists for a gap, use venueId "surprise" with venueName "Surprise me!" and a creative reason.
        11. Response language: \(language == .de ? "German" : "English")
        """
    }

    // MARK: - User Prompt Builder

    private static func buildUserPrompt(
        gaps: [FreeGap],
        activities: [Activity],
        lunches: [LunchSpot],
        dinners: [LunchSpot],
        weather: Weather?,
        session: FamilySession,
        language: AppLanguage
    ) -> String {
        var lines: [String] = []

        // Gaps section
        lines.append("## Gaps to fill\n")
        for (i, gap) in gaps.enumerated() {
            let typeLabel = gap.suggestedType?.rawValue ?? "unknown"
            let start = timeString(gap.effectiveStart)
            let end = timeString(gap.gapEnd)
            lines.append("- Gap \(i + 1): \(typeLabel) window \(start)–\(end) (\(gap.effectiveMinutes) min)")
        }

        // Activities section
        if !activities.isEmpty {
            lines.append("\n## Activities pool (top \(activities.count), ranked by freshness)\n")
            for act in activities {
                let name = language == .de ? act.nameDE : act.name
                let price = (language == .de ? act.priceDE : act.price) ?? "n/a"
                lines.append("- id: \(act.id) | \(name) | indoor:\(act.indoor) | category:\(act.category) | duration:\(act.duration) | price:\(price)")
            }
        }

        // Lunch restaurants section
        if !lunches.isEmpty {
            lines.append("\n## Restaurants pool — lunch (top \(lunches.count))\n")
            for spot in lunches {
                let rating = spot.rating.map { String(format: "%.1f", $0) } ?? "n/a"
                lines.append("- id: \(spot.id) | \(spot.name) | cuisine:\(spot.cuisineDisplay) | rating:\(rating) | openForLunch:\(spot.openForLunch ?? false) | openForDinner:\(spot.openForDinner ?? false)")
            }
        }

        // Dinner restaurants section
        if !dinners.isEmpty {
            lines.append("\n## Restaurants pool — dinner (top \(dinners.count))\n")
            for spot in dinners {
                let rating = spot.rating.map { String(format: "%.1f", $0) } ?? "n/a"
                lines.append("- id: \(spot.id) | \(spot.name) | cuisine:\(spot.cuisineDisplay) | rating:\(rating) | openForLunch:\(spot.openForLunch ?? false) | openForDinner:\(spot.openForDinner ?? false)")
            }
        }

        // Context
        let weatherDesc: String
        if let w = weather {
            weatherDesc = "\(Int(w.temperature))°C, \(w.description.lowercased())"
        } else {
            weatherDesc = "unavailable"
        }
        lines.append("\n## Context\n")
        lines.append("Weather: \(weatherDesc). Session: \(session.promptDescription).")

        return lines.joined(separator: "\n")
    }

    // MARK: - Anthropic API Call

    private static func callAnthropic(
        system: String,
        user: String,
        apiKey: String
    ) async throws -> String {
        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")

        let body: [String: Any] = [
            "model": "claude-sonnet-4-20250514",
            "max_tokens": 1024,
            "system": system,
            "messages": [
                ["role": "user", "content": user]
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ComposerError.httpError(0, "Invalid response")
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8)
            throw ComposerError.httpError(httpResponse.statusCode, errorBody)
        }

        // Parse Anthropic response: { "content": [ { "type": "text", "text": "..." } ] }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let firstBlock = content.first,
              let text = firstBlock["text"] as? String else {
            throw ComposerError.emptyResponse
        }

        return text
    }

    // MARK: - Response Parser

    private static func parseSlots(json: String, gaps: [FreeGap], planDate: Date = Date()) throws -> [AgendaSlot] {
        // Strip any accidental markdown fencing
        var cleaned = json.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("```") {
            // Remove opening fence (with optional language tag)
            if let newlineIdx = cleaned.firstIndex(of: "\n") {
                cleaned = String(cleaned[cleaned.index(after: newlineIdx)...])
            }
        }
        if cleaned.hasSuffix("```") {
            cleaned = String(cleaned.dropLast(3)).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        guard let data = cleaned.data(using: .utf8) else {
            throw ComposerError.jsonParsingFailed("Could not convert to data")
        }

        let rawSlots: [RawSlot]
        do {
            rawSlots = try JSONDecoder().decode([RawSlot].self, from: data)
        } catch {
            throw ComposerError.jsonParsingFailed(error.localizedDescription)
        }

        guard !rawSlots.isEmpty else {
            throw ComposerError.emptyResponse
        }

        // Map raw slots to AgendaSlots, capping at gap count
        let slotCount = min(rawSlots.count, gaps.count)
        var result: [AgendaSlot] = []

        for i in 0..<slotCount {
            let raw = rawSlots[i]
            let gap = gaps[i]

            let slotType: AgendaSlot.SlotType
            switch raw.type.lowercased() {
            case "lunch": slotType = .lunch
            case "dinner": slotType = .dinner
            default: slotType = .activity
            }

            // Determine slot ID from gap type
            let slotId: String
            switch gap.suggestedType {
            case .morningActivity: slotId = "morning"
            case .lunch: slotId = "lunch"
            case .afternoonActivity: slotId = "afternoon"
            case .dinner: slotId = "dinner"
            case .quickActivity: slotId = "quick"
            case nil: slotId = raw.id
            }

            // Use AI-provided duration or fall back to type defaults
            let duration = raw.durationMinutes ?? {
                switch slotType {
                case .activity: return 100
                case .lunch: return 90
                case .dinner: return 120
                case .homeActivity: return 60
                }
            }()

            let slot = AgendaSlot(
                id: slotId,
                time: raw.time,
                type: slotType,
                venueName: raw.venueName,
                venueId: raw.venueId,
                reason: raw.reason,
                tags: raw.tags,
                swaps: [],
                durationMinutes: duration,
                source: .aiGenerated,
                isLocked: false,
                slotDate: AgendaSlot.resolveSlotDate(time: raw.time, planDate: planDate)
            )
            result.append(slot)
        }

        #if DEBUG
        if rawSlots.count != gaps.count {
            print("⚠️ AgendaComposer: AI returned \(rawSlots.count) slots for \(gaps.count) gaps")
        }
        #endif

        return result
    }

    // MARK: - Helpers

    private static func timeString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        f.timeZone = TimeZone(identifier: "Europe/Zurich")
        return f.string(from: date)
    }

    // MARK: - Raw Response Model

    private struct RawSlot: Decodable {
        let id: String
        let time: String
        let type: String
        let venueId: String
        let venueName: String
        let reason: String
        let durationMinutes: Int?
        let tags: [String]
    }
}
