import SwiftUI
import CoreLocation

/// Weekend Planner — two-day agenda via GapAnalysisEngine + AgendaComposer.
///
/// Shows a "Plan the weekend" entry point, then day-switcher pills (Sat/Sun)
/// with weather headers and `AgendaTimelineView` for each day.
/// Execution mode is Today-tab-only — no "Let's go" button here.
struct WeekendView: View {
    @Environment(AppState.self) private var appState
    @Environment(LocationManager.self) private var locationManager

    @State private var todayVM = TodayViewModel()
    @State private var hasPlanned = false
    @State private var expandedSlotID: String?
    @State private var showSlotEditSheet = false
    @State private var showCustomSlotForm = false
    @State private var editingSlot: AgendaSlot?
    @State private var showAnchorForm = false
    @State private var editingAnchor: AnchorEvent?
    @State private var weekendAnchors: [PlanDay: [AnchorEvent]] = [:]

    var body: some View {
        content
            .sheet(isPresented: $showSlotEditSheet) {
                if let slot = editingSlot {
                    SlotEditSheet(
                        slot: slot,
                        onEditTime: { newTime in
                            todayVM.editSlotTime(slotId: slot.id, newTime: newTime)
                        },
                        onReplaceWithCustom: {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                showCustomSlotForm = true
                            }
                        },
                        onToggleLock: {
                            todayVM.toggleSlotLock(slotId: slot.id)
                        },
                        onRemove: {
                            todayVM.removeSlot(slotId: slot.id)
                        }
                    )
                    .presentationDetents([.medium])
                }
            }
            .sheet(isPresented: $showAnchorForm) {
                AnchorFormSheet(
                    existingAnchor: editingAnchor,
                    activitiesData: todayVM.activitiesData
                ) { anchor in
                    // Adjust anchor's startTime to the selected weekend day
                    let targetDate = todayVM.selectedPlanDay.date()
                    let adjusted = adjustAnchorDate(anchor, to: targetDate)

                    if editingAnchor != nil {
                        // Update: remove old, add new at date
                        AnchorStore.shared.remove(id: adjusted.id, for: targetDate)
                        AnchorStore.shared.add(adjusted, for: targetDate)
                    } else {
                        AnchorStore.shared.add(adjusted, for: targetDate)
                    }
                    editingAnchor = nil
                    refreshAnchors()
                    Task {
                        await todayVM.composeWeekend(
                            city: appState.city,
                            language: appState.language,
                            session: FamilySession.load()
                        )
                    }
                }
                .environment(appState)
                .presentationDetents([.large])
            }
            .sheet(isPresented: $showCustomSlotForm) {
                if let slot = editingSlot {
                    CustomSlotFormSheet(
                        slotType: slot.type,
                        onSave: { name, time, neighbourhood, locked in
                            todayVM.replaceSlotWithCustom(
                                slotId: slot.id,
                                venueName: name,
                                time: time,
                                neighbourhood: neighbourhood,
                                locked: locked
                            )
                        }
                    )
                    .presentationDetents([.medium, .large])
                }
            }
    }

    // MARK: - Content Router

    @ViewBuilder
    private var content: some View {
        Group {
            if !hasPlanned {
                entryState
            } else {
                plannedContent
            }
        }
        .onAppear {
            restorePersistedPlan()
        }
    }

    // MARK: - Entry State ("Plan the weekend" button)

    private var entryState: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 48))
                .foregroundStyle(.znNavy.opacity(0.5))

            Text(appState.localized(
                en: "Plan your weekend",
                de: "Plane dein Wochenende"
            ))
            .font(.sectionHeadline)
            .foregroundStyle(.znInk)

            Text(appState.localized(
                en: "AI-powered activities and restaurants\nfor Saturday & Sunday",
                de: "KI-gesteuerte Aktivitäten und Restaurants\nfür Samstag & Sonntag"
            ))
            .font(.subheadline)
            .foregroundStyle(.znBody)
            .multilineTextAlignment(.center)

            planWeekendButton

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
    }

    private var planWeekendButton: some View {
        Button {
            Task {
                await planWeekend()
            }
        } label: {
            HStack(spacing: 8) {
                if isComposing {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 15, weight: .semibold))
                }
                Text(appState.localized(
                    en: "Plan the weekend",
                    de: "Wochenende planen"
                ))
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
        .disabled(isComposing)
        .padding(.top, 8)
    }

    // MARK: - Planned Content (day switcher + timeline)

    private var plannedContent: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Day switcher pills
                daySwitcher
                    .padding(.top, 8)

                // Weather header for current day
                weatherHeader

                // Anchor pills for current day
                anchorSection

                // Loading state for current day
                if agendaStateForSelectedDay == .loading {
                    LoadingView(message: appState.localized(
                        en: "Composing agenda...",
                        de: "Agenda wird erstellt..."
                    ))
                } else if let agenda = agendaForSelectedDay {
                    if agenda.badWeatherMode {
                        // Bad weather: home activities + reduced timeline
                        BadWeatherAgendaView(
                            agenda: agenda,
                            activities: todayVM.activitiesData?.activities ?? [],
                            lunchSpots: todayVM.lunchData?.spots ?? [],
                            location: locationManager.location,
                            agendaMode: .browsing,
                            expandedSlotID: $expandedSlotID,
                            onSwap: { slotId, swap in
                                todayVM.swapSlot(slotId: slotId, with: swap)
                            },
                            onEditSlot: { slot in
                                editingSlot = slot
                                showSlotEditSheet = true
                            },
                            onSuggestAnother: { slotId in
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    todayVM.suggestAnotherNearby(slotId: slotId)
                                }
                            },
                            showReflowBanner: todayVM.showReflowBanner,
                            reflowSlotId: todayVM.reflowSlotId,
                            onRebuild: {
                                Task {
                                    await todayVM.reflowAgenda(
                                        city: appState.city,
                                        language: appState.language,
                                        session: appState.familySession
                                    )
                                }
                            },
                            onKeepSlots: {
                                todayVM.clearStaleSlots()
                            }
                        )
                    } else {
                        // Normal agenda timeline (no execution mode — browse only)
                        AgendaTimelineView(
                            agenda: agenda,
                            activities: todayVM.activitiesData?.activities ?? [],
                            lunchSpots: todayVM.lunchData?.spots ?? [],
                            location: locationManager.location,
                            agendaMode: .browsing,
                            expandedSlotID: $expandedSlotID,
                            onSwap: { slotId, swap in
                                todayVM.swapSlot(slotId: slotId, with: swap)
                            },
                            onEditSlot: { slot in
                                editingSlot = slot
                                showSlotEditSheet = true
                            },
                            onSuggestAnother: { slotId in
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    todayVM.suggestAnotherNearby(slotId: slotId)
                                }
                            },
                            showReflowBanner: todayVM.showReflowBanner,
                            reflowSlotId: todayVM.reflowSlotId,
                            onRebuild: {
                                Task {
                                    await todayVM.reflowAgenda(
                                        city: appState.city,
                                        language: appState.language,
                                        session: appState.familySession
                                    )
                                }
                            },
                            onKeepSlots: {
                                todayVM.clearStaleSlots()
                            }
                        )
                    }
                } else {
                    // Agenda not yet composed for this day
                    emptyDayState
                }

                // Rebuild button
                rebuildButton
                    .padding(.top, 8)
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Day Switcher Pills

    private var daySwitcher: some View {
        HStack(spacing: 12) {
            dayPill(for: .saturday)
            dayPill(for: .sunday)
        }
    }

    private func dayPill(for day: PlanDay) -> some View {
        let isSelected = todayVM.selectedPlanDay == day
        return Button {
            withAnimation(AppAnimation.spring) {
                todayVM.selectedPlanDay = day
            }
        } label: {
            VStack(spacing: 2) {
                Text(day.shortLabel(language: appState.language))
                    .font(.system(size: 14, weight: .semibold))

                // Status indicator
                if let state = agendaState(for: day) {
                    switch state {
                    case .loading:
                        ProgressView()
                            .scaleEffect(0.6)
                            .frame(height: 12)
                    case .loaded, .fallback:
                        let slotCount = agendaSlotCount(for: day)
                        Text(slotCount > 0
                             ? "\(slotCount) \(appState.localized(en: "slots", de: "Slots"))"
                             : appState.localized(en: "Ready", de: "Bereit"))
                            .font(.caption2)
                            .foregroundStyle(isSelected ? .white.opacity(0.7) : .znMuted)
                    default:
                        EmptyView()
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isSelected ? Color.znNavy : Color.znSurface)
            .foregroundStyle(isSelected ? .white : .znInk)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(isSelected ? Color.clear : Color.znBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Weather Header

    @ViewBuilder
    private var weatherHeader: some View {
        if let dayWeather = todayVM.weekendDayWeather(for: todayVM.selectedPlanDay) {
            HStack(spacing: 10) {
                Image(systemName: dayWeather.sfSymbol)
                    .font(.title2)
                    .foregroundStyle(weatherIconColor(code: dayWeather.weatherCode))
                    .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text("\(Int(dayWeather.tempMax))\u{00B0}")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text("/")
                            .font(.caption)
                            .foregroundStyle(.znMuted)
                        Text("\(Int(dayWeather.tempMin))\u{00B0}")
                            .font(.subheadline)
                            .foregroundStyle(.znMuted)
                    }
                    Text(dayWeather.localizedDescription(language: appState.language))
                        .font(.caption)
                        .foregroundStyle(.znMuted)
                        .lineLimit(1)
                }

                Spacer()
            }
            .padding(10)
            .background(Color.weatherCard)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    // MARK: - Rebuild Button

    private var rebuildButton: some View {
        Button {
            Task {
                await todayVM.rebuildWeekend(
                    city: appState.city,
                    language: appState.language,
                    session: appState.familySession
                )
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 13, weight: .medium))
                Text(appState.localized(en: "Rebuild weekend", de: "Wochenende neu planen"))
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundStyle(.znNavy)
            .frame(maxWidth: .infinity)
            .frame(height: 42)
            .background(Color.znNavy.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Empty Day State

    private var emptyDayState: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar")
                .font(.system(size: 32))
                .foregroundStyle(.znMuted)
            Text(appState.localized(
                en: "No plan for this day yet",
                de: "Noch kein Plan für diesen Tag"
            ))
            .font(.subheadline)
            .foregroundStyle(.znMuted)
        }
        .padding(.vertical, 40)
    }

    // MARK: - Anchor Section

    private var anchorSection: some View {
        let currentAnchors = weekendAnchors[todayVM.selectedPlanDay] ?? []
        return AnchorPillRowView(
            anchors: currentAnchors,
            onAdd: {
                editingAnchor = nil
                showAnchorForm = true
            },
            onEdit: { anchor in
                editingAnchor = anchor
                showAnchorForm = true
            },
            onDelete: { anchor in
                let targetDate = todayVM.selectedPlanDay.date()
                AnchorStore.shared.remove(id: anchor.id, for: targetDate)
                refreshAnchors()
                Task {
                    await todayVM.composeWeekend(
                        city: appState.city,
                        language: appState.language,
                        session: FamilySession.load()
                    )
                }
            }
        )
    }

    /// Adjust an anchor's startTime to fall on the target date (preserving hour/minute).
    private func adjustAnchorDate(_ anchor: AnchorEvent, to targetDate: Date) -> AnchorEvent {
        let cal = Calendar.current
        let timeComponents = cal.dateComponents([.hour, .minute], from: anchor.startTime)
        let adjustedStart = cal.date(bySettingHour: timeComponents.hour ?? 10,
                                     minute: timeComponents.minute ?? 0,
                                     second: 0, of: targetDate) ?? anchor.startTime
        return AnchorEvent(
            id: anchor.id,
            title: anchor.title,
            category: anchor.category,
            startTime: adjustedStart,
            durationMinutes: anchor.durationMinutes,
            neighbourhood: anchor.neighbourhood,
            kreis: anchor.kreis,
            sourceEventId: anchor.sourceEventId,
            createdDate: anchor.createdDate
        )
    }

    /// Reload anchors from store for both weekend days.
    private func refreshAnchors() {
        weekendAnchors[.saturday] = AnchorStore.shared.anchors(for: PlanDay.saturday.date())
        weekendAnchors[.sunday] = AnchorStore.shared.anchors(for: PlanDay.sunday.date())
    }

    /// Restore a persisted weekend plan from MultiDayPlanStore.
    /// If a plan exists for the current weekend dates, restore agendas and show planned content.
    private func restorePersistedPlan() {
        guard !hasPlanned else { return }
        guard let plan = MultiDayPlanStore.shared.mostRecentWeekendPlan() else { return }

        let satISO = PlanDay.saturday.isoDate
        let sunISO = PlanDay.sunday.isoDate

        // Check if the persisted plan matches the current weekend
        let planDates = Set(plan.days.map(\.isoDate))
        guard planDates.contains(satISO) || planDates.contains(sunISO) else { return }

        // Restore agendas
        for day in plan.days {
            if let agenda = day.agenda {
                todayVM._agendas[day.isoDate] = agenda
                todayVM._agendaStates[day.isoDate] = .loaded
            }
        }

        // Restore anchors
        refreshAnchors()

        // Show planned content
        todayVM.isWeekendMode = true
        todayVM.selectedPlanDay = .saturday
        hasPlanned = true
    }

    // MARK: - Helpers

    private var isComposing: Bool {
        let satISO = PlanDay.saturday.isoDate
        let sunISO = PlanDay.sunday.isoDate
        let satState = todayVM._agendaStates[satISO] ?? .idle
        let sunState = todayVM._agendaStates[sunISO] ?? .idle
        return satState == .loading || sunState == .loading
    }

    private var agendaForSelectedDay: DayAgenda? {
        todayVM.agenda
    }

    private var agendaStateForSelectedDay: AgendaState {
        todayVM.agendaState
    }

    private func agendaState(for day: PlanDay) -> AgendaState? {
        todayVM._agendaStates[day.isoDate]
    }

    private func agendaSlotCount(for day: PlanDay) -> Int {
        todayVM._agendas[day.isoDate]?.slots.count ?? 0
    }

    private func weatherIconColor(code: Int) -> Color {
        switch code {
        case 0: return .znTerracotta
        case 1, 2: return .znTerracotta.opacity(0.7)
        case 3: return .znMuted
        case 45, 48: return .znMuted
        case 51...67: return .znNavy
        case 71...77: return .znNavy.opacity(0.7)
        case 80...82: return .znNavy
        case 85, 86: return .znNavy.opacity(0.7)
        case 95...99: return .znNavy.opacity(0.85)
        default: return .znMuted
        }
    }

    private func planWeekend() async {
        // Load anchors for both weekend days
        refreshAnchors()

        // Load data sources first (news for weather, activities, restaurants)
        await todayVM.loadAll(
            city: appState.city,
            language: appState.language
        )

        // Compose both days (now anchor-aware)
        await todayVM.composeWeekend(
            city: appState.city,
            language: appState.language,
            session: appState.familySession
        )

        withAnimation(AppAnimation.spring) {
            hasPlanned = true
        }
    }
}

/// Multi-day planner view — alias for WeekendView (Step 16 naming convention).
typealias MultiDayPlannerView = WeekendView

#Preview {
    NavigationStack {
        WeekendView()
            .environment(AppState())
            .environment(LocationManager())
    }
}
