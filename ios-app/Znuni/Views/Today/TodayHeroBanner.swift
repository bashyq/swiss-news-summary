import SwiftUI

/// Sub-view toggle for the Today tab: News (default) or Plan.
enum TodaySubView: String, CaseIterable {
    case news
    case plan
}

/// Full-width gradient hero for the Today tab.
///
/// Shows a Plan/News segment control in the header.
/// - **News mode**: story count + category filter pills
/// - **Plan browsing**: weather, session pill, context banner
/// Same edge-to-edge pattern: VStack content with `.background {}` modifier.
struct TodayHeroBanner: View {
    @Environment(AppState.self) private var appState

    let weather: Weather?
    let badWeatherMode: Bool
    let planningDate: Date
    @Binding var subView: TodaySubView
    var onHolidayTap: (() -> Void)?

    // News mode properties
    var totalStoryCount: Int = 0
    var categoryKeys: [String] = []
    @Binding var selectedCategory: String
    var itemCount: ((String) -> Int)?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Eyebrow + segment control + city selector row
            HStack(alignment: .center) {
                Text(eyebrowDate)
                    .font(.znEyebrow)
                    .tracking(1.3)
                    .textCase(.uppercase)
                    .foregroundStyle(badWeatherMode
                        ? Color(red: 0.96, green: 0.91, blue: 0.83).opacity(0.42)
                        : .white.opacity(0.42))

                Spacer()

                segmentControl

                CityMenuButton()
            }
            .padding(.bottom, 2)

            // Title row
            titleText
                .padding(.bottom, 6)

            // Compact weather row (both modes)
            if let weather {
                weatherCompactRow(weather)
                    .padding(.bottom, 12)
            } else {
                Spacer().frame(height: 8)
            }

