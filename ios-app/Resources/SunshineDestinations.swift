import Foundation

// MARK: - SunshineDestinations
// All 29 sunshine destinations from the PWA's SUNSHINE_DESTS array in app.js.
// Used for client-side Open-Meteo fallback when the worker is rate-limited.
// The SunshineDestinationConfig struct is defined in APIClient.swift.

enum SunshineDestinations {
    static let all: [SunshineDestinationConfig] = [
        // MARK: Zürich (Baseline)
        SunshineDestinationConfig(
            id: "zurich",
            name: "Zürich",
            nameDE: "Zürich",
            lat: 47.3769,
            lon: 8.5417,
            region: "Zürich",
            regionDE: "Zürich",
            driveMinutes: 0,
            isBaseline: true
        ),

        // MARK: Ticino
        SunshineDestinationConfig(
            id: "lugano",
            name: "Lugano",
            nameDE: "Lugano",
            lat: 46.0037,
            lon: 8.9511,
            region: "Ticino",
            regionDE: "Tessin",
            driveMinutes: 150,
            isBaseline: false
        ),
        SunshineDestinationConfig(
            id: "locarno",
            name: "Locarno",
            nameDE: "Locarno",
            lat: 46.1711,
            lon: 8.7953,
            region: "Ticino",
            regionDE: "Tessin",
            driveMinutes: 160,
            isBaseline: false
        ),
        SunshineDestinationConfig(
            id: "bellinzona",
            name: "Bellinzona",
            nameDE: "Bellinzona",
            lat: 46.1955,
            lon: 9.0234,
            region: "Ticino",
            regionDE: "Tessin",
            driveMinutes: 140,
            isBaseline: false
        ),
        SunshineDestinationConfig(
            id: "ascona",
            name: "Ascona",
            nameDE: "Ascona",
            lat: 46.157,
            lon: 8.7726,
            region: "Ticino",
            regionDE: "Tessin",
            driveMinutes: 165,
            isBaseline: false
        ),

        // MARK: Graubünden
        SunshineDestinationConfig(
            id: "chur",
            name: "Chur",
            nameDE: "Chur",
            lat: 46.8499,
            lon: 9.5329,
            region: "Graubünden",
            regionDE: "Graubünden",
            driveMinutes: 80,
            isBaseline: false
        ),
        SunshineDestinationConfig(
            id: "davos",
            name: "Davos",
            nameDE: "Davos",
            lat: 46.8027,
            lon: 9.836,
            region: "Graubünden",
            regionDE: "Graubünden",
            driveMinutes: 115,
            isBaseline: false
        ),
        SunshineDestinationConfig(
            id: "stmoritz",
            name: "St. Moritz",
            nameDE: "St. Moritz",
            lat: 46.4908,
            lon: 9.8355,
            region: "Graubünden",
            regionDE: "Graubünden",
            driveMinutes: 150,
            isBaseline: false
        ),
        SunshineDestinationConfig(
            id: "flims",
            name: "Flims",
            nameDE: "Flims",
            lat: 46.8354,
            lon: 9.2836,
            region: "Graubünden",
            regionDE: "Graubünden",
            driveMinutes: 95,
            isBaseline: false
        ),

        // MARK: Valais
        SunshineDestinationConfig(
            id: "sion",
            name: "Sion",
            nameDE: "Sitten",
            lat: 46.233,
            lon: 7.3597,
            region: "Valais",
            regionDE: "Wallis",
            driveMinutes: 165,
            isBaseline: false
        ),
        SunshineDestinationConfig(
            id: "brig",
            name: "Brig",
            nameDE: "Brig",
            lat: 46.3138,
            lon: 7.9877,
            region: "Valais",
            regionDE: "Wallis",
            driveMinutes: 140,
            isBaseline: false
        ),
        SunshineDestinationConfig(
            id: "zermatt",
            name: "Zermatt",
            nameDE: "Zermatt",
            lat: 46.0207,
            lon: 7.7491,
            region: "Valais",
            regionDE: "Wallis",
            driveMinutes: 195,
            isBaseline: false
        ),

        // MARK: Central Switzerland
        SunshineDestinationConfig(
            id: "luzern",
            name: "Lucerne",
            nameDE: "Luzern",
            lat: 47.0502,
            lon: 8.3093,
            region: "Central Switzerland",
            regionDE: "Zentralschweiz",
            driveMinutes: 45,
            isBaseline: false
        ),
        SunshineDestinationConfig(
            id: "engelberg",
            name: "Engelberg",
            nameDE: "Engelberg",
            lat: 46.821,
            lon: 8.4013,
            region: "Central Switzerland",
            regionDE: "Zentralschweiz",
            driveMinutes: 65,
            isBaseline: false
        ),
        SunshineDestinationConfig(
            id: "schwyz",
            name: "Schwyz",
            nameDE: "Schwyz",
            lat: 47.0207,
            lon: 8.6571,
            region: "Central Switzerland",
            regionDE: "Zentralschweiz",
            driveMinutes: 40,
            isBaseline: false
        ),
        SunshineDestinationConfig(
            id: "altdorf",
            name: "Altdorf",
            nameDE: "Altdorf",
            lat: 46.8802,
            lon: 8.6441,
            region: "Central Switzerland",
            regionDE: "Zentralschweiz",
            driveMinutes: 50,
            isBaseline: false
        ),

        // MARK: Bernese Oberland
        SunshineDestinationConfig(
            id: "interlaken",
            name: "Interlaken",
            nameDE: "Interlaken",
            lat: 46.6863,
            lon: 7.8632,
            region: "Bernese Oberland",
            regionDE: "Berner Oberland",
            driveMinutes: 110,
            isBaseline: false
        ),

        // MARK: Lake Geneva
        SunshineDestinationConfig(
            id: "lausanne",
            name: "Lausanne",
            nameDE: "Lausanne",
            lat: 46.5197,
            lon: 6.6323,
            region: "Lake Geneva",
            regionDE: "Genfersee",
            driveMinutes: 140,
            isBaseline: false
        ),
        SunshineDestinationConfig(
            id: "montreux",
            name: "Montreux",
            nameDE: "Montreux",
            lat: 46.4312,
            lon: 6.9107,
            region: "Lake Geneva",
            regionDE: "Genfersee",
            driveMinutes: 150,
            isBaseline: false
        ),
        SunshineDestinationConfig(
            id: "vevey",
            name: "Vevey",
            nameDE: "Vevey",
            lat: 46.4603,
            lon: 6.8412,
            region: "Lake Geneva",
            regionDE: "Genfersee",
            driveMinutes: 145,
            isBaseline: false
        ),

        // MARK: Northwestern Switzerland
        SunshineDestinationConfig(
            id: "basel",
            name: "Basel",
            nameDE: "Basel",
            lat: 47.5596,
            lon: 7.5886,
            region: "Northwestern Switzerland",
            regionDE: "Nordwestschweiz",
            driveMinutes: 55,
            isBaseline: false
        ),
        SunshineDestinationConfig(
            id: "solothurn",
            name: "Solothurn",
            nameDE: "Solothurn",
            lat: 47.2088,
            lon: 7.5378,
            region: "Northwestern Switzerland",
            regionDE: "Nordwestschweiz",
            driveMinutes: 65,
            isBaseline: false
        ),

        // MARK: Jura
        SunshineDestinationConfig(
            id: "delemont",
            name: "Delémont",
            nameDE: "Delémont",
            lat: 47.3647,
            lon: 7.3462,
            region: "Jura",
            regionDE: "Jura",
            driveMinutes: 90,
            isBaseline: false
        ),

        // MARK: Lake Constance
        SunshineDestinationConfig(
            id: "konstanz",
            name: "Konstanz",
            nameDE: "Konstanz",
            lat: 47.6633,
            lon: 9.1753,
            region: "Lake Constance",
            regionDE: "Bodensee",
            driveMinutes: 50,
            isBaseline: false
        ),
        SunshineDestinationConfig(
            id: "lindau",
            name: "Lindau",
            nameDE: "Lindau",
            lat: 47.546,
            lon: 9.6829,
            region: "Lake Constance",
            regionDE: "Bodensee",
            driveMinutes: 70,
            isBaseline: false
        ),

        // MARK: Lake Como
        SunshineDestinationConfig(
            id: "como",
            name: "Como",
            nameDE: "Como",
            lat: 45.8081,
            lon: 9.0852,
            region: "Lake Como",
            regionDE: "Comer See",
            driveMinutes: 155,
            isBaseline: false
        ),

        // MARK: Eastern Switzerland
        SunshineDestinationConfig(
            id: "schaffhausen",
            name: "Schaffhausen",
            nameDE: "Schaffhausen",
            lat: 47.696,
            lon: 8.6342,
            region: "Eastern Switzerland",
            regionDE: "Ostschweiz",
            driveMinutes: 35,
            isBaseline: false
        ),
        SunshineDestinationConfig(
            id: "frauenfeld",
            name: "Frauenfeld",
            nameDE: "Frauenfeld",
            lat: 47.5535,
            lon: 8.8987,
            region: "Eastern Switzerland",
            regionDE: "Ostschweiz",
            driveMinutes: 30,
            isBaseline: false
        ),

        // MARK: Lake Zurich
        SunshineDestinationConfig(
            id: "rapperswil",
            name: "Rapperswil",
            nameDE: "Rapperswil",
            lat: 47.2267,
            lon: 8.8184,
            region: "Lake Zurich",
            regionDE: "Zürichsee",
            driveMinutes: 25,
            isBaseline: false
        ),
    ]
}
