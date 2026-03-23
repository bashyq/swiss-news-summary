import Foundation

/// Curated toddler-friendly attractions per sunshine destination
/// Sourced from DEST_HIGHLIGHTS in the PWA
enum DestinationHighlights {
    static func forDestination(_ id: String) -> [DestinationHighlight] {
        highlights[id] ?? []
    }

    /// Cities that overlap with the Activities view
    static let activityCities: Set<String> = ["basel", "lausanne", "luzern"]

    private static let highlights: [String: [DestinationHighlight]] = [
        "lugano": [
            DestinationHighlight(name: "Parco Ciani", nameDE: "Parco Ciani", type: "playground", description: "Lakeside park with large playground and duck pond", descriptionDE: "Park am See mit grossem Spielplatz und Ententeich", lat: 46.0053, lon: 8.9580),
            DestinationHighlight(name: "Swissminiatur", nameDE: "Swissminiatur", type: "nature", description: "Miniature Switzerland park with 120+ scale models", descriptionDE: "Miniatur-Schweiz-Park mit über 120 Modellen", lat: 45.9553, lon: 8.9468),
            DestinationHighlight(name: "Lido di Lugano", nameDE: "Lido di Lugano", type: "playground", description: "Sandy beach with kids pool and playground", descriptionDE: "Sandstrand mit Kinderplanschbecken und Spielplatz", lat: 46.0005, lon: 8.9625),
        ],
        "locarno": [
            DestinationHighlight(name: "Lido Locarno", nameDE: "Lido Locarno", type: "playground", description: "Family pool complex with slides and sandy beach", descriptionDE: "Familien-Schwimmbad mit Rutschen und Sandstrand", lat: 46.1660, lon: 8.7935),
            DestinationHighlight(name: "Cardada Playground", nameDE: "Spielplatz Cardada", type: "playground", description: "Mountain playground at 1340m with cable car ride", descriptionDE: "Bergspielplatz auf 1340m mit Seilbahnfahrt", lat: 46.1835, lon: 8.7640),
        ],
        "bellinzona": [
            DestinationHighlight(name: "Castelgrande", nameDE: "Castelgrande", type: "nature", description: "UNESCO castle with grassy courtyards, lift access", descriptionDE: "UNESCO-Burg mit Grünflächen und Liftanschluss", lat: 46.1944, lon: 9.0168),
            DestinationHighlight(name: "Castello Montebello", nameDE: "Castello Montebello", type: "playground", description: "Medieval castle with playground and picnic area", descriptionDE: "Mittelalterliche Burg mit Spielplatz und Picknick", lat: 46.1943, lon: 9.0244),
        ],
        "ascona": [
            DestinationHighlight(name: "Lakefront Playground", nameDE: "Spielplatz Seepromenade", type: "playground", description: "Lakefront playground with trampolines and swings", descriptionDE: "Spielplatz am See mit Trampolinen und Schaukeln", lat: 46.1570, lon: 8.7730),
            DestinationHighlight(name: "Brissago Islands", nameDE: "Brissago-Inseln", type: "nature", description: "Botanical island with treasure hunt, boat ride over", descriptionDE: "Botanische Insel mit Schatzsuche, per Boot erreichbar", lat: 46.1317, lon: 8.7344),
        ],
        "chur": [
            DestinationHighlight(name: "Brambrüesch Playground", nameDE: "Spielplatz Brambrüesch", type: "playground", description: "Mountain playground with cable car and theme trail", descriptionDE: "Bergspielplatz mit Seilbahn und Themenweg", lat: 46.8670, lon: 9.5025),
            DestinationHighlight(name: "Bündner Naturmuseum", nameDE: "Bündner Naturmuseum", type: "museum", description: "Interactive alpine animal exhibits for kids", descriptionDE: "Interaktive Ausstellung alpiner Tiere für Kinder", lat: 46.8494, lon: 9.5362),
        ],
        "davos": [
            DestinationHighlight(name: "Schatzalp Alpine Garden", nameDE: "Alpengarten Schatzalp", type: "nature", description: "Alpine garden at 1864m with funicular ride up", descriptionDE: "Alpengarten auf 1864m mit Standseilbahn", lat: 46.7927, lon: 9.8204),
            DestinationHighlight(name: "Rinerhorn Petting Zoo", nameDE: "Rinerhorn Streichelzoo", type: "nature", description: "Free alpine petting zoo with goats and alpacas", descriptionDE: "Gratis Streichelzoo mit Ziegen und Alpakas", lat: 46.7560, lon: 9.8630),
        ],
        "stmoritz": [
            DestinationHighlight(name: "Muottas Muragl Playground", nameDE: "Spielplatz Muottas Muragl", type: "playground", description: "Mountain playground at 2456m with epic Engadin view", descriptionDE: "Bergspielplatz auf 2456m mit Engadin-Panorama", lat: 46.5237, lon: 9.9092),
            DestinationHighlight(name: "Lake St. Moritz Promenade", nameDE: "St. Moritzer See Promenade", type: "playground", description: "Flat lakeside walk with playground and duck feeding", descriptionDE: "Flacher Seeweg mit Spielplatz und Enten füttern", lat: 46.4935, lon: 9.8410),
        ],
        "flims": [
            DestinationHighlight(name: "Caumasee", nameDE: "Caumasee", type: "nature", description: "Turquoise alpine lake with playground and paddleboats", descriptionDE: "Türkiser Bergsee mit Spielplatz und Tretbooten", lat: 46.8188, lon: 9.2908),
            DestinationHighlight(name: "Spielplatz Prau la Selva", nameDE: "Spielplatz Prau la Selva", type: "playground", description: "Large forest playground with water play features", descriptionDE: "Grosser Waldspielplatz mit Wasserspiel", lat: 46.8340, lon: 9.2810),
        ],
        "sion": [
            DestinationHighlight(name: "Domaine des Îles", nameDE: "Domaine des Îles", type: "playground", description: "Huge park with playground, mini-golf and mini train", descriptionDE: "Grosser Park mit Spielplatz, Minigolf und Bähnli", lat: 46.2131, lon: 7.3332),
            DestinationHighlight(name: "Musée de la Nature", nameDE: "Naturmuseum Wallis", type: "museum", description: "Interactive alpine exhibits, free first Sunday", descriptionDE: "Interaktive Alpen-Ausstellung, 1. Sonntag gratis", lat: 46.2330, lon: 7.3601),
        ],
        "brig": [
            DestinationHighlight(name: "Stockalperschloss Garden", nameDE: "Stockalperschloss Garten", type: "playground", description: "Castle garden with playground, free courtyard access", descriptionDE: "Schlossgarten mit Spielplatz, Hof frei zugänglich", lat: 46.3150, lon: 7.9873),
            DestinationHighlight(name: "Brigerbad Thermal Baths", nameDE: "Thermalbad Brigerbad", type: "playground", description: "Thermal pools with toddler area and water slides", descriptionDE: "Therme mit Kleinkinderbereich und Wasserrutschen", lat: 46.3025, lon: 7.9240),
        ],
        "zermatt": [
            DestinationHighlight(name: "Wolli Park Sunnegga", nameDE: "Wolli Park Sunnegga", type: "playground", description: "Mountain playground with lake beach, by funicular", descriptionDE: "Bergspielplatz mit Seestrand, per Standseilbahn", lat: 46.0300, lon: 7.7701),
            DestinationHighlight(name: "Obere Matten Playground", nameDE: "Spielplatz Obere Matten", type: "playground", description: "Village playground near shops and restaurants", descriptionDE: "Spielplatz im Dorf nahe Läden und Restaurants", lat: 46.0207, lon: 7.7480),
        ],
        "luzern": [
            DestinationHighlight(name: "Verkehrshaus", nameDE: "Verkehrshaus der Schweiz", type: "museum", description: "Transport museum with hands-on exhibits and playground", descriptionDE: "Verkehrsmuseum mit Mitmach-Stationen und Spielplatz", lat: 47.0531, lon: 8.3356),
            DestinationHighlight(name: "Vögeligärtli Park", nameDE: "Vögeligärtli", type: "playground", description: "Central playground near train station with sandbox", descriptionDE: "Zentraler Spielplatz beim Bahnhof mit Sandkasten", lat: 47.0485, lon: 8.3068),
        ],
        "interlaken": [
            DestinationHighlight(name: "Harder Kulm Playground", nameDE: "Spielplatz Harder Kulm", type: "playground", description: "Alpine playground at 1322m with Jungfrau panorama", descriptionDE: "Bergspielplatz auf 1322m mit Jungfrau-Panorama", lat: 46.6974, lon: 7.8519),
            DestinationHighlight(name: "Höhematte Park", nameDE: "Spielplatz Höhematte", type: "playground", description: "Free central park playground with mountain views", descriptionDE: "Gratis Spielplatz im Zentrum mit Bergpanorama", lat: 46.6859, lon: 7.8598),
        ],
        "engelberg": [
            DestinationHighlight(name: "Globi Playground Ristis", nameDE: "Globi Spielplatz Ristis", type: "playground", description: "Alpine playground with rope park and bouncy castle", descriptionDE: "Bergspielplatz mit Seilpark und Hüpfburg", lat: 46.8130, lon: 8.3820),
            DestinationHighlight(name: "Trübsee Playground", nameDE: "Spielplatz Trübsee", type: "playground", description: "Smuggler-themed playground by mountain lake", descriptionDE: "Schmuggler-Spielplatz am Bergsee", lat: 46.7890, lon: 8.3920),
        ],
        "schwyz": [
            DestinationHighlight(name: "Swiss Knife Valley Center", nameDE: "Swiss Knife Valley Besucherzentrum", type: "museum", description: "Victorinox museum where kids can build a knife", descriptionDE: "Victorinox-Museum, Kinder bauen ein Messer", lat: 46.9944, lon: 8.6054),
            DestinationHighlight(name: "Swiss Holiday Park", nameDE: "Swiss Holiday Park", type: "playground", description: "Indoor waterpark with slides and toddler pool", descriptionDE: "Erlebnisbad mit Rutschen und Kleinkinderbecken", lat: 46.9830, lon: 8.6160),
        ],
        "altdorf": [
            DestinationHighlight(name: "Tell Monument Square", nameDE: "Telldenkmal", type: "nature", description: "Iconic William Tell statue with playground nearby", descriptionDE: "Ikonisches Telldenkmal mit Spielplatz in der Nähe", lat: 46.8802, lon: 8.6393),
            DestinationHighlight(name: "Schwimmbad Altdorf", nameDE: "Schwimmbad Altdorf", type: "playground", description: "Indoor/outdoor pool with slides and paddling pool", descriptionDE: "Hallen-/Freibad mit Rutschen und Planschbecken", lat: 46.8760, lon: 8.6500),
        ],
        "lausanne": [
            DestinationHighlight(name: "Olympic Museum", nameDE: "Olympisches Museum", type: "museum", description: "Interactive sports museum with lakeside park", descriptionDE: "Interaktives Sportmuseum mit Seeuferpark", lat: 46.5088, lon: 6.6340),
            DestinationHighlight(name: "Ouchy Playground", nameDE: "Spielplatz Ouchy", type: "playground", description: "Lakefront playground with paddleboats and ducks", descriptionDE: "Spielplatz am See mit Tretbooten und Enten", lat: 46.5075, lon: 6.6282),
        ],
        "montreux": [
            DestinationHighlight(name: "Château de Chillon", nameDE: "Schloss Chillon", type: "museum", description: "Fairy-tale lakeside castle with kids activity booklet", descriptionDE: "Märchenschloss am See mit Kinder-Aktivheft", lat: 46.4142, lon: 6.9276),
            DestinationHighlight(name: "Lakefront Playground", nameDE: "Spielplatz Seepromenade", type: "playground", description: "Flower-lined lakefront promenade with playground", descriptionDE: "Blumengesäumte Seepromenade mit Spielplatz", lat: 46.4340, lon: 6.9120),
        ],
        "vevey": [
            DestinationHighlight(name: "Alimentarium", nameDE: "Alimentarium", type: "museum", description: "Interactive food museum with hands-on kids exhibits", descriptionDE: "Interaktives Ernährungsmuseum mit Kinderstationen", lat: 46.4583, lon: 6.8464),
            DestinationHighlight(name: "Lakefront Playground", nameDE: "Spielplatz am See", type: "playground", description: "Large jungle gym by lake with swing sets", descriptionDE: "Grosses Klettergerüst am See mit Schaukeln", lat: 46.4610, lon: 6.8430),
        ],
        "basel": [
            DestinationHighlight(name: "Zoo Basel (Zolli)", nameDE: "Zoo Basel (Zolli)", type: "nature", description: "Historic zoo with petting area and kids playground", descriptionDE: "Historischer Zoo mit Streichelzoo und Spielplatz", lat: 47.5472, lon: 7.5789),
            DestinationHighlight(name: "Tierpark Lange Erlen", nameDE: "Tierpark Lange Erlen", type: "nature", description: "Free animal park with deer, ponies and playground", descriptionDE: "Gratis Tierpark mit Hirschen, Ponys und Spielplatz", lat: 47.5760, lon: 7.6230),
        ],
        "solothurn": [
            DestinationHighlight(name: "Naturmuseum Solothurn", nameDE: "Naturmuseum Solothurn", type: "museum", description: "Regional nature exhibits for families", descriptionDE: "Regionale Naturausstellung für Familien", lat: 47.2078, lon: 7.5372),
            DestinationHighlight(name: "Verenaschlucht", nameDE: "Verenaschlucht", type: "nature", description: "Atmospheric gorge walk to hermitage, stroller-friendly", descriptionDE: "Stimmungsvolle Schluchtwanderung, kinderwagentauglich", lat: 47.2200, lon: 7.5415),
        ],
        "delemont": [
            DestinationHighlight(name: "Préhisto-Parc", nameDE: "Préhisto-Parc", type: "nature", description: "Dinosaur park with 45 life-size models in forest", descriptionDE: "Dinosaurierpark mit 45 lebensgrossen Modellen", lat: 47.3013, lon: 7.0532),
            DestinationHighlight(name: "Parc du Château", nameDE: "Parc du Château", type: "playground", description: "Castle park with playground and shaded picnic area", descriptionDE: "Schlosspark mit Spielplatz und schattigem Picknick", lat: 47.3650, lon: 7.3450),
        ],
        "konstanz": [
            DestinationHighlight(name: "SEA LIFE Konstanz", nameDE: "SEA LIFE Konstanz", type: "museum", description: "Aquarium with underwater tunnel and touch pools", descriptionDE: "Aquarium mit Unterwassertunnel und Streichelbecken", lat: 47.6605, lon: 9.1770),
            DestinationHighlight(name: "Stadtgarten Playground", nameDE: "Spielplatz Stadtgarten", type: "playground", description: "Large lakeside playground with water play area", descriptionDE: "Grosser Seespielplatz mit Wasserspielbereich", lat: 47.6615, lon: 9.1790),
        ],
        "lindau": [
            DestinationHighlight(name: "Harbour Playground", nameDE: "Spielplatz am Hafen", type: "playground", description: "Harbour playground with slides and lake views", descriptionDE: "Hafenspielplatz mit Rutschen und Seeblick", lat: 47.5450, lon: 9.6840),
            DestinationHighlight(name: "Lindenhofpark", nameDE: "Lindenhofpark", type: "nature", description: "Lakeside park with paddleboats and shaded playground", descriptionDE: "Seepark mit Tretbooten und schattigem Spielplatz", lat: 47.5510, lon: 9.6920),
        ],
        "como": [
            DestinationHighlight(name: "Villa Olmo Park", nameDE: "Park Villa Olmo", type: "nature", description: "Grand lakefront park with playground, free entry", descriptionDE: "Grosser Seeuferpark mit Spielplatz, Eintritt frei", lat: 45.8180, lon: 9.0598),
            DestinationHighlight(name: "Harbour Playground", nameDE: "Spielplatz am Hafen", type: "playground", description: "Modern playground by boat dock with lake views", descriptionDE: "Moderner Spielplatz beim Anleger mit Seeblick", lat: 45.8110, lon: 9.0720),
        ],
        "schaffhausen": [
            DestinationHighlight(name: "Rhine Falls", nameDE: "Rheinfall", type: "nature", description: "Europe's largest waterfall with playground and boat rides", descriptionDE: "Grösster Wasserfall Europas mit Spielplatz und Boot", lat: 47.6778, lon: 8.6152),
            DestinationHighlight(name: "Munot Fortress", nameDE: "Munot Festung", type: "nature", description: "Circular fortress with playground and deer park", descriptionDE: "Runde Festung mit Spielplatz und Hirschgehege", lat: 47.6965, lon: 8.6390),
        ],
        "frauenfeld": [
            DestinationHighlight(name: "Plättli Zoo", nameDE: "Plättli Zoo", type: "nature", description: "Small zoo with petting area and pony rides", descriptionDE: "Kleiner Zoo mit Streichelzoo und Ponyreiten", lat: 47.5605, lon: 8.9157),
            DestinationHighlight(name: "Schloss Frauenfeld", nameDE: "Schloss Frauenfeld", type: "museum", description: "Historic castle with nature museum and park", descriptionDE: "Historisches Schloss mit Naturmuseum und Park", lat: 47.5565, lon: 8.8980),
        ],
        "rapperswil": [
            DestinationHighlight(name: "Knies Kinderzoo", nameDE: "Knies Kinderzoo", type: "nature", description: "Children's zoo with camel rides and adventure playground", descriptionDE: "Kinderzoo mit Kamelreiten und Abenteuerspielplatz", lat: 47.2290, lon: 8.8210),
            DestinationHighlight(name: "Castle Playground", nameDE: "Spielplatz Lindenhof", type: "playground", description: "Lakefront playground below castle with climbing tower", descriptionDE: "Seespielplatz unter dem Schloss mit Kletterturm", lat: 47.2267, lon: 8.8180),
        ],
    ]
}
