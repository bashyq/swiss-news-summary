import SwiftUI
import CoreLocation

/// Main "Today" tab view — News (default) or AI-powered Plan.
///
/// Toggle between two sub-views via segment control in the hero:
/// - **News** (default): Transport alerts, history, categorized news cards
/// - **Plan**: Transport alerts, agenda timeline, events, rebuild/session config
struct TodayView: View {
    @Environment(AppState.self) private var appState
    @Environment(LocationManager.self) private var locationManager
    @Environment(ToastManager.self) private var toastManager
    @State private var viewModel = TodayViewModel()
    @State private var subView: TodaySubView = .news
    @State private var showWeatherDetail = false
    @State private var showHolidayDetail = false
    @State private var showSessionConfig = false
    @State private var showSlotEditSheet = false
    @State private var showCustomSlotForm = false
    @State private var showAnchorForm = false
    @State private var editingSlot: AgendaSlot?
    @State private var editingAnchor: DayAnchor?
    @State private var anchors: [DayAnchor] = AnchorStore.shared.anchors()
    @State private var expandedNewsID: String?
    @State private var expandedSlotID: String?
    @State private var showNotificationPrompt = false
    @State private var briefingDismissed = false

    var body: some View {
        content
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: String.self) { route in
                if route == "allNews" {
                    NewsView(showAsChild: true)
                }
            }
            .task(id: "\(appState.city.id)-\(appState.language)") {
                await viewModel.loadAll(
                    city: appState.city,
                    language: appState.language
                )
            }
            .onChange(of: viewModel.selectedPlanDay) { _, newDay in
                anchors = AnchorStore.shared.anchors(for: newDay.date())
                Task {
                    await viewModel.composeAgendaForSelectedDay(
                        city: appState.city,
                        language: appState.language,
                        session: appState.familySession
                    )
                }
            }
            .sheet(isPresented: $showWeatherDetail) {
                if let weather = viewModel.weather {
                    WeatherDetailSheet(weather: weather)
                        .presentationDetents([.medium, .large])
                }
            }
            .sheet(isPresented: $showHolidayDetail) {
                HolidayDetailSheet()
                    .presentationDetents([.medium])
            }
            .sheet(isPresented: $showSessionConfig) {
                SessionConfigSheet(session: appState.familySession) { newSession in
                    appState.familySession = newSession
                    Task {
                        await viewModel.rebuildAgenda(
                            city: appState.city,
                            language: appState.language,
                            session: newSession
                        )
                    }
                }
                .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showSlotEditSheet) {
                if let slot = editingSlot {
                    SlotEditSheet(
                        slot: slot,
                        onEditTime: { newTime in
                            viewModel.editSlotTime(slotId: slot.id, newTime: newTime)
                        },
                        onReplaceWithCustom: {
                            // Delay slightly to allow edit sheet to dismiss first
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                showCustomSlotForm = true
                            }
                        },
                        onToggleLock: {
                            viewModel.toggleSlotLock(slotId: slot.id)
                        },
                        onRemove: {
                            viewModel.removeSlot(slotId: slot.id)
                        }
                    )
                    .environment(appState)
                    .presentationDetents([.medium])
                }
            }
            .sheet(isPresented: $showCustomSlotForm) {
                if let slot = editingSlot {
                    CustomSlotFormSheet(
                        slotType: slot.type,
                        existingVenueName: slot.source == .userCustom ? slot.customVenueName : nil,
                        existingTime: slot.time,
                        existingNeighbourhood: slot.customNeighbourhood
                    ) { venueName, time, neighbourhood, locked in
                        viewModel.replaceSlotWithCustom(
                            slotId: slot.id,
                            venueName: venueName,
                            time: time,
                            neighbourhood: neighbourhood,
                            locked: locked
                        )
                    }
                    .environment(appState)
                    .presentationDetents([.large])
                }
            }
            .sheet(isPresented: $showAnchorForm) {
                AnchorFormSheet(existingAnchor: editingAnchor, activitiesData: viewModel.activitiesData) { anchor in
                    let planDate = viewModel.selectedPlanDay.date()
                    if editingAnchor != nil {
                        AnchorStore.shared.update(anchor, for: planDate)
                    } else {
                        AnchorStore.shared.add(anchor, for: planDate)
                    }
                    anchors = AnchorStore.shared.anchors(for: planDate)
                    editingAnchor = nil
                    // Rebuild is triggered automatically by AnchorStore.didChangeNotification
                }
                .environment(appState)
                .presentationDetents([.large])
            }
            .sheet(isPresented: $showNotificationPrompt) {
                NotificationPromptSheet(
                    onAccept: { acceptNotifications() },
                    onDecline: { declineNotifications() }
                )
                .environment(appState)
                .presentationDetents([.height(280)])
                .interactiveDismissDisabled()
            }
            .fullScreenCover(isPresented: $viewModel.showCalendarSwipe) {
                CalendarSwipeView(
                    events: viewModel.pendingCalendarEvents,
                    planDate: viewModel.selectedPlanDay.date()
                ) { acceptedAnchors in
                    Task {
                        await viewModel.handleCalendarSwipeComplete(
                            acceptedAnchors: acceptedAnchors,
                            city: appState.city,
                            language: appState.language,
                            session: appState.familySession
                        )
                        anchors = AnchorStore.shared.anchors(for: viewModel.selectedPlanDay.date())
                    }
                }
            }
            .onAppear {
                AnchorStore.shared.purgeIfNewDay()
                anchors = AnchorStore.shared.anchors(for: viewModel.selectedPlanDay.date())
            }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.newsData == nil
            && viewModel.activitiesData == nil {
            // Skeleton loading state
            VStack(spacing: 0) {
                heroBanner
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(0..<4, id: \.self) { _ in
                            SkeletonNewsCard()
                        }
                        .padding(.horizontal)
                    }
                    .padding(.top, 12)
                }
            }
        } else if let error = viewModel.error, viewModel.newsData == nil {
            VStack(spacing: 0) {
                heroBanner
                ErrorView(message: error) {
                    Task {
                        await viewModel.loadAll(
                            city: appState.city,
                            language: appState.language,
                            forceRefresh: true
                        )
                    }
                }
            }
        } else {
            mainContent
        }
    }

    // MARK: - Hero Banner

    @ViewBuilder
    private var heroBanner: some View {
        if subView == .plan, viewModel.agendaMode.isExecuting, let agenda = viewModel.agenda {
            ExecHeaderView(
                agenda: agenda,
                currentSlotIndex: viewModel.agendaMode.currentSlotIndex ?? 0,
                weather: viewModel.weather,
                isComplete: viewModel.isAgendaComplete,
                onSessionTap: { showSessionConfig = true },
                subView: $subView
            )
        } else {
            TodayHeroBanner(
                weather: viewModel.weatherForSelectedDay,
                badWeatherMode: viewModel.isBadWeatherForSelectedDay,
                planningDate: viewModel.selectedPlanDay.date(),
                subView: $subView,
                onHolidayTap: { showHolidayDetail = true },
                totalStoryCount: viewModel.totalNewsCount,
                categoryKeys: viewModel.categoryKeys,
                selectedCategory: $viewModel.selectedCategory,
                itemCount: { viewModel.newsItemCount(for: $0) }
            )
        }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        VStack(spacing: 0) {
            // Hero banner — outside ScrollView so navy extends behind Dynamic Island
            heroBanner

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        // Transport alert (both sub-views)
                        transportSection

                        // AI summary (news mode only) + events (both modes)
                        if !viewModel.agendaMode.isExecuting {
                            if subView == .news {
                                briefingSection
                            }
                            eventsSection
                        }

                        // Mode-specific content
                        if subView == .plan {
                            planSubView
                        } else {
                            newsSubView
                        }

                        Spacer(minLength: 24)
                    }
                }
                .refreshable {
                    await viewModel.loadAll(
                        city: appState.city,
                        language: appState.language,
                        forceRefresh: true
                    )
                }
                .onChange(of: expandedSlotID) { _, newID in
                    if let newID {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            withAnimation {
                                proxy.scrollTo(newID, anchor: .top)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Plan Sub-View

    @ViewBuilder
    private var planSubView: some View {
        // Day config (hidden in execution mode)
        if !viewModel.agendaMode.isExecuting {
            yourDayConfigSection
        }

        // Agenda section
        agendaSection
            .onAppear {
                // Calendar sync: check for new events when Plan mode appears
                viewModel.checkCalendarSync()
            }
    }

    // MARK: - Your Day Config Section

    private var yourDayConfigSection: some View {
        YourDayConfigSection(
            weather: viewModel.weatherForSelectedDay,
            badWeatherMode: viewModel.isBadWeatherForSelectedDay,
            contextText: viewModel.contextBannerText(language: appState.language),
            sessionDisplay: appState.familySession.childrenDisplay,
            anchors: anchors,
            anchorCount: anchors.count,
            canPlanWeekend: viewModel.canPlanWeekend,
            isWeekendMode: viewModel.isWeekendMode,
            onWeatherTap: { showWeatherDetail = true },
            onSessionTap: { showSessionConfig = true },
            onAnchorAdd: {
                editingAnchor = nil
                showAnchorForm = true
            },
            onAnchorEdit: { anchor in
                editingAnchor = anchor
                showAnchorForm = true
            },
            onAnchorDelete: { anchor in
                let planDate = viewModel.selectedPlanDay.date()
                AnchorStore.shared.remove(id: anchor.id, for: planDate)
                anchors = AnchorStore.shared.anchors(for: planDate)
                // Rebuild is triggered automatically by AnchorStore.didChangeNotification
            },
            onPlanWeekend: {
                Task {
                    await viewModel.composeWeekend(
                        city: appState.city,
                        language: appState.language,
                        session: appState.familySession
                    )
                }
            }
        )
    }

    // MARK: - News Sub-View

    @ViewBuilder
    private var newsSubView: some View {
        // History
        historySection

        // News cards for selected category
        newsCategoryCards
    }

    // MARK: - Transport Alert

    @ViewBuilder
    private var transportSection: some View {
        if let transport = viewModel.newsData?.transport,
           !transport.delays.isEmpty {
            TransportWidget(transport: transport)
                .padding(.horizontal)
                .padding(.top, 12)
        }
    }

    // MARK: - Agenda Section

    @ViewBuilder
    private var agendaSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header with rebuild button (hidden in execution mode)
            if !viewModel.agendaMode.isExecuting {
                HStack(alignment: .center) {
                    Text(viewModel.selectedPlanDay.headerTitle(language: appState.language))
                        .font(.sectionHeadline)
                        .foregroundStyle(.znInk)

                    Spacer()

                    if viewModel.agenda != nil {
                        HStack(spacing: 8) {
                            Button {
                                Task {
                                    await viewModel.rebuildAgenda(
                                        city: appState.city,
                                        language: appState.language,
                                        session: appState.familySession
                                    )
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                        .font(.system(size: 10, weight: .semibold))
                                    Text(appState.localized(en: "Rebuild", de: "Neu planen"))
                                        .font(.system(size: 12, weight: .medium))
                                }
                                .foregroundStyle(Color.znNavy)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.znNeutralTagBg)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)

                            Button {
                                Task {
                                    await viewModel.handleCalendarSync(toast: toastManager)
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "calendar.badge.plus")
                                        .font(.system(size: 10, weight: .semibold))
                                    Text(appState.localized(en: "Sync", de: "Sync"))
                                        .font(.system(size: 12, weight: .medium))
                                }
                                .foregroundStyle(Color.znNavy)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.znNeutralTagBg)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 6)

                // Save to Calendar ghost button
                if viewModel.agenda != nil && !viewModel.agendaMode.isExecuting {
                    Button {
                        Task {
                            await viewModel.exportPlanToCalendar(toast: toastManager)
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "calendar")
                                .font(.system(size: 12))
                            Text(appState.localized(en: "Save to Calendar", de: "Im Kalender speichern"))
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundStyle(Color.znNavy)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .overlay(
                            Capsule()
                                .stroke(Color.znNavy.opacity(0.4), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)
                    .padding(.bottom, 6)
                }

                // Day picker pills (today/tomorrow or weekend)
                if viewModel.availablePlanDays.count > 1 {
                    dayPickerPills
                        .padding(.horizontal)
                        .padding(.bottom, 12)
                }
            }

            // Calendar sync banner (new events detected after plan built)
            if viewModel.showCalendarSyncBanner {
                CalendarSyncBanner(
                    eventCount: viewModel.pendingBannerEventCount,
                    onSync: {
                        Task {
                            await viewModel.handleCalendarSync(toast: toastManager)
                        }
                    }
                )
                .padding(.bottom, 8)
            }

            // Conflict warning (overlapping anchors)
            if let warning = viewModel.conflictWarning {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.orange)
                    Text(warning)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.znBody)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.znAlertBg)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal)
                .padding(.bottom, 8)
            }

            // Weather note (if agenda has one, and not executing)
            if !viewModel.agendaMode.isExecuting,
               let weatherNote = viewModel.agenda?.weatherNote, !weatherNote.isEmpty {
                Text(weatherNote)
                    .font(.system(size: 12))
                    .foregroundStyle(.znMuted)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            }

            // Agenda content
            agendaContent
                .padding(.horizontal)
        }
        .padding(.top, 10)
    }

    @ViewBuilder
    private var agendaContent: some View {
        // Special states — no API call needed
        if viewModel.isDayCompleteState {
            DayCompleteView()
                .environment(appState)
        } else if viewModel.isAnchorOnlyState {
            AnchorOnlyView(
                anchors: anchors,
                onEdit: { anchor in
                    editingAnchor = anchor
                    showAnchorForm = true
                },
                onDelete: { anchor in
                    let planDate = viewModel.selectedPlanDay.date()
                    AnchorStore.shared.remove(id: anchor.id, for: planDate)
                    anchors = AnchorStore.shared.anchors(for: planDate)
                    // Rebuild is triggered automatically by AnchorStore.didChangeNotification
                },
                onAdd: {
                    editingAnchor = nil
                    showAnchorForm = true
                }
            )
            .environment(appState)
        } else {
        // Normal agenda flow
        switch viewModel.agendaState {
        case .idle, .loading:
            AgendaLoadingView()

        case .loaded, .fallback:
            if let agenda = viewModel.agenda {
                if agenda.badWeatherMode {
                    BadWeatherAgendaView(
                        agenda: agenda,
                        activities: viewModel.activitiesData?.activities ?? [],
                        lunchSpots: viewModel.lunchData?.spots ?? [],
                        location: locationManager.location,
                        agendaMode: viewModel.agendaMode,
                        expandedSlotID: $expandedSlotID,
                        onSwap: { slotId, swap in
                            viewModel.swapSlot(slotId: slotId, with: swap)
                        },
                        onStartExecuting: {
                            handleLetsGo()
                        },
                        onAdvanceSlot: {
                            viewModel.handleCheckIn()
                        },
                        onExitExecution: {
                            withAnimation(AppAnimation.spring) {
                                viewModel.exitExecution()
                            }
                        },
                        onEditSlot: { slot in
                            editingSlot = slot
                            showSlotEditSheet = true
                        },
                        onSuggestAnother: { slotId in
                            withAnimation(.easeInOut(duration: 0.2)) {
                                viewModel.suggestAnotherNearby(slotId: slotId)
                            }
                        },
                        showReflowBanner: viewModel.showReflowBanner,
                        reflowSlotId: viewModel.reflowSlotId,
                        onRebuild: {
                            Task {
                                await viewModel.reflowAgenda(
                                    city: appState.city,
                                    language: appState.language,
                                    session: appState.familySession
                                )
                            }
                        },
                        onKeepSlots: {
                            viewModel.clearStaleSlots()
                        },
                        activeWarning: viewModel.activeWarning,
                        onAcceptWarning: {
                            viewModel.applyWarningResolution()
                        },
                        onDismissWarning: {
                            viewModel.dismissWarning()
                        }
                    )
                } else {
                    AgendaTimelineView(
                        agenda: agenda,
                        activities: viewModel.activitiesData?.activities ?? [],
                        lunchSpots: viewModel.lunchData?.spots ?? [],
                        location: locationManager.location,
                        agendaMode: viewModel.agendaMode,
                        expandedSlotID: $expandedSlotID,
                        onSwap: { slotId, swap in
                            viewModel.swapSlot(slotId: slotId, with: swap)
                        },
                        onStartExecuting: {
                            handleLetsGo()
                        },
                        onAdvanceSlot: {
                            viewModel.handleCheckIn()
                        },
                        onExitExecution: {
                            withAnimation(AppAnimation.spring) {
                                viewModel.exitExecution()
                            }
                        },
                        onEditSlot: { slot in
                            editingSlot = slot
                            showSlotEditSheet = true
                        },
                        onSuggestAnother: { slotId in
                            withAnimation(.easeInOut(duration: 0.2)) {
                                viewModel.suggestAnotherNearby(slotId: slotId)
                            }
                        },
                        showReflowBanner: viewModel.showReflowBanner,
                        reflowSlotId: viewModel.reflowSlotId,
                        onRebuild: {
                            Task {
                                await viewModel.reflowAgenda(
                                    city: appState.city,
                                    language: appState.language,
                                    session: appState.familySession
                                )
                            }
                        },
                        onKeepSlots: {
                            viewModel.clearStaleSlots()
                        },
                        activeWarning: viewModel.activeWarning,
                        onAcceptWarning: {
                            viewModel.applyWarningResolution()
                        },
                        onDismissWarning: {
                            viewModel.dismissWarning()
                        }
                    )
                }
            } else {
                AgendaLoadingView()
            }

        case .error(let message):
            VStack(spacing: 8) {
                Text(message)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.znBody)

                Button {
                    Task {
                        await viewModel.rebuildAgenda(
                            city: appState.city,
                            language: appState.language,
                            session: appState.familySession
                        )
                    }
                } label: {
                    Text(appState.localized(en: "Try again", de: "Nochmal versuchen"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.znNavy)
                }
            }
            .padding()
        }
        } // end else (normal agenda flow)
    }

    // MARK: - AI Summary / Briefing

    @ViewBuilder
    private var briefingSection: some View {
        if !briefingDismissed,
           let briefing = viewModel.newsData?.briefing,
           briefing.topStory != nil {
            BriefingCard(briefing: briefing) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    briefingDismissed = true
                }
            }
            .padding(.horizontal)
            .padding(.top, 16)
        }
    }

    // MARK: - What's On Today

    @ViewBuilder
    private var eventsSection: some View {
        let events = viewModel.todayEvents(
            language: appState.language,
            city: appState.city
        )
        if !events.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                // Header with inline calendar link
                HStack(alignment: .firstTextBaseline) {
                    Text(appState.localized(en: "What's on today", de: "Was läuft heute"))
                        .font(.sectionHeadline)
                        .foregroundStyle(.znInk)

                    Spacer()

                    Button {
                        appState.pendingExploreRoute = "events"
                        appState.selectedTab = .explore
                    } label: {
                        HStack(spacing: 3) {
                            Text(appState.localized(en: "Calendar", de: "Kalender"))
                                .font(.system(size: 12, weight: .medium))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundStyle(.znNavy)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal)
                .padding(.bottom, 10)

                VStack(spacing: 6) {
                    ForEach(events) { event in
                        TodayEventRow(event: event)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.top, 12)
        }
    }

    // MARK: - History

    @ViewBuilder
    private var historySection: some View {
        if let history = viewModel.newsData?.history {
            HistoryBanner(history: history)
                .padding(.horizontal)
                .padding(.top, 20)
        }
    }

    // MARK: - News Category Cards

    @ViewBuilder
    private var newsCategoryCards: some View {
        let items = viewModel.currentNewsItems
        if !items.isEmpty {
            VStack(spacing: 8) {
                ForEach(items) { item in
                    NewsCard(
                        item: item,
                        category: viewModel.selectedCategory,
                        expandedID: $expandedNewsID
                    )
                }
            }
            .padding(.horizontal)
            .padding(.top, 12)

            // See all news → push full NewsView
            NavigationLink(value: "allNews") {
                HStack(spacing: 4) {
                    Text(appState.localized(
                        en: "See all \(viewModel.totalNewsCount) articles",
                        de: "Alle \(viewModel.totalNewsCount) Artikel"
                    ))
                    .font(.system(size: 13, weight: .medium))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundStyle(.znNavy)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(Color.znNeutralTagBg)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .padding(.horizontal)
            .padding(.top, 10)
        }
    }

    // MARK: - Day Picker Pills (Weekend Mode)

    private var dayPickerPills: some View {
        HStack(spacing: 8) {
            ForEach(viewModel.availablePlanDays, id: \.self) { day in
                let isSelected = viewModel.selectedPlanDay == day
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.selectedPlanDay = day
                    }
                } label: {
                    Text(day.shortLabel(language: appState.language))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(isSelected ? .white : .znBody)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(isSelected ? Color.znNavy : Color.znNeutralTagBg)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .sensoryFeedback(.selection, trigger: isSelected)
            }

            Spacer()
        }
    }

    // MARK: - Section Header

    private func sectionHeader(title: String, subtitle: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.sectionHeadline)
                .foregroundStyle(.znInk)

            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.znMuted)
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 10)
    }

    // MARK: - Let's Go (with notification permission)

    private static let notificationPromptShownKey = "znuni.notificationPromptShown"

    private func handleLetsGo() {
        let alreadyAsked = UserDefaults.standard.bool(forKey: Self.notificationPromptShownKey)

        if alreadyAsked {
            // Permission already handled — just start
            withAnimation(AppAnimation.spring) {
                viewModel.startExecuting()
            }
        } else {
            // Show custom in-app prompt first
            showNotificationPrompt = true
        }
    }

    private func acceptNotifications() {
        UserDefaults.standard.set(true, forKey: Self.notificationPromptShownKey)
        showNotificationPrompt = false
        Task {
            await AgendaNotificationScheduler.requestPermission()
            await MainActor.run {
                withAnimation(AppAnimation.spring) {
                    viewModel.startExecuting()
                }
            }
        }
    }

    private func declineNotifications() {
        UserDefaults.standard.set(true, forKey: Self.notificationPromptShownKey)
        showNotificationPrompt = false
        withAnimation(AppAnimation.spring) {
            viewModel.startExecuting()
        }
    }
}

#Preview {
    NavigationStack {
        TodayView()
    }
    .environment(AppState())
    .environment(LocationManager())
}
