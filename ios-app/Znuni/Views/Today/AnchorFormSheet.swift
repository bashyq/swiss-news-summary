import SwiftUI

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
    @State private var selectedTime: Date
    @State private var selectedDuration: DurationOption
    @State private var customDurationMinutes: Int
    @State private var showCustomDuration: Bool = false
    @State private var selectedNeighbourhood: String?
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
        _selectedTime = State(initialValue: existingAnchor?.startTime ?? Self.nearestHalfHour())
        _selectedNeighbourhood = State(initialValue: existingAnchor?.neighbourhood)

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
        _selectedTime = State(initialValue: Self.nearestHalfHour())
        _selectedNeighbourhood = State(initialValue: nil)
        _selectedDuration = State(initialValue: .preset(120))
        _customDurationMinutes = State(initialValue: 120)
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
                        ? appState.localized(en: "Add plans for today", de: "Pläne für heute hinzufügen")
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

    private var saveButton: some View {
        Button {
            guard canSave, let category = selectedCategory else { return }
            let anchor = DayAnchor(
                id: existingAnchor?.id ?? UUID(),
                title: label.trimmingCharacters(in: .whitespaces),
                category: category,
                startTime: selectedTime,
                durationMinutes: effectiveDuration,
                neighbourhood: selectedNeighbourhood,
                sourceEventId: existingAnchor?.sourceEventId ?? sourceEvent?.id,
                createdDate: existingAnchor?.createdDate ?? Date()
            )
            onSave(anchor)
            dismiss()
        } label: {
            Text(existingAnchor == nil
                ? appState.localized(en: "Add to today", de: "Heute hinzufügen")
                : appState.localized(en: "Update", de: "Aktualisieren"))
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

    private let neighbourhoods = [
        "Kreis 1", "Kreis 2", "Kreis 3", "Kreis 4", "Kreis 5",
        "Kreis 6", "Kreis 7", "Kreis 8", "Seefeld", "Wiedikon",
        "Oerlikon", "Altstetten"
    ]
}
