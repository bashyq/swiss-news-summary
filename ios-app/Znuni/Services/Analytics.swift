import Foundation
#if canImport(TelemetryDeck)
import TelemetryDeck
#endif

/// Lightweight wrapper around TelemetryDeck.
/// Compiles and logs to console even when the SPM package is not yet added.
enum Analytics {
    static func initialize() {
        #if canImport(TelemetryDeck)
        let config = TelemetryDeck.Config(appID: "YOUR-APP-ID")
        TelemetryDeck.initialize(config: config)
        #else
        print("[Analytics] TelemetryDeck not available - add SPM package")
        #endif
    }

    static func signal(_ name: String, parameters: [String: String] = [:]) {
        #if canImport(TelemetryDeck)
        TelemetryDeck.signal(name, parameters: parameters)
        #else
        #if DEBUG
        print("[Analytics] \(name) \(parameters)")
        #endif
        #endif
    }
}
