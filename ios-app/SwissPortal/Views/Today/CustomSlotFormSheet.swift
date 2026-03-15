import SwiftUI

/// Form sheet for entering a custom venue to replace an AI-generated slot.
/// Three fields: venue name, time, neighbourhood. Plus lock toggle.
struct CustomSlotFormSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    let slotType: AgendaSlot.SlotType
    let existingVenueName: String?
    let existingTime: String?
    let existingNeighbourhood: String?
    let onSave: (String, String, String?, Bool) -> Void // (venueName, time, neighbourhood, locked)

    @State private var venueName: String
    @State private var selectedTime: String
    @State private var selectedNeighbourhood: String?
    @State private var isLocked: Bool

    init(
        slotType: AgendaSlot.SlotType,
        existingVenueName: String? = nil,
        existingTime: String? = nil,
        existingNeighbourhood: String? = nil,
        onSave: @escaping (String, String, String?, Bool) -> Void
    ) {
        self.slotType = slotType
        self.existingVenueName = existingVenueName
        self.existingTime = existingTime
        self.existingNeighbourhood = existingNeighbourhood
        self.onSave = onSave

        _venueName = State(initialValue: existingVenueName ?? "")
        _selectedTime = State(initialValue: existingTime ?? Self.defaultTime(for: slotType))
        _selectedNeighbourhood = State(initialValue: existingNeighbourhood)
        _isLocked = State(initialValue: true) // Custom slots default to locked
    }

    private static func defaultTime(for type: AgendaSlot.SlotType) -> String {
        switch type {
        case .lunch: return "12:00"
        case .dinner: return "18:00"
        default: return "10:00"
        }
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
                    Text(appState.localized(
                        en: "Your \(slotType.displayName.lowercased()) plans",
                        de: "Dein \(slotType.displayName.lowercased())-Plan"
                    ))
                    .font(.custom("Playfair", size: 20, relativeTo: .title3))
                    .foregroundStyle(.znInk)

                    // 1. Venue name
                    VStack(alignment: .leading, spacing: 8) {
                        Text(appState.localized(en: "Where", de: "Wo"))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.znInk)

                        TextField(
                            appState.localized(
                                en: "e.g. Lily's, Hiltl, Tibits...",
                                de: "z.B. Lily's, Hiltl, Tibits..."
                            ),
                            text: $venueName
                        )
                        .font(.system(size: 15))
                        .padding(12)
                        .background(Color.znCream)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.znBorder, lineWidth: 1)
                        )
                    }

                    // 2. Time picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text(appState.localized(en: "When", de: "Wann"))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.znInk)

                        let quickTimes = quickTimesForType
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            ForEach(quickTimes, id: \.self) { time in
                                let selected = time == selectedTime
                                Button {
                                    selectedTime = time
                                } label: {
                                    Text(time)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(selected ? .white : .znInk)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 40)
                                        .background(selected ? Color.znNavy : Color.znCream)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(selected ? Color.clear : Color.znBorder, lineWidth: 1)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // 3. Neighbourhood (optional)
                    VStack(alignment: .leading, spacing: 8) {
                        Text(appState.localized(en: "Neighbourhood", de: "Quartier"))
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

                    // 4. Lock toggle
                    HStack(spacing: 12) {
                        Image(systemName: isLocked ? "lock.fill" : "lock.open")
                            .font(.system(size: 14))
                            .foregroundStyle(.znNavy)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(appState.localized(en: "Lock this slot", de: "Slot sperren"))
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.znInk)
                            Text(appState.localized(
                                en: "Won't be changed if you rebuild the plan",
                                de: "Wird beim Neuaufbau nicht geändert"
                            ))
                            .font(.system(size: 11))
                            .foregroundStyle(.znMuted)
                        }

                        Spacer()

                        Toggle("", isOn: $isLocked)
                            .labelsHidden()
                            .tint(.znNavy)
                    }
                    .padding(12)
                    .background(Color.znCream)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // Save button
                    Button {
                        guard !venueName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                        onSave(venueName.trimmingCharacters(in: .whitespaces), selectedTime, selectedNeighbourhood, isLocked)
                        dismiss()
                    } label: {
                        Text(appState.localized(
                            en: "Save \(slotType.displayName.lowercased()) plans",
                            de: "\(slotType.displayName)-Plan speichern"
                        ))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            venueName.trimmingCharacters(in: .whitespaces).isEmpty
                                ? Color.znNavy.opacity(0.4)
                                : Color.znNavy
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                    .disabled(venueName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
        }
    }

    private var quickTimesForType: [String] {
        switch slotType {
        case .lunch:
            return ["11:00", "11:30", "12:00", "12:30"]
        case .dinner:
            return ["17:30", "18:00", "18:30", "19:00"]
        case .activity:
            return ["09:30", "10:00", "14:00", "14:30"]
        case .homeActivity:
            return ["09:00", "10:00", "11:00", "14:00"]
        }
    }

    private let neighbourhoods = [
        "Kreis 1", "Kreis 2", "Kreis 3", "Kreis 4", "Kreis 5",
        "Kreis 6", "Kreis 7", "Kreis 8", "Seefeld", "Wiedikon",
        "Oerlikon", "Altstetten"
    ]
}
