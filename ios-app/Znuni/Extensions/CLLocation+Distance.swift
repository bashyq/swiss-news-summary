import CoreLocation

/// Travel estimate between two locations with mode-aware timing.
struct TravelEstimate {
    enum Mode {
        case walk    // Under ~2 km — walking pace
        case transit // Over ~2 km — public transport estimate
    }

    let minutes: Int
    let mode: Mode

    /// Straight-line distance threshold: walk under 2 km, transit above.
    private static let walkThresholdMeters: Double = 2000

    /// Estimate travel between two locations.
    /// - Walk: ~5 km/h (83 m/min) with 1.3× detour factor
    /// - Transit: ~15 km/h average (includes walk to stop, waiting, stops, transfers)
    ///   This is realistic for Zürich ZVV urban transit.
    static func estimate(from origin: CLLocation, to destination: CLLocation) -> TravelEstimate {
        let meters = origin.distance(from: destination)

        if meters <= walkThresholdMeters {
            let walkMin = Int(ceil(meters * 1.3 / 83.0))
            return TravelEstimate(minutes: max(walkMin, 2), mode: .walk)
        } else {
            // Transit: 15 km/h = 250 m/min + 5 min base (walk to stop + wait)
            let transitMin = 5 + Int(ceil(meters / 250.0))
            return TravelEstimate(minutes: max(transitMin, 8), mode: .transit)
        }
    }
}

extension CLLocation {
    /// Format distance for display (e.g., "1.2 km" or "350 m")
    static func formattedDistance(_ meters: Double) -> String {
        if meters >= 1000 {
            return String(format: "%.1f km", meters / 1000)
        } else {
            return String(format: "%.0f m", meters)
        }
    }

    /// Format drive time for display (e.g., "2h 30min" or "45 min")
    static func formattedDriveTime(_ minutes: Int) -> String {
        if minutes >= 60 {
            let hours = minutes / 60
            let mins = minutes % 60
            if mins == 0 {
                return "\(hours)h"
            }
            return "\(hours)h \(mins)min"
        }
        return "\(minutes) min"
    }
}

extension CLLocationCoordinate2D: @retroactive Equatable {
    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}
