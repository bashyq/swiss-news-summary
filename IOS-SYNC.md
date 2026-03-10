# iOS App Sync — Features to Implement

This document tracks PWA features that need to be ported to the SwiftUI iOS app on branch `claude/plan-ios-app-4aOQo` under `ios-app/`.

## API-Side (Already Available — No iOS Work Needed)

These features were added to the Cloudflare Worker and are automatically available to the iOS app via existing API calls:

| Feature | Endpoint | Field | Notes |
|---------|----------|-------|-------|
| Daily Pick | `GET /` | `briefing.dailyPick` | Weather+time-aware activity recommendation with `reason`/`reasonDE` text |
| Weekend Brief | `GET /` | `weekendBrief` | Sat+Sun weather + weekend events. `null` on Sundays. |
| Featured Activities | `GET /activities` | `featured: true` | 13 activities across all cities flagged as featured |
| News Expansion | `GET /` | `categories.*` | Now 8-10 items per category (was 5-8). Added Blick, Watson, Google Trends, Kantonspolizei ZH sources. Better categorization (elections→politics, police→local). No model changes needed — same JSON shape, just more items. |
| Deals API | `GET /deals` | `deals[]` | Deals/free entry data now served from worker endpoint. iOS should fetch from `/deals` instead of hardcoding `DealsData.swift`. Same JSON shape as before. |
| Sunshine Highlights | `GET /sunshine` | `destinations[].highlights[]` | Each destination now includes `highlights` array with toddler-friendly attractions. iOS can drop `DestinationHighlights.swift` and use API data directly. |

The iOS `NewsViewModel` and `ActivitiesViewModel` just need to parse these new fields from the existing JSON responses.

---

## Features Requiring iOS Implementation

### 1. Daily Pick Card (News View)
**PWA**: `renderNewsView()` in `app.js` — `.briefing-pick` card
**iOS target**: `ios-app/SwissPortal/Views/News/BriefingCard.swift`

**What to build:**
- Parse `briefing.dailyPick` from news API response (add to `NewsResponse.swift` model)
- Fields: `activityId`, `name`, `nameDE`, `reason`, `reasonDE`, `emoji`, `indoor`, `category`
- Show card below greeting in BriefingCard with:
  - Label: "Today's Pick" / "Tipp des Tages"
  - Emoji + reason text (localized)
  - Tap → navigate to Activities tab
- Replace old `briefing.suggestedActivity` handling (field no longer sent)

### 2. Weekend Brief Card (News View)
**PWA**: `renderWeekendBriefCard()` in `app.js` — `.weekend-brief` card
**iOS target**: New `WeekendBriefCard.swift` in `Views/News/`

**What to build:**
- Parse `weekendBrief` from news API response (add to `NewsResponse.swift`)
- Fields: `saturday { date, weatherCode, tempMax, tempMin }`, `sunday { ... }`, `events[]`, `satDate`, `sunDate`
- Card with:
  - "This Weekend" / "Dieses Wochenende" header (purple)
  - Two weather badges (Sat + Sun with icon + temps)
  - Up to 3 weekend events with toddler-friendly/free badges
  - Tap → navigate to Events tab
- Hide when `weekendBrief` is `null` (Sundays)

### 3. Activity Reminders
**PWA**: `showReminderModal()`, `checkReminders()` in `app.js`
**iOS target**: New functionality in `ActivitiesViewModel.swift` + `ActivityCard.swift`

