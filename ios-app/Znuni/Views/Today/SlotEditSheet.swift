import SwiftUI

/// Bottom sheet presented when user taps ··· on a slot card.
/// Content adapts based on slot source (AI-generated vs custom).
struct SlotEditSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    let slot: AgendaSlot
    let onEditTime: (String) -> Void
    let onReplaceWithCustom: () -> Void
    let onToggleLock: () -> Void
    let onRemove: () -> Void

    @State private var showTimeEditor = false
    @State private var selectedHour: Int
    @State private var selectedMinute: Int

    init(
        slot: AgendaSlot,
        onEditTime: @escaping (String) -> Void,
        onReplaceWithCustom: @escaping () -> Void,
        onToggleLock: @escaping () -> Void,
        onRemove: @escaping () -> Void
    ) {
        self.slot = slot
        self.onEditTime = onEditTime
        self.onReplaceWithCustom = onReplaceWithCustom
        self.onToggleLock = onToggleLock
        self.onRemove = onRemove

        // Parse time from slot
        let parts = slot.time.split(separator: ":").compactMap { Int($0) }
        _selectedHour = State(initialValue: parts.count >= 1 ? parts[0] : 10)
        _selectedMinute = State(initialValue: parts.count >= 2 ? parts[1] : 0)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Handle
            Capsule()
                .fill(Color.znBorder)
                .frame(width: 36, height: 4)
                .padding(.top, 8)
                .padding(.bottom, 16)

            // Header
            VStack(spacing: 4) {
                Text(slot.type.displayName)
                    .font(.znEyebrow)
                    .foregroundStyle(slot.accentColor)

                Text(slot.venueName)
                    .font(.custom("Playfair", size: 17, relativeTo: .body).weight(.semibold))
                    .foregroundStyle(.znInk)

                Text(slot.time)
                    .font(.znMono)
                    .foregroundStyle(.znMuted)
            }
            .padding(.bottom, 20)

            Divider().overlay(Color.znInnerDivider)

            // Options
            VStack(spacing: 0) {
                if showTimeEditor {
                    timeEditorView
                } else {
                    optionsList
                }
            }
            .padding(.top, 8)

            Spacer(minLength: 16)
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Options List

    @ViewBuilder
    private var optionsList: some View {
        VStack(spacing: 2) {
            // Edit time — available for all slots
            optionRow(
                icon: "clock",
                label: appState.localized(en: "Edit time", de: "Zeit ändern"),
                color: .znNavy
            ) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showTimeEditor = true
                }
            }

            // Replace with custom — only for lunch and dinner slots, not for custom/anchor
            if (slot.type == .lunch || slot.type == .dinner),
               slot.source != .userCustom, slot.source != .userAnchor {
                optionRow(
                    icon: "pencil.line",
                    label: appState.localized(en: "Replace with my own", de: "Eigenen Vorschlag"),
                    color: .znNavy
                ) {
                    dismiss()
                    onReplaceWithCustom()
                }
            }

            // Edit — for custom slots, re-open form
            if slot.source == .userCustom {
                optionRow(
                    icon: "pencil",
                    label: appState.localized(en: "Edit", de: "Bearbeiten"),
                    color: .znNavy
                ) {
                    dismiss()
                    onReplaceWithCustom()
                }
            }

            // Lock/Unlock — not for anchors (always locked)
            if slot.source != .userAnchor {
                optionRow(
                    icon: slot.isLocked ? "lock.open" : "lock",
                    label: slot.isLocked
                        ? appState.localized(en: "Unlock slot", de: "Entsperren")
                        : appState.localized(en: "Lock this slot", de: "Slot sperren"),
                    color: .znNavy
                ) {
                    onToggleLock()
                    dismiss()
                }
            }

            Divider()
                .overlay(Color.znInnerDivider)
                .padding(.vertical, 4)

            // Remove
            optionRow(
                icon: "trash",
                label: appState.localized(en: "Remove slot", de: "Slot entfernen"),
                color: .znNegative
            ) {
                onRemove()
                dismiss()
            }
        }
    }

    // MARK: - Time Editor

    private var timeEditorView: some View {
        VStack(spacing: 16) {
            Text(appState.localized(en: "Choose a time", de: "Zeit wählen"))
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.znInk)

            // Quick time buttons based on slot type
            let quickTimes = quickTimesForSlot
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(quickTimes, id: \.self) { time in
                    let selected = time == String(format: "%02d:%02d", selectedHour, selectedMinute)
                    Button {
                        let parts = time.split(separator: ":").compactMap { Int($0) }
                        if parts.count == 2 {
                            selectedHour = parts[0]
                            selectedMinute = parts[1]
                        }
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

            // Save button
            Button {
                let timeStr = String(format: "%02d:%02d", selectedHour, selectedMinute)
                onEditTime(timeStr)
                dismiss()
            } label: {
                Text(appState.localized(en: "Save time", de: "Zeit speichern"))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(Color.znNavy)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)

            // Back
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showTimeEditor = false
                }
            } label: {
                Text(appState.localized(en: "Back", de: "Zurück"))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.znMuted)
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 8)
    }

    private var quickTimesForSlot: [String] {
        switch slot.type {
        case .activity:
            if slot.id == "morning" {
                return ["09:00", "09:30", "10:00", "10:30"]
            } else {
                return ["13:30", "14:00", "14:30", "15:00"]
            }
        case .lunch:
            return ["11:00", "11:30", "12:00", "12:30"]
        case .dinner:
            return ["17:30", "18:00", "18:30", "19:00"]
        case .homeActivity:
            return ["09:00", "10:00", "11:00", "14:00"]
        }
    }

    // MARK: - Option Row

    private func optionRow(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundStyle(color)
                    .frame(width: 24)

                Text(label)
                    .font(.system(size: 15))
                    .foregroundStyle(color)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.znChevron)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 14)
            .background(Color.znSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}
