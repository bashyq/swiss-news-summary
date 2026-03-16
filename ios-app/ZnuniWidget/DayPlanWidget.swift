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

struct DayPlanWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> WidgetDayPlanEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (WidgetDayPlanEntry) -> Void) {
        completion(WidgetDataProvider.loadDayPlan() ?? .placeholder)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WidgetDayPlanEntry>) -> Void) {
        let entry = WidgetDataProvider.loadDayPlan() ?? .placeholder

        // Refresh every 15 minutes (agenda may change from swaps/check-ins)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

// MARK: - Medium Widget View

struct DayPlanWidgetMediumView: View {
    let entry: WidgetDayPlanEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: "calendar.day.timeline.leading")
                    .font(.caption)
                    .foregroundStyle(Color("znNavy"))
                Text(localized(en: "YOUR DAY", de: "DEIN TAG").uppercased())
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Color("znNavy"))
                    .tracking(0.5)
                Spacer()
                Text(entry.weatherNote)
                    .font(.caption2)
                    .foregroundStyle(Color("znBody"))
                    .lineLimit(1)
            }

            // Compact 4-slot timeline
            HStack(spacing: 0) {
                ForEach(Array(entry.slots.prefix(4).enumerated()), id: \.element.id) { index, slot in
                    slotColumn(slot: slot, isLast: index == min(entry.slots.count, 4) - 1)

                    if index < min(entry.slots.count, 4) - 1 {
                        // Connector
                        VStack(spacing: 0) {
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 7, weight: .bold))
                                .foregroundStyle(Color("znBorder"))
                            Spacer(minLength: 0)
                        }
                        .frame(width: 12)
                    }
                }
            }
        }
        .padding(14)
        .containerBackground(for: .widget) {
            Color("znSurface")
        }
    }

    @ViewBuilder
    private func slotColumn(slot: WidgetAgendaSlot, isLast: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            // Time
            Text(slot.time)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color("znMuted"))

            // Icon + accent dot
            HStack(spacing: 4) {
                Circle()
                    .fill(slotAccentColor(slot))
                    .frame(width: 6, height: 6)
                Image(systemName: slot.slotIcon)
                    .font(.system(size: 10))
                    .foregroundStyle(slotAccentColor(slot))
            }

            // Venue name
            Text(slot.venueName)
                .font(.caption2.weight(.medium))
                .foregroundStyle(Color("znInk"))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func slotAccentColor(_ slot: WidgetAgendaSlot) -> Color {
        switch slot.type {
        case "lunch": return Color("znTerracotta")
        case "dinner": return Color(red: 0.48, green: 0.37, blue: 0.65) // purple
        case "homeActivity": return Color(red: 0.55, green: 0.41, blue: 0.08) // gold
        default: return Color("znNavy")
        }
    }
}

// MARK: - Large Widget View

struct DayPlanWidgetLargeView: View {
    let entry: WidgetDayPlanEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: "calendar.day.timeline.leading")
                    .font(.subheadline)
                    .foregroundStyle(Color("znNavy"))
                VStack(alignment: .leading, spacing: 1) {
                    Text(localized(en: "YOUR DAY", de: "DEIN TAG").uppercased())
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Color("znNavy"))
                        .tracking(0.5)
                    Text(entry.theme)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color("znInk"))
                        .lineLimit(1)
                }
                Spacer()
                Text(entry.weatherNote)
                    .font(.caption2)
                    .foregroundStyle(Color("znBody"))
                    .lineLimit(1)
            }

            Rectangle()
                .fill(Color("znBorder"))
                .frame(height: 1)

            // Vertical timeline
            ForEach(Array(entry.slots.enumerated()), id: \.element.id) { index, slot in
                HStack(alignment: .top, spacing: 12) {
                    // Time column
                    Text(slot.time)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color("znMuted"))
                        .frame(width: 42, alignment: .trailing)

                    // Timeline track
                    VStack(spacing: 0) {
                        Circle()
                            .fill(slotAccentColor(slot))
                            .frame(width: 10, height: 10)
                            .padding(.top, 3)

                        if index < entry.slots.count - 1 {
                            Rectangle()
                                .fill(Color("znBorder"))
                                .frame(width: 2)
                                .frame(maxHeight: .infinity)
                        }
                    }
                    .frame(width: 10)

                    // Slot content
                    VStack(alignment: .leading, spacing: 3) {
                        // Type eyebrow
                        Text(slotTypeLabel(slot))
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(slotAccentColor(slot))
                            .tracking(0.3)

                        // Venue name
                        Text(slot.venueName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color("znInk"))
                            .lineLimit(2)
                    }
                    .padding(.bottom, index < entry.slots.count - 1 ? 12 : 0)

                    Spacer(minLength: 0)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .containerBackground(for: .widget) {
            Color("znSurface")
        }
    }

    private func slotAccentColor(_ slot: WidgetAgendaSlot) -> Color {
        switch slot.type {
        case "lunch": return Color("znTerracotta")
        case "dinner": return Color(red: 0.48, green: 0.37, blue: 0.65)
        case "homeActivity": return Color(red: 0.55, green: 0.41, blue: 0.08)
        default: return Color("znNavy")
        }
    }

    private func slotTypeLabel(_ slot: WidgetAgendaSlot) -> String {
        switch slot.type {
        case "activity": return localized(en: "ACTIVITY", de: "AKTIVITÄT")
        case "lunch": return localized(en: "LUNCH", de: "MITTAGESSEN")
        case "dinner": return localized(en: "DINNER", de: "ABENDESSEN")
        case "homeActivity": return localized(en: "AT HOME", de: "ZUHAUSE")
        default: return slot.type.uppercased()
        }
    }
}