**What to build:**
- Bell icon button on saved activity cards (next to heart)
- Tap → date picker sheet to set reminder date
- Store reminders in UserDefaults: `[{ activityId, name, date }]`
- Use `UNUserNotificationCenter` for local notifications (much better than PWA's limited Notification API)
- Schedule notification for reminder date at 9:00 AM
- On app launch, clean up past reminders
- Model: `ActivityReminder` struct with `activityId`, `name`, `date`, `notificationId`

### 4. Visual Hero Cards (Activity Cards)
**PWA**: `.activity-hero` gradient + emoji in `renderActivityCard()`
**iOS target**: `ios-app/SwissPortal/Views/Activities/ActivityCard.swift`

**What to build:**
- Category-based gradient header at top of each activity card
- Gradient colors per category:
  - `animals` → warm gold (#fef3c7 → #fde68a)
  - `museum` → purple (#ede9fe → #c4b5fd)
  - `playground` → green (#dcfce7 → #86efac)
  - `outdoor` → teal (#d1fae5 → #6ee7b7)
  - `nature` → mint (#d1fae5 → #a7f3d0)
  - `indoor-play` → pink (#fce7f3 → #f9a8d4)
  - `event` → blue (#dbeafe → #93c5fd)
  - `seasonal` → red (#fee2e2 → #fca5a5)
  - `cafe` → brown (#fef3c7 → #d97706)
- Large category emoji centered on gradient
- Skip for `stayhome` category cards

### 5. Featured / NEW Badges
**PWA**: Badge rendering in `renderActivityCard()`
**iOS target**: `ActivityCard.swift` + `BadgeView.swift`

**What to build:**
- Parse `featured: true` from activity JSON (add to `Activity.swift` model)
- Parse `addedDate` string field (optional)
- Purple "Featured" / "Empfohlen" badge when `featured == true`
- Green "NEW" / "NEU" badge when `addedDate` is within 30 days
- In "All" filter, sort featured activities to top (`ActivitiesViewModel`)

### 6. Explore View (Map-First Discovery)
**PWA**: `renderExploreView()`, `initExploreMap()`, `getExploreItems()`
**iOS target**: New `ExploreView.swift` in `Views/` + `ExploreViewModel.swift`

**What to build:**
- New tab in ContentView tab bar (🗺️ icon)
- Full MapKit map at top (~300pt height, ~400pt on iPad)
- Filter bar: All / Activities / Events / Deals
- Map annotations colored by type:
  - Activities: green circles (larger if featured)
  - Events: purple circles (only events within next 7 days)
  - Deals: blue/amber circles (city-relevant, month-relevant)
- Events and deals don't have coordinates — place at city center with small random offset
- Card list below map (compact: emoji + name + description + badges)
- Tap activity card → navigate to Activities tab
- Tap event card → navigate to Events tab
- Tap deal card → open URL in Safari
- Auto-request location permission, sort by distance
- User location annotation on map
- `ExploreViewModel`:
  - Reuse `ActivitiesViewModel` data (activities + cityEvents)
  - Filter `DealsData` by city + month
  - `exploreFilter` published property

---

## Model Changes Summary

### `NewsResponse.swift`
```swift
// Add to existing Briefing struct:
struct DailyPick: Codable {
    let activityId: String
    let name: String
    let nameDE: String
    let reason: String
    let reasonDE: String
    let emoji: String
    let indoor: Bool
    let category: String
}

struct WeekendBriefDay: Codable {
    let date: String
    let weatherCode: Int
    let tempMax: Int
    let tempMin: Int
    let description: String?
}

struct WeekendBriefEvent: Codable {
    let name: String
    let nameDE: String?
    let startDate: String
    let endDate: String?
    let toddlerFriendly: Bool?
    let free: Bool?
}

struct WeekendBrief: Codable {
    let saturday: WeekendBriefDay?
    let sunday: WeekendBriefDay?
    let events: [WeekendBriefEvent]
    let satDate: String
    let sunDate: String
}

// Add to Briefing:
let dailyPick: DailyPick?
// Remove: let suggestedActivity (no longer sent)

// Add to NewsResponse:
let weekendBrief: WeekendBrief?
```

### `Activity.swift`
```swift
// Add optional fields:
let featured: Bool?
let addedDate: String?
```

---

## Priority Order

1. **Daily Pick + Weekend Brief** (models + 2 cards) — quick wins, data already in API
2. **Featured badges** — small change, improves Activities view
3. **Visual hero cards** — visual polish, self-contained
4. **Reminders** — requires UNNotificationCenter, most iOS-specific work
5. **Explore view** — new tab + MapKit, largest effort

---

## Testing Notes

- Test Daily Pick with different weather conditions (use `?refresh=true` to get fresh data)
- Weekend Brief is `null` on Sundays — verify it hides correctly
- Featured activities: zoo-zurich, kindercity, wildnispark (Zürich), basel-zoo, basel-lange-erlen, bern-barenpark, bern-gurten, geneva-jardin-botanique, lausanne-aquatis, luzern-verkehrshaus, winterthur-technorama, winterthur-wildpark-bruderhaus
- Explore view: verify events within 7 days show up, deals filter by city + month
