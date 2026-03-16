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

                // "Pick date" button
                Button(action: onPickDate) {
                    HStack(spacing: 4) {
                        if case .specific = selectedPlanDay {
                            // Show the selected date
                            Text(selectedPlanDay.shortLabel(language: appState.language))
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.white)
                        } else {
                            Image(systemName: "calendar")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.znBody)
                        }
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(isSpecificSelected ? .white.opacity(0.6) : .znMuted)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(isSpecificSelected ? Color.znNavy : Color.znNeutralTagBg)
                    .clipShape(Capsule())
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
