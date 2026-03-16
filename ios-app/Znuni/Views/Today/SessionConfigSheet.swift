import SwiftUI

/// Sheet for configuring the family session: solo/both parents, children names + ages.
struct SessionConfigSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    @State private var session: FamilySession
    let onSave: (FamilySession) -> Void

    init(session: FamilySession, onSave: @escaping (FamilySession) -> Void) {
        self._session = State(initialValue: session)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                // Parents section
                Section {
                    Toggle(isOn: $session.soloParent) {
                        Label {
                            Text(appState.localized(en: "Solo parent", de: "Allein mit Kind"))
                        } icon: {
                            Image(systemName: session.soloParent ? "person.fill" : "person.2.fill")
                                .foregroundStyle(Color.znNavy)
                        }
                    }
                    .tint(Color.znNavy)
                } header: {
                    Text(appState.localized(en: "Parents", de: "Eltern"))
                }

                // Children section
                Section {
                    ForEach($session.children) { $child in
                        HStack(spacing: 12) {
                            TextField(
                                appState.localized(en: "Name", de: "Name"),
                                text: $child.name
                            )
                            .textContentType(.givenName)

                            Divider()

                            Stepper(value: $child.age, in: 0...10) {
                                Text(appState.localized(
                                    en: "\(child.age) years",
                                    de: "\(child.age) Jahre"
                                ))
                                .font(.system(size: 14))
                                .foregroundStyle(Color.znBody)
                            }
                        }
                    }
                    .onDelete { offsets in
                        session.children.remove(atOffsets: offsets)
                    }

                    if session.children.count < 5 {
                        Button {
                            withAnimation {
                                session.children.append(
                                    FamilySession.Child(
                                        id: UUID(),
                                        name: "",
                                        age: 3
                                    )
                                )
                            }
                        } label: {
                            Label(
                                appState.localized(en: "Add child", de: "Kind hinzufügen"),
                                systemImage: "plus.circle.fill"
                            )
                            .foregroundStyle(Color.znNavy)
                        }
                    }
                } header: {
                    Text(appState.localized(en: "Children", de: "Kinder"))
                } footer: {
                    Text(appState.localized(
                        en: "Ages help us pick activities and plan the day.",
                        de: "Das Alter hilft uns, passende Aktivitäten auszuwählen."
                    ))
                }
            }
            .navigationTitle(appState.localized(en: "Family Setup", de: "Familie"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(appState.localized(en: "Cancel", de: "Abbrechen")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(appState.localized(en: "Done", de: "Fertig")) {
                        // Ensure at least one child
                        if session.children.isEmpty {
                            session.children = [
                                FamilySession.Child(id: UUID(), name: "Child", age: 3)
                            ]
                        }
                        // Fill in empty names
                        for i in session.children.indices {
                            if session.children[i].name.trimmingCharacters(in: .whitespaces).isEmpty {
                                session.children[i].name = "Child \(i + 1)"
                            }
                        }
                        onSave(session)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}
