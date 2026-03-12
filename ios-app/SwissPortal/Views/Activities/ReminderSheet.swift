import SwiftUI

/// Date picker sheet for setting an activity reminder.
struct ReminderSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(ReminderManager.self) private var reminderManager
    @Environment(ToastManager.self) private var toastManager
    @Environment(\.dismiss) private var dismiss

    let activity: Activity

    @State private var selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Activity info
                HStack(spacing: 10) {
                    Image(systemName: "bell.fill")
                        .font(.title2)
                        .foregroundStyle(.brand)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(appState.localized(en: "Set Reminder", de: "Erinnerung setzen"))
                            .font(.headline)
                        Text(activity.localizedName(language: appState.language))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
                .padding(.horizontal)

                // Date picker
                DatePicker(
                    appState.localized(en: "Remind me on", de: "Erinnere mich am"),
                    selection: $selectedDate,
                    in: Date()...,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .padding(.horizontal)

                Text(appState.localized(
                    en: "You'll receive a notification at 9:00 AM",
                    de: "Du erhältst eine Benachrichtigung um 9:00 Uhr"
                ))
                .font(.caption)
                .foregroundStyle(.secondary)

                Spacer()

                // Confirm button
                Button {
                    Task {
                        await reminderManager.scheduleReminder(
                            activityId: activity.id,
                            name: activity.localizedName(language: appState.language),
                            date: selectedDate
                        )
                        toastManager.show(
                            appState.localized(en: "Reminder set", de: "Erinnerung gesetzt"),
                            type: .success
                        )
                        dismiss()
                    }
                } label: {
                    Text(appState.localized(en: "Set Reminder", de: "Erinnerung setzen"))
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(LinearGradient.brand)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}
