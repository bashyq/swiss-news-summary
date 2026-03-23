import SwiftUI
import CoreLocation

/// Form sheet for replacing an AI-generated slot with a user's own entry.
/// Presented when user taps "Replace with my own" from the slot context menu.
struct CustomSlotSheet: View {
    let replacingSlot: AgendaSlot
    var onSave: (String, Date, Date, String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var address = ""

    init(replacingSlot: AgendaSlot, onSave: @escaping (String, Date, Date, String?) -> Void) {
        self.replacingSlot = replacingSlot
        self.onSave = onSave
        _startTime = State(initialValue: replacingSlot.slotDate)
        _endTime = State(initialValue: replacingSlot.slotDate.addingTimeInterval(TimeInterval((replacingSlot.durationMinutes ?? 60) * 60)))
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && endTime > startTime
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Venue") {
                    TextField("Name", text: $name)
                    TextField("Address (optional)", text: $address)
                }
                Section("Time") {
                    DatePicker("Start", selection: $startTime, displayedComponents: .hourAndMinute)
                    DatePicker("End", selection: $endTime, displayedComponents: .hourAndMinute)
                }
            }
            .navigationTitle("Replace slot")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(name, startTime, endTime, address.isEmpty ? nil : address)
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }
}
