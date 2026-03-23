import Foundation

// MARK: - DealsData
// All 28 deals from the "Today in Switzerland" PWA's DEALS array in app.js.
// The Deal model is defined elsewhere; this file only provides the data.

enum DealsData {
    static let all: [Deal] = [
        // MARK: Museum Free Days
        Deal(
            id: "kunsthaus-free",
            name: "Kunsthaus Zürich — Free Wednesdays",
            nameDE: "Kunsthaus Zürich — Mittwochs gratis",
            description: "Free entry every Wednesday. World-class art collection.",
            descriptionDE: "Jeden Mittwoch gratis Eintritt. Weltklasse-Kunstsammlung.",
            category: "museum",
            type: .free,
            city: "zurich",
            url: "https://www.kunsthaus.ch",
            validMonths: nil
        ),
        Deal(
            id: "landesmuseum-free",
            name: "Swiss National Museum — Kids free",
            nameDE: "Landesmuseum — Kinder gratis",
            description: "Free for under 16. First Saturday of month free for everyone.",
            descriptionDE: "Gratis für unter 16. Erster Samstag im Monat gratis für alle.",
            category: "museum",
            type: .free,
            city: "zurich",
            url: "https://www.landesmuseum.ch",
            validMonths: nil
        ),
        Deal(
            id: "zoologisches-museum",
            name: "Zoological Museum — Always free",
            nameDE: "Zoologisches Museum — Immer gratis",
            description: "Free entry always. Dinosaur skeletons, animal exhibits kids love.",
            descriptionDE: "Immer gratis. Dinosaurierskelette und Tierausstellungen.",
            category: "museum",
            type: .free,
            city: "zurich",
            url: "https://www.zm.uzh.ch",
            validMonths: nil
        ),
        Deal(
            id: "botanischer-garten-free",
            name: "Botanical Garden Zürich — Always free",
            nameDE: "Botanischer Garten Zürich — Immer gratis",
            description: "Free tropical greenhouses, turtles, and space to run.",
            descriptionDE: "Kostenlose Tropenhäuser, Schildkröten und Platz zum Spielen.",
            category: "museum",
            type: .free,
            city: "zurich",
            url: "https://www.bg.uzh.ch",
            validMonths: nil
        ),
        Deal(
            id: "fifa-museum-kids",
            name: "FIFA Museum — Kids under 6 free",
            nameDE: "FIFA Museum — Kinder unter 6 gratis",
            description: "Interactive football museum. Free for toddlers.",
            descriptionDE: "Interaktives Fussball-Museum. Gratis für Kleinkinder.",
            category: "museum",
            type: .free,
            city: "zurich",
            url: "https://www.fifamuseum.com",
            validMonths: nil
        ),
        Deal(
            id: "rietberg-permanent",
            name: "Museum Rietberg — Free permanent collection",
            nameDE: "Museum Rietberg — Dauerausstellung gratis",
            description: "Free entry to the permanent collection. Beautiful park.",
            descriptionDE: "Gratis Eintritt zur Dauerausstellung. Schöner Park.",
            category: "museum",
            type: .free,
            city: "zurich",
            url: "https://rietberg.ch",
            validMonths: nil
        ),
        Deal(
            id: "basel-zoo-kids",
            name: "Zoo Basel — Kids under 6 free",
            nameDE: "Zoo Basel — Kinder unter 6 gratis",
            description: "One of the oldest zoos in Switzerland. Free for toddlers.",
            descriptionDE: "Einer der ältesten Zoos der Schweiz. Gratis für Kleinkinder.",
            category: "museum",
            type: .free,
            city: "basel",
            url: "https://www.zoobasel.ch",
            validMonths: nil
        ),
        Deal(
            id: "basel-lange-erlen-free",
            name: "Lange Erlen Animal Park — Always free",
            nameDE: "Tierpark Lange Erlen — Immer gratis",
            description: "Free animal park with deer, wild boar, birds, and playground.",
            descriptionDE: "Gratis Tierpark mit Hirschen, Wildschweinen, Vögeln und Spielplatz.",
            category: "museum",
            type: .free,
            city: "basel",
            url: nil,
            validMonths: nil
        ),
        Deal(
            id: "bern-barenpark-free",
            name: "BärenPark Bern — Always free",
            nameDE: "BärenPark Bern — Immer gratis",
            description: "See the famous Bern bears for free. Right by the old town.",
            descriptionDE: "Die berühmten Berner Bären gratis sehen. Direkt bei der Altstadt.",
            category: "museum",
            type: .free,
            city: "bern",
            url: "https://www.baerenpark-bern.ch",
            validMonths: nil
        ),
        Deal(
            id: "geneva-natural-history",
            name: "Natural History Museum Geneva — Always free",
            nameDE: "Naturhistorisches Museum Genf — Immer gratis",
            description: "Huge dinosaur and animal collection. Always free entry.",
            descriptionDE: "Riesige Dinosaurier- und Tiersammlung. Immer gratis.",
            category: "museum",
            type: .free,
            city: "geneva",
            url: "https://www.museum-geneve.ch",
            validMonths: nil
        ),

        // MARK: Free Outdoor
        Deal(
            id: "wildnispark-free",
            name: "Wildnispark Zürich — Always free",
            nameDE: "Wildnispark Zürich — Immer gratis",
            description: "Free nature park with native Swiss animals and forest trails.",
            descriptionDE: "Gratis Naturpark mit einheimischen Tieren und Waldwegen.",
            category: "outdoor",
            type: .free,
            city: "zurich",
            url: "https://www.wildnispark.ch",
            validMonths: nil
        ),
        Deal(
            id: "uetliberg-free",
            name: "Uetliberg Hiking — Free",
            nameDE: "Uetliberg Wandern — Gratis",
            description: "Free hiking with amazing views of Zürich and the Alps.",
            descriptionDE: "Gratis Wandern mit Aussicht auf Zürich und die Alpen.",
            category: "outdoor",
            type: .free,
            city: "zurich",
            url: nil,
            validMonths: nil
        ),
        Deal(
            id: "irchelpark-free",
            name: "Irchelpark Playground — Free",
            nameDE: "Spielplatz Irchelpark — Gratis",
            description: "Large natural playground with climbing, sand pit, and water play.",
            descriptionDE: "Grosser Naturspielplatz mit Klettergerüsten und Wasserspiel.",
            category: "outdoor",
            type: .free,
            city: "zurich",
            url: nil,
            validMonths: nil
        ),
        Deal(
            id: "sauvabelin-free",
            name: "Sauvabelin Park Lausanne — Free",
            nameDE: "Sauvabelin Park Lausanne — Gratis",
            description: "Forest park with animals, playground, and wooden observation tower.",
            descriptionDE: "Waldpark mit Tieren, Spielplatz und Holzturm.",
            category: "outdoor",
            type: .free,
            city: "lausanne",
            url: nil,
            validMonths: nil
        ),
        Deal(
            id: "bruderhaus-free",
            name: "Wildpark Bruderhaus — Free",
            nameDE: "Wildpark Bruderhaus — Gratis",
            description: "Free forest animal park with deer, wild boar, and wolves.",
            descriptionDE: "Gratis Waldtierpark mit Hirschen, Wildschweinen und Wölfen.",
            category: "outdoor",
            type: .free,
            city: "winterthur",
            url: "https://www.wildpark.ch",
            validMonths: nil
        ),

        // MARK: Transport Deals
        Deal(
            id: "junior-card",
            name: "SBB Junior Card — CHF 30/year",
            nameDE: "SBB Junior-Karte — CHF 30/Jahr",
            description: "Kids travel free on all Swiss trains when accompanied by a parent. Best deal in Switzerland!",
            descriptionDE: "Kinder fahren gratis auf allen Schweizer Zügen in Begleitung eines Elternteils. Bester Deal der Schweiz!",
            category: "transport",
            type: .deal,
            city: "all",
            url: "https://www.sbb.ch/en/travelcards-and-tickets/railpasses/junior-card.html",
            validMonths: nil
        ),
        Deal(
            id: "zvv-9oclock",
            name: "ZVV 9 o'clock Pass",
            nameDE: "ZVV 9-Uhr-Pass",
            description: "Unlimited travel in Zürich zone after 9am for CHF 28.80/month.",
            descriptionDE: "Unbegrenzte Fahrten in der Zone Zürich nach 9 Uhr für CHF 28.80/Monat.",
            category: "transport",
            type: .deal,
            city: "zurich",
            url: "https://www.zvv.ch",
            validMonths: nil
        ),
        Deal(
            id: "sbb-supersaver",
            name: "SBB Supersaver Tickets",
            nameDE: "SBB Spartageskarten",
            description: "Up to 70% off train tickets when booked in advance online.",
            descriptionDE: "Bis zu 70% Rabatt auf Zugtickets bei Online-Vorbuchung.",
            category: "transport",
            type: .tip,
            city: "all",
            url: "https://www.sbb.ch/en/travelcards-and-tickets/tickets-for-switzerland/supersaver-tickets.html",
            validMonths: nil
        ),

        // MARK: Family Passes
        Deal(
            id: "zurich-card",
            name: "Zürich Card — Free transport + museums",
            nameDE: "Zürich Card — Gratis Transport + Museen",
            description: "Free public transport, free or reduced museum entry. CHF 27/24h.",
            descriptionDE: "Gratis ÖV, gratis oder reduzierter Museums-Eintritt. CHF 27/24h.",
            category: "family",
            type: .deal,
            city: "zurich",
            url: "https://www.zuerich.com/en/zurichcard",
            validMonths: nil
        ),
        Deal(
            id: "swiss-museum-pass",
            name: "Swiss Museum Pass — 500+ museums",
            nameDE: "Schweizer Museumspass — 500+ Museen",
            description: "Free entry to 500+ Swiss museums for one year. CHF 166/year.",
            descriptionDE: "Gratis Eintritt in 500+ Schweizer Museen für ein Jahr. CHF 166/Jahr.",
            category: "family",
            type: .deal,
            city: "all",
            url: "https://www.museumspass.ch",
            validMonths: nil
        ),
        Deal(
            id: "raiffeisen-member",
            name: "Raiffeisen Member Discounts",
            nameDE: "Raiffeisen Mitglieder-Rabatte",
            description: "Reduced entry to zoos, museums, and attractions with Raiffeisen membership.",
            descriptionDE: "Reduzierter Eintritt in Zoos, Museen und Attraktionen mit Raiffeisen-Mitgliedschaft.",
            category: "family",
            type: .tip,
            city: "all",
            url: "https://www.raiffeisen.ch/memberplus",
            validMonths: nil
        ),
        Deal(
            id: "family-card-sbb",
            name: "SBB Family Card — Free",
            nameDE: "SBB Family Card — Gratis",
            description: "Free card: kids 6-16 travel free with a parent holding a valid ticket.",
            descriptionDE: "Gratis Karte: Kinder 6-16 fahren gratis mit einem Elternteil.",
            category: "family",
            type: .free,
            city: "all",
            url: "https://www.sbb.ch",
            validMonths: nil
        ),

        // MARK: Seasonal
        Deal(
            id: "summer-badi-free",
            name: "Free Badi Days",
            nameDE: "Gratis Badi-Tage",
            description: "Many public pools offer free entry days in summer. Check local listings.",
            descriptionDE: "Viele Freibäder bieten im Sommer Gratis-Tage an. Lokale Veranstaltungen prüfen.",
            category: "seasonal",
            type: .free,
            city: "all",
            url: nil,
            validMonths: [6, 7, 8]
        ),
        Deal(
            id: "christmas-markets-free",
            name: "Christmas Markets — Free entry",
            nameDE: "Weihnachtsmärkte — Gratis Eintritt",
            description: "All Swiss Christmas markets are free to enter. Food and drinks for purchase.",
            descriptionDE: "Alle Schweizer Weihnachtsmärkte haben freien Eintritt. Essen und Getränke zum Kaufen.",
            category: "seasonal",
            type: .free,
            city: "all",
            url: nil,
            validMonths: [11, 12]
        ),
        Deal(
            id: "open-air-cinemas",
            name: "Open-air Cinemas",
            nameDE: "Open-Air Kinos",
            description: "Summer outdoor cinemas in most Swiss cities. Family screenings available.",
            descriptionDE: "Sommer-Open-Air-Kinos in den meisten Schweizer Städten. Familienvorstellungen verfügbar.",
            category: "seasonal",
            type: .deal,
            city: "all",
            url: nil,
            validMonths: [7, 8]
        ),

        // MARK: Community & Tips
        Deal(
            id: "gz-play-free",
            name: "GZ Play Afternoons — Free",
            nameDE: "GZ Spielnachmittage — Gratis",
            description: "Free drop-in play sessions at Zürich community centers (Gemeinschaftszentren).",
            descriptionDE: "Kostenlose Spielnachmittage in Zürcher Gemeinschaftszentren.",
            category: "outdoor",
            type: .free,
            city: "zurich",
            url: "https://gz-zh.ch",
            validMonths: nil
        ),
        Deal(
            id: "library-story-time",
            name: "Library Story Times — Free",
            nameDE: "Bibliothek Geschichtenzeit — Gratis",
            description: "Free story readings for toddlers at public libraries across Switzerland.",
            descriptionDE: "Kostenlose Geschichten für Kleinkinder in öffentlichen Bibliotheken.",
            category: "outdoor",
            type: .free,
            city: "all",
            url: nil,
            validMonths: nil
        ),
        Deal(
            id: "migros-kulturprozent",
            name: "Migros Kulturprozent — Free events",
            nameDE: "Migros Kulturprozent — Gratis Events",
            description: "Free family workshops, concerts, and cultural events funded by Migros.",
            descriptionDE: "Gratis Familien-Workshops, Konzerte und Kulturveranstaltungen von Migros.",
            category: "family",
            type: .free,
            city: "all",
            url: "https://www.migros-kulturprozent.ch",
            validMonths: nil
        ),
    ]
}
