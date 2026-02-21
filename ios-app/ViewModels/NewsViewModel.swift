import Foundation

/// ViewModel for the News view — manages fetching, caching, and category selection.
@Observable
final class NewsViewModel {

    // MARK: - Published State

    /// The full news response from the API (weather, transport, holidays, categories, etc.)
    var newsData: NewsResponse?

    /// Currently selected category tab key (e.g., "topStories", "politics")
    var selectedCategory: String = "topStories"

    /// Whether a network fetch is in progress
    var isLoading: Bool = false

    /// Human-readable error message if the last fetch failed
    var error: String?

    // MARK: - Computed Properties

    /// News items for the currently selected category
    var currentItems: [NewsItem] {
        guard let categories = newsData?.categories else { return [] }
        return categories.items(for: selectedCategory)
    }

    /// Category keys that have at least one item, preserving display order
    var categoryKeys: [String] {
        guard let categories = newsData?.categories else { return [] }
        return NewsCategories.allKeys.filter { !categories.items(for: $0).isEmpty }
    }

    /// Number of items in a given category
    func itemCount(for key: String) -> Int {
        guard let categories = newsData?.categories else { return 0 }
        return categories.items(for: key).count
    }

    // MARK: - Loading

    /// Load news for the given city and language.
    ///
    /// Strategy: show cached data immediately (if available), then fetch fresh data in the background.
    /// When `forceRefresh` is true, cached data is bypassed entirely.
    @MainActor
    func loadNews(city: City, language: AppLanguage, forceRefresh: Bool = false) async {
        let cacheKey = CacheKey.news(city: city, language: language)

        // 1. Show cached data immediately (unless forcing refresh)
        if !forceRefresh {
            let cached: NewsResponse? = await CacheManager.shared.get(
                NewsResponse.self,
                key: cacheKey,
                ttl: .news
            )
            if let cached {
                self.newsData = cached
                // Ensure selected category is still valid after loading cached data
                if !categoryKeys.contains(selectedCategory), let first = categoryKeys.first {
                    selectedCategory = first
                }
            }
        }

        // 2. Fetch fresh data from the API
        isLoading = true
        error = nil

        do {
            let response = try await APIClient.shared.fetchNews(
                city: city,
                language: language,
                forceRefresh: forceRefresh
            )

            self.newsData = response

            // Cache the fresh response
            await CacheManager.shared.set(response, key: cacheKey)

            // Ensure selected category is still valid after loading fresh data
            if !categoryKeys.contains(selectedCategory), let first = categoryKeys.first {
                selectedCategory = first
            }

            self.error = nil
        } catch {
            // Only set error if we have no cached data to show
            if self.newsData == nil {
                self.error = error.localizedDescription
            }
        }

        isLoading = false
    }
}
