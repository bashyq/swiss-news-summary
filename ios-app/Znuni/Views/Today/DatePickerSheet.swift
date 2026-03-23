import SwiftUI

/// Calendar sheet for picking any date within the next 14 days.
/// Presented from the "Pick date →" button in DatePickerRow.
struct DatePickerSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedPlanDay: PlanDay
    @State private var pickerDate: Date

    init(selectedPlanDay: Binding<PlanDay>) {
        self._selectedPlanDay = selectedPlanDay
        // Initialize with current selection's date, or today
        self._pickerDate = State(initialValue: selectedPlanDay.wrappedValue.date())
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                DatePicker(
                    appState.localized(en: "Plan date", de: "Plandatum"),
                    selection: $pickerDate,
                    in: dateRange,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .tint(.znNavy)
                .padding()
                .onChange(of: pickerDate) {
                    // Auto-apply when user taps a date on the calendar
                    applySelection()
                }

                // Selected date summary
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(formattedDate)
                            .font(.cardHeadline)
                            .foregroundStyle(.znInk)
                        Text(relativeDateText)
                            .font(.caption)
                            .foregroundStyle(.znMuted)
                    }
                    Spacer()
                    Button {
                        applySelection()
                    } label: {
                        Text(appState.localized(en: "Plan this day", de: "Tag planen"))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.znNavy)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .background(Color.znCream)
            .navigationTitle(appState.localized(en: "Pick a date", de: "Datum wählen"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(appState.localized(en: "Cancel", de: "Abbrechen")) {
                        dismiss()
                    }
                    .foregroundStyle(.znNavy)
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Helpers

    private var dateRange: ClosedRange<Date> {
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        let end = cal.date(byAdding: .day, value: 14, to: start) ?? start
        return start...end
    }

    private var formattedDate: String {
        let f = DateFormatter()
        f.locale = appState.language == .de ? Locale(identifier: "de_CH") : Locale(identifier: "en_US")
        f.dateFormat = appState.language == .de ? "EEEE, d. MMMM" : "EEEE, MMMM d"
        return f.string(from: pickerDate)
    }

    private var relativeDateText: String {
        let cal = Calendar.current
        if cal.isDateInToday(pickerDate) {
            return appState.localized(en: "Today", de: "Heute")
        } else if cal.isDateInTomorrow(pickerDate) {
            return appState.localized(en: "Tomorrow", de: "Morgen")
        }
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: Date()), to: cal.startOfDay(for: pickerDate)).day ?? 0
        return appState.localized(
            en: "In \(days) days",
            de: "In \(days) Tagen"
        )
    }

    private func applySelection() {
        let cal = Calendar.current
        if cal.isDateInToday(pickerDate) {
            selectedPlanDay = .today
        } else if cal.isDateInTomorrow(pickerDate) {
            selectedPlanDay = .tomorrow
        } else if cal.isDate(pickerDate, inSameDayAs: PlanDay.saturday.date()) {
            selectedPlanDay = .saturday
        } else if cal.isDate(pickerDate, inSameDayAs: PlanDay.sunday.date()) {
            selectedPlanDay = .sunday
        } else {
            selectedPlanDay = .specific(cal.startOfDay(for: pickerDate))
        }
        dismiss()
    }
}
