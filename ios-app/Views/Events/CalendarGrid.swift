import SwiftUI

/// Interactive month calendar grid with colored event dots.
///
/// Displays a month/year header with navigation arrows, day-of-week headers (Mon-Sun),
/// and a grid of day cells. Each cell shows the day number and up to 3 colored dots
/// indicating event types. Today is highlighted with a circle outline, and the selected
/// day uses a filled purple circle.
struct CalendarGrid: View {
    @Environment(AppState.self) private var appState
    @Bindable var viewModel: EventsViewModel

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    var body: some View {
        VStack(spacing: 12) {
            // Month/year header with navigation
            monthHeader

            // Day-of-week labels
            dayOfWeekHeaders

            // Calendar day grid
            calendarDays
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Month Header

    private var monthHeader: some View {
        HStack {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.previousMonth()
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.purple)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Spacer()

            Text(viewModel.monthYearLabel)
                .font(.headline)
                .fontWeight(.bold)

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.nextMonth()
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.purple)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Day of Week Headers

    private var dayOfWeekHeaders: some View {
        let dayLabels: [String] = {
            if appState.language == .de {
                return ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]
            } else {
                return ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
            }
        }()

        return LazyVGrid(columns: columns, spacing: 0) {
            ForEach(dayLabels, id: \.self) { day in
                Text(day)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 4)
            }
        }
    }

    // MARK: - Calendar Days Grid

    private var calendarDays: some View {
        let offset = viewModel.firstWeekdayOffset
        let dates = viewModel.datesInMonth

        return LazyVGrid(columns: columns, spacing: 4) {
            // Empty cells before the first day
            ForEach(0..<offset, id: \.self) { _ in
                Color.clear
                    .frame(height: 44)
            }

            // Day cells
            ForEach(dates, id: \.self) { date in
                DayCell(
                    date: date,
                    isToday: DateHelpers.isToday(date),
                    isSelected: isSelected(date),
                    dots: viewModel.dotColors(for: date)
                ) {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        viewModel.selectDate(date)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func isSelected(_ date: Date) -> Bool {
        guard let selected = viewModel.selectedDate else { return false }
        return DateHelpers.isSameDay(selected, date)
    }
}

// MARK: - Day Cell

/// A single day cell in the calendar grid.
///
/// Shows the day number, highlights today with a circle outline,
/// highlights the selected day with a filled purple background,
/// and displays up to 3 small colored dots below the number.
private struct DayCell: View {
    let date: Date
    let isToday: Bool
    let isSelected: Bool
    let dots: [Color]
    let onTap: () -> Void

    private var dayNumber: Int {
        Calendar.current.component(.day, from: date)
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 2) {
                // Day number
                Text("\(dayNumber)")
                    .font(.subheadline)
                    .fontWeight(isToday ? .bold : .regular)
                    .foregroundStyle(dayTextColor)
                    .frame(width: 32, height: 32)
                    .background(dayBackground)
                    .clipShape(Circle())

                // Colored dots (up to 3)
                HStack(spacing: 3) {
                    ForEach(Array(dots.prefix(3).enumerated()), id: \.offset) { _, color in
                        Circle()
                            .fill(color)
                            .frame(width: 5, height: 5)
                    }
                }
                .frame(height: 6)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Styling

    private var dayTextColor: Color {
        if isSelected {
            return .white
        } else if isToday {
            return .purple
        } else {
            return .primary
        }
    }

    @ViewBuilder
    private var dayBackground: some View {
        if isSelected {
            Color.purple
        } else if isToday {
            Circle()
                .strokeBorder(Color.purple, lineWidth: 1.5)
                .background(Circle().fill(Color.purple.opacity(0.08)))
        } else {
            Color.clear
        }
    }
}

#Preview {
    CalendarGrid(viewModel: EventsViewModel())
        .padding()
        .environment(AppState())
}
