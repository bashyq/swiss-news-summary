import SwiftUI

/// Compact event row for the "What's on today" section.
///
/// Shows emoji icon (32pt), event name, venue/time, and free badge or price.
/// Stacked with 6px gap for grouped appearance.
struct TodayEventRow: View {
    @Environment(AppState.self) private var appState

    let event: TodayEvent

    var body: some View {
        HStack(spacing: 12) {
            // Emoji icon
            Text(event.emoji)
                .font(.system(size: 26))
                .frame(width: 40, height: 40)

            // Name + venue/time
            VStack(alignment: .leading, spacing: 2) {
                Text(event.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.znInk)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    if let venue = event.venue {
                        Text(venue)
                            .font(.system(size: 12))
                            .foregroundStyle(.znMuted)
                            .lineLimit(1)
                    }

                    if let time = event.time {
                        if event.venue != nil {
                            Text("·")
                                .font(.system(size: 12))
                                .foregroundStyle(.znMuted)
                        }
                        Text(time)
                            .font(.znMono)
                            .foregroundStyle(.znBody)
                    }
                }
            }

            Spacer()

            // Free badge or price
            if event.isFree {
                Text(appState.localized(en: "Free", de: "Gratis"))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.znPositive)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.znPositive.opacity(0.1))
                    .clipShape(Capsule())
            } else if let price = event.price {
                Text(price)
                    .font(.system(size: 11))
                    .foregroundStyle(.znMuted)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.znSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    VStack(spacing: 6) {
        TodayEventRow(event: TodayEvent(
            id: "1",
            emoji: "🧺",
            name: "Bürkliplatz Farmers Market",
            venue: "Bürkliplatz",
            time: "06:00–11:00",
            isFree: true,
            price: nil
        ))
        TodayEventRow(event: TodayEvent(
            id: "2",
            emoji: "📖",
            name: "English Storytime",
            venue: "Pestalozzi-Bibliothek",
            time: "10:30",
            isFree: true,
            price: nil
        ))
        TodayEventRow(event: TodayEvent(
            id: "3",
            emoji: "🎪",
            name: "Sechseläuten",
            venue: nil,
            time: nil,
            isFree: false,
            price: "CHF 15"
        ))
    }
    .padding()
    .background(Color.znCream)
    .environment(AppState())
}