// MARK: - Lock Screen Accessory Views

/// Rectangular lock screen widget — next slot in agenda
struct DayPlanAccessoryRectangularView: View {
    let entry: WidgetDayPlanEntry

    var body: some View {
        if let nextSlot = nextUpcomingSlot() {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: "calendar.day.timeline.leading")
                        .font(.caption2)
                        .widgetAccentable()
                    Text(nextSlot.time)
                        .font(.caption2.weight(.semibold))
                    Text("·")
                        .foregroundStyle(.tertiary)
                    Text(slotTypeShort(nextSlot))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Text(nextSlot.venueName)
                    .font(.caption2.weight(.medium))
                    .lineLimit(2)
            }
        } else {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: "calendar.day.timeline.leading")
                        .font(.caption2)
                        .widgetAccentable()
                    Text(localized(en: "Day Plan", de: "Tagesplan"))
                        .font(.caption2.weight(.semibold))
                }
                Text(entry.theme)
                    .font(.caption2)
                    .lineLimit(2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func nextUpcomingSlot() -> WidgetAgendaSlot? {
        let now = Date()
        let cal = Calendar.current
        let hour = cal.component(.hour, from: now)
        let minute = cal.component(.minute, from: now)
        let nowMinutes = hour * 60 + minute

        return entry.slots.first { slot in
            let parts = slot.time.split(separator: ":")
            guard parts.count == 2,
                  let h = Int(parts[0]),
                  let m = Int(parts[1]) else { return false }
            return h * 60 + m > nowMinutes
        }
    }

    private func slotTypeShort(_ slot: WidgetAgendaSlot) -> String {
        switch slot.type {
        case "lunch": return localized(en: "Lunch", de: "Mittag")
        case "dinner": return localized(en: "Dinner", de: "Abend")
        default: return localized(en: "Activity", de: "Aktivität")
        }
    }
}

/// Circular lock screen widget — time of next slot
struct DayPlanAccessoryCircularView: View {
    let entry: WidgetDayPlanEntry

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            if let nextSlot = entry.slots.first {
                VStack(spacing: 1) {
                    Image(systemName: "calendar.day.timeline.leading")
                        .font(.caption2)
                        .widgetAccentable()
                    Text(nextSlot.time)
                        .font(.caption2.weight(.semibold))
                }
            } else {
                Image(systemName: "calendar.day.timeline.leading")
                    .font(.title3)
                    .widgetAccentable()
            }
        }
    }
}

// MARK: - Widget Configuration

struct DayPlanWidget: Widget {
    let kind = "DayPlanWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DayPlanWidgetProvider()) { entry in
            DayPlanWidgetEntryView(entry: entry)
        }
        .configurationDisplayName(localized(en: "Day Plan", de: "Tagesplan"))
        .description(localized(en: "Your family day agenda at a glance", de: "Euer Familientagesplan auf einen Blick"))
        .supportedFamilies([.systemMedium, .systemLarge, .accessoryRectangular, .accessoryCircular])
    }
}

struct DayPlanWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: WidgetDayPlanEntry

    var body: some View {
        switch family {
        case .systemMedium:
            DayPlanWidgetMediumView(entry: entry)
        case .systemLarge:
            DayPlanWidgetLargeView(entry: entry)
        case .accessoryRectangular:
            DayPlanAccessoryRectangularView(entry: entry)
        case .accessoryCircular:
            DayPlanAccessoryCircularView(entry: entry)
        default:
            DayPlanWidgetMediumView(entry: entry)
        }
    }
}
