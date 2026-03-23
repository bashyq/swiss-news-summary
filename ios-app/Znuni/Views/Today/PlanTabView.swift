import SwiftUI
import UIKit

/// Main container view for the Plan tab.
/// Renders hero banner, date strip, and state-driven content from PlanViewModel.
struct PlanTabView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = PlanViewModel()
    @State private var hasInitializedCity = false
    @State private var showDatePicker = false
    @State private var datePickerPlanDay: PlanDay = .today
    @State private var expandedSlotID: String?
    @State private var replacingSlot: AgendaSlot?
    @State private var visibleSlotCount: Int = 0
    @State private var isAnimatingDeal = false
    @State private var previousStateWasCalendarPreview = false
    @State private var debugSlotAction: String?
    @State private var showWeatherDetail = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Hero outside ScrollView so navy extends behind Dynamic Island
                PlanHeroBanner(
                    selectedDate: viewModel.selectedDate,
                    planState: viewModel.planState,
                    weather: viewModel.weather,
                    forecast: viewModel.isSelectedDateToday ? nil : viewModel.forecastForSelectedDate,
                    isToday: viewModel.isSelectedDateToday,
                    planningCity: viewModel.planningCity,
                    onWeatherTap: { showWeatherDetail = true },
                    onCityChange: { newCity in
                        guard newCity != viewModel.planningCity else { return }
                        viewModel.changeCity(to: newCity)
                        Task { await viewModel.deal() }
                    }
                )

                DateStripView(
                    dates: viewModel.dates,
                    selectedDate: Binding(
                        get: { viewModel.selectedDate },
                        set: { viewModel.selectedDate = $0 }
                    ),
                    onCalendarTap: {
                        datePickerPlanDay = currentPlanDay
                        showDatePicker = true
                    }
                )

                ScrollView {
                    planContent
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 32)
                }
                .scrollIndicators(.hidden)
            }
            .background(Color.znCream)
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onChange(of: viewModel.selectedDate) { oldValue, newValue in
            Task {
                await viewModel.selectDate(newValue, previousDate: oldValue)
                // After date selection, if we loaded a cached plan, show all cards immediately
                if let agenda = viewModel.currentAgenda {
                    visibleSlotCount = agenda.slots.count
                }
            }
        }
        .task {
            // Initialize planning city from global city only on first appear
            if !hasInitializedCity {
                hasInitializedCity = true
                viewModel.planningCity = PlanningCity(city: appState.city)
            }
            await viewModel.selectDate(viewModel.selectedDate)
            // Pre-fetch weather so it shows before user taps "Plan my day"
            await viewModel.loadWeatherIfNeeded()
            // Load 7-day forecast for per-day weather display
            await viewModel.loadDailyForecastsIfNeeded()
            // If a cached plan was loaded, show all cards immediately
            if let agenda = viewModel.currentAgenda {
                visibleSlotCount = agenda.slots.count
            }
        }
        .sheet(isPresented: $showDatePicker) {
            DatePickerSheet(selectedPlanDay: $datePickerPlanDay)
                .onChange(of: datePickerPlanDay) {
                    viewModel.selectedDate = datePickerPlanDay.date()
                }
        }
        .sheet(isPresented: $showWeatherDetail) {
            if let weather = viewModel.weather {
                WeatherDetailSheet(weather: weather)
                    .presentationDetents([.medium, .large])
            }
        }
        .sheet(item: $replacingSlot) { slot in
            CustomSlotSheet(replacingSlot: slot) { name, start, end, address in
                Task {
                    await viewModel.replaceWithCustom(slotId: slot.id, name: name, start: start, end: end, address: address)
                }
            }
        }
        .alert("Debug: Slot Action", isPresented: Binding(get: { debugSlotAction != nil }, set: { if !$0 { debugSlotAction = nil } })) {
            Button("OK") { debugSlotAction = nil }
        } message: {
            Text(debugSlotAction ?? "")
        }
        .onChange(of: isDealState) { _, isDealt in
            if isDealt {
                animateDealIn()
                // Fetch real travel times from MapKit (async, updates in background)
                Task { await viewModel.fetchMapKitTravelTimes() }
            }
        }
        .onChange(of: isCalendarPreviewState) { _, isPreviewing in
            if isPreviewing {
                previousStateWasCalendarPreview = true
            }
        }
    }

    // MARK: - Plan Content (State-Driven)

    @ViewBuilder
    private var planContent: some View {
        switch viewModel.planState {
        case .empty:
            emptyState

        case .calendarPreview(let events):
            calendarPreviewState(events)

        case .composing(let locked):
            composingState(locked)

        case .dealt(let agenda):
            dealtState(agenda, isSaved: false)

        case .saved(let agenda):
            dealtState(agenda, isSaved: true)

        case .error(let message):
            errorState(message)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Text(appState.localized(
                en: "No plans yet for \(dayName)",
                de: "Noch keine Plaene fuer \(dayName)"
            ))
            .font(.system(size: 15))
            .foregroundStyle(.znMuted)

            planMyDayButton(
                label: appState.localized(en: "Plan my day", de: "Tag planen")
            )
        }
    }

    // MARK: - Calendar Preview

    private func calendarPreviewState(_ events: [CalendarSlot]) -> some View {
        VStack(spacing: 16) {
            // Section label
            Text(appState.localized(en: "FROM YOUR CALENDAR", de: "AUS DEINEM KALENDER"))
                .font(.znEyebrow)
                .tracking(1)
                .foregroundStyle(.znMuted)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Calendar event cards
            ForEach(events) { event in
                let slot = calendarSlotToAgendaSlot(event)
                PlanSlotCard(
                    slot: slot,
                    expandedID: $expandedSlotID,
                    viewModel: viewModel
                )
            }

            // Fill the gaps button
            planMyDayButton(
                label: appState.localized(en: "Fill the gaps", de: "Luecken fuellen")
            )

            Text(appState.localized(
                en: "Morning \u{00B7} Lunch \u{00B7} Afternoon \u{00B7} Dinner",
                de: "Morgen \u{00B7} Mittag \u{00B7} Nachmittag \u{00B7} Abend"
            ))
            .font(.system(size: 11))
            .foregroundStyle(.znMuted)
        }
    }

    // MARK: - Composing State

    private func composingState(_ locked: [AgendaSlot]) -> some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(.znNavy)
                .padding(.top, 32)

            Text(appState.localized(
                en: "Planning your day...",
                de: "Plane deinen Tag..."
            ))
            .font(.system(size: 14))
            .foregroundStyle(.znMuted)

            // Show locked slots if any
            ForEach(locked) { slot in
                PlanSlotCard(
                    slot: slot,
                    expandedID: .constant(nil)
                )
            }
        }
    }

    // MARK: - Dealt / Saved State

    private func dealtState(_ agenda: DayAgenda, isSaved: Bool) -> some View {
        VStack(spacing: 0) {
            // Timeline of slots — staggered appearance via visibleSlotCount
            ForEach(Array(agenda.slots.prefix(visibleSlotCount).enumerated()), id: \.element.id) { index, slot in
                PlanSlotCard(
                    slot: slot,
                    expandedID: $expandedSlotID,
                    isSaved: isSaved,
                    viewModel: viewModel,
                    onReplace: { replacingSlot = slot }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))

                // Travel connector between slots
                if index < agenda.slots.count - 1, let travel = slot.travelToNext {
                    SimpleTravelConnector(estimate: travel)
                        .transition(.opacity)
                }
            }

            // Bottom action bar — show only when all cards are visible
            if visibleSlotCount >= agenda.slots.count {
                actionBar(isSaved: isSaved)
                    .padding(.top, 24)
                    .transition(.opacity)
            }
        }
        .onAppear {
            // If returning to a dealt state (e.g. date switch with cached plan)
            // and no deal animation is in progress, show all cards immediately
            if visibleSlotCount == 0 && !isAnimatingDeal {
                visibleSlotCount = agenda.slots.count
            }
        }
    }

    // MARK: - Error State

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 12) {
            // Check for stale cached plan to show as fallback
            if let staleAgenda = viewModel.lastDealtAgenda {
                // Warning banner
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color.znTerracotta)
                    Text(appState.localized(
                        en: "Couldn\u{2019}t refresh \u{2014} showing previous plan",
                        de: "Aktualisierung fehlgeschlagen \u{2014} zeige letzten Plan"
                    ))
                    .font(.system(size: 13))
                    .foregroundStyle(.znBody)
                }
                .padding(12)
                .background(Color.znAlertBg)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                Button {
                    Task { await viewModel.deal() }
                } label: {
                    Text(appState.localized(en: "Tap to retry", de: "Tippen zum Wiederholen"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.znNavy)
                }
                .buttonStyle(.plain)

                // Show the stale plan
                dealtState(staleAgenda, isSaved: false)
                    .opacity(0.75)
            } else {
                // Pure error — no fallback available
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 32))
                    .foregroundStyle(.znMuted)
                    .padding(.top, 32)

                Text(message)
                    .font(.cardHeadline)
                    .foregroundStyle(.znInk)
                    .multilineTextAlignment(.center)

                Button {
                    Task { await viewModel.deal() }
                } label: {
                    Text(appState.localized(en: "Retry", de: "Erneut versuchen"))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.znNavy)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Reusable Components

    private func weatherSummaryCard(_ weather: Weather, subtitle: String? = nil) -> some View {
        HStack(spacing: 12) {
            Image(systemName: weather.sfSymbol)
                .symbolRenderingMode(.multicolor)
                .foregroundStyle(.yellow)
                .font(.system(size: 28))

            VStack(alignment: .leading, spacing: 2) {
                Text("\(Int(weather.temperature))\u{00B0} \(weather.description)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.znInk)

                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(.znMuted)
                }
            }

            Spacer()
        }
        .padding(AppSpacing.cardPadding)
        .background(Color.znSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
        .shadow(
            color: AppShadow.card.color,
            radius: AppShadow.card.radius,
            x: AppShadow.card.x,
            y: AppShadow.card.y
        )
    }

    private func planMyDayButton(label: String) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            Task {
                if case .calendarPreview(let events) = viewModel.planState {
                    // Convert calendar events to locked slots for gap filling
                    let lockedSlots = events.map { event in
                        calendarSlotToAgendaSlot(event)
                    }
                    await viewModel.deal(lockedSlots: lockedSlots)
                } else {
                    await viewModel.deal()
                }
            }
        } label: {
            Text(label)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.vertical, 14)
                .padding(.horizontal, 32)
                .background(LinearGradient.brand)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    private func calendarEventCard(_ event: CalendarSlot) -> some View {
        HStack(spacing: 12) {
            // Blue accent bar
            RoundedRectangle(cornerRadius: 1.5)
                .fill(Color.znNavy)
                .frame(width: AppSpacing.borderStripWidth)

            Image(systemName: "calendar")
                .font(.system(size: 14))
                .foregroundStyle(.znNavy)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.custom("Playfair", size: 15).weight(.semibold))
                    .foregroundStyle(.znInk)

                Text(eventTimeString(event))
                    .font(.znMono)
                    .foregroundStyle(.znMuted)
            }

            Spacer()

            // Locked badge
            Text(appState.localized(en: "Locked", de: "Fixiert"))
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.znNavy)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.znNavy.opacity(0.1))
                .clipShape(Capsule())
        }
        .padding(AppSpacing.cardPadding)
        .background(Color.znSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
        .shadow(
            color: AppShadow.card.color,
            radius: AppShadow.card.radius,
            x: AppShadow.card.x,
            y: AppShadow.card.y
        )
    }

    private func simplifiedSlotCard(
        _ slot: AgendaSlot,
        accentColor: Color,
        showLockBadge: Bool = false
    ) -> some View {
        HStack(spacing: 12) {
            // Accent bar
            RoundedRectangle(cornerRadius: 1.5)
                .fill(accentColor)
                .frame(width: AppSpacing.borderStripWidth)

            VStack(alignment: .leading, spacing: 4) {
                // Type label
                Text(slotTypeLabel(slot.type))
                    .font(.znEyebrow)
                    .tracking(1)
                    .foregroundStyle(.znMuted)
                    .textCase(.uppercase)

                // Venue name
                Text(slot.venueName)
                    .font(.custom("Playfair", size: 15).weight(.semibold))
                    .foregroundStyle(.znInk)

                // Time
                HStack(spacing: 6) {
                    Text(slot.time)
                        .font(.znMono)
                        .foregroundStyle(.znMuted)

                    if let duration = slot.durationDisplay {
                        Text("\u{00B7} \(duration)")
                            .font(.znMono)
                            .foregroundStyle(.znMuted)
                    }
                }
            }

            Spacer()

            if showLockBadge || slot.isLocked {
                Image(systemName: "lock.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.znNavy.opacity(0.5))
            }
        }
        .padding(AppSpacing.cardPadding)
        .background(Color.znSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
        .shadow(
            color: AppShadow.card.color,
            radius: AppShadow.card.radius,
            x: AppShadow.card.x,
            y: AppShadow.card.y
        )
        .padding(.vertical, 4)
    }

    private func travelConnector(_ travel: TravelEstimate) -> some View {
        HStack(spacing: 6) {
            Rectangle()
                .fill(Color.znBorder)
                .frame(width: 1, height: 20)
                .padding(.leading, 24)

            Image(systemName: travel.mode == .walking ? "figure.walk" : "tram.fill")
                .font(.system(size: 10))
                .foregroundStyle(.znMuted)

            Text("\(travel.minutes) min")
                .font(.system(size: 11))
                .foregroundStyle(.znMuted)

            Spacer()
        }
    }

    private func actionBar(isSaved: Bool) -> some View {
        HStack(spacing: 12) {
            // Save to calendar
            Button {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                Task {
                    try? await viewModel.saveToCalendar()
                }
            } label: {
                HStack(spacing: 6) {
                    if isSaved {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    Text(isSaved
                        ? appState.localized(en: "Saved to calendar", de: "Im Kalender gespeichert")
                        : appState.localized(en: "Save to calendar", de: "Im Kalender speichern")
                    )
                    .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(LinearGradient.brand)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .opacity(isSaved ? 0.5 : 1)
            }
            .buttonStyle(.plain)
            .disabled(isSaved)

            // Redeal
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                Task { await viewModel.redeal() }
            } label: {
                Text(appState.localized(en: "Refresh plan", de: "Plan auffrischen"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.znInk)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .background(Color.znSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.znBorder, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)

            // Clear plan
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                viewModel.clearPlan()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.znMuted)
                    .padding(12)
                    .background(Color.znSurface)
                    .clipShape(Circle())
                    .overlay(
                        Circle().stroke(Color.znBorder, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Deal Animation

    private var isDealState: Bool {
        if case .dealt = viewModel.planState { return true }
        if case .saved = viewModel.planState { return true }
        return false
    }

    private var isCalendarPreviewState: Bool {
        if case .calendarPreview = viewModel.planState { return true }
        return false
    }

    private func animateDealIn() {
        guard let agenda = viewModel.currentAgenda else { return }
        let slots = agenda.slots
        guard !slots.isEmpty else { return }
        let cameFromCalendar = previousStateWasCalendarPreview
        previousStateWasCalendarPreview = false

        // Mark animation in progress so onAppear doesn't override
        isAnimatingDeal = true
        visibleSlotCount = 0

        if cameFromCalendar {
            let lastCalendarIndex = slots.lastIndex(where: { $0.source == .calendar }) ?? -1
            let immediateCount = lastCalendarIndex + 1

            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                visibleSlotCount = max(immediateCount, 0)
            }
            let baseDelay: Double = 0.3
            for i in immediateCount..<slots.count {
                let staggerIndex = i - immediateCount
                let isLast = i == slots.count - 1
                DispatchQueue.main.asyncAfter(deadline: .now() + baseDelay + Double(staggerIndex) * 0.12) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        visibleSlotCount = i + 1
                    }
                    if isLast { isAnimatingDeal = false }
                }
            }
            // If all slots are calendar slots, finish immediately
            if immediateCount >= slots.count {
                isAnimatingDeal = false
            }
        } else {
            // Standard stagger: all cards deal in one by one
            for i in 0..<slots.count {
                let isLast = i == slots.count - 1
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08 + Double(i) * 0.12) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        visibleSlotCount = i + 1
                    }
                    if isLast { isAnimatingDeal = false }
                }
            }
        }
    }

    // MARK: - Helpers

    private var dayName: String {
        let f = DateFormatter()
        f.locale = appState.language == .de ? Locale(identifier: "de_CH") : Locale(identifier: "en_US")
        f.dateFormat = "EEEE"
        return f.string(from: viewModel.selectedDate)
    }

    private var currentPlanDay: PlanDay {
        let cal = Calendar.current
        let date = viewModel.selectedDate
        if cal.isDateInToday(date) { return .today }
        if cal.isDateInTomorrow(date) { return .tomorrow }
        let weekendDates = PlanDay.nextWeekendDates()
        if cal.isDate(date, inSameDayAs: weekendDates.saturday) { return .saturday }
        if cal.isDate(date, inSameDayAs: weekendDates.sunday) { return .sunday }
        return .specific(date)
    }

    private func eventTimeString(_ event: CalendarSlot) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        f.timeZone = TimeZone(identifier: "Europe/Zurich")
        if event.isAllDay {
            return appState.localized(en: "All day", de: "Ganztaegig")
        }
        return "\(f.string(from: event.startDate)) - \(f.string(from: event.endDate))"
    }

    private func slotAccentColor(_ slot: AgendaSlot) -> Color {
        switch slot.type {
        case .activity, .homeActivity: return .znTerracotta
        case .lunch: return .znPositive
        case .dinner: return .znNavy
        }
    }

    private func slotTypeLabel(_ type: AgendaSlot.SlotType) -> String {
        switch type {
        case .activity:
            return appState.localized(en: "ACTIVITY", de: "AKTIVITAET")
        case .lunch:
            return appState.localized(en: "LUNCH", de: "MITTAGESSEN")
        case .dinner:
            return appState.localized(en: "DINNER", de: "ABENDESSEN")
        case .homeActivity:
            return appState.localized(en: "AT HOME", de: "ZUHAUSE")
        }
    }

    private func calendarSlotToAgendaSlot(_ event: CalendarSlot) -> AgendaSlot {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        f.timeZone = TimeZone(identifier: "Europe/Zurich")
        let timeString = event.isAllDay ? "09:00" : f.string(from: event.startDate)
        let duration = Int(event.endDate.timeIntervalSince(event.startDate) / 60)

        return AgendaSlot(
            id: event.id,
            time: timeString,
            type: .activity,
            venueName: event.title,
            venueId: nil,
            reason: "",
            tags: [],
            durationMinutes: max(duration, 60),
            source: .calendar,
            isLocked: true,
            slotDate: event.startDate
        )
    }
}
