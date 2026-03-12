import SwiftUI
import PhotosUI

/// Sheet for adding a custom restaurant to the lunch list.
///
/// Provides a form with fields for name, cuisine category, photo, rating, and notes.
/// Saves the restaurant to UserDefaults.
struct AddRestaurantSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @Environment(ToastManager.self) private var toastManager

    @State private var name: String = ""
    @State private var cuisineCategory: String = "Swiss"
    @State private var notes: String = ""
    @State private var showValidationError: Bool = false
    @State private var userRating: Int = 0
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var selectedImage: UIImage?

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
                        .foregroundStyle(.znNegative)
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

                // Photo
                Section {
                    HStack {
                        PhotosPicker(
                            selection: $selectedPhotoItem,
                            matching: .images
                        ) {
                            if let selectedImage {
                                Image(uiImage: selectedImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 80, height: 80)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            } else {
                                VStack(spacing: 6) {
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 22))
                                        .foregroundStyle(.znMuted)
                                    Text(appState.localized(en: "Add photo", de: "Foto hinzufügen"))
                                        .font(.caption2)
                                        .foregroundStyle(.znMuted)
                                }
                                .frame(width: 80, height: 80)
                                .background(Color.znCream)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5]))
                                        .foregroundStyle(.znBorder)
                                )
                            }
                        }
                        .onChange(of: selectedPhotoItem) { _, newItem in
                            Task {
                                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                    selectedImageData = data
                                    selectedImage = UIImage(data: data)
                                }
                            }
                        }

                        if selectedImage != nil {
                            Spacer()
                            Button {
                                selectedPhotoItem = nil
                                selectedImageData = nil
                                selectedImage = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.znMuted)
                            }
                        }
                    }
                } header: {
                    Text(appState.localized(en: "Photo", de: "Foto"))
                }

                // Rating
                Section {
                    HStack(spacing: 8) {
                        ForEach(1...5, id: \.self) { star in
                            Button {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    userRating = userRating == star ? 0 : star
                                }
                            } label: {
                                Image(systemName: star <= userRating ? "star.fill" : "star")
                                    .font(.system(size: 24))
                                    .foregroundStyle(star <= userRating ? .znTerracotta : .znBorder)
                            }
                            .buttonStyle(.plain)
                            .sensoryFeedback(.selection, trigger: userRating)
                        }
                        Spacer()
                        if userRating > 0 {
                            Text("\(userRating)/5")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.znMuted)
                        }
                    }
                } header: {
                    Text(appState.localized(en: "Your rating", de: "Deine Bewertung"))
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

        // Compress photo to JPEG for storage (max ~200KB)
        let compressedPhoto: Data? = selectedImage?
            .jpegData(compressionQuality: 0.5)

        let spot = CustomLunchSpot(
            id: "custom-\(UUID().uuidString)",
            name: trimmedName,
            cuisineCategory: cuisineCategory,
            notes: notes.trimmingCharacters(in: .whitespaces).isEmpty
                ? nil
                : notes.trimmingCharacters(in: .whitespaces),
            rating: userRating > 0 ? userRating : nil,
            photoData: compressedPhoto
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
    let rating: Int?
    let photoData: Data?

    /// Look up a custom lunch spot by ID from UserDefaults.
    static func find(_ id: String) -> CustomLunchSpot? {
        guard let data = UserDefaults.standard.data(forKey: "customLunch"),
              let list = try? JSONDecoder().decode([CustomLunchSpot].self, from: data) else {
            return nil
        }
        return list.first { $0.id == id }
    }

    /// UIImage from stored photo data, if available.
    var photo: UIImage? {
        guard let photoData else { return nil }
        return UIImage(data: photoData)
    }
}
