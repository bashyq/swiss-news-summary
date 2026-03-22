import SwiftUI
import CoreLocation

/// Bad weather mode: home activities section + section divider + reduced timeline.
struct BadWeatherAgendaView: View {
    @Environment(AppState.self) private var appState

    let agenda: DayAgenda
    let activities: [Activity]
    let lunchSpots: [LunchSpot]
    let location: CLLocation?
    let agendaMode: AgendaMode
    @Binding var expandedSlotID: String?
    // onSwap removed — card-dealing model replaces swap trays
    var onStartExecuting: (() -> Void)?
    var onAdvanceSlot: (() -> Void)?
    var onExitExecution: (() -> Void)?
    var onEditSlot: ((AgendaSlot) -> Void)?
    var onSuggestAnother: ((String) -> Void)?
    var showReflowBanner: Bool = false
    var reflowSlotId: String?
    var onRebuild: (() -> Void)?
    var onKeepSlots: (() -> Void)?
    var activeWarning: FeasibilityWarning?
    var onAcceptWarning: (() -> Void)?
    var onDismissWarning: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Home activities section
            if let home = agenda.homeActivities {
                homeSection(home)
            }

            // Divider with text
            HStack(spacing: 12) {
                Rectangle()
                    .fill(Color.znBorder)
                    .frame(height: 1)

                Text(appState.localized(
                    en: "One outing — if you dare",
                    de: "Ein Ausflug — wenn ihr euch traut"
                ))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.znMuted)
                .lineLimit(1)
                .fixedSize()

                Rectangle()
                    .fill(Color.znBorder)
                    .frame(height: 1)
            }
            .padding(.vertical, 4)

            // Reduced timeline (afternoon + dinner only)
            AgendaTimelineView(
                agenda: agenda,
                activities: activities,
                lunchSpots: lunchSpots,
                location: location,
                agendaMode: agendaMode,
                expandedSlotID: $expandedSlotID,
                onStartExecuting: onStartExecuting,
                onAdvanceSlot: onAdvanceSlot,
                onExitExecution: onExitExecution,
                onEditSlot: onEditSlot,
                onSuggestAnother: onSuggestAnother,
                showReflowBanner: showReflowBanner,
                reflowSlotId: reflowSlotId,
                onRebuild: onRebuild,
                onKeepSlots: onKeepSlots,
                activeWarning: activeWarning,
                onAcceptWarning: onAcceptWarning,
                onDismissWarning: onDismissWarning
            )
        }
    }

    // MARK: - Home Section

    @ViewBuilder
    private func homeSection(_ home: HomeActivities) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(appState.localized(en: "At Home", de: "Zuhause"))
                .font(.znEyebrow)
                .foregroundStyle(Color.znMuted)

            if let baking = home.baking {
                HomeActivityCard(
                    activity: baking,
                    label: baking.label,
                    gradient: HomeActivityCard.bakingGradient
                )
            }

            if let movie = home.movie {
                HomeActivityCard(movie: movie)
            }

            if let craft = home.craft {
                HomeActivityCard(
                    activity: craft,
                    label: craft.label,
                    gradient: HomeActivityCard.craftGradient
                )
            }
        }
    }
}
