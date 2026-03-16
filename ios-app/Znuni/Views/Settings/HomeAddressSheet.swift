import SwiftUI
import MapKit

/// Sheet for searching and selecting a home address using MapKit autocomplete.
struct HomeAddressSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""
    @State private var completer = AddressCompleter()
    @State private var isResolving = false

    var body: some View {
        NavigationStack {
            List {
                if completer.results.isEmpty && !searchText.isEmpty {
                    Text(appState.localized(
                        en: "No results found",
                        de: "Keine Ergebnisse gefunden"
                    ))
                    .font(.system(size: 13))
                    .foregroundStyle(.znMuted)
                } else {
                    ForEach(completer.results, id: \.self) { completion in
                        Button {
                            selectCompletion(completion)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(completion.title)
                                    .font(.system(size: 15))
                                    .foregroundStyle(.znInk)
                                if !completion.subtitle.isEmpty {
                                    Text(completion.subtitle)
                                        .font(.system(size: 12))
                                        .foregroundStyle(.znMuted)
                                }
                            }
                        }
                        .disabled(isResolving)
                    }
                }
            }
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: appState.localized(en: "Search address…", de: "Adresse suchen…")
            )
            .onChange(of: searchText) { _, query in
                completer.update(query: query)
            }
            .navigationTitle(appState.localized(en: "Home Address", de: "Heimadresse"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(appState.localized(en: "Cancel", de: "Abbrechen")) {
                        dismiss()
                    }
                }
            }
            .overlay {
                if isResolving {
                    ProgressView()
                }
            }
        }
    }

    private func selectCompletion(_ completion: MKLocalSearchCompletion) {
        isResolving = true
        let request = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            isResolving = false
            guard let item = response?.mapItems.first,
                  let location = item.placemark.location else { return }

            let displayName: String
            if let name = item.placemark.name {
                displayName = name
            } else {
                displayName = completion.title
            }

            appState.setHomeAddress(
                name: displayName,
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude
            )
            dismiss()
        }
    }
}

// MARK: - Address Completer

/// Wraps MKLocalSearchCompleter for address-only autocomplete.
@Observable
final class AddressCompleter: NSObject, MKLocalSearchCompleterDelegate {
    var results: [MKLocalSearchCompletion] = []

    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = .address
        // Focus on Switzerland region
        completer.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 47.37, longitude: 8.54),
            latitudinalMeters: 300_000,
            longitudinalMeters: 300_000
        )
    }

    func update(query: String) {
        guard !query.isEmpty else {
            results = []
            return
        }
        completer.queryFragment = query
    }

    // MARK: - MKLocalSearchCompleterDelegate

    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        Task { @MainActor in
            self.results = completer.results
        }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        // Silently ignore — results stay empty
    }
}
