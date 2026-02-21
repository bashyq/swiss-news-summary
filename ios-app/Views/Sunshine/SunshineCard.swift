import SwiftUI
import MapKit
import CoreLocation

/// Expandable card for a sunshine destination.
///
/// Collapsed state shows name, region, total sunshine hours, drive time badge, optional distance badge,
/// and a weather icon for the best day. Baseline destinations (Zurich) get a purple accent border.
/// Tapping expands an accordion with daily forecasts, hourly timeline, destination highlights,
/// and action buttons for directions and nearby places.
struct SunshineCard: View {
    let destination: SunshineDestination
    let language: AppLanguage
    let isExpanded: Bool
    let userLocation: CLLocation?
    var highlightID: String?
    let onTap: () -> Void

    private var isBaseline: Bool {
        destination.isBaseline == true
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            collapsedContent
            if isExpanded {
                Divider()
                    .padding(.horizontal, 14)
                expandedContent
            }
        }
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isBaseline ? Color.purple.opacity(0.5) : .clear, lineWidth: isBaseline ? 2 : 0)
        )
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
    }

    // MARK: - Card Background

    private var cardBackground: some View {
        Group {
            if isBaseline {
                Color.purple.opacity(0.06)
            } else {
                Color(.secondarySystemGroupedBackground)
            }
        }
    }

    // MARK: - Collapsed Content

    private var collapsedContent: some View {
        HStack(spacing: 12) {
            // Weather icon for best day
            bestDayIcon
                .frame(width: 36, height: 36)

            // Name and region
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    if isBaseline {
                        Image(systemName: "house.fill")
                            .font(.caption2)
                            .foregroundStyle(.purple)
                    }
                    Text(destination.localizedName(language: language))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                }
                Text(destination.localizedRegion(language: language))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Sunshine hours total
            sunshineHoursLabel

            // Badges
            VStack(alignment: .trailing, spacing: 4) {
                DriveTimeBadge(minutes: destination.driveMinutes)
                if let distance = distanceMeters {
                    DistanceBadge(meters: distance)
                }
            }

            // Chevron
            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(14)
    }

    // MARK: - Sunshine Hours Label

    private var sunshineHoursLabel: some View {
        VStack(spacing: 1) {
            Text(String(format: "%.1f", destination.sunshineHoursTotal))
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(Color.sunshineColor(hours: destination.sunshineHoursTotal))
            Text(language == .de ? "Std" : "hrs")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Best Day Icon

    private var bestDayIcon: some View {
        Group {
            if let bestDay = destination.forecast.max(by: { $0.sunshineHours < $1.sunshineHours }) {
                Image(systemName: bestDay.sfSymbol)
                    .font(.title2)
                    .foregroundStyle(Color.sunshineColor(hours: destination.sunshineHoursTotal))
                    .symbolRenderingMode(.multicolor)
            } else {
                Image(systemName: "sun.max.fill")
                    .font(.title2)
                    .foregroundStyle(.gray)
            }
        }
    }

    // MARK: - Expanded Content

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Daily forecast rows
            dailyForecastSection

            // Hourly timeline for the best day
            hourlyTimelineSection

            // Destination highlights
            highlightsSection

            // Action buttons
            actionButtons
        }
        .padding(14)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: - Daily Forecast

    private var dailyForecastSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(language == .de ? "Wochenendprognose" : "Weekend Forecast")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            ForEach(destination.forecast) { day in
                dailyForecastRow(day)
            }
        }
    }

    private func dailyForecastRow(_ day: SunshineDayForecast) -> some View {
        HStack(spacing: 8) {
            // Day name
            Text(dayName(for: day.date))
                .font(.caption)
                .fontWeight(.medium)
                .frame(width: 36, alignment: .leading)

            // Weather icon
            Image(systemName: day.sfSymbol)
                .font(.caption)
                .symbolRenderingMode(.multicolor)
                .frame(width: 20)

            // Temperature range
            Text("\(Int(day.tempMin))° / \(Int(day.tempMax))°")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 60, alignment: .leading)

            // Sunshine hours bar
            GeometryReader { geo in
                let maxWidth = geo.size.width
                let barWidth = maxWidth * CGFloat(min(day.sunshineHours, 14)) / 14.0

                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(.systemGray5))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.sunshineColor(hours: day.sunshineHours))
                        .frame(width: max(barWidth, 0), height: 6)
                }
            }
            .frame(height: 6)

            // Hours label
            Text(String(format: "%.1fh", day.sunshineHours))
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundStyle(Color.sunshineColor(hours: day.sunshineHours))
                .frame(width: 32, alignment: .trailing)
        }
    }

    // MARK: - Hourly Timeline

    @ViewBuilder
    private var hourlyTimelineSection: some View {
        // Show timeline for the day with the most sunshine data
        if let bestDay = destination.forecast.max(by: { $0.sunshineHours < $1.sunshineHours }),
           let sunnyHours = bestDay.sunnyHours, !sunnyHours.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Text(language == .de ? "Sonnenstunden" : "Sunny Hours")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    Text("(\(dayName(for: bestDay.date)))")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                HourlyTimelineView(sunnyHours: sunnyHours)
            }
        }
    }

    // MARK: - Highlights

    @ViewBuilder
    private var highlightsSection: some View {
        let highlights = DestinationHighlights.forDestination(destination.id)
        if !highlights.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(language == .de ? "Highlights" : "Things to do")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                ForEach(highlights) { highlight in
                    highlightRow(highlight)
                }
            }
        }
    }

    private func highlightRow(_ highlight: DestinationHighlight) -> some View {
        HStack(spacing: 10) {
            Image(systemName: highlight.sfSymbol)
                .font(.caption)
                .foregroundStyle(.purple)
                .frame(width: 20, height: 20)

            VStack(alignment: .leading, spacing: 1) {
                Text(highlight.localizedName(language: language))
                    .font(.caption)
                    .fontWeight(.medium)
                Text(highlight.localizedDescription(language: language))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            // Directions button
            Button {
                openDirections(to: highlight.coordinate, name: highlight.localizedName(language: language))
            } label: {
                Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                    .font(.caption)
                    .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 8) {
            // Get directions button
            Button {
                openDirections(to: destination.coordinate, name: destination.localizedName(language: language))
            } label: {
                Label(
                    language == .de ? "Route anzeigen" : "Get directions",
                    systemImage: "car.fill"
                )
                .font(.subheadline)
                .fontWeight(.medium)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.purple.opacity(0.12))
                .foregroundStyle(.purple)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)

            // Find playgrounds / restaurants
            HStack(spacing: 8) {
                Button {
                    searchNearby(query: "playground", coordinate: destination.coordinate)
                } label: {
                    Label(
                        language == .de ? "Spielplätze" : "Find playgrounds",
                        systemImage: "figure.play"
                    )
                    .font(.caption)
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .foregroundStyle(.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)

                Button {
                    searchNearby(query: "restaurant", coordinate: destination.coordinate)
                } label: {
                    Label(
                        language == .de ? "Restaurants" : "Find restaurants",
                        systemImage: "fork.knife"
                    )
                    .font(.caption)
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .foregroundStyle(.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Helpers

    private var distanceMeters: Double? {
        guard let location = userLocation else { return nil }
        return destination.distance(from: location)
    }

    private func dayName(for dateString: String) -> String {
        guard let date = DateHelpers.parseISO(dateString) else { return dateString }
        return DateHelpers.shortDayName(date)
    }

    private func openDirections(to coordinate: CLLocationCoordinate2D, name: String) {
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = name
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }

    private func searchNearby(query: String, coordinate: CLLocationCoordinate2D) {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let urlString = "maps://?q=\(encodedQuery)&sll=\(coordinate.latitude),\(coordinate.longitude)&z=14"
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Destination Highlights Data

/// Static data provider for curated toddler-friendly attractions per sunshine destination.
/// Mirrors the DEST_HIGHLIGHTS data from the web app's app.js.
enum DestinationHighlights {
    /// Returns curated highlights for a given destination ID.
    static func forDestination(_ id: String) -> [DestinationHighlight] {
        allHighlights[id] ?? []
    }

    private static let allHighlights: [String: [DestinationHighlight]] = [
        "lugano": [
            DestinationHighlight(
                name: "Parco Ciani",
                nameDE: "Parco Ciani",
                type: "nature",
                description: "Beautiful lakeside park with playground and ducks",
                descriptionDE: "Wunderschöner Park am See mit Spielplatz und Enten",
                lat: 46.0028, lon: 8.9530
            ),
            DestinationHighlight(
                name: "Lido di Lugano",
                nameDE: "Lido di Lugano",
                type: "playground",
                description: "Beach with shallow kids pool and sandy play area",
                descriptionDE: "Strand mit flachem Kinderbecken und Sandspielbereich",
                lat: 46.0060, lon: 8.9595
            ),
            DestinationHighlight(
                name: "Swiss Miniatur",
                nameDE: "Swissminiatur",
                type: "museum",
                description: "Miniature Switzerland park — trains, buildings, landscapes",
                descriptionDE: "Miniaturschweiz-Park — Züge, Gebäude, Landschaften",
                lat: 45.9499, lon: 8.9462
            )
        ],
        "locarno": [
            DestinationHighlight(
                name: "Piazza Grande",
                nameDE: "Piazza Grande",
                type: "playground",
                description: "Main square with gelato shops and fountain for splashing",
                descriptionDE: "Hauptplatz mit Glacé-Läden und Brunnen zum Planschen",
                lat: 46.1707, lon: 8.7952
            ),
            DestinationHighlight(
                name: "Lido Locarno",
                nameDE: "Lido Locarno",
                type: "playground",
                description: "Lake beach with toddler-friendly shallow areas",
                descriptionDE: "Seestrand mit kinderfreundlichen Flachwasserbereichen",
                lat: 46.1678, lon: 8.8010
            )
        ],
        "ascona": [
            DestinationHighlight(
                name: "Lungolago Promenade",
                nameDE: "Lungolago-Promenade",
                type: "nature",
                description: "Scenic lakefront walk with playgrounds and cafes",
                descriptionDE: "Malerischer Seeuferweg mit Spielplätzen und Cafés",
                lat: 46.1574, lon: 8.7728
            ),
            DestinationHighlight(
                name: "Lido Ascona",
                nameDE: "Lido Ascona",
                type: "playground",
                description: "Family-friendly beach with warm shallow waters",
                descriptionDE: "Familienfreundlicher Strand mit warmem Flachwasser",
                lat: 46.1555, lon: 8.7758
            )
        ],
        "bellinzona": [
            DestinationHighlight(
                name: "Castelgrande",
                nameDE: "Castelgrande",
                type: "museum",
                description: "UNESCO castle with grassy courtyard for kids to explore",
                descriptionDE: "UNESCO-Burg mit Rasenhof zum Erkunden für Kinder",
                lat: 46.1952, lon: 9.0208
            ),
            DestinationHighlight(
                name: "Parco Urbano",
                nameDE: "Parco Urbano",
                type: "playground",
                description: "City park with modern playground equipment",
                descriptionDE: "Stadtpark mit modernen Spielgeräten",
                lat: 46.1928, lon: 9.0240
            )
        ],
        "interlaken": [
            DestinationHighlight(
                name: "Höhematte Park",
                nameDE: "Höhematte Park",
                type: "nature",
                description: "Large open meadow with mountain views and playground",
                descriptionDE: "Grosse offene Wiese mit Bergblick und Spielplatz",
                lat: 46.6858, lon: 7.8593
            ),
            DestinationHighlight(
                name: "Schifffahrt Brienzersee",
                nameDE: "Schifffahrt Brienzersee",
                type: "nature",
                description: "Scenic boat ride on turquoise Lake Brienz",
                descriptionDE: "Malerische Bootsfahrt auf dem türkisfarbenen Brienzersee",
                lat: 46.6949, lon: 7.8814
            )
        ],
        "thun": [
            DestinationHighlight(
                name: "Schloss Thun",
                nameDE: "Schloss Thun",
                type: "museum",
                description: "Medieval castle with panoramic views and knight exhibits",
                descriptionDE: "Mittelalterliche Burg mit Panoramablick und Ritterausstellung",
                lat: 46.7576, lon: 7.6281
            ),
            DestinationHighlight(
                name: "Strandbad Thun",
                nameDE: "Strandbad Thun",
                type: "playground",
                description: "Lake beach with toddler pool and large playground",
                descriptionDE: "Seestrand mit Kleinkinderbecken und grossem Spielplatz",
                lat: 46.7535, lon: 7.6170
            )
        ],
        "montreux": [
            DestinationHighlight(
                name: "Château de Chillon",
                nameDE: "Schloss Chillon",
                type: "museum",
                description: "Fairy-tale castle on the lake with kid-friendly audioguide",
                descriptionDE: "Märchenschloss am See mit kinderfreundlichem Audioguide",
                lat: 46.4143, lon: 6.9274
            ),
            DestinationHighlight(
                name: "Lakeside Promenade",
                nameDE: "Seeuferpromenade",
                type: "nature",
                description: "Flat promenade with flower gardens and duck feeding spots",
                descriptionDE: "Flache Promenade mit Blumengärten und Enten füttern",
                lat: 46.4312, lon: 6.9107
            )
        ],
        "sion": [
            DestinationHighlight(
                name: "Valère Castle",
                nameDE: "Basilika von Valère",
                type: "museum",
                description: "Hilltop castle-church with views of Rhône valley",
                descriptionDE: "Burgkirche auf dem Hügel mit Blick auf das Rhonetal",
                lat: 46.2316, lon: 7.3667
            ),
            DestinationHighlight(
                name: "Parc de Tourbillon",
                nameDE: "Parc de Tourbillon",
                type: "nature",
                description: "Castle hill park with hiking paths for little explorers",
                descriptionDE: "Burghügelpark mit Wanderwegen für kleine Entdecker",
                lat: 46.2333, lon: 7.3581
            )
        ],
        "davos": [
            DestinationHighlight(
                name: "Schatzalp",
                nameDE: "Schatzalp",
                type: "nature",
                description: "Mountain garden with sledding paths and alpine playground",
                descriptionDE: "Berggarten mit Schlittenwegen und alpinem Spielplatz",
                lat: 46.8063, lon: 9.8280
            ),
            DestinationHighlight(
                name: "Davos Lake",
                nameDE: "Davosersee",
                type: "nature",
                description: "Easy lakeside walk with picnic spots and paddle boats",
                descriptionDE: "Einfacher Seeweg mit Picknickplätzen und Tretbooten",
                lat: 46.7790, lon: 9.8520
            )
        ],
        "chur": [
            DestinationHighlight(
                name: "Brambrüesch",
                nameDE: "Brambrüesch",
                type: "nature",
                description: "Family mountain with cable car from city center and playground",
                descriptionDE: "Familienberg mit Seilbahn ab Stadtzentrum und Spielplatz",
                lat: 46.8429, lon: 9.4984
            ),
            DestinationHighlight(
                name: "Altstadt Chur",
                nameDE: "Altstadt Chur",
                type: "nature",
                description: "Oldest Swiss town center with fountains and narrow lanes",
                descriptionDE: "Ältestes Schweizer Stadtzentrum mit Brunnen und engen Gassen",
                lat: 46.8508, lon: 9.5315
            )
        ],
        "como": [
            DestinationHighlight(
                name: "Giardini a Lago",
                nameDE: "Giardini a Lago",
                type: "nature",
                description: "Lakefront gardens with playground and gelato nearby",
                descriptionDE: "Seegärten mit Spielplatz und Glacé in der Nähe",
                lat: 45.8114, lon: 9.0820
            ),
            DestinationHighlight(
                name: "Funicolare Como-Brunate",
                nameDE: "Standseilbahn Como-Brunate",
                type: "nature",
                description: "Short funicular ride to hilltop village with panoramic views",
                descriptionDE: "Kurze Standseilbahnfahrt zum Hügeldorf mit Panoramablick",
                lat: 45.8143, lon: 9.0870
            )
        ],
        "stgallen": [
            DestinationHighlight(
                name: "Wildpark Peter und Paul",
                nameDE: "Wildpark Peter und Paul",
                type: "nature",
                description: "Free wildlife park with ibex, deer, and playground",
                descriptionDE: "Kostenloser Wildpark mit Steinböcken, Rehen und Spielplatz",
                lat: 47.4343, lon: 9.3898
            ),
            DestinationHighlight(
                name: "Stiftsbibliothek",
                nameDE: "Stiftsbibliothek",
                type: "museum",
                description: "UNESCO Abbey library — the baroque hall amazes even toddlers",
                descriptionDE: "UNESCO-Stiftsbibliothek — der Barocksaal beeindruckt auch Kleinkinder",
                lat: 47.4235, lon: 9.3770
            )
        ],
        "luzern": [
            DestinationHighlight(
                name: "Verkehrshaus",
                nameDE: "Verkehrshaus der Schweiz",
                type: "museum",
                description: "Swiss transport museum with trains, planes, and hands-on exhibits",
                descriptionDE: "Schweizer Verkehrsmuseum mit Zügen, Flugzeugen und Mitmach-Ausstellungen",
                lat: 47.0536, lon: 8.3355
            ),
            DestinationHighlight(
                name: "Ufschötti Park",
                nameDE: "Ufschötti-Park",
                type: "playground",
                description: "Lakeside park with large playground and paddling area",
                descriptionDE: "Seeuferpark mit grossem Spielplatz und Planschbecken",
                lat: 47.0442, lon: 8.3074
            )
        ],
        "basel": [
            DestinationHighlight(
                name: "Basel Zoo",
                nameDE: "Zoo Basel (Zolli)",
                type: "nature",
                description: "Oldest Swiss zoo with aquarium and petting area",
                descriptionDE: "Ältester Schweizer Zoo mit Aquarium und Streichelzoo",
                lat: 47.5472, lon: 7.5788
            ),
            DestinationHighlight(
                name: "Rhine Promenade",
                nameDE: "Rheinuferpromenade",
                type: "nature",
                description: "Walk along the Rhine with ferry crossings and splash spots",
                descriptionDE: "Spaziergang am Rhein mit Fähren und Planschstellen",
                lat: 47.5600, lon: 7.5925
            )
        ],
        "lausanne": [
            DestinationHighlight(
                name: "Olympic Museum",
                nameDE: "Olympisches Museum",
                type: "museum",
                description: "Interactive sports museum with garden playground",
                descriptionDE: "Interaktives Sportmuseum mit Gartenspielplatz",
                lat: 46.5082, lon: 6.6340
            ),
            DestinationHighlight(
                name: "Parc de Mon-Repos",
                nameDE: "Parc de Mon-Repos",
                type: "playground",
                description: "Shaded park with aviary, playground, and mini train",
                descriptionDE: "Schattiger Park mit Voliere, Spielplatz und Minizug",
                lat: 46.5247, lon: 6.6360
            )
        ]
    ]
}

#Preview {
    let sampleDest = SunshineDestination(
        id: "lugano",
        name: "Lugano",
        nameDE: "Lugano",
        lat: 46.0037,
        lon: 8.9511,
        region: "Ticino",
        regionDE: "Tessin",
        driveMinutes: 150,
        forecast: [
            SunshineDayForecast(
                date: "2026-02-20",
                weatherCode: 1,
                tempMax: 12,
                tempMin: 3,
                sunshineHours: 7.2,
                precipMm: 0,
                sunnyHours: [8, 9, 10, 11, 12, 13, 14, 15, 16],
                description: SunshineDescription(en: "Mainly sunny", de: "Überwiegend sonnig")
            ),
            SunshineDayForecast(
                date: "2026-02-21",
                weatherCode: 2,
                tempMax: 10,
                tempMin: 2,
                sunshineHours: 5.5,
                precipMm: 0.2,
                sunnyHours: [9, 10, 11, 12, 13, 14],
                description: SunshineDescription(en: "Partly sunny", de: "Teilweise sonnig")
            ),
            SunshineDayForecast(
                date: "2026-02-22",
                weatherCode: 3,
                tempMax: 8,
                tempMin: 1,
                sunshineHours: 3.0,
                precipMm: 1.0,
                sunnyHours: [10, 11, 12],
                description: SunshineDescription(en: "Cloudy", de: "Bewölkt")
            )
        ],
        sunshineHoursTotal: 15.7,
        isBaseline: false
    )

    VStack {
        SunshineCard(
            destination: sampleDest,
            language: .en,
            isExpanded: true,
            userLocation: nil,
            onTap: {}
        )
    }
    .padding()
}