            // Mode-specific content
            if subView == .plan {
                planHeaderContent
            } else {
                newsHeaderContent
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 18)
        .padding(.bottom, 24)
        .background {
            ZStack(alignment: .bottomTrailing) {
                (badWeatherMode ? Color(red: 0.173, green: 0.125, blue: 0.094) : Color.znNavy)
                    .ignoresSafeArea(.container, edges: .top)

                // Subtle warm glow (top-right)
                RadialGradient(
                    colors: [
                        badWeatherMode
                            ? Color(red: 1, green: 0.31, blue: 0.16).opacity(0.15)
                            : Color.znTerracotta.opacity(0.22),
                        .clear
                    ],
                    center: UnitPoint(x: 1.2, y: -0.3),
                    startRadius: 0,
                    endRadius: 220
                )

                // Skyline silhouette (bottom-right, 9% opacity)
                SkylineIllustration()
                    .frame(width: 200, height: 110)
                    .opacity(0.09)
            }
        }
    }

    // MARK: - Segment Control

    private var segmentControl: some View {
        HStack(spacing: 2) {
            ForEach(TodaySubView.allCases, id: \.self) { tab in
                let isActive = subView == tab
                let label = tab == .plan
                    ? appState.localized(en: "Plan", de: "Plan")
                    : appState.localized(en: "News", de: "News")

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        subView = tab
                    }
                } label: {
                    Text(label)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(isActive ? Color.znNavy : .white.opacity(0.5))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 5)
                        .background(isActive ? .white : .clear)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .sensoryFeedback(.selection, trigger: isActive)
            }
        }
        .padding(3)
        .background(.white.opacity(0.1))
        .clipShape(Capsule())
    }

    // MARK: - Plan Header Content (moved to YourDayConfigSection)

    @ViewBuilder
    private var planHeaderContent: some View {
        EmptyView()
    }

    // MARK: - News Header Content

    @ViewBuilder
    private var newsHeaderContent: some View {
        // Story count
        HStack(spacing: 0) {
            Text("\(totalStoryCount) ")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.8))
            + Text(appState.localized(en: "stories today", de: "Meldungen heute"))
                .font(.system(size: 13, weight: .light))
                .foregroundStyle(.white.opacity(0.55))
        }
        .padding(.bottom, 10)

        // Category filter pills
        if !categoryKeys.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(categoryKeys, id: \.self) { key in
                        let isSelected = selectedCategory == key
                        let count = itemCount?(key) ?? 0

                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                selectedCategory = key
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(NewsCategories.displayName(for: key, language: appState.language))
                                    .font(.system(size: 11, weight: .medium))

                                if count > 0 {
                                    Text("\(count)")
                                        .font(.system(size: 9))
                                        .frame(width: 16, height: 16)
                                        .background(
                                            isSelected
                                                ? Color.znNavy.opacity(0.15)
                                                : .white.opacity(0.15)
                                        )
                                        .clipShape(Circle())
                                }
                            }
                            .padding(.horizontal, 12)
                            .frame(height: 26)
                            .background(isSelected ? .white : .clear)
                            .foregroundStyle(isSelected ? Color.znNavy : .white.opacity(0.55))
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(isSelected ? .clear : .white.opacity(0.15), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .sensoryFeedback(.selection, trigger: isSelected)
                    }
                }
            }
        }

        // Next holiday row (in news mode)
        if let nextHoliday = SwissHolidayCalculator.upcomingHolidays().first {
            Button {
                onHolidayTap?()
            } label: {
                nextHolidayRow(nextHoliday)
            }
            .buttonStyle(.plain)
            .padding(.top, 10)
        }
    }

    // MARK: - Eyebrow Date

    private var eyebrowDate: String {
        let formatter = DateFormatter()
        formatter.locale = appState.language == .de
            ? Locale(identifier: "de_CH")
            : Locale(identifier: "en_US")
        formatter.dateFormat = appState.language == .de
            ? "EEEE · d. MMMM"
            : "EEEE · d MMMM"
        // News mode always shows today; Plan mode uses planningDate
        let displayDate = subView == .news ? Date() : planningDate
        return formatter.string(from: displayDate)
    }

    /// Whether we're planning for a future date (e.g. tomorrow after 8 PM)
    /// Only applies in Plan mode — News always shows "Today".
    private var isNextDayMode: Bool {
        subView == .plan && !Calendar.current.isDateInToday(planningDate)
    }

    // MARK: - Title

    private var titleText: some View {
        let cityName = appState.city.localizedName(language: appState.language)
        let titleColor: Color = badWeatherMode
            ? Color(red: 0.96, green: 0.91, blue: 0.83)
            : .white
        let titleLabel = isNextDayMode
            ? appState.localized(en: "Tomorrow in", de: "Morgen in")
            : appState.localized(en: "Today in", de: "Heute in")

        return HStack(spacing: 6) {
            Text(titleLabel)
                .font(.bannerTitle)
                .foregroundStyle(titleColor)
            Text(cityName)
                .font(.custom("Playfair", size: 28).italic())
                .foregroundStyle(titleColor.opacity(0.6))
        }
    }

    // MARK: - Weather Compact Row

    private func weatherCompactRow(_ weather: Weather) -> some View {
        let textColor: Color = badWeatherMode
            ? Color(red: 0.96, green: 0.91, blue: 0.83)
            : .white

        return HStack(spacing: 8) {
            Image(systemName: weather.sfSymbol)
                .symbolRenderingMode(.multicolor)
                .font(.system(size: 18))

            Text("\(Int(weather.temperature))°")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(textColor)

            Text(weather.description)
                .font(.system(size: 13))
                .foregroundStyle(textColor.opacity(0.6))

            if let high = weather.highTemp, let low = weather.lowTemp {
                Text("H:\(Int(high))° L:\(Int(low))°")
                    .font(.system(size: 12))
                    .foregroundStyle(textColor.opacity(0.45))
            }
        }
    }

    // MARK: - Holiday Row

    private func nextHolidayRow(_ holiday: Holiday) -> some View {
        HStack(spacing: 8) {
            Text("🇨🇭")
                .font(.system(size: 13))

            Text(holiday.localizedName(language: appState.language))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(badWeatherMode
                    ? Color(red: 0.96, green: 0.91, blue: 0.83).opacity(0.7)
                    : .white.opacity(0.7))

            Spacer()

            Text(daysUntilText(holiday.daysUntil))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color(red: 0.94, green: 0.66, blue: 0.51)) // #F0A882
                .padding(.horizontal, 9)
                .padding(.vertical, 3)
                .background(Color.znTerracotta.opacity(0.25))
                .clipShape(Capsule())

            Image(systemName: "chevron.right")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(badWeatherMode
                    ? Color(red: 0.96, green: 0.91, blue: 0.83).opacity(0.3)
                    : .white.opacity(0.3))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(badWeatherMode
            ? Color(red: 0.96, green: 0.91, blue: 0.83).opacity(0.07)
            : .white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func daysUntilText(_ days: Int) -> String {
        if days == 0 {
            return appState.localized(en: "Today", de: "Heute")
        } else if days == 1 {
            return appState.localized(en: "Tomorrow", de: "Morgen")
        } else {
            return appState.localized(en: "in \(days) days", de: "in \(days) Tagen")
        }
    }
}

#Preview {
    TodayHeroBanner(
        weather: Weather(
            temperature: 7,
            description: "Rain showers",
            weatherCode: 80,
            windSpeed: 12,
            hourly: nil
        ),
        badWeatherMode: false,
        planningDate: Date(),
        subView: .constant(.plan),
        onHolidayTap: {},
        totalStoryCount: 19,
        categoryKeys: ["topStories", "politics", "events"],
        selectedCategory: .constant("topStories"),
        itemCount: { _ in 5 }
    )
    .environment(AppState())
}
