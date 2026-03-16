import Foundation

/// UserDefaults-backed store for multi-day plans.
/// Plans older than 30 days are automatically purged on access.
class MultiDayPlanStore {
    static let shared = MultiDayPlanStore()

    private let key = "znuni.multiDayPlans"
    private let maxAgeDays = 30

    init() {}

    // MARK: - Store & Retrieve

    /// Store a multi-day plan (replaces any existing plan with the same ID).
    func store(_ plan: MultiDayPlan) {
        var plans = allPlans()
        plans.removeAll { $0.id == plan.id }
        plans.append(plan)
        purgeOldEntries(&plans)
        save(plans)
    }

    /// Retrieve a specific plan by ID.
    func plan(for id: UUID) -> MultiDayPlan? {
        allPlans().first { $0.id == id }
    }

    /// All stored plans, newest first.
    func allPlans() -> [MultiDayPlan] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let plans = try? JSONDecoder().decode([MultiDayPlan].self, from: data)
        else { return [] }
        return plans.sorted { $0.createdAt > $1.createdAt }
    }

    /// Delete a plan by ID.
    func delete(id: UUID) {
        var plans = allPlans()
        plans.removeAll { $0.id == id }
        save(plans)
    }

    /// Purge plans older than the specified number of days.
    func purgeOlderThan(days: Int) {
        var plans = allPlans()
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        plans.removeAll { $0.createdAt < cutoff }
        save(plans)
    }

    /// Find the most recent weekend plan (if any).
    func mostRecentWeekendPlan() -> MultiDayPlan? {
        allPlans().first
    }

    // MARK: - Private

    private func purgeOldEntries(_ plans: inout [MultiDayPlan]) {
        let cutoff = Calendar.current.date(byAdding: .day, value: -maxAgeDays, to: Date()) ?? Date()
        plans.removeAll { $0.createdAt < cutoff }
    }

    private func save(_ plans: [MultiDayPlan]) {
        if let data = try? JSONEncoder().encode(plans) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
