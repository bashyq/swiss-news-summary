# iOS App Sync — Features to Implement

This document tracks PWA features that need to be ported to the SwiftUI iOS app on branch `claude/plan-ios-app-4aOQo` under `ios-app/`.

## API-Side (Already Available — No iOS Work Needed)

These features were added to the Cloudflare Worker and are automatically available to the iOS app via existing API calls:

| Feature | Endpoint | Field | Notes |
|---------|----------|-------|-------|
| Daily Pick | `GET /` | `briefing.dailyPick` | Weather+time-aware activity recommendation with `reason`/`reasonDE` text |
| Featured Activities | `GET /activities` | `featured: true` | 13 activities across all cities flagged as featured |
| News Expansion | `GET /` | `categories.*` | 8-10 items per category. When `lang=en`, all items (including local/culture/events from German feeds) are translated via Claude. Each item has `detail` field (1 sentence, shown on tap). |
| Deals API | `GET /deals` | `deals[]` | Deals/free entry data now served from worker endpoint. iOS should fetch from `/deals` instead of hardcoding `DealsData.swift`. Same JSON shape as before. |
| Sunshine Highlights | `GET /sunshine` | `destinations[].highlights[]` | Each destination now includes `highlights` array with toddler-friendly attractions. iOS can drop `DestinationHighlights.swift` and use API data directly. |
| Activities Expanded | `GET /activities` | `activities[]` | Now 94 base activities (was 52). 20km radius per city. No model changes — same JSON shape, just more items. |
| Transport Multi-Station | `GET /` | `transport` | Zürich now fetches from Stadelhofen + Hardbrücke (was HB only). Deduplicated. Other cities unchanged. No model change — same JSON shape. |

The iOS `NewsViewModel` and `ActivitiesViewModel` just need to parse these new fields from the existing JSON responses.

---

## ⚠️ PWA Changes — iOS Should NOT Implement

These features were removed or changed in the PWA and the iOS app should match:

| Change | Details |
|--------|---------|
| **Weekend Brief removed from News** | The `.weekend-brief` card is no longer rendered on the news page. iOS should NOT build `WeekendBriefCard.swift`. The `weekendBrief` field is still in the API response but the PWA ignores it. |
| **Age filter removed** | Activity age filters (All ages / 2-3 / 4-5) have been removed from the PWA. iOS should NOT implement age filtering in `ActivitiesViewModel`. |

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

### 2. News View Layout: Trending Below History
**PWA**: Trending banner renders in header, right after "This Day in History"
**iOS target**: `NewsView.swift`

**What to build:**
- `trending` object from news API: `{ topic, topicDE, url }`
- Show as compact card right below "This Day in History" (before briefing card)
- Left-border accent style with subtle gradient background
- Tap → open URL in Safari
- Only visible on News view

### 3. Lunch Filter Rework (Multi-Select + Cuisine Dropdown)
**PWA**: `renderLunchView()` in `app.js` — multi-toggle pills + `<select>` dropdown
**iOS target**: `LunchView.swift` + `LunchViewModel.swift`

**What to build:**
- **Toggle pills** (multi-select, combine freely):
  - Near Me — uses CoreLocation, filters to within 2km
  - Open — filters `openForLunch === true`
  - Terrace — filters `outdoorSeating === true`
  - Saved — filters to saved restaurants
- **Cuisine picker** (single-select, replaces old Vegi filter):
  - All cuisines (default)
  - Italian, Asian, Kebab, Café, Fast Food, International
  - Filters on `cuisineCategory` field from API
- Filters stack: e.g. Near Me + Open + Italian = open Italian restaurants within 2km
- SwiftUI: Use `Toggle`-style buttons or `Chip` pattern for pills, `Picker`/`Menu` for cuisine

### 4. Activity Reminders
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

### 5. Visual Hero Cards (Activity Cards)
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

### 6. Featured / NEW Badges
**PWA**: Badge rendering in `renderActivityCard()`
**iOS target**: `ActivityCard.swift` + `BadgeView.swift`

**What to build:**
- Parse `featured: true` from activity JSON (add to `Activity.swift` model)
- Parse `addedDate` string field (optional)
- Purple "Featured" / "Empfohlen" badge when `featured == true`
- Green "NEW" / "NEU" badge when `addedDate` is within 30 days
- In "All" filter, sort featured activities to top (`ActivitiesViewModel`)

### 7. Explore View (Map-First Discovery)
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
  - Fetch deals from `/deals` endpoint
  - `exploreFilter` published property

