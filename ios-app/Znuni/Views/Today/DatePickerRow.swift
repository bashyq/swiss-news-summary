import SwiftUI

/// Horizontal pill row for selecting the planning date.
/// Shows quick-pick pills (Today / Tomorrow / Sat / Sun) plus a "Pick date →" button
/// that opens a calendar sheet for any date within 14 days.
struct DatePickerRow: View {
    @Environment(AppState.self) private var appState
    @Binding var selectedPlanDay: PlanDay
    let availableDays: [PlanDay]
    var onPickDate: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(availableDays, id: \.self) { day in
                    let isSelected = selectedPlanDay == day
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedPlanDay = day
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

                // "Pick date" button — matches pill style
                Button(action: onPickDate) {
                    if case .specific = selectedPlanDay {
                        // Show the selected specific date as a filled pill
                        HStack(spacing: 4) {
                            Text(selectedPlanDay.shortLabel(language: appState.language))
                                .font(.system(size: 13, weight: .medium))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 9, weight: .semibold))
                                .opacity(0.6)
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Color.znNavy)
                        .clipShape(Capsule())
                    } else {
                        // Dashed outline pill: "Pick date →"
                        HStack(spacing: 4) {
                            Text(appState.localized(en: "Pick date", de: "Datum"))
                                .font(.system(size: 13, weight: .medium))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9, weight: .semibold))
                        }
                        .foregroundStyle(Color.znMuted)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Color.clear)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .strokeBorder(Color.znBorder, style: StrokeStyle(lineWidth: 1, dash: [5, 3]))
                        )
                    }
                }
                .buttonStyle(.plain)

                Spacer(minLength: 0)
            }
        }
    }

    private var isSpecificSelected: Bool {
        if case .specific = selectedPlanDay { return true }
        return false
    }
}
