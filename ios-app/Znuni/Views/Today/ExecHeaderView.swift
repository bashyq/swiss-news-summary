import SwiftUI

/// Execution mode header: progress dots, current slot hero, "Up next" strip.
///
/// Replaces the standard TodayHeroBanner when the user is actively executing their day plan.
/// Dark background (#0F2238) with grid texture, progress dots (done/active/future),
/// current venue hero (Playfair 26pt name, 38pt time), and optional "Up next" strip
/// with "Leave at" chip.
struct ExecHeaderView: View {
    @Environment(AppState.self) private var appState

    let agenda: DayAgenda
    let currentSlotIndex: Int
    let weather: Weather?
    let isComplete: Bool
    let onSessionTap: () -> Void
    @Binding var subView: TodaySubView
    @State private var showShareSheet = false

    private var currentSlot: AgendaSlot? {
        guard currentSlotIndex < agenda.slots.count else { return nil }
        return agenda.slots[currentSlotIndex]
    }

    private var nextSlot: AgendaSlot? {
        let nextIdx = currentSlotIndex + 1
        guard nextIdx < agenda.slots.count else { return nil }
        return agenda.slots[nextIdx]
    }

    /// "Leave at" time based on next slot's time minus travel from current.
    private var leaveAtTime: String? {
        guard let current = currentSlot,
              let next = nextSlot,
              let travelMin = current.travelMinutesToNext else { return nil }
        let parts = next.time.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return nil }
        let totalMinutes = parts[0] * 60 + parts[1] - travelMin
        let h = totalMinutes / 60
        let m = totalMinutes % 60
        return String(format: "%02d:%02d", h, m)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Eyebrow + segment control + city selector — matches TodayHeroBanner layout
            HStack(alignment: .center) {
                Text(eyebrowDate)
                    .font(.znEyebrow)
                    .tracking(1.3)
                    .textCase(.uppercase)
                    .foregroundStyle(.white.opacity(0.42))

                Spacer()

                execSegmentControl

                Button { showShareSheet = true } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .buttonStyle(.plain)
                .sheet(isPresented: $showShareSheet) {
                    ShareSheet(items: [PlanShareFormatter.format(agenda, city: appState.city.displayName)])
                }

                CityMenuButton()
            }
            .padding(.bottom, 6)

            // Progress dots row
            progressDotsRow
                .padding(.bottom, 16)

            if isComplete {
                completionHero
            } else if let slot = currentSlot {
                // Current slot hero
                slotHero(slot)

                // Up next strip
                if let next = nextSlot {
                    upNextStrip(next)
                        .padding(.top, 14)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 18)
        .padding(.bottom, 24)
        .background {
            ZStack {
                // Dark execution background
                Color(red: 0.059, green: 0.133, blue: 0.220) // #0F2238
                    .ignoresSafeArea(.container, edges: .top)

                // Subtle grid texture overlay
                gridTexture
                    .opacity(0.04)
            }
        }
    }

    // MARK: - Exec Segment Control (smaller, subdued)

