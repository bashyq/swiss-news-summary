import SwiftUI
import WidgetKit

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
            HStack {
                Image(systemName: "sun.max.fill")
                    .foregroundStyle(.orange)
                Text("Weekend Sunshine")
                    .font(.caption.weight(.semibold))
                Spacer()
                // Zürich baseline
                Text("ZH: \(String(format: "%.0f", entry.baselineSunshineHours))h")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            // Top 3 sunny destinations
            ForEach(entry.topDestinations.indices, id: \.self) { index in
                let dest = entry.topDestinations[index]
                HStack(spacing: 8) {
                    // Rank
                    Text("\(index + 1)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 16, height: 16)
                        .background(rankColor(index))
                        .clipShape(Circle())

                    // Name
                    Text(dest.name)
                        .font(.caption.weight(.medium))
                        .lineLimit(1)

                    Spacer()

                    // Sunshine hours
                    HStack(spacing: 2) {
                        Image(systemName: "sun.max.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(.orange)
                        Text("\(String(format: "%.0f", dest.sunshineHours))h")
                            .font(.caption2.weight(.semibold))
                    }

                    // Drive time
                    HStack(spacing: 2) {
                        Image(systemName: "car.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                        Text("\(dest.driveMinutes)m")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private func rankColor(_ index: Int) -> Color {
        switch index {
        case 0: return .orange
        case 1: return .blue
        case 2: return .gray
        default: return .gray
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
        .configurationDisplayName("Weekend Sunshine")
        .description("Top 3 sunniest weekend destinations")
        .supportedFamilies([.systemMedium])
    }
}
