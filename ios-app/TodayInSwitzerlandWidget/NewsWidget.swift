import SwiftUI
import WidgetKit

// MARK: - Language Helper

private var widgetLanguage: String {
    UserDefaults(suiteName: "group.com.todayinswitzerland")?.string(forKey: "language") ?? "en"
}

private func localized(en: String, de: String) -> String {
    widgetLanguage == "de" ? de : en
}

// MARK: - Timeline Provider

struct NewsWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> WidgetHeadlinesEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (WidgetHeadlinesEntry) -> Void) {
        completion(.placeholder)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WidgetHeadlinesEntry>) -> Void) {
        Task {
            let city = UserDefaults(suiteName: "group.com.todayinswitzerland")?.string(forKey: "city") ?? "zurich"
            let language = UserDefaults(suiteName: "group.com.todayinswitzerland")?.string(forKey: "language") ?? "en"

            let entry = await WidgetDataProvider.fetchHeadlines(city: city, language: language) ?? .placeholder

            // Refresh every 30 minutes
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
        }
    }
}

// MARK: - Medium Widget View

struct NewsWidgetMediumView: View {
    let entry: WidgetHeadlinesEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: "newspaper.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
                Text(entry.cityName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                // Compact weather
                HStack(spacing: 3) {
                    Image(systemName: entry.weatherSFSymbol)
                        .font(.caption2)
                        .symbolRenderingMode(.multicolor)
                    Text("\(Int(entry.temperature))°")
                        .font(.caption.weight(.medium))
                }
                .foregroundStyle(.secondary)
            }

            // Headlines
            ForEach(Array(entry.headlines.prefix(3).enumerated()), id: \.offset) { index, item in
                HStack(alignment: .top, spacing: 8) {
                    Circle()
                        .fill(dotColor(index))
                        .frame(width: 6, height: 6)
                        .padding(.top, 5)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(item.localizedHeadline(entry.language))
                            .font(.caption.weight(.medium))
                            .lineLimit(2)
                        if let source = item.source {
                            Text(source)
                                .font(.system(size: 9))
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private func dotColor(_ index: Int) -> Color {
        switch index {
        case 0: return .red
        case 1: return .blue
        case 2: return .orange
        default: return .gray
        }
    }
}

// MARK: - Large Widget View

struct NewsWidgetLargeView: View {
    let entry: WidgetHeadlinesEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: "newspaper.fill")
                    .font(.subheadline)
                    .foregroundStyle(.red)
                Text(localized(en: "Headlines", de: "Schlagzeilen"))
                    .font(.subheadline.weight(.semibold))
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: entry.weatherSFSymbol)
                        .font(.caption)
                        .symbolRenderingMode(.multicolor)
                    Text("\(Int(entry.temperature))°")
                        .font(.caption.weight(.medium))
                    Text("·")
                        .foregroundStyle(.tertiary)
                    Text(entry.cityName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            // Headlines list
            ForEach(Array(entry.headlines.prefix(5).enumerated()), id: \.offset) { index, item in
                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(index + 1)")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 16, height: 16)
                            .background(rankColor(index))
                            .clipShape(Circle())
                            .padding(.top, 1)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.localizedHeadline(entry.language))
                                .font(.caption.weight(.medium))
                                .lineLimit(2)
                            if let summary = item.localizedSummary(entry.language) {
                                Text(summary)
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            if let source = item.source {
                                Text(source)
                                    .font(.system(size: 9))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }

                    if index < entry.headlines.prefix(5).count - 1 {
                        Divider()
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private func rankColor(_ index: Int) -> Color {
        switch index {
        case 0: return .red
        case 1: return .blue
        case 2: return .orange
        case 3: return .purple
        case 4: return .teal
        default: return .gray
        }
    }
}

// MARK: - Widget Configuration

struct NewsWidget: Widget {
    let kind = "NewsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NewsWidgetProvider()) { entry in
            NewsWidgetEntryView(entry: entry)
        }
        .configurationDisplayName(localized(en: "News Headlines", de: "Schlagzeilen"))
        .description(localized(en: "Latest Swiss news headlines", de: "Neueste Schweizer Schlagzeilen"))
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

struct NewsWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: WidgetHeadlinesEntry

    var body: some View {
        switch family {
        case .systemMedium:
            NewsWidgetMediumView(entry: entry)
        case .systemLarge:
            NewsWidgetLargeView(entry: entry)
        default:
            NewsWidgetMediumView(entry: entry)
        }
    }
}
