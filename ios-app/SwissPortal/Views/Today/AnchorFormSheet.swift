import SwiftUI

/// Form sheet for adding or editing a day anchor (pre-existing commitment).
///
/// Three fields:
/// 1. **What** — text field with autocomplete suggestions
/// 2. **When** — time picker row (defaults to nearest half-hour)
/// 3. **Where** — optional neighbourhood chips
///
/// Suggestions drawn from: today's city events, recurring activities, hardcoded presets.
struct AnchorFormSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    /// Existing anchor to edit, or nil for new.
    let existingAnchor: DayAnchor?
    /// Activities data for building suggestions.
    let activitiesData: ActivitiesResponse?
    let onSave: (DayAnchor) -> Void

    @State private var label: String
    @State private var selectedTime: Date
    @State private var selectedNeighbourhood: String?
    @FocusState private var isLabelFocused: Bool

    init(
        existingAnchor: DayAnchor? = nil,
        activitiesData: ActivitiesResponse? = nil,
        onSave: @escaping (DayAnchor) -> Void
    ) {
        self.existingAnchor = existingAnchor
        self.activitiesData = activitiesData
        self.onSave = onSave
        _label = State(initialValue: existingAnchor?.label ?? "")
        _selectedTime = State(initialValue: existingAnchor?.time ?? Self.nearestHalfHour())
        _selectedNeighbourhood = State(initialValue: existingAnchor?.neighbourhood)
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

                    // 2. When — time picker
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

                    // 3. Where (optional) — neighbourhood chips
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

                    // Save button
                    Button {
                        guard !label.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                        let anchor = DayAnchor(
                            id: existingAnchor?.id ?? UUID(),
                            label: label.trimmingCharacters(in: .whitespaces),
                            time: selectedTime,
                            neighbourhood: selectedNeighbourhood,
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
                        .background(
                            label.trimmingCharacters(in: .whitespaces).isEmpty
                                ? Color.znNavy.opacity(0.4)
                                : Color.znNavy
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                    .disabled(label.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
        }
    }

    // MARK: - Suggestions View

    private var suggestionsView: some View {
        VStack(spacing: 0) {
            ForEach(Array(filteredSuggestions.enumerated()), id: \.element.id) { index, suggestion in
                Button {
                    label = suggestion.label
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
