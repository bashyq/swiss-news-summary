// ios-app/Znuni/Services/POISearchService.swift
import MapKit

enum POICategory: String, CaseIterable, Codable {
    case restaurant, cafe, playground, park, museum, bakery, lake

    var searchQuery: String {
        switch self {
        case .restaurant: return "restaurant"
        case .cafe: return "café"
        case .playground: return "playground"
        case .park: return "park"
        case .museum: return "museum"
        case .bakery: return "bakery"
        case .lake: return "lake beach"
        }
    }

    var pointOfInterestFilter: MKPointOfInterestFilter {
        switch self {
        case .restaurant: return MKPointOfInterestFilter(including: [.restaurant])
        case .cafe: return MKPointOfInterestFilter(including: [.cafe])
        case .playground, .lake: return MKPointOfInterestFilter(including: [.park])
        case .park: return MKPointOfInterestFilter(including: [.park, .nationalPark])
        case .museum: return MKPointOfInterestFilter(including: [.museum])
        case .bakery: return MKPointOfInterestFilter(including: [.bakery])
        }
    }
}

struct POIResult: Identifiable, Codable, Equatable {
    let id: String          // "name-lat3-lon3"
    let name: String
    let category: POICategory
    let latitude: Double
    let longitude: Double
    let url: String?
    let phoneNumber: String?

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    static func stableId(name: String, lat: Double, lon: Double) -> String {
        let n = name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return "\(n)-\(String(format: "%.3f", lat))-\(String(format: "%.3f", lon))"
    }
}

actor POISearchService {
    static let shared = POISearchService()

    private var cache: [String: (results: [POIResult], timestamp: Date)] = [:]
    private let cacheTTL: TimeInterval = 3600 // 1 hour

    func search(
        near coordinate: CLLocationCoordinate2D,
        radius: CLLocationDistance = 5000
    ) async -> [POIResult] {
        let cacheKey = "\(String(format: "%.2f", coordinate.latitude))-\(String(format: "%.2f", coordinate.longitude))-\(Int(radius))"

        if let cached = cache[cacheKey], Date().timeIntervalSince(cached.timestamp) < cacheTTL {
            return cached.results
        }

        let region = MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: radius * 2,
            longitudinalMeters: radius * 2
        )

        var results = await withTaskGroup(of: [POIResult].self) { group in
            for category in POICategory.allCases {
                group.addTask {
                    await self.searchCategory(category, in: region)
                }
            }
            var all: [POIResult] = []
            for await batch in group {
                all.append(contentsOf: batch)
            }
            return all
        }

        results = deduplicate(results, threshold: 50)
        results.sort { distanceFrom(coordinate, to: $0) < distanceFrom(coordinate, to: $1) }

        // Retry with wider radius if too few results
        if results.count < 5 && radius < 15000 {
            return await search(near: coordinate, radius: min(radius * 2, 15000))
        }

        cache[cacheKey] = (results, Date())
        return results
    }

    private func searchCategory(_ category: POICategory, in region: MKCoordinateRegion) async -> [POIResult] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = category.searchQuery
        request.region = region
        request.resultTypes = .pointOfInterest

        do {
            let search = MKLocalSearch(request: request)
            let response = try await search.start()
            return response.mapItems.compactMap { item in
                guard let name = item.name else { return nil }
                let lat = item.placemark.coordinate.latitude
                let lon = item.placemark.coordinate.longitude
                return POIResult(
                    id: POIResult.stableId(name: name, lat: lat, lon: lon),
                    name: name,
                    category: category,
                    latitude: lat,
                    longitude: lon,
                    url: item.url?.absoluteString,
                    phoneNumber: item.phoneNumber
                )
            }
        } catch {
            return []
        }
    }

    private func deduplicate(_ results: [POIResult], threshold: Double) -> [POIResult] {
        var unique: [POIResult] = []
        for result in results {
            let isDuplicate = unique.contains { existing in
                let dist = TravelEstimate.haversine(
                    lat1: existing.latitude, lon1: existing.longitude,
                    lat2: result.latitude, lon2: result.longitude
                )
                return dist < threshold && existing.name.lowercased() == result.name.lowercased()
            }
            if !isDuplicate {
                unique.append(result)
            }
        }
        return unique
    }

    private func distanceFrom(_ center: CLLocationCoordinate2D, to poi: POIResult) -> Double {
        TravelEstimate.haversine(
            lat1: center.latitude, lon1: center.longitude,
            lat2: poi.latitude, lon2: poi.longitude
        )
    }
}
