import EventKit
import CoreLocation

struct DetectedTrip: Equatable, Identifiable {
    let id: String
    let calendarEvent: EKEvent?
    let locality: String
    let coordinate: CLLocationCoordinate2D
    let startTime: Date?
    let endTime: Date?
    let eventTitle: String

    static func == (lhs: DetectedTrip, rhs: DetectedTrip) -> Bool {
        lhs.id == rhs.id
    }

    static func synthetic(locality: String, coordinate: CLLocationCoordinate2D) -> DetectedTrip {
        DetectedTrip(
            id: "synthetic-\(locality.lowercased())",
            calendarEvent: nil,
            locality: locality,
            coordinate: coordinate,
            startTime: nil,
            endTime: nil,
            eventTitle: locality
        )
    }
}

actor TripDetector {
    static let shared = TripDetector()

    private var geocodeCache: [String: String] = [:]

    func detectTrips(
        for date: Date,
        homeCity: City,
        calendarEvents: [EKEvent]
    ) async -> [DetectedTrip] {
        let eventsWithLocation = calendarEvents.filter { event in
            event.structuredLocation?.geoLocation != nil
        }

        var trips: [DetectedTrip] = []

        for event in eventsWithLocation {
            guard let geoLocation = event.structuredLocation?.geoLocation else { continue }
            let coord = geoLocation.coordinate

            let distanceKm = TravelEstimate.haversine(
                lat1: homeCity.coordinate.latitude,
                lon1: homeCity.coordinate.longitude,
                lat2: coord.latitude,
                lon2: coord.longitude
            ) / 1000.0

            guard distanceKm > 5.0 else { continue }

            guard let locality = await reverseGeocode(coordinate: coord) else { continue }

            let homeName = homeCity.displayName.lowercased()
            guard locality.lowercased() != homeName else { continue }

            let isCurated = City.allCases.contains { city in
                city.displayName.lowercased() == locality.lowercased() ||
                city.displayNameDE.lowercased() == locality.lowercased()
            }
            guard !isCurated else { continue }

            trips.append(DetectedTrip(
                id: event.calendarItemExternalIdentifier,
                calendarEvent: event,
                locality: locality,
                coordinate: coord,
                startTime: event.startDate,
                endTime: event.endDate,
                eventTitle: event.title ?? locality
            ))
        }

        var seen: Set<String> = []
        return trips.filter { trip in
            let key = trip.locality.lowercased()
            if seen.contains(key) { return false }
            seen.insert(key)
            return true
        }
    }

    private func reverseGeocode(coordinate: CLLocationCoordinate2D) async -> String? {
        let cacheKey = "\(String(format: "%.3f", coordinate.latitude))-\(String(format: "%.3f", coordinate.longitude))"

        if let cached = geocodeCache[cacheKey] {
            return cached
        }

        // Retry up to 3 times with short delays (CLGeocoder can be flaky)
        for attempt in 0..<3 {
            if attempt > 0 {
                try? await Task.sleep(for: .milliseconds(500))
            }

            let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            do {
                let geocoder = CLGeocoder() // fresh instance per attempt
                let placemarks = try await geocoder.reverseGeocodeLocation(location)
                if let locality = placemarks.first?.locality {
                    geocodeCache[cacheKey] = locality
                    return locality
                }
            } catch {
                continue
            }
        }
        return nil
    }

    func prefetchTrips(
        dates: [Date],
        homeCity: City,
        calendarService: CalendarService
    ) async -> [String: [DetectedTrip]] {
        var result: [String: [DetectedTrip]] = [:]
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]

        for date in dates {
            let events = calendarService.fetchEvents(for: date)
            let trips = await detectTrips(for: date, homeCity: homeCity, calendarEvents: events)
            if !trips.isEmpty {
                result[formatter.string(from: date)] = trips
            }
        }
        return result
    }
}
