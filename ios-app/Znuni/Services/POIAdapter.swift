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

        return Activity(
            id: id,
            name: name,
            nameDE: name,
            description: "Nearby \(category.rawValue) in the area",
            descriptionDE: "\(category.rawValue.capitalized) in der Nähe",
            indoor: isIndoor,
            ageRange: "0-99",
            duration: "60",
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
            suggestibility: "always"
        )
    }

    func toLunchSpot() -> LunchSpot {
        return LunchSpot(
            id: id,
            name: name,
            lat: latitude,
            lon: longitude,
            cuisine: category == .cafe ? "cafe" : nil,
            cuisineCategory: category == .cafe ? "cafe" : nil,
            wheelchair: nil,
            outdoorSeating: nil,
            takeaway: nil,
            openingHours: nil,
            openForLunch: true,
            openForDinner: true,
            kidFriendly: nil,
            vegetarian: nil,
            vegan: nil,
            phone: phoneNumber,
            website: url,
            amenity: category == .cafe ? "cafe" : "restaurant",
            rating: nil,
            ratingCount: nil,
            permanentlyClosed: false
        )
    }
}
