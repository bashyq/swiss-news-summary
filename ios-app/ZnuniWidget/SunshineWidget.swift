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

struct SunshineWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> WidgetSunshineEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (WidgetSunshineEntry) -> Void) {
        completion(.placeholder)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WidgetSunshineEntry>) -> Void) {
        Task {
            let language = UserDefaults(suiteName: "group.com.todayinswitzerland")?.string(forKey: "language") ?? "en"

            let entry = await WidgetDataProvider.fetchSunshine(language: language) ?? .placeholder

            // Refresh every 30 minutes
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
        }
    }
}

// MARK: - Sunshine Widget View

struct SunshineWidgetView: View {
    let entry: WidgetSunshineEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: "sun.max.fill")
                    .font(.caption)
                    .foregroundStyle(Color("znTerracotta"))
                Text(localized(en: "WEEKEND SUN", de: "WOCHENEND-SONNE").uppercased())
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Color("znTerracotta"))
                    .tracking(0.5)
                Spacer()
                // Zürich baseline
                HStack(spacing: 3) {
                    Text("ZH")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Color("znNavy"))
                    Text("\(String(format: "%.0f", entry.baselineSunshineHours))h")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(Color("znBody"))
                }
            }

            // Top 3 sunny destinations
            ForEach(entry.topDestinations.indices, id: \.self) { index in
                let dest = entry.topDestinations[index]
                HStack(spacing: 10) {
                    // Rank
                    Text("\(index + 1)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 18, height: 18)
                        .background(rankColor(index))
                        .clipShape(Circle())

                    // Name
                    Text(dest.name)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color("znInk"))
                        .lineLimit(1)

                    Spacer()

                    // Sunshine hours
                    HStack(spacing: 3) {
                        Image(systemName: "sun.max.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(Color("znTerracotta"))
                        Text("\(String(format: "%.0f", dest.sunshineHours))h")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Color("znInk"))
                    }

                    // Drive time
                    HStack(spacing: 3) {
                        Image(systemName: "car.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(Color("znMuted"))
                        Text("\(dest.driveMinutes)m")
                            .font(.caption2)
                            .foregroundStyle(Color("znMuted"))
                    }
                    .frame(width: 48, alignment: .trailing)
                }
            }
        }
        .padding(14)
        .containerBackground(for: .widget) {
            Color("znSurface")
        }
    }

    private func rankColor(_ index: Int) -> Color {
        switch index {
        case 0: return Color("znTerracotta")
        case 1: return Color("znNavy")
        case 2: return Color("znMuted")
        default: return Color("znMuted")
        }
    }
}

// MARK: - Widget Configuration

struct SunshineWidget: Widget {
    let kind = "SunshineWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SunshineWidgetProvider()) { entry in
            SunshineWidgetView(entry: entry)
        }
        .configurationDisplayName(localized(en: "Weekend Sunshine", de: "Wochenend-Sonnenschein"))
        .description(localized(en: "Top 3 sunniest weekend destinations", de: "Top 3 sonnigste Wochenendziele"))
        .supportedFamilies([.systemMedium])
    }
}
