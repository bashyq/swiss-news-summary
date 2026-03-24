// ios-app/Znuni/Services/POIAdapter.swift
import Foundation

struct POIAdapter {
    static func buildPools(from pois: [POIResult]) -> (activities: [Activity], lunches: [LunchSpot], dinners: [LunchSpot]) {
        var activities: [Activity] = []
        var lunches: [LunchSpot] = []
        var dinners: [LunchSpot] = []

        for poi in pois {
            switch poi.category {
            case .restaurant, .cafe:
                let spot = poi.toLunchSpot()
                lunches.append(spot)
                dinners.append(spot)
            case .playground, .park, .museum, .bakery, .lake:
                activities.append(poi.toActivity())
            }
        }

        return (activities, lunches, dinners)
    }
}

extension POIResult {
    func toActivity() -> Activity {
        let isIndoor: Bool
        switch category {
        case .museum, .bakery, .cafe: isIndoor = true
        case .playground, .park, .lake: isIndoor = false
        case .restaurant: isIndoor = true
        }

        let desc: String
        let descDE: String
        switch category {
        case .museum:
            desc = "Museum worth visiting in the area"
            descDE = "Sehenswertes Museum in der Nähe"
        case .park:
            desc = "Park to explore nearby"
            descDE = "Park zum Erkunden in der Nähe"
        case .playground:
            desc = "Playground for the kids nearby"
            descDE = "Spielplatz für die Kinder in der Nähe"
        case .lake:
            desc = "Lake or beach spot nearby"
            descDE = "See- oder Strandplatz in der Nähe"
        case .bakery:
            desc = "Local bakery for a treat"
            descDE = "Lokale Bäckerei für eine Leckerei"
        default:
            desc = "Interesting spot to visit nearby"
            descDE = "Interessanter Ort in der Nähe"
        }

        let duration: String
        switch category {
        case .museum: duration = "1-2 hours"
        case .park, .lake: duration = "1-3 hours"
        case .playground: duration = "1-2 hours"
        case .bakery, .cafe: duration = "30-60 min"
        default: duration = "1-2 hours"
        }

        return Activity(
            id: id,
            name: name,
            nameDE: name,
            description: desc,
            descriptionDE: descDE,
            indoor: isIndoor,
            ageRange: "",
            duration: duration,
            price: nil,
            priceDE: nil,
            url: url,
            lat: latitude,
            lon: longitude,
            category: category.rawValue,
            minAge: nil,
            maxAge: nil,
            season: nil,
            free: category == .playground || category == .park || category == .lake,
            recurring: nil,
            stayHome: false,
            availableMonths: nil,
            subcategory: nil,
            materials: nil,
            materialsDE: nil,
            addedDate: nil,
            suggestibility: "always",
            openingHours: openingHours
        )
    }

    func toLunchSpot() -> LunchSpot {
        let cuisineCat: String?
        switch category {
        case .cafe: cuisineCat = "Cafe"
        case .restaurant: cuisineCat = "Restaurant"
        default: cuisineCat = nil
        }

        return LunchSpot(
            id: id,
            name: name,
            lat: latitude,
            lon: longitude,
            cuisine: category == .cafe ? "cafe" : "restaurant",
            cuisineCategory: cuisineCat,
            wheelchair: nil,
            outdoorSeating: nil,
            takeaway: nil,
            openingHours: openingHours,
            openForLunch: true,
            openForDinner: true,
            kidFriendly: nil,
            vegetarian: nil,
            vegan: nil,
            phone: phoneNumber,
            website: url,
            amenity: category == .cafe ? "cafe" : "restaurant",
            rating: rating,
            ratingCount: ratingCount,
            permanentlyClosed: false
        )
    }
}
