import SwiftUI
import CoreLocation

/// Pre-fill data for the "Plan around this" flow from activity/lunch/event cards.
struct AnchorPrefill {
    var title: String
    var category: AnchorCategory
    var lat: Double?
    var lon: Double?
    var address: String?
    var date: Date?
    var durationMinutes: Int = 120
    var sourceEventId: String?
}

/// Form sheet for adding or editing a day anchor (pre-existing commitment).
///
/// Five fields:
/// 1. **What** — text field with autocomplete suggestions
/// 2. **Category** — 2×3 grid (food, social, activity, errand, other) — required
/// 3. **When** — time picker row (defaults to nearest half-hour)
/// 4. **How long** — segmented duration (30m/1h/1.5h/2h/3h/Custom) — required
/// 5. **Where** — optional neighbourhood chips
///
/// Save is disabled until label, category, and duration are all set.
struct AnchorFormSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    /// Existing anchor to edit, or nil for new.
    let existingAnchor: DayAnchor?
    /// Activities data for building suggestions.
    let activitiesData: ActivitiesResponse?
    let onSave: (DayAnchor) -> Void

    @State private var label: String
    @State private var selectedCategory: AnchorCategory?
    @State private var selectedDate: Date
    @State private var selectedTime: Date
    @State private var selectedDuration: DurationOption
    @State private var customDurationMinutes: Int
    @State private var showCustomDuration: Bool = false
    @State private var selectedNeighbourhood: String?
    @State private var addressText: String
    @State private var resolvedLat: Double?
    @State private var resolvedLon: Double?
    @State private var isGeocoding: Bool = false
    @FocusState private var isLabelFocused: Bool

    // MARK: - Duration Options

    enum DurationOption: Hashable {
        case preset(Int)   // minutes
        case custom

        var label: String {
            switch self {
            case .preset(30):  return "30m"
            case .preset(60):  return "1h"
            case .preset(90):  return "1.5h"
            case .preset(120): return "2h"
            case .preset(180): return "3h"
            case .preset(let m): return "\(m)m"
            case .custom:      return "..."
            }
        }

        var minutes: Int? {
            switch self {
            case .preset(let m): return m
            case .custom:        return nil
            }
        }

        static let allPresets: [DurationOption] = [
            .preset(30), .preset(60), .preset(90), .preset(120), .preset(180), .custom
        ]
    }

    /// Optional CityEvent that triggered the form — sets sourceEventId on save.
    private let sourceEvent: CityEvent?

    // MARK: - Init

    init(
        existingAnchor: DayAnchor? = nil,
        activitiesData: ActivitiesResponse? = nil,
        onSave: @escaping (DayAnchor) -> Void
    ) {
        self.existingAnchor = existingAnchor
        self.activitiesData = activitiesData
        self.onSave = onSave
        self.sourceEvent = nil
        _label = State(initialValue: existingAnchor?.title ?? "")
        _selectedCategory = State(initialValue: existingAnchor?.category)
        _selectedDate = State(initialValue: existingAnchor?.startTime ?? Date())
        _selectedTime = State(initialValue: existingAnchor?.startTime ?? Self.nearestHalfHour())
        _selectedNeighbourhood = State(initialValue: existingAnchor?.neighbourhood)
        _addressText = State(initialValue: existingAnchor?.address ?? "")
        _resolvedLat = State(initialValue: existingAnchor?.lat)
        _resolvedLon = State(initialValue: existingAnchor?.lon)

        // Match existing duration to closest preset
        if let existing = existingAnchor {
            let closestPreset = Self.closestPreset(to: existing.durationMinutes)
            _selectedDuration = State(initialValue: closestPreset)
            _customDurationMinutes = State(initialValue: existing.durationMinutes)
            _showCustomDuration = State(initialValue: closestPreset == .custom)
        } else {
            _selectedDuration = State(initialValue: .preset(60))
            _customDurationMinutes = State(initialValue: 60)
        }
    }

    /// Convenience init pre-filled from a CityEvent.
    init(
        event: CityEvent,
        language: AppLanguage,
        activitiesData: ActivitiesResponse? = nil,
        onSave: @escaping (DayAnchor) -> Void
    ) {
        self.existingAnchor = nil
        self.activitiesData = activitiesData
        self.onSave = onSave
        self.sourceEvent = event
        _label = State(initialValue: event.localizedName(language: language))
        _selectedCategory = State(initialValue: event.defaultAnchorCategory)
        _selectedDate = State(initialValue: Date())
        _selectedTime = State(initialValue: Self.nearestHalfHour())
        _selectedNeighbourhood = State(initialValue: nil)
        _selectedDuration = State(initialValue: .preset(120))
        _customDurationMinutes = State(initialValue: 120)
        _addressText = State(initialValue: "")
        _resolvedLat = State(initialValue: nil)
        _resolvedLon = State(initialValue: nil)
    }

    /// Convenience init pre-filled from an AnchorPrefill (e.g. "Plan around this" flow).
    init(
        prefill: AnchorPrefill,
        activitiesData: ActivitiesResponse? = nil,
        onSave: @escaping (DayAnchor) -> Void
    ) {
        self.existingAnchor = nil
        self.activitiesData = activitiesData
        self.onSave = onSave
        self.sourceEvent = nil
        _label = State(initialValue: prefill.title)
        _selectedCategory = State(initialValue: prefill.category)
        _selectedDate = State(initialValue: prefill.date ?? Date())
        _selectedTime = State(initialValue: Self.nearestHalfHour())
        _selectedNeighbourhood = State(initialValue: nil)
        let closestPreset = Self.closestPreset(to: prefill.durationMinutes)
        _selectedDuration = State(initialValue: closestPreset)
        _customDurationMinutes = State(initialValue: prefill.durationMinutes)
        _showCustomDuration = State(initialValue: closestPreset == .custom)
        _addressText = State(initialValue: prefill.address ?? "")
        _resolvedLat = State(initialValue: prefill.lat)
        _resolvedLon = State(initialValue: prefill.lon)
    }

    private static func closestPreset(to minutes: Int) -> DurationOption {
        let presets = [30, 60, 90, 120, 180]
        if presets.contains(minutes) { return .preset(minutes) }
        return .custom
    }

    /// Round to the nearest half-hour from now.
    private static func nearestHalfHour() -> Date {
        let now = Date()
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: now)
        let minute = components.minute ?? 0
        if minute < 15 {
            components.minute = 30
        } else if minute < 45 {
            components.minute = 30
        } else {
            components.hour = (components.hour ?? 0) + 1
            components.minute = 0
        }
        components.second = 0
        return calendar.date(from: components) ?? now
    }

    // MARK: - Validation

    private var canSave: Bool {
        !label.trimmingCharacters(in: .whitespaces).isEmpty && selectedCategory != nil
    }

    private var effectiveDuration: Int {
        selectedDuration.minutes ?? customDurationMinutes
    }

    // MARK: - Suggestions

    private var suggestionProvider: AnchorSuggestionProvider {
        AnchorSuggestionProvider(
            activitiesData: activitiesData,
            language: appState.language,
            today: Date()
        )
    }

    private var filteredSuggestions: [AnchorSuggestion] {
        suggestionProvider.filtered(by: label)
    }

    private var showSuggestions: Bool {
        isLabelFocused && !filteredSuggestions.isEmpty
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Handle
            Capsule()
                .fill(Color.znBorder)
                .frame(width: 36, height: 4)
                .padding(.top, 8)
                .padding(.bottom, 16)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    Text(existingAnchor == nil
                        ? appState.localized(en: "Plan an activity", de: "Aktivität planen")
                        : appState.localized(en: "Edit plans", de: "Pläne bearbeiten"))
                    .font(.custom("Playfair", size: 20, relativeTo: .title3))
                    .foregroundStyle(.znInk)

                    // 1. What — with autocomplete suggestions
                    whatSection

                    // 2. Category — 2×3 grid
                    categorySection

                    // 3. When — time picker
                    whenSection

                    // 4. How long — segmented duration
                    durationSection

                    // 5. Where (optional) — neighbourhood chips
                    whereSection

                    // 6. Address (optional) — for proximity scoring
                    addressSection

                    // Save button
                    saveButton
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
        }
    }

    // MARK: - 1. What

    private var whatSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(appState.localized(en: "What", de: "Was"))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.znInk)

            TextField(
                appState.localized(
                    en: "e.g. Birthday party, Football match",
                    de: "z.B. Geburtstagsfeier, Fussballspiel"
                ),
                text: $label
            )
            .font(.system(size: 15))
            .focused($isLabelFocused)
            .padding(12)
            .background(Color.znCream)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.znBorder, lineWidth: 1)
            )

            // Suggestions list
            if showSuggestions {
                suggestionsView
            }
        }
    }

    // MARK: - 2. Category

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(appState.localized(en: "What kind?", de: "Welche Art?"))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.znInk)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ForEach(AnchorCategory.allCases, id: \.self) { category in
                    let isSelected = selectedCategory == category
                    Button {
                        withAnimation(.spring(duration: 0.2)) {
                            selectedCategory = category
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Text(category.emoji)
                                .font(.system(size: 20))
                            Text(appState.language == .de
                                 ? category.displayNameDE
                                 : category.displayName)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(isSelected ? .white : .znInk)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(isSelected ? Color.znNavy : Color.znCream)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(isSelected ? Color.clear : Color.znBorder, lineWidth: 1)
                        )
                        .scaleEffect(isSelected ? 1.03 : 1.0)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - 3. When

    private var whenSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(appState.localized(en: "When", de: "Wann"))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.znInk)

            // Date picker — today + next 7 days
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(0..<8, id: \.self) { offset in
                        let date = Calendar.current.date(byAdding: .day, value: offset, to: Calendar.current.startOfDay(for: Date()))!
                        let isSelected = Calendar.current.isDate(selectedDate, inSameDayAs: date)
                        Button {
                            withAnimation(.spring(duration: 0.2)) {
                                selectedDate = date
                            }
                        } label: {
                            VStack(spacing: 2) {
                                Text(offset == 0
                                    ? appState.localized(en: "Today", de: "Heute")
                                    : offset == 1
                                    ? appState.localized(en: "Tomorrow", de: "Morgen")
                                    : date.formatted(.dateTime.weekday(.abbreviated)))
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(isSelected ? .white : .znMuted)
                                Text(date.formatted(.dateTime.day()))
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(isSelected ? .white : .znInk)
                            }
                            .frame(width: 52, height: 52)
                            .background(isSelected ? Color.znNavy : Color.znCream)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(isSelected ? Color.clear : Color.znBorder, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Time picker
            DatePicker(
                "",
                selection: $selectedTime,
                displayedComponents: .hourAndMinute
            )
            .datePickerStyle(.wheel)
            .labelsHidden()
            .frame(height: 120)
            .frame(maxWidth: .infinity)
            .clipped()
        }
    }

    // MARK: - 4. Duration

    private var durationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(appState.localized(en: "How long", de: "Wie lange"))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.znInk)

            HStack(spacing: 6) {
                ForEach(DurationOption.allPresets, id: \.self) { option in
                    let isSelected = selectedDuration == option
                    Button {
                        withAnimation(.spring(duration: 0.2)) {
                            selectedDuration = option
                            if option == .custom {
                                showCustomDuration = true
                            } else {
                                showCustomDuration = false
                            }
                        }
                    } label: {
                        Text(option.label)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(isSelected ? .white : .znInk)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(isSelected ? Color.znNavy : Color.znCream)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(isSelected ? Color.clear : Color.znBorder, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            // Custom duration picker
            if showCustomDuration {
                HStack {
                    Spacer()
                    Picker("", selection: $customDurationMinutes) {
                        ForEach(Array(stride(from: 15, through: 480, by: 15)), id: \.self) { minutes in
                            Text(Self.formatMinutes(minutes))
                                .tag(minutes)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 160, height: 120)
                    .clipped()
                    Spacer()
                }
            }
        }
    }

    private static func formatMinutes(_ m: Int) -> String {
        let h = m / 60
        let remainder = m % 60
        if h == 0 { return "\(remainder) min" }
        if remainder == 0 { return "\(h)h" }
        return "\(h)h \(remainder)m"
    }

    // MARK: - 5. Where

    private var whereSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(appState.localized(en: "Where", de: "Wo"))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.znInk)

            Text(appState.localized(
                en: "Helps us plan what's nearby — optional",
                de: "Hilft bei der Planung in der Nähe — optional"
            ))
            .font(.system(size: 11))
            .foregroundStyle(.znMuted)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(neighbourhoods, id: \.self) { hood in
                        let selected = selectedNeighbourhood == hood
                        Button {
                            if selected {
                                selectedNeighbourhood = nil
                            } else {
                                selectedNeighbourhood = hood
                            }
                        } label: {
                            Text(hood)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(selected ? .white : .znInk)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(selected ? Color.znNavy : Color.znCream)
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(selected ? Color.clear : Color.znBorder, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Save Button

    /// Combine selectedDate (day) + selectedTime (hour/minute) into a single Date.
    private var combinedDateTime: Date {
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: selectedDate)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: selectedTime)
        var combined = DateComponents()
        combined.year = dateComponents.year
        combined.month = dateComponents.month
        combined.day = dateComponents.day
        combined.hour = timeComponents.hour
        combined.minute = timeComponents.minute
        return calendar.date(from: combined) ?? selectedTime
    }

    private var isToday: Bool {
        Calendar.current.isDateInToday(selectedDate)
    }

    private var saveButtonLabel: String {
        if existingAnchor != nil {
            return appState.localized(en: "Update", de: "Aktualisieren")
        }
        if isToday {
            return appState.localized(en: "Add to today", de: "Heute hinzufügen")
        }
        let dayName = selectedDate.formatted(.dateTime.weekday(.wide))
        return appState.localized(
            en: "Add to \(dayName)",
            de: "Für \(dayName) hinzufügen"
        )
    }

    private var saveButton: some View {
        Button {
            guard canSave, let category = selectedCategory else { return }
            let trimmedAddress = addressText.trimmingCharacters(in: .whitespaces)
            let anchor = DayAnchor(
                id: existingAnchor?.id ?? UUID(),
                title: label.trimmingCharacters(in: .whitespaces),
                category: category,
                startTime: combinedDateTime,
                durationMinutes: effectiveDuration,
                neighbourhood: selectedNeighbourhood,
                sourceEventId: existingAnchor?.sourceEventId ?? sourceEvent?.id,
                createdDate: existingAnchor?.createdDate ?? Date(),
                address: trimmedAddress.isEmpty ? nil : trimmedAddress,
                lat: resolvedLat,
                lon: resolvedLon
            )
            onSave(anchor)
            dismiss()
        } label: {
            Text(saveButtonLabel)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(canSave ? Color.znNavy : Color.znNavy.opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .disabled(!canSave)
    }

    // MARK: - Suggestions View

    private var suggestionsView: some View {
        VStack(spacing: 0) {
            ForEach(Array(filteredSuggestions.enumerated()), id: \.element.id) { index, suggestion in
                Button {
                    label = suggestion.label
                    selectedCategory = suggestion.defaultCategory
                    // Map preset duration to closest option
                    let closestPreset = Self.closestPreset(to: suggestion.defaultDuration)
                    selectedDuration = closestPreset
                    customDurationMinutes = suggestion.defaultDuration
                    showCustomDuration = closestPreset == .custom
                    if let coord = suggestion.coordinate {
                        selectedNeighbourhood = AnchorSuggestionProvider.nearestNeighbourhood(to: coord)
                    }
                    isLabelFocused = false
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: suggestion.type.sfSymbol)
                            .font(.system(size: 12))
                            .foregroundStyle(.znMuted)
                            .frame(width: 20)

                        Text(suggestion.label)
                            .font(.system(size: 14))
                            .foregroundStyle(.znInk)
                            .lineLimit(1)

                        Spacer()

                        Text(suggestion.type.badgeText(language: appState.language))
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.znMuted)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.znNeutralTagBg)
                            .clipShape(Capsule())
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)

                if index < filteredSuggestions.count - 1 {
                    Divider()
                        .foregroundStyle(Color.znInnerDivider)
                        .padding(.leading, 42)
                }
            }
        }
        .background(Color.znSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.znBorder, lineWidth: 1)
        )
    }

    // MARK: - 6. Address (optional)

    private var addressSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(appState.localized(en: "Address", de: "Adresse"))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.znInk)

            Text(appState.localized(
                en: "Helps plan nearby activities — optional",
                de: "Hilft, Aktivitäten in der Nähe zu planen — optional"
            ))
            .font(.system(size: 11))
            .foregroundStyle(.znMuted)

            HStack {
                TextField(
                    appState.localized(
                        en: "e.g. Bahnhofstrasse 1, Zürich",
                        de: "z.B. Bahnhofstrasse 1, Zürich"
                    ),
                    text: $addressText
                )
                .font(.system(size: 15))
                .padding(12)
                .background(Color.znCream)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.znBorder, lineWidth: 1)
                )
                .onSubmit {
                    geocodeAddress()
                }

                if isGeocoding {
                    ProgressView()
                        .scaleEffect(0.8)
                        .frame(width: 32)
                }
            }

            // Location resolved indicator
            if resolvedLat != nil && resolvedLon != nil {
                HStack(spacing: 4) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.znPositive)
                    Text(appState.localized(en: "Location resolved", de: "Standort aufgelöst"))
                        .font(.system(size: 11))
                        .foregroundStyle(.znPositive)
                }
            }
        }
    }

    /// Geocode the entered address to lat/lon using CLGeocoder.
    private func geocodeAddress() {
        let trimmed = addressText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            resolvedLat = nil
            resolvedLon = nil
            return
        }
        isGeocoding = true
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(trimmed) { placemarks, error in
            isGeocoding = false
            if let placemark = placemarks?.first, let location = placemark.location {
                resolvedLat = location.coordinate.latitude
                resolvedLon = location.coordinate.longitude
            }
        }
    }

    private let neighbourhoods = [
        "Kreis 1", "Kreis 2", "Kreis 3", "Kreis 4", "Kreis 5",
        "Kreis 6", "Kreis 7", "Kreis 8", "Seefeld", "Wiedikon",
        "Oerlikon", "Altstetten"
    ]
}
