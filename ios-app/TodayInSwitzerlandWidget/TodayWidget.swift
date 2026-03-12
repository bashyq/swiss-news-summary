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

struct TodayWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> WidgetNewsEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (WidgetNewsEntry) -> Void) {
        completion(.placeholder)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WidgetNewsEntry>) -> Void) {
        Task {
            let city = UserDefaults(suiteName: "group.com.todayinswitzerland")?.string(forKey: "city") ?? "zurich"
            let language = UserDefaults(suiteName: "group.com.todayinswitzerland")?.string(forKey: "language") ?? "en"

            let entry = await WidgetDataProvider.fetchNews(city: city, language: language) ?? .placeholder

            // Refresh every 30 minutes
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
        }
    }
}

// MARK: - Small Widget View

struct TodayWidgetSmallView: View {
    let entry: WidgetNewsEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Weather row
            HStack(spacing: 4) {
                Image(systemName: entry.weatherSFSymbol)
                    .font(.title2)
                    .symbolRenderingMode(.multicolor)
                Text("\(Int(entry.temperature))°")
                    .font(.title2.weight(.semibold))
                Spacer()
            }

            Text(entry.cityName)
                .font(.caption2)
                .foregroundStyle(.secondary)

            Spacer()

            // Transport status dot
            HStack(spacing: 4) {
                Circle()
                    .fill(transportColor)
                    .frame(width: 6, height: 6)
                Text(transportLabel)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var transportColor: Color {
        switch entry.transportStatus {
        case "none": return Color("znPositive")
        case "minor": return Color("znTerracotta")
        case "major": return Color("znNegative")
        default: return Color("znMuted")
        }
    }

    private var transportLabel: String {
        switch entry.transportStatus {
        case "none": return localized(en: "Trains OK", de: "Züge OK")
        case "minor": return localized(en: "\(entry.transportDelays) delays", de: "\(entry.transportDelays) Verspätungen")
        case "major": return localized(en: "\(entry.transportDelays) delays", de: "\(entry.transportDelays) Verspätungen")
        default: return "—"
        }
    }
}

// MARK: - Medium Widget View

struct TodayWidgetMediumView: View {
    let entry: WidgetNewsEntry

    var body: some View {
        HStack(spacing: 12) {
            // Left: Weather
            VStack(alignment: .leading, spacing: 4) {
                Image(systemName: entry.weatherSFSymbol)
                    .font(.largeTitle)
                    .symbolRenderingMode(.multicolor)
                Text("\(Int(entry.temperature))°")
                    .font(.title.weight(.bold))
                Text(entry.weatherDescription)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer()

                HStack(spacing: 4) {
                    Circle()
                        .fill(transportColor)
                        .frame(width: 6, height: 6)
                    Text(entry.transportStatus == "none"
                         ? localized(en: "Trains OK", de: "Züge OK")
                         : localized(en: "\(entry.transportDelays) delays", de: "\(entry.transportDelays) Verspätungen"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 80)

            // Right: Headline
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.cityName)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color("znNavy"))

                Text(entry.topHeadline)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()
            }
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var transportColor: Color {
        switch entry.transportStatus {
        case "none": return Color("znPositive")
        case "minor": return Color("znTerracotta")
        case "major": return Color("znNegative")
        default: return Color("znMuted")
        }
    }
}

// MARK: - Widget Configuration

struct TodayWidget: Widget {
    let kind = "TodayWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodayWidgetProvider()) { entry in
            TodayWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Znüni")
        .description("Weather, headlines, and transport status")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct TodayWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: WidgetNewsEntry

    var body: some View {
        switch family {
        case .systemSmall:
            TodayWidgetSmallView(entry: entry)
        case .systemMedium:
            TodayWidgetMediumView(entry: entry)
        default:
            TodayWidgetMediumView(entry: entry)
        }
    }
}
