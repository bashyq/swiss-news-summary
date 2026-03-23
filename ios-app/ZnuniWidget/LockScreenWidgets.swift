import SwiftUI
import WidgetKit

// MARK: - Weather Lock Screen Widget
// Uses the same TodayWidgetProvider and WidgetNewsEntry as TodayWidget

/// Circular lock screen widget — weather icon + temperature
struct WeatherAccessoryCircularView: View {
    let entry: WidgetNewsEntry

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 1) {
                Image(systemName: entry.weatherSFSymbol)
                    .font(.title3)
                    .widgetAccentable()
                Text("\(Int(entry.temperature))°")
                    .font(.caption.weight(.semibold))
            }
        }
    }
}

/// Rectangular lock screen widget — weather + top headline
struct WeatherAccessoryRectangularView: View {
    let entry: WidgetNewsEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: entry.weatherSFSymbol)
                    .font(.caption)
                    .widgetAccentable()
                Text("\(Int(entry.temperature))° \(entry.weatherDescription)")
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
            }
            Text(entry.topHeadline)
                .font(.caption2)
                .lineLimit(2)
                .foregroundStyle(.secondary)
        }
    }
}

/// Inline lock screen widget — temperature + city
struct WeatherAccessoryInlineView: View {
    let entry: WidgetNewsEntry

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: entry.weatherSFSymbol)
            Text("\(Int(entry.temperature))° \(entry.cityName)")
        }
    }
}

/// Lock screen weather widget configuration
struct WeatherLockScreenWidget: Widget {
    let kind = "WeatherLockScreenWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodayWidgetProvider()) { entry in
            WeatherLockScreenEntryView(entry: entry)
        }
        .configurationDisplayName("Weather")
        .description("Current temperature and conditions")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct WeatherLockScreenEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: WidgetNewsEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            WeatherAccessoryCircularView(entry: entry)
        case .accessoryRectangular:
            WeatherAccessoryRectangularView(entry: entry)
        case .accessoryInline:
            WeatherAccessoryInlineView(entry: entry)
        default:
            WeatherAccessoryCircularView(entry: entry)
        }
    }
}

// MARK: - News Lock Screen Widget
// Uses NewsWidgetProvider and WidgetHeadlinesEntry

/// Circular lock screen widget — newspaper icon with headline count
struct NewsAccessoryCircularView: View {
    let entry: WidgetHeadlinesEntry

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 1) {
                Image(systemName: "newspaper.fill")
                    .font(.title3)
                    .widgetAccentable()
                Text("\(entry.headlines.count)")
                    .font(.caption.weight(.semibold))
            }
        }
    }
}

/// Rectangular lock screen widget — top 2 headlines
struct NewsAccessoryRectangularView: View {
    let entry: WidgetHeadlinesEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: "newspaper.fill")
                    .font(.caption2)
                    .widgetAccentable()
                Text(entry.cityName)
                    .font(.caption2.weight(.semibold))
            }

            if let first = entry.headlines.first {
                Text(first.localizedHeadline(entry.language))
                    .font(.caption2)
                    .lineLimit(2)
            }
        }
    }
}

/// Inline lock screen widget — top headline
struct NewsAccessoryInlineView: View {
    let entry: WidgetHeadlinesEntry

    var body: some View {
        if let first = entry.headlines.first {
            Text(first.localizedHeadline(entry.language))
                .lineLimit(1)
        } else {
            Text("No headlines")
        }
    }
}

/// Lock screen news widget configuration
struct NewsLockScreenWidget: Widget {
    let kind = "NewsLockScreenWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NewsWidgetProvider()) { entry in
            NewsLockScreenEntryView(entry: entry)
        }
        .configurationDisplayName("News Headlines")
        .description("Latest headline at a glance")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct NewsLockScreenEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: WidgetHeadlinesEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            NewsAccessoryCircularView(entry: entry)
        case .accessoryRectangular:
            NewsAccessoryRectangularView(entry: entry)
        case .accessoryInline:
            NewsAccessoryInlineView(entry: entry)
        default:
            NewsAccessoryCircularView(entry: entry)
        }
    }
}

// MARK: - Transport Lock Screen Widget
// Uses TodayWidgetProvider — shows transport status

/// Circular lock screen widget — transport status indicator
struct TransportAccessoryCircularView: View {
    let entry: WidgetNewsEntry

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 1) {
                Image(systemName: "tram.fill")
                    .font(.title3)
                    .widgetAccentable()
                if entry.transportDelays > 0 {
                    Text("\(entry.transportDelays)")
                        .font(.caption.weight(.semibold))
                } else {
                    Image(systemName: "checkmark")
                        .font(.caption2.weight(.bold))
                }
            }
        }
    }
}

/// Rectangular lock screen widget — transport delays summary
struct TransportAccessoryRectangularView: View {
    let entry: WidgetNewsEntry

    private var widgetLanguage: String {
        UserDefaults(suiteName: "group.com.todayinswitzerland")?.string(forKey: "language") ?? "en"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "tram.fill")
                    .font(.caption)
                    .widgetAccentable()
                Text("Transport")
                    .font(.caption.weight(.semibold))
                Text("·")
                    .foregroundStyle(.tertiary)
                Text(entry.cityName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if entry.transportDelays > 0 {
                Text(widgetLanguage == "de"
                     ? "\(entry.transportDelays) Verspätungen"
                     : "\(entry.transportDelays) delays")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                Text(widgetLanguage == "de" ? "Keine Verspätungen" : "No delays — trains on time")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// Inline lock screen widget — quick transport status
struct TransportAccessoryInlineView: View {
    let entry: WidgetNewsEntry

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "tram.fill")
            if entry.transportDelays > 0 {
                Text("\(entry.transportDelays) delays")
            } else {
                Text("Trains OK")
            }
        }
    }
}

/// Lock screen transport widget configuration
struct TransportLockScreenWidget: Widget {
    let kind = "TransportLockScreenWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodayWidgetProvider()) { entry in
            TransportLockScreenEntryView(entry: entry)
        }
        .configurationDisplayName("Transport")
        .description("Train delay status")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct TransportLockScreenEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: WidgetNewsEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            TransportAccessoryCircularView(entry: entry)
        case .accessoryRectangular:
            TransportAccessoryRectangularView(entry: entry)
        case .accessoryInline:
            TransportAccessoryInlineView(entry: entry)
        default:
            TransportAccessoryCircularView(entry: entry)
        }
    }
}