    private var execSegmentControl: some View {
        HStack(spacing: 2) {
            ForEach(TodaySubView.allCases, id: \.self) { tab in
                let isActive = subView == tab
                let label = tab == .plan
                    ? appState.localized(en: "Plan", de: "Plan")
                    : appState.localized(en: "News", de: "News")

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        subView = tab
                    }
                } label: {
                    Text(label)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(isActive ? Color.znNavy : .white.opacity(0.5))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 5)
                        .background(isActive ? .white : .clear)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .sensoryFeedback(.selection, trigger: isActive)
            }
        }
        .padding(3)
        .background(.white.opacity(0.1))
        .clipShape(Capsule())
    }

    // MARK: - Progress Dots

    private var progressDotsRow: some View {
        HStack(spacing: 8) {
            ForEach(Array(agenda.slots.enumerated()), id: \.element.id) { index, slot in
                Circle()
                    .fill(dotColor(for: index))
                    .frame(width: 8, height: 8)
                    .overlay {
                        if index == currentSlotIndex && !isComplete {
                            // Pulsing glow for active
                            Circle()
                                .fill(Color.znTerracotta.opacity(0.4))
                                .frame(width: 16, height: 16)
                        }
                    }
            }

            Spacer()

            // Weather mini
            if let weather {
                HStack(spacing: 4) {
                    Image(systemName: weather.sfSymbol)
                        .symbolRenderingMode(.multicolor)
                        .font(.system(size: 14))
                    Text("\(Int(weather.temperature))°")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
        }
    }

    private func dotColor(for index: Int) -> Color {
        if isComplete || index < currentSlotIndex {
            return .white.opacity(0.35)  // done
        } else if index == currentSlotIndex {
            return .znTerracotta           // active
        } else {
            return .white.opacity(0.15)  // future
        }
    }

    // MARK: - Slot Hero

    private func slotHero(_ slot: AgendaSlot) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // Type eyebrow
            Text(slot.type.displayName)
                .font(.znEyebrow)
                .tracking(1.3)
                .textCase(.uppercase)
                .foregroundStyle(slot.accentColor.opacity(0.7))

            // Venue name (Playfair 26pt)
            Text(slot.venueName)
                .font(.custom("Playfair", size: 26))
                .foregroundStyle(.white)
                .lineLimit(2)

            // Time (large display) — animated on timeline shift
            Text(slot.time)
                .font(.system(size: 38, weight: .ultraLight, design: .default))
                .foregroundStyle(.white.opacity(0.85))
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.3), value: slot.time)
                .padding(.top, 2)

            // Duration + tags
            HStack(spacing: 8) {
                if let duration = slot.durationDisplay {
                    Text(duration)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                }

                ForEach(slot.tags.prefix(3), id: \.self) { tag in
                    Text(tag)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.white.opacity(0.08))
                        .clipShape(Capsule())
                }
            }
            .padding(.top, 4)
        }
    }

    // MARK: - Completion Hero

    private var completionHero: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(appState.localized(en: "Great day!", de: "Toller Tag!"))
                .font(.custom("Playfair", size: 26))
                .foregroundStyle(.white)

            Text(appState.localized(
                en: "You completed all \(agenda.slots.count) stops",
                de: "Alle \(agenda.slots.count) Stationen geschafft"
            ))
            .font(.system(size: 14))
            .foregroundStyle(.white.opacity(0.6))
        }
    }

    // MARK: - Up Next Strip

    private func upNextStrip(_ nextSlot: AgendaSlot) -> some View {
        HStack(spacing: 10) {
            // Up next label
            VStack(alignment: .leading, spacing: 2) {
                Text(appState.localized(en: "UP NEXT", de: "ALS NÄCHSTES"))
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(.white.opacity(0.4))

                Text(nextSlot.venueName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(1)
            }

            Spacer()

            // Leave at chip — animated on timeline shift
            if let leaveAt = leaveAtTime {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 10))
                    Text(appState.localized(en: "Leave at \(leaveAt)", de: "Los um \(leaveAt)"))
                        .font(.system(size: 11, weight: .medium))
                        .contentTransition(.numericText())
                        .animation(.easeInOut(duration: 0.3), value: leaveAt)
                }
                .foregroundStyle(Color.znTerracotta)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.znTerracotta.opacity(0.15))
                .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Eyebrow Date

    private var eyebrowDate: String {
        let formatter = DateFormatter()
        formatter.locale = appState.language == .de
            ? Locale(identifier: "de_CH")
            : Locale(identifier: "en_US")
        formatter.dateFormat = appState.language == .de
            ? "EEEE · d. MMMM"
            : "EEEE · d MMMM"
        return formatter.string(from: Date())
    }

    // MARK: - Grid Texture

    private var gridTexture: some View {
        Canvas { context, size in
            let spacing: CGFloat = 20
            for x in stride(from: 0, through: size.width, by: spacing) {
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(path, with: .color(.white), lineWidth: 0.5)
            }
            for y in stride(from: 0, through: size.height, by: spacing) {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(path, with: .color(.white), lineWidth: 0.5)
            }
        }
    }
}