### 8. Activity Filter Order
**PWA**: Filter pills in `renderActivitiesView()`
**iOS target**: `ActivitiesView.swift`

**What to build:**
- Filter pill order: All, Near Me, Indoor, Outdoor, Stay Home, Free, Seasonal, Saved
- No age filter (removed from PWA)

### 9. Menu / Tab Order
**PWA**: Hamburger menu in `renderHeader()`
**iOS target**: `ContentView.swift` tab bar

**Recommended tab order:**
- News, What to do, Explore, Sunshine, Snow, Where to eat, Weekend, Events, Deals
- Consider bottom tab bar with 5 primary items + "More" for overflow

---

## Design System — Color Tokens for iOS

The PWA now uses a centralized color system. iOS should match:

### Map Marker Colors (`MAP_COLORS`)
```swift
struct MapColors {
    static let green = Color(hex: "#22c55e")    // Activities
    static let purple = Color(hex: "#a855f7")   // Events, Zürich baseline
    static let amber = Color(hex: "#f59e0b")    // Sunshine, deals
    static let blue = Color(hex: "#3b82f6")     // Deals
    static let sky = Color(hex: "#60a5fa")      // Partly sunny, snow moderate
    static let navy = Color(hex: "#1e40af")     // Snow heavy
    static let gray = Color(hex: "#6b7280")     // Cloudy, snow light
    static let slate = Color(hex: "#94a3b8")    // Snow light alt
}
```

### Category Border Colors
```swift
struct CategoryColors {
    static let animals = Color(hex: "#f59e0b")   // amber
    static let museum = Color(hex: "#a855f7")    // purple
    static let playground = Color(hex: "#22c55e") // green
    static let outdoor = Color(hex: "#10b981")   // emerald
    static let nature = Color(hex: "#34d399")    // teal
    static let indoorPlay = Color(hex: "#f472b6") // pink
    static let event = Color(hex: "#3b82f6")     // blue
    static let seasonal = Color(hex: "#ef4444")  // red
    static let stayhome = Color(hex: "#6b7280")  // gray
    static let cafe = Color(hex: "#f97316")      // orange
}
```

### Badge Colors
```swift
// Type badges
static let badgeFree = Color(hex: "#22c55e")       // green — free entry
static let badgeDeal = Color(hex: "#3b82f6")       // blue — deals
static let badgeTip = Color(hex: "#f59e0b")        // amber — tips
static let badgeFeatured = Color(hex: "#a855f7")   // purple — featured
static let badgeNew = Color(hex: "#22c55e")        // green — new (< 30 days)
static let badgeSchoolHoliday = Color(hex: "#f59e0b") // amber
```

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

struct Trending: Codable {
    let topic: String
    let topicDE: String?
    let url: String?
}

// Add to Briefing:
let dailyPick: DailyPick?
// Remove: let suggestedActivity (no longer sent)

// Add to NewsResponse:
let trending: Trending?
// Note: weekendBrief field still exists in API but PWA no longer renders it — skip in iOS
```

### `Activity.swift`
```swift
// Add optional fields:
let featured: Bool?
let addedDate: String?
// Note: No age filter — minAge/maxAge fields exist but are not used for filtering
```

### `NewsItem.swift`
```swift
// Add optional field:
let detail: String?  // 1-sentence expansion, shown on tap
```

---

## Priority Order

1. **Daily Pick + Trending** (models + 2 cards) — quick wins, data already in API
2. **Lunch filter rework** — multi-select pills + cuisine dropdown
3. **Featured badges** — small change, improves Activities view
4. **Visual hero cards** — visual polish, self-contained
5. **Reminders** — requires UNNotificationCenter, most iOS-specific work
6. **Explore view** — new tab + MapKit, largest effort
7. **Menu/filter order alignment** — cosmetic, do alongside other work

---

## Testing Notes

- Test Daily Pick with different weather conditions (use `?refresh=true` to get fresh data)
- Featured activities: zoo-zurich, kindercity, wildnispark (Zürich), basel-zoo, basel-lange-erlen, bern-barenpark, bern-gurten, geneva-jardin-botanique, lausanne-aquatis, luzern-verkehrshaus, winterthur-technorama, winterthur-wildpark-bruderhaus
- Explore view: verify events within 7 days show up, deals filter by city + month
- Lunch filters: test combining Near Me + Open, verify cuisine filter matches `cuisineCategory` values
- Activities: 94 base activities now (was 52), verify all render correctly
- Trending: verify it shows below history and only on news view
- Local news tab: should be in English when `lang=en` (worker now translates German RSS via Claude)
