import Foundation

// MARK: - SnowResorts
// All 22 ski resorts from the PWA's SNOW_DESTS array in app.js.
// Used for client-side Open-Meteo fallback when the worker is rate-limited.
// The SnowResortConfig struct is defined in APIClient.swift.

enum SnowResorts {
    static let all: [SnowResortConfig] = [
        // MARK: Valais
        SnowResortConfig(
            id: "zermatt",
            name: "Zermatt",
            nameDE: "Zermatt",
            lat: 46.0207,
            lon: 7.7491,
            region: "Valais",
            regionDE: "Wallis",
            driveMinutes: 195,
            altitude: 1620
        ),
        SnowResortConfig(
            id: "verbier",
            name: "Verbier",
            nameDE: "Verbier",
            lat: 46.0967,
            lon: 7.2286,
            region: "Valais",
            regionDE: "Wallis",
            driveMinutes: 170,
            altitude: 1500
        ),
        SnowResortConfig(
            id: "saas-fee",
            name: "Saas-Fee",
            nameDE: "Saas-Fee",
            lat: 46.1048,
            lon: 7.9329,
            region: "Valais",
            regionDE: "Wallis",
            driveMinutes: 185,
            altitude: 1800
        ),
        SnowResortConfig(
            id: "crans-montana",
            name: "Crans-Montana",
            nameDE: "Crans-Montana",
            lat: 46.3072,
            lon: 7.4816,
            region: "Valais",
            regionDE: "Wallis",
            driveMinutes: 175,
            altitude: 1500
        ),
        SnowResortConfig(
            id: "nendaz",
            name: "Nendaz",
            nameDE: "Nendaz",
            lat: 46.1871,
            lon: 7.3041,
            region: "Valais",
            regionDE: "Wallis",
            driveMinutes: 165,
            altitude: 1400
        ),

        // MARK: Graubünden
        SnowResortConfig(
            id: "davos",
            name: "Davos",
            nameDE: "Davos",
            lat: 46.8027,
            lon: 9.836,
            region: "Graubunden",
            regionDE: "Graubünden",
            driveMinutes: 115,
            altitude: 1560
        ),
        SnowResortConfig(
            id: "stmoritz",
            name: "St. Moritz",
            nameDE: "St. Moritz",
            lat: 46.4908,
            lon: 9.8355,
            region: "Graubunden",
            regionDE: "Graubünden",
            driveMinutes: 150,
            altitude: 1822
        ),
        SnowResortConfig(
            id: "laax",
            name: "Laax",
            nameDE: "Laax",
            lat: 46.8097,
            lon: 9.2579,
            region: "Graubunden",
            regionDE: "Graubünden",
            driveMinutes: 100,
            altitude: 1100
        ),
        SnowResortConfig(
            id: "arosa",
            name: "Arosa",
            nameDE: "Arosa",
            lat: 46.7832,
            lon: 9.678,
            region: "Graubunden",
            regionDE: "Graubünden",
            driveMinutes: 110,
            altitude: 1775
        ),
        SnowResortConfig(
            id: "lenzerheide",
            name: "Lenzerheide",
            nameDE: "Lenzerheide",
            lat: 46.7394,
            lon: 9.5584,
            region: "Graubunden",
            regionDE: "Graubünden",
            driveMinutes: 95,
            altitude: 1473
        ),
        SnowResortConfig(
            id: "klosters",
            name: "Klosters",
            nameDE: "Klosters",
            lat: 46.8683,
            lon: 9.8756,
            region: "Graubunden",
            regionDE: "Graubünden",
            driveMinutes: 110,
            altitude: 1191
        ),

        // MARK: Bernese Oberland
        SnowResortConfig(
            id: "grindelwald",
            name: "Grindelwald",
            nameDE: "Grindelwald",
            lat: 46.6244,
            lon: 8.0413,
            region: "Bernese Oberland",
            regionDE: "Berner Oberland",
            driveMinutes: 130,
            altitude: 1034
        ),
        SnowResortConfig(
            id: "wengen",
            name: "Wengen",
            nameDE: "Wengen",
            lat: 46.6082,
            lon: 7.9222,
            region: "Bernese Oberland",
            regionDE: "Berner Oberland",
            driveMinutes: 140,
            altitude: 1274
        ),
        SnowResortConfig(
            id: "adelboden",
            name: "Adelboden",
            nameDE: "Adelboden",
            lat: 46.4917,
            lon: 7.5611,
            region: "Bernese Oberland",
            regionDE: "Berner Oberland",
            driveMinutes: 125,
            altitude: 1353
        ),
        SnowResortConfig(
            id: "gstaad",
            name: "Gstaad",
            nameDE: "Gstaad",
            lat: 46.475,
            lon: 7.2861,
            region: "Bernese Oberland",
            regionDE: "Berner Oberland",
            driveMinutes: 145,
            altitude: 1050
        ),

        // MARK: Central Switzerland
        SnowResortConfig(
            id: "engelberg",
            name: "Engelberg",
            nameDE: "Engelberg",
            lat: 46.821,
            lon: 8.4013,
            region: "Central Switzerland",
            regionDE: "Zentralschweiz",
            driveMinutes: 65,
            altitude: 1000
        ),
        SnowResortConfig(
            id: "andermatt",
            name: "Andermatt",
            nameDE: "Andermatt",
            lat: 46.6343,
            lon: 8.5936,
            region: "Central Switzerland",
            regionDE: "Zentralschweiz",
            driveMinutes: 85,
            altitude: 1444
        ),
        SnowResortConfig(
            id: "stoos",
            name: "Stoos",
            nameDE: "Stoos",
            lat: 46.9767,
            lon: 8.6625,
            region: "Central Switzerland",
            regionDE: "Zentralschweiz",
            driveMinutes: 55,
            altitude: 1300
        ),
        SnowResortConfig(
            id: "hoch-ybrig",
            name: "Hoch-Ybrig",
            nameDE: "Hoch-Ybrig",
            lat: 47.031,
            lon: 8.789,
            region: "Central Switzerland",
            regionDE: "Zentralschweiz",
            driveMinutes: 50,
            altitude: 1100
        ),
        SnowResortConfig(
            id: "sattel-hochstuckli",
            name: "Sattel-Hochstuckli",
            nameDE: "Sattel-Hochstuckli",
            lat: 47.08,
            lon: 8.63,
            region: "Central Switzerland",
            regionDE: "Zentralschweiz",
            driveMinutes: 40,
            altitude: 1170
        ),

        // MARK: Eastern Switzerland
        SnowResortConfig(
            id: "flumserberg",
            name: "Flumserberg",
            nameDE: "Flumserberg",
            lat: 47.0912,
            lon: 9.2739,
            region: "Eastern Switzerland",
            regionDE: "Ostschweiz",
            driveMinutes: 60,
            altitude: 1220
        ),
        SnowResortConfig(
            id: "braunwald",
            name: "Braunwald",
            nameDE: "Braunwald",
            lat: 46.9412,
            lon: 8.9998,
            region: "Eastern Switzerland",
            regionDE: "Ostschweiz",
            driveMinutes: 70,
            altitude: 1256
        ),
    ]
}
