import SwiftUI
import CoreLocation

/// Vertical timeline composing slot cards with travel connectors.
///
/// Supports two modes:
/// - **Browsing**: all cards interactive, swap trays, "Let's go →" button at bottom
/// - **Executing**: done/active/future card states, "Done ✓" advancement, "← Edit plan" link
struct AgendaTimelineView: View {
    @Environment(AppState.self) private var appState

    let agenda: DayAgenda
    let activities: [Activity]
    let lunchSpots: [LunchSpot]
    let location: CLLocation?
    let agendaMode: AgendaMode
    @Binding var expandedSlotID: String?
    let onSwap: (String, AgendaSlot.SwapOption) -> Void
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

    @State private var openSwapTray: String?

    private var currentSlotIndex: Int? {
        agendaMode.currentSlotIndex
    }

    private var isComplete: Bool {
        guard let idx = currentSlotIndex else { return false }
        return idx >= agenda.slots.count
    }

    var body: some View {
        VStack(spacing: 0) {
            // Completion banner
            if isComplete {
                completionBanner
                    .padding(.bottom, 12)
            }

            ForEach(Array(agenda.slots.enumerated()), id: \.element.id) { index, slot in
                // Slot card
                AgendaSlotCard(
                    slot: slot,
                    accentColor: slot.accentColor,
                    showSwapTray: Binding(
                        get: { openSwapTray == slot.id },
                        set: { openSwapTray = $0 ? slot.id : nil }
                    ),
                    expandedSlotID: $expandedSlotID,
                    onSwap: { swap in
                        onSwap(slot.id, swap)
                    },
                    execState: slotExecState(for: index),
                    onDone: slotExecState(for: index) == .active ? {
                        onAdvanceSlot?()
                    } : nil,
                    onEdit: slotExecState(for: index) == .browsing ? {
                        onEditSlot?(slot)
                    } : nil,
                    onSuggestAnother: slotExecState(for: index) == .browsing
                        && (slot.type == .lunch || slot.type == .dinner)
                        ? { onSuggestAnother?(slot.id) } : nil,
                    activities: activities,
                    lunchSpots: lunchSpots,
                    location: location
                )
                .id(slot.id)

                // Reflow banner — shown below the slot that triggered it
                if showReflowBanner, reflowSlotId == slot.id {
                    ReflowBanner(
                        slotType: slot.type.displayName.lowercased(),
                        onRebuild: { onRebuild?() },
                        onKeep: { onKeepSlots?() }
                    )
                    .padding(.vertical, 8)
                }

                // Trim suggestion banner — shown below the affected slot after timeline shift
                if let warning = activeWarning, warning.slotId == slot.id {
                    TrimSuggestionBanner(
                        warning: warning,
                        onAccept: { onAcceptWarning?() },
                        onDismiss: { onDismissWarning?() }
                    )
                    .padding(.vertical, 8)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                // Travel connector between slots (not after last)
                if index < agenda.slots.count - 1 {
                    let nextSlot = agenda.slots[index + 1]
                    let tight = isTightConnection(
                        currentSlot: slot, nextSlot: nextSlot
                    )
                    TravelConnectorView(
                        travelNote: nextSlot.travelNote,
                        travelMinutes: slot.travelMinutesToNext,
                        execState: connectorExecState(afterSlotAt: index),
                        isTight: tight,
                        nextVenueName: tight ? nextSlot.venueName : nil,
                        leaveAtTime: leaveAtTime(afterSlotAt: index)
                    )
                }
            }

            // Bottom controls
            bottomControls
                .padding(.top, 16)
        }
    }

    // MARK: - Tight Connection Check

    /// Check if the gap between two consecutive slots is tight (< 20 min after travel).
    private func isTightConnection(currentSlot: AgendaSlot, nextSlot: AgendaSlot) -> Bool {
        guard let travelMins = currentSlot.travelMinutesToNext else { return false }
        // Parse times
        let currentParts = currentSlot.time.split(separator: ":").compactMap { Int($0) }
        let nextParts = nextSlot.time.split(separator: ":").compactMap { Int($0) }
        guard currentParts.count == 2, nextParts.count == 2 else { return false }

        let currentMinutes = currentParts[0] * 60 + currentParts[1]
        let nextMinutes = nextParts[0] * 60 + nextParts[1]
        let gapMinutes = nextMinutes - currentMinutes

        return (gapMinutes - travelMins) < 20
    }

    // MARK: - Exec State Helpers

    private func slotExecState(for index: Int) -> SlotExecState {
        guard agendaMode.isExecuting else { return .browsing }
        guard let currentIdx = currentSlotIndex else { return .browsing }

        if currentIdx >= agenda.slots.count {
            // All complete
            return .done
        } else if index < currentIdx {
            return .done
        } else if index == currentIdx {
            return .active
        } else {
            return .future
        }
    }

    /// Compute "Leave at HH:MM" for the connector after `index`.
    /// Only meaningful when the connector is `.upcoming` (between done and active slot).
    private func leaveAtTime(afterSlotAt index: Int) -> String? {
        guard index + 1 < agenda.slots.count else { return nil }
        let slot = agenda.slots[index]
        let nextSlot = agenda.slots[index + 1]
        guard let travelMin = slot.travelMinutesToNext else { return nil }
        let nextParts = nextSlot.time.split(separator: ":").compactMap { Int($0) }
        guard nextParts.count == 2 else { return nil }
        let totalMinutes = nextParts[0] * 60 + nextParts[1] - travelMin
        guard totalMinutes >= 0 else { return nil }
        return String(format: "%02d:%02d", totalMinutes / 60, totalMinutes % 60)
    }

    private func connectorExecState(afterSlotAt index: Int) -> ConnectorExecState {
        guard agendaMode.isExecuting else { return .browsing }
        guard let currentIdx = currentSlotIndex else { return .browsing }

        if currentIdx >= agenda.slots.count {
            return .done
        } else if index < currentIdx - 1 {
            return .done
        } else if index == currentIdx - 1 {
            // Connector between the just-done slot and the active slot
            return .upcoming
        } else if index == currentIdx {
            // Connector after the active slot → future
            return .future
        } else {
            return .future
        }
    }

    // MARK: - Completion Banner

    private var completionBanner: some View {
        VStack(spacing: 8) {
            Text(appState.localized(en: "All done!", de: "Alles erledigt!"))
                .font(.custom("Playfair", size: 20))
                .foregroundStyle(Color.znInk)

            Text(appState.localized(
                en: "You completed your \(agenda.slots.count)-stop day",
                de: "Alle \(agenda.slots.count) Stationen geschafft"
            ))
            .font(.system(size: 13))
            .foregroundStyle(Color.znBody)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.znPositive.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.znPositive.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Bottom Controls

    @ViewBuilder
    private var bottomControls: some View {
        if agendaMode.isExecuting {
            // "← Edit plan" escape link
            Button {
                onExitExecution?()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 10, weight: .semibold))
                    Text(appState.localized(en: "Edit plan", de: "Plan bearbeiten"))
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundStyle(Color.znMuted)
            }
            .buttonStyle(.plain)
        } else if onStartExecuting != nil {
            // "Let's go →" button — disabled while reflow banner is showing
            // Only shown when execution mode is supported (Today tab, not Weekend).
            Button {
                onStartExecuting?()
            } label: {
                HStack(spacing: 8) {
                    Text(appState.localized(en: "Let's go", de: "Los geht's"))
                        .font(.system(size: 16, weight: .semibold))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    LinearGradient(
                        colors: [Color.znNavy, Color.znNavy.opacity(0.85)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: Color.znNavy.opacity(0.2), radius: 8, y: 4)
            }
            .buttonStyle(.plain)
            .opacity(showReflowBanner ? 0.5 : 1.0)
            .disabled(showReflowBanner)
        }
    }
}
