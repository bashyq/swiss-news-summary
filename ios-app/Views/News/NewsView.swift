import SwiftUI

/// The main News tab view — landing page of the app.
///
/// Displays weather, history, transport disruptions, trending topics,
/// category-filtered news cards, and a share button.
struct NewsView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = NewsViewModel()
    @State private var showWeatherDetail = false

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(navigationTitle)
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        shareButton
                    }
                }
                .refreshable {
                    await viewModel.loadNews(
                        city: appState.city,
                        language: appState.language,
                        forceRefresh: true
                    )
                }
                .task {
                    await viewModel.loadNews(
                        city: appState.city,
                        language: appState.language
                    )
                }
                .onChange(of: appState.city) { _, _ in
                    Task {
                        await viewModel.loadNews(
                            city: appState.city,
                            language: appState.language,
                            forceRefresh: true
                        )
                    }
                }
                .onChange(of: appState.language) { _, _ in
                    Task {
                        await viewModel.loadNews(
                            city: appState.city,
                            language: appState.language,
                            forceRefresh: true
                        )
                    }
                }
                .sheet(isPresented: $showWeatherDetail) {
                    if let weather = viewModel.newsData?.weather {
                        WeatherDetailSheet(weather: weather)
                    }
                }
        }
    }

    // MARK: - Navigation Title

    private var navigationTitle: String {
        let cityName = appState.city.localizedName(language: appState.language)
        return appState.localized(
            en: "Today in \(cityName)",
            de: "Heute in \(cityName)"
        )
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.newsData == nil {
            LoadingView(message: appState.localized(
                en: "Loading news...",
                de: "Nachrichten laden..."
            ))
        } else if let error = viewModel.error, viewModel.newsData == nil {
            ErrorView(message: error) {
                Task {
                    await viewModel.loadNews(
                        city: appState.city,
                        language: appState.language,
                        forceRefresh: true
                    )
                }
            }
        } else {
            newsContent
        }
    }

    private var newsContent: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // 1. Compact weather (tappable)
                if let weather = viewModel.newsData?.weather {
                    WeatherCompactView(weather: weather) {
                        showWeatherDetail = true
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                }

                // 2. History banner
                if let history = viewModel.newsData?.history {
                    HistoryBanner(history: history)
                        .padding(.horizontal)
                        .padding(.top, 12)
                }

                // 3. Transport widget
                if let transport = viewModel.newsData?.transport,
                   !transport.delays.isEmpty {
                    TransportWidget(transport: transport)
                        .padding(.horizontal)
                        .padding(.top, 12)
                }

                // 4. Trending banner
                if let trending = viewModel.newsData?.trending,
                   let topic = trending.localizedTopic(language: appState.language) {
                    TrendingBanner(text: topic)
                        .padding(.horizontal)
                        .padding(.top, 12)
                }

                // 5. Category tabs
                if !viewModel.categoryKeys.isEmpty {
                    NewsCategoryTab(
                        categoryKeys: viewModel.categoryKeys,
                        selectedCategory: $viewModel.selectedCategory,
                        itemCount: viewModel.itemCount
                    )
                    .padding(.top, 16)
                }

                // 6. Inline loading indicator for background refresh
                if viewModel.isLoading && viewModel.newsData != nil {
                    InlineLoadingView()
                        .padding(.top, 4)
                }

                // 7. News cards for current category
                if viewModel.currentItems.isEmpty {
                    emptyCategory
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.currentItems) { item in
                            NewsCard(item: item)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyCategory: some View {
        VStack(spacing: 8) {
            Image(systemName: "newspaper")
                .font(.title)
                .foregroundStyle(.secondary)
            Text(appState.localized(
                en: "No articles in this category",
                de: "Keine Artikel in dieser Kategorie"
            ))
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Share Button

    private var shareButton: some View {
        Group {
            if let topItem = viewModel.currentItems.first {
                let shareText = buildShareText(topItem: topItem)
                ShareLink(item: shareText) {
                    Image(systemName: "square.and.arrow.up")
                }
            } else {
                EmptyView()
            }
        }
    }

    private func buildShareText(topItem: NewsItem) -> String {
        let cityName = appState.city.localizedName(language: appState.language)
        let headline = topItem.localizedHeadline(language: appState.language)
        let summary = topItem.localizedSummary(language: appState.language)

        return appState.localized(
            en: "Today in \(cityName): \(headline) -- \(summary)",
            de: "Heute in \(cityName): \(headline) -- \(summary)"
        )
    }
}

// MARK: - Trending Banner

/// A small banner showing the current trending topic
private struct TrendingBanner: View {
    let text: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "flame.fill")
                .font(.caption)
                .foregroundStyle(.orange)
            Text(text)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    NewsView()
        .environment(AppState())
}
