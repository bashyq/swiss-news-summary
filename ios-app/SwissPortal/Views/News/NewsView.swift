import SwiftUI

/// The main News tab view — landing page of the app.
///
/// Displays weather, history, transport disruptions, trending topics,
/// category-filtered news cards, and a share button.
struct NewsView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = NewsViewModel()
    @State private var showWeatherDetail = false
    @State private var briefingDismissedToday = false

    var body: some View {
        content
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .task(id: "\(appState.city.id)-\(appState.language)") {
                await viewModel.loadNews(
                    city: appState.city,
                    language: appState.language
                )
            }
            .sheet(isPresented: $showWeatherDetail) {
                if let weather = viewModel.newsData?.weather {
                    WeatherDetailSheet(weather: weather)
                        .presentationDetents([.medium, .large])
                }
            }
            .onAppear {
                checkBriefingDismissed()
            }
    }

    // MARK: - Briefing Helpers

    private func checkBriefingDismissed() {
        let key = "briefingDismissed"
        let todayString = DateHelpers.toISO(Date())
        briefingDismissedToday = UserDefaults.standard.string(forKey: key) == todayString
    }

    private func dismissBriefing() {
        let key = "briefingDismissed"
        let todayString = DateHelpers.toISO(Date())
        UserDefaults.standard.set(todayString, forKey: key)
        withAnimation {
            briefingDismissedToday = true
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

    // MARK: - Hero Banner

    private var heroBanner: some View {
        HeroBanner(style: .news, title: navigationTitle) {
            HStack(spacing: 14) {
                weatherButton
                cityMenuButton
            }
        }
    }

    private var weatherButton: some View {
        Button {
            showWeatherDetail = true
        } label: {
            HStack(spacing: 4) {
                Image(systemName: viewModel.newsData?.weather.sfSymbol ?? "cloud.sun.fill")
                    .symbolRenderingMode(.multicolor)
                if let weather = viewModel.newsData?.weather {
                    Text("\(Int(weather.temperature))°")
                        .font(.callout)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.newsData == nil {
            ScrollView {
                VStack(spacing: 12) {
                    heroBanner
                        .padding(.horizontal)
                        .padding(.top, 8)
                    ForEach(0..<5, id: \.self) { _ in
                        SkeletonNewsCard()
                    }
                    .padding(.horizontal)
                }
            }
        } else if let error = viewModel.error, viewModel.newsData == nil {
            VStack(spacing: 0) {
                heroBanner
                    .padding(.horizontal)
                    .padding(.top, 8)
                ErrorView(message: error) {
                    Task {
                        await viewModel.loadNews(
                            city: appState.city,
                            language: appState.language,
                            forceRefresh: true
                        )
                    }
                }
            }
        } else {
            newsContent
        }
    }

    private var weatherTintColor: Color? {
        guard let code = viewModel.newsData?.weather.weatherCode else { return nil }
        switch code {
        case 0...3: return Color.orange.opacity(0.03)
        case 51...67, 80...82: return Color.blue.opacity(0.03)
        case 71...77, 85, 86: return Color.gray.opacity(0.03)
        default: return nil
        }
    }

    private var newsContent: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // 0. Hero banner with title + city picker + share
                heroBanner
                    .padding(.horizontal)
                    .padding(.top, 8)

                // 0.5. Briefing card (dismissible, daily)
                if let briefing = viewModel.newsData?.briefing, !briefingDismissedToday {
                    BriefingCard(briefing: briefing, onDismiss: dismissBriefing)
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
                    TrendingBanner(text: topic, url: trending.url)
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
                            NewsCard(item: item, category: viewModel.selectedCategory)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }
            }
        }
        .background(weatherTintColor ?? .clear)
        .refreshable {
            await viewModel.loadNews(
                city: appState.city,
                language: appState.language,
                forceRefresh: true
            )
        }
    }

    // MARK: - Empty State

    private var emptyCategory: some View {
        VStack(spacing: 12) {
            EmojiScene(["📰", "🇨🇭", "🏔️", "📡"])
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

    // MARK: - City Menu Button

    private var cityMenuButton: some View {
        Menu {
            ForEach(City.allCases) { city in
                Button {
                    appState.city = city
                } label: {
                    HStack {
                        Text(city.localizedName(language: appState.language))
                        if city == appState.city {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "building.2")
        }
    }

}

// MARK: - Trending Banner

/// A small banner showing the current trending topic.
/// Taps open the trending URL in the browser if available.
private struct TrendingBanner: View {
    let text: String
    let url: String?

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
            if url != nil {
                Image(systemName: "arrow.up.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
        .onTapGesture {
            if let urlString = url, let link = URL(string: urlString) {
                UIApplication.shared.open(link)
            }
        }
    }
}

#Preview {
    NewsView()
        .environment(AppState())
}
