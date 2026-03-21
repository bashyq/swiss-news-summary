import Foundation
import TelemetryDeck

/// Lightweight wrapper around TelemetryDeck.
enum Analytics {
    static func initialize() {
        let config = TelemetryDeck.Config(appID: "E10CE9CC-BD37-4484-9845-054D7CD55CEA")
        TelemetryDeck.initialize(config: config)
    }

    static func signal(_ name: String, parameters: [String: String] = [:]) {
        TelemetryDeck.signal(name, parameters: parameters)
    }
}
