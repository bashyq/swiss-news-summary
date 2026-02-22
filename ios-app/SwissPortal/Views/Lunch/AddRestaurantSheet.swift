import SwiftUI

/// Sheet for adding a custom restaurant to the lunch list.
///
/// Provides a form with fields for name, cuisine category, and notes.
/// Saves the restaurant to UserDefaults.
struct AddRestaurantSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @Environment(ToastManager.self) private var toastManager

    @State private var name: String = ""
    @State private var cuisineCategory: String = "Swiss"
    @State private var notes: String = ""
    @State private var showValidationError: Bool = false

    private let cuisineOptions = ["Swiss", "Italian", "Asian", "Cafe", "Vegetarian", "Other"]

    var body: some View {
        NavigationStack {
            Form {
                // Name field
                Section {
                    TextField(
                        appState.localized(en: "Restaurant name", de: "Restaurantname"),
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

                // Cuisine category picker
                Section {
                    Picker(
                        appState.localized(en: "Cuisine", de: "Küche"),
                        selection: $cuisineCategory
                    ) {
                        ForEach(cuisineOptions, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                } header: {
                    Text(appState.localized(en: "Cuisine", de: "Küche"))
                }

                // Notes field
                Section {
                    TextField(
                        appState.localized(en: "Notes (optional)", de: "Notizen (optional)"),
                        text: $notes,
                        axis: .vertical
                    )
                    .lineLimit(3...6)
                } header: {
                    Text(appState.localized(en: "Notes", de: "Notizen"))
                }
            }
            .navigationTitle(appState.localized(en: "Add Restaurant", de: "Restaurant hinzufügen"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(appState.localized(en: "Cancel", de: "Abbrechen")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(appState.localized(en: "Save", de: "Speichern")) {
                        saveRestaurant()
                    }
                    .fontWeight(.semibold)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    // MARK: - Save

    private func saveRestaurant() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)

        guard !trimmedName.isEmpty else {
            showValidationError = true
            return
        }

        let spot = CustomLunchSpot(
            id: "custom-\(UUID().uuidString)",
            name: trimmedName,
            cuisineCategory: cuisineCategory,
            notes: notes.trimmingCharacters(in: .whitespaces).isEmpty
                ? nil
                : notes.trimmingCharacters(in: .whitespaces)
        )

        saveToUserDefaults(spot)
        toastManager.show(
            appState.localized(en: "Restaurant added", de: "Restaurant hinzugefügt"),
            type: .success
        )
        dismiss()
    }

    private func saveToUserDefaults(_ spot: CustomLunchSpot) {
        let key = "customLunch"
        var existing: [CustomLunchSpot] = []

        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([CustomLunchSpot].self, from: data) {
            existing = decoded
        }

        existing.append(spot)

        if let encoded = try? JSONEncoder().encode(existing) {
            UserDefaults.standard.set(encoded, forKey: key)
        }
    }
}

// MARK: - Custom Lunch Spot Model

/// Lightweight model for user-created lunch spots stored in UserDefaults.
struct CustomLunchSpot: Codable, Identifiable {
    let id: String
    let name: String
    let cuisineCategory: String
    let notes: String?
}
