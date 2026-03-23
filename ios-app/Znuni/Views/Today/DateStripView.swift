import SwiftUI

/// Horizontal scrolling date strip showing 14 days.
/// 5 cells visible at a time, with trailing calendar icon for date picker.
struct DateStripView: View {
    let dates: [Date]
    @Binding var selectedDate: Date
    var onCalendarTap: () -> Void

    private let calendar = Calendar.current

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(dates, id: \.self) { date in
                        dateCell(date)
                            .id(date)
                            .onTapGesture {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    selectedDate = date
                                }
                            }
                    }

                    // Calendar icon trailing
                    Button(action: onCalendarTap) {
                        Image(systemName: "calendar")
                            .font(.system(size: 18))
                            .foregroundStyle(Color.znChevron)
                            .frame(width: 44, height: 56)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color.znCream)
            .onChange(of: selectedDate) { _, newDate in
                withAnimation {
                    proxy.scrollTo(newDate, anchor: .center)
                }
            }
            .onAppear {
                // Initial scroll to selected date
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    proxy.scrollTo(selectedDate, anchor: .center)
                }
            }
        }
    }

    // MARK: - Date Cell

    @ViewBuilder
    private func dateCell(_ date: Date) -> some View {
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let isToday = calendar.isDateInToday(date)
        let isFutureWeek = dayOffset(date) >= 7

        VStack(spacing: 2) {
            Text(dayName(date))
                .font(.system(size: 10, weight: .medium))
                .textCase(.uppercase)

            Text("\(calendar.component(.day, from: date))")
                .font(.system(size: 16, weight: .semibold))
        }
        .frame(width: 44, height: 56)
        .foregroundStyle(
            isSelected ? .white :
            isToday ? Color.znNavy :
            isFutureWeek ? Color.znMuted : Color.znInk
        )
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? Color.znNavy : .clear)
        )
        .overlay {
            if isToday && !isSelected {
                // Small dot indicator for today
                VStack {
                    Spacer()
                    Circle()
                        .fill(Color.znNavy)
                        .frame(width: 4, height: 4)
                        .padding(.bottom, 4)
                }
            }
        }
    }

    // MARK: - Helpers

    private func dayName(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f.string(from: date)
    }

    private func dayOffset(_ date: Date) -> Int {
        let start = calendar.startOfDay(for: Date())
        let target = calendar.startOfDay(for: date)
        return calendar.dateComponents([.day], from: start, to: target).day ?? 0
    }
}
