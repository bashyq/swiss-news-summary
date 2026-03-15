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
        VStack(alignment: .leading, spacing: 8) {
            // Weather row
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Image(systemName: entry.weatherSFSymbol)
                    .font(.title2)
                    .symbolRenderingMode(.multicolor)
                Text("\(Int(entry.temperature))°")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(Color("znInk"))
            }

            Text(entry.weatherDescription)
                .font(.caption2)
                .foregroundStyle(Color("znBody"))
                .lineLimit(1)

            Spacer()

            // City
            Text(entry.cityName.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Color("znMuted"))
                .tracking(0.5)

            // Transport status
            HStack(spacing: 5) {
                Circle()
                    .fill(transportColor)
                    .frame(width: 7, height: 7)
                Text(transportLabel)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(Color("znBody"))
            }
        }
        .padding(14)
        .containerBackground(for: .widget) {
            Color("znSurface")
        }
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
        case "minor": return localized(en: "\(entry.transportDelays) delays", de: "\(entry.transportDelays) Versp.")
        case "major": return localized(en: "\(entry.transportDelays) delays", de: "\(entry.transportDelays) Versp.")
        default: return "—"
        }
    }
}

// MARK: - Medium Widget View

struct TodayWidgetMediumView: View {
    let entry: WidgetNewsEntry

    var body: some View {
        HStack(spacing: 14) {
            // Left: Weather column
            VStack(alignment: .leading, spacing: 4) {
                Image(systemName: entry.weatherSFSymbol)
                    .font(.largeTitle)
                    .symbolRenderingMode(.multicolor)
                Text("\(Int(entry.temperature))°")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(Color("znInk"))
                Text(entry.weatherDescription)
                    .font(.caption2)
                    .foregroundStyle(Color("znBody"))
                    .lineLimit(1)

                Spacer()

                HStack(spacing: 5) {
                    Circle()
                        .fill(transportColor)
                        .frame(width: 7, height: 7)
                    Text(entry.transportStatus == "none"
                         ? localized(en: "Trains OK", de: "Züge OK")
                         : localized(en: "\(entry.transportDelays) delays", de: "\(entry.transportDelays) Versp."))
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(Color("znBody"))
                }
            }
            .frame(width: 90)

            // Divider
            Rectangle()
                .fill(Color("znBorder"))
                .frame(width: 1)
                .padding(.vertical, 4)

            // Right: Headline
            VStack(alignment: .leading, spacing: 6) {
                Text(entry.cityName.uppercased())
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Color("znNavy"))
                    .tracking(0.5)

                Text(entry.topHeadline)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color("znInk"))
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()
            }
        }
        .padding(14)
        .containerBackground(for: .widget) {
            Color("znSurface")
        }
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
        .description(localized(en: "Weather, headlines & transport", de: "Wetter, Schlagzeilen & ÖV"))
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
