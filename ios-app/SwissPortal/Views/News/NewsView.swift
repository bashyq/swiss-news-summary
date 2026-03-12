import SwiftUI

/// The main News tab view — landing page of the app.
///
/// Displays a full-width hero with weather, history, transport,
/// category-filtered accordion news cards.
struct NewsView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = NewsViewModel()
    @State private var showWeatherDetail = false
    @State private var showHolidayDetail = false
    @State private var expandedNewsID: String?

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
            .sheet(isPresented: $showHolidayDetail) {
                HolidayDetailSheet()
                    .presentationDetents([.medium])
            }
            .onChange(of: viewModel.selectedCategory) { _, _ in
                expandedNewsID = nil
            }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.newsData == nil {
            VStack(spacing: 0) {
                NewsHeroBanner(weather: nil, onWeatherTap: {}, onHolidayTap: { showHolidayDetail = true })
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(0..<5, id: \.self) { _ in
                            SkeletonNewsCard()
                        }
                        .padding(.horizontal)
                    }
                }
            }
        } else if let error = viewModel.error, viewModel.newsData == nil {
            VStack(spacing: 0) {
                NewsHeroBanner(weather: nil, onWeatherTap: {}, onHolidayTap: { showHolidayDetail = true })
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
        case 0...3: return Color.znTerracotta.opacity(0.03)
        case 51...67, 80...82: return Color.znNavy.opacity(0.03)
        case 71...77, 85, 86: return Color.znMuted.opacity(0.03)
        default: return nil
        }
    }

    private var newsContent: some View {
        VStack(spacing: 0) {
            // Hero banner with weather — outside ScrollView so navy extends behind Dynamic Island
            NewsHeroBanner(
                weather: viewModel.newsData?.weather,
                onWeatherTap: { showWeatherDetail = true },
                onHolidayTap: { showHolidayDetail = true }
            )

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        // History banner
                        if let history = viewModel.newsData?.history {
                            HistoryBanner(history: history)
                                .padding(.horizontal)
                                .padding(.top, 12)
                        }

                        // Transport widget
                        if let transport = viewModel.newsData?.transport,
                           !transport.delays.isEmpty {
                            TransportWidget(transport: transport)
                                .padding(.horizontal)
                                .padding(.top, 12)
                        }

                        // Category tabs
                        if !viewModel.categoryKeys.isEmpty {
                            NewsCategoryTab(
                                categoryKeys: viewModel.categoryKeys,
                                selectedCategory: $viewModel.selectedCategory,
                                itemCount: viewModel.itemCount
                            )
                            .padding(.top, 16)
                        }

                        // Inline loading indicator for background refresh
                        if viewModel.isLoading && viewModel.newsData != nil {
                            InlineLoadingView()
                                .padding(.top, 4)
                        }

                        // News cards — accordion
                        if viewModel.currentItems.isEmpty {
                            emptyCategory
                        } else {
                            LazyVStack(spacing: 12) {
                                ForEach(viewModel.currentItems) { item in
                                    NewsCard(
                                        item: item,
                                        category: viewModel.selectedCategory,
                                        expandedID: $expandedNewsID
                                    )
                                    .id(item.id)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.top, 12)
                            .padding(.bottom, 24)
                        }
                    }
                }
                .refreshable {
                    await viewModel.loadNews(
                        city: appState.city,
                        language: appState.language,
                        forceRefresh: true
                    )
                }
                .onChange(of: expandedNewsID) { _, newID in
                    if let newID {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            withAnimation {
                                proxy.scrollTo(newID, anchor: .top)
                            }
                        }
                    }
                }
            }
        }
        .background(weatherTintColor ?? .clear)
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
}

#Preview {
    NewsView()
        .environment(AppState())
}
