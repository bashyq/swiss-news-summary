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
    /// - Walk: 80 m/min with 1.3× detour factor (≈ 4 km/h)
    /// - Transit: straight-line × 1.4 detour / 25 km/h average speed + 5 min wait
    static func estimate(from origin: CLLocation, to destination: CLLocation) -> TravelEstimate {
        let meters = origin.distance(from: destination)

        if meters <= walkThresholdMeters {
            let walkMin = Int(ceil(meters * 1.3 / 80.0))
            return TravelEstimate(minutes: max(walkMin, 1), mode: .walk)
        } else {
            // Transit: detour factor × distance / urban transit speed + wait time
            let transitMin = Int(ceil(meters * 1.4 / (25_000.0 / 60.0))) + 5
            return TravelEstimate(minutes: max(transitMin, 5), mode: .transit)
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
