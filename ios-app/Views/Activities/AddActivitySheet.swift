import SwiftUI

/// Sheet for adding a custom user-created activity.
///
/// Provides a form with fields for name, description, indoor/outdoor toggle,
/// price, and URL. Saves the activity to UserDefaults via AppState's custom activities.
struct AddActivitySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    @State private var name: String = ""
    @State private var description: String = ""
    @State private var isIndoor: Bool = true
    @State private var price: String = ""
    @State private var urlString: String = ""
    @State private var showValidationError: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                // Name field
                Section {
                    TextField(
                        appState.localized(en: "Activity name", de: "Name der Aktivitat"),
                        text: $name
                    )
                    .textInputAutocapitalization(.words)
                } header: {
                    Text(appState.localized(en: "Name", de: "Name"))
                } footer: {
                    if showValidationError && name.trimmingCharacters(in: .whitespaces).isEmpty {
                        Text(appState.localized(
                            en: "Name is required",
                            de: "Name ist erforderlich"
                        ))
                        .foregroundStyle(.red)
                    }
                }

                // Description field
                Section {
                    TextField(
                        appState.localized(
                            en: "Brief description",
                            de: "Kurze Beschreibung"
                        ),
                        text: $description,
                        axis: .vertical
                    )
                    .lineLimit(3...6)
                } header: {
                    Text(appState.localized(en: "Description", de: "Beschreibung"))
                }

                // Indoor/Outdoor toggle
                Section {
                    Toggle(
                        appState.localized(en: "Indoor activity", de: "Indoor-Aktivitat"),
                        isOn: $isIndoor
                    )
                } header: {
                    Text(appState.localized(en: "Type", de: "Typ"))
                } footer: {
                    Text(isIndoor
                         ? appState.localized(en: "This activity is indoors", de: "Diese Aktivitat ist drinnen")
                         : appState.localized(en: "This activity is outdoors", de: "Diese Aktivitat ist draussen")
                    )
                }

                // Price field
                Section {
                    TextField(
                        appState.localized(en: "e.g., Free, CHF 15", de: "z.B. Gratis, CHF 15"),
                        text: $price
                    )
                } header: {
                    Text(appState.localized(en: "Price", de: "Preis"))
                }

                // URL field
                Section {
                    TextField(
                        appState.localized(en: "Website URL (optional)", de: "Webseite URL (optional)"),
                        text: $urlString
                    )
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
                } header: {
                    Text(appState.localized(en: "Website", de: "Webseite"))
                }
            }
            .navigationTitle(appState.localized(en: "Add Activity", de: "Aktivitat hinzufugen"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(appState.localized(en: "Cancel", de: "Abbrechen")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(appState.localized(en: "Save", de: "Speichern")) {
                        saveActivity()
                    }
                    .fontWeight(.semibold)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    // MARK: - Save

    private func saveActivity() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)

        guard !trimmedName.isEmpty else {
            showValidationError = true
            return
        }

        let customActivity = CustomActivity(
            id: "custom-\(UUID().uuidString)",
            name: trimmedName,
            description: description.trimmingCharacters(in: .whitespaces),
            indoor: isIndoor,
            price: price.trimmingCharacters(in: .whitespaces).isEmpty
                ? nil
                : price.trimmingCharacters(in: .whitespaces),
            url: urlString.trimmingCharacters(in: .whitespaces).isEmpty
                ? nil
                : urlString.trimmingCharacters(in: .whitespaces)
        )

        saveToUserDefaults(customActivity)
        dismiss()
    }

    /// Persist the custom activity to UserDefaults.
    private func saveToUserDefaults(_ activity: CustomActivity) {
        let key = "customActivities"
        var existing: [CustomActivity] = []

        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([CustomActivity].self, from: data) {
            existing = decoded
        }

        existing.append(activity)

        if let encoded = try? JSONEncoder().encode(existing) {
            UserDefaults.standard.set(encoded, forKey: key)
        }
    }
}

// MARK: - Custom Activity Model

/// Lightweight model for user-created activities stored in UserDefaults.
struct CustomActivity: Codable, Identifiable {
    let id: String
    let name: String
    let description: String
    let indoor: Bool
    let price: String?
    let url: String?
}

#Preview {
    AddActivitySheet()
        .environment(AppState())
}
