# Native iOS App Plan — "Today in Switzerland"

## Approach: SwiftUI + Existing Cloudflare Worker API

Build a native SwiftUI app that consumes the existing Cloudflare Worker REST API. The backend stays unchanged — all 8 endpoints already return clean JSON. The iOS app replaces the PWA frontend with native UI components, navigation, maps, and system integrations.

### Why SwiftUI (not React Native / Flutter / WebView wrapper)

- **True native feel**: Native navigation, gestures, animations, and HIG compliance
- **MapKit**: Replaces Leaflet with native Apple Maps (better performance, no JS bridge)
- **WidgetKit**: Home screen widgets (weather + headline) — replaces the widget.html page
- **System integration**: Spotlight search, Siri Shortcuts, Live Activities, Share extensions
- **Performance**: No JS runtime overhead, native scrolling/rendering
- **App Store presence**: Discoverability beyond the web
- **Offline**: SwiftData for local persistence (replaces localStorage)

---

## Architecture

```
┌─────────────────────────────────────────────────┐
│  iOS App (SwiftUI)                              │
│                                                 │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐     │
│  │  Views    │  │ ViewModels│  │ Services │     │
│  │ (SwiftUI)│→ │ (Observable)│→│ (Network)│    │
│  └──────────┘  └──────────┘  └──────────┘     │
│                                    │            │
│  ┌──────────┐  ┌──────────┐      │            │
│  │ Models   │  │  Cache   │      │            │
│  │ (Codable)│  │(SwiftData)│      │            │
│  └──────────┘  └──────────┘      │            │
│                                    │            │
│  ┌──────────┐  ┌──────────┐      │            │
│  │ WidgetKit│  │ MapKit   │      │            │
│  └──────────┘  └──────────┘      │            │
└────────────────────────────────────┼────────────┘
                                     │
                          HTTPS (JSON)│
                                     ▼
                     ┌──────────────────────────┐
                     │  Cloudflare Worker API    │
                     │  (unchanged — 8 endpoints)│
                     └──────────────────────────┘
```

### Pattern: MVVM

- **Models**: Codable structs matching the existing JSON response shapes
- **ViewModels**: `@Observable` classes, one per major view, handle data fetching and state
- **Views**: SwiftUI views, composable components
- **Services**: Network layer (URLSession + async/await), location manager, cache manager

---

## Project Structure

```
ios/
├── TodayInSwitzerland.xcodeproj
├── TodayInSwitzerland/
│   ├── App/
│   │   ├── TodayInSwitzerlandApp.swift       # App entry point, tab navigation
│   │   ├── AppState.swift                     # Global app state (city, lang, theme)
│   │   └── ContentView.swift                  # Root view with TabView
│   │
│   ├── Models/                                # Codable structs (match API JSON)
│   │   ├── NewsResponse.swift                 # Weather, transport, holidays, categories
│   │   ├── Activity.swift                     # Activity + CityEvent models
│   │   ├── SunshineResponse.swift             # Destinations, forecast, weekend dates
│   │   ├── SnowResponse.swift                 # Resorts, snowfall, week dates
│   │   ├── LunchResponse.swift                # Restaurant spots
│   │   ├── WeekendResponse.swift              # Weekend planner with plans
│   │   └── Deal.swift                         # Deals (static, bundled in app)
│   │
│   ├── Services/
│   │   ├── APIClient.swift                    # URLSession wrapper, base URL, error handling
│   │   ├── CacheManager.swift                 # SwiftData-backed cache with TTL
│   │   ├── LocationManager.swift              # CLLocationManager wrapper
│   │   └── Networking.swift                   # Request builder, retry logic
│   │
│   ├── ViewModels/
│   │   ├── NewsViewModel.swift                # Fetch + cache news, manage tab state
│   │   ├── ActivitiesViewModel.swift          # Fetch activities, filter/sort/search
│   │   ├── EventsViewModel.swift              # Calendar state, day selection, filters
│   │   ├── SunshineViewModel.swift            # Fetch sunshine, sort/filter, client fallback
│   │   ├── SnowViewModel.swift                # Fetch snow, sort/filter, client fallback
│   │   ├── LunchViewModel.swift               # Fetch restaurants, filter/rate
│   │   ├── WeekendViewModel.swift             # Fetch weekend plan, shuffle
│   │   └── DealsViewModel.swift               # Filter static deals data
│   │
│   ├── Views/
│   │   ├── News/
│   │   │   ├── NewsView.swift                 # News tab root: weather header + tabs
│   │   │   ├── NewsCategoryTab.swift          # Horizontal scrollable category tabs
│   │   │   ├── NewsCard.swift                 # Individual article card
│   │   │   ├── WeatherCompactView.swift       # Compact weather (temp + icon)
│   │   │   ├── WeatherDetailSheet.swift       # Expanded weather with hourly chart
│   │   │   ├── TransportWidget.swift          # Transport disruptions inline
│   │   │   └── HistoryBanner.swift            # "This Day in History" banner
│   │   │
│   │   ├── Activities/
│   │   │   ├── ActivitiesView.swift           # Activities tab root: map + list
│   │   │   ├── ActivityCard.swift             # Activity card with save/heart
│   │   │   ├── ActivityFilterBar.swift        # Filter chips (all/near/indoor/outdoor/free/saved)
│   │   │   ├── AgeFilterPicker.swift          # Segmented control: All / 2-3 / 4-5
│   │   │   ├── ActivityMapView.swift          # MapKit map with activity pins
│   │   │   ├── SurpriseMeSheet.swift          # Random activity modal
│   │   │   ├── AddActivitySheet.swift         # Custom activity form
│   │   │   └── StayHomeSection.swift          # Stay-home activities grid
│   │   │
│   │   ├── Events/
│   │   │   ├── EventsView.swift               # Calendar + day detail + event list
│   │   │   ├── CalendarGrid.swift             # Month grid with colored dots
│   │   │   ├── DayDetailView.swift            # Selected day panel
│   │   │   └── EventCard.swift                # Event/festival card
│   │   │
│   │   ├── Sunshine/
│   │   │   ├── SunshineView.swift             # Map + ranked destination list
│   │   │   ├── SunshineMapView.swift          # MapKit with circle annotations
│   │   │   ├── SunshineCard.swift             # Expandable destination card
│   │   │   ├── HourlyTimelineView.swift       # Hourly sunshine bar (6-20h)
│   │   │   └── SunnyEscapeBanner.swift        # "Nearest sunny escape" nudge
│   │   │
│   │   ├── Snow/
│   │   │   ├── SnowView.swift                 # Map + ranked resort list
│   │   │   ├── SnowMapView.swift              # MapKit with circle annotations
│   │   │   ├── SnowCard.swift                 # Resort card with 7-day bars
│   │   │   └── PowderAlertBanner.swift        # Fresh powder alert
│   │   │
│   │   ├── Lunch/
│   │   │   ├── LunchView.swift                # Map + restaurant list
│   │   │   ├── LunchMapView.swift             # MapKit with restaurant pins
│   │   │   ├── LunchCard.swift                # Restaurant card with rating
│   │   │   └── LunchFilterBar.swift           # Filter chips
│   │   │
│   │   ├── Weekend/
│   │   │   ├── WeekendView.swift              # Sat/Sun cards with weather + plans
│   │   │   └── WeekendDayCard.swift           # Day card with morning/afternoon
│   │   │
│   │   ├── Deals/
│   │   │   ├── DealsView.swift                # Deals list with filter bar
│   │   │   └── DealCard.swift                 # Individual deal card
│   │   │
│   │   └── Shared/
│   │       ├── LoadingView.swift              # Loading spinner/skeleton
│   │       ├── ErrorView.swift                # Error state with retry
│   │       ├── BadgeView.swift                # Reusable badge (free, distance, etc.)
│   │       ├── FilterChip.swift               # Reusable filter chip button
│   │       └── SortPicker.swift               # Sort toggle (by value / by distance)
│   │
│   ├── Extensions/
│   │   ├── Color+Theme.swift                  # App color palette (light/dark)
│   │   ├── Date+Helpers.swift                 # Date formatting, weekend calc
│   │   ├── CLLocation+Distance.swift          # Haversine distance helper
│   │   └── String+Localization.swift          # i18n helper
│   │
│   ├── Resources/
│   │   ├── Assets.xcassets                    # App icon, colors, images
│   │   ├── Localizable.xcstrings              # String catalog (en/de)
│   │   ├── Deals.json                         # Bundled deals data (static)
│   │   └── Info.plist                         # Permissions, URL schemes
│   │
│   └── Preview Content/
│       └── PreviewData.swift                  # Sample data for SwiftUI previews
│
├── TodayInSwitzerlandWidget/                  # WidgetKit extension
│   ├── TodayWidget.swift                      # Small/medium widget: weather + headline
│   ├── SunshineWidget.swift                   # Medium widget: top 3 sunny destinations
│   └── WidgetDataProvider.swift               # Timeline provider, shared API client
│
└── TodayInSwitzerlandTests/
    ├── APIClientTests.swift
    ├── ModelDecodingTests.swift
    └── ViewModelTests.swift
```

---

## Implementation Phases

### Phase 1: Foundation + News View

**Goal**: Buildable app with core navigation and the primary news view.

1. **Xcode project setup**
   - Create SwiftUI app target (iOS 17+ minimum)
   - Configure project structure (folders above)
   - Add `.gitignore` for Xcode artifacts

2. **Models layer**
   - Define all Codable structs matching the 8 API response shapes
   - Use `CodingKeys` where JSON keys differ from Swift conventions
   - Write unit tests to decode sample JSON payloads

3. **Network layer**
   - `APIClient` with base URL `https://swiss-news-worker.swissnews.workers.dev`
   - Generic `fetch<T: Decodable>(_ endpoint: String, query: [String: String]) async throws -> T`
   - Retry logic (3 retries with exponential backoff for network errors)
   - Error types: `networkError`, `decodingError`, `serverError(statusCode)`

4. **App state**
   - `@Observable AppState`: city, language, theme (persisted via `@AppStorage`)
   - City enum with display names, coordinates, station names
   - Language enum (en, de)

5. **Tab navigation**
   - `TabView` with 5 tabs: News, Activities, Events, Sunshine/Snow, More
   - SF Symbols for tab icons
   - "More" tab houses: Weekend, Lunch, Deals, Settings

6. **News view**
   - `NewsViewModel`: fetch news, manage selected category tab
   - Weather compact header (tappable → sheet with hourly chart)
   - Horizontal scrollable category tabs with item counts
   - News cards: headline, summary, source, time-ago, sentiment badge
   - Transport disruptions widget (collapsible section)
   - History banner under title
   - Pull-to-refresh (native `.refreshable`)
   - Share button (native `ShareLink`)

7. **Caching**
   - `CacheManager` using SwiftData: store API responses with timestamp
   - TTL: 2 hours for news, 30 min for sunshine/snow
   - On launch: show cached data immediately, fetch fresh in background

8. **Theming**
   - Light/dark mode following system preference (with manual override)
   - Custom color palette in `Color+Theme.swift`

### Phase 2: Activities + Events

**Goal**: Second and third major views with maps and calendar.

9. **Activities view**
   - `ActivitiesViewModel`: fetch activities, manage filters and age filter
   - Filter bar: All, Near Me, Indoor, Outdoor, Free, Saved, Seasonal, Stay Home
   - Age segmented control: All / 2-3 / 4-5
   - Activity cards with heart button (saved to SwiftData)
   - MapKit map with annotation pins (tappable → scroll to card)
   - "Surprise Me" button → sheet with random weather-appropriate activity
   - Custom activity form (sheet)
   - Stay-home section with subcategory tabs

10. **Location services**
    - `LocationManager`: request when-in-use authorization
    - Distance calculation (CLLocation.distance)
    - "Near Me" filter sorts by distance, shows distance badges
    - Sort by distance option for sunshine/snow/activities

11. **Events calendar view**
    - `EventsViewModel`: manage selected month, selected day, filters
    - Calendar grid: LazyVGrid of days, colored dots for event types
    - Month navigation (< > buttons)
    - Day detail panel (holidays, school holidays, festivals, recurring, weather picks)
    - Event list with filter bar below calendar
    - Highlight today, auto-select today on load

### Phase 3: Sunshine + Snow

**Goal**: Weather forecast views with maps and ranked lists.

12. **Sunshine view**
    - `SunshineViewModel`: fetch sunshine data, manage sort/filter
    - MapKit map with circle overlays (color/size by sunshine hours)
    - Zürich baseline card pinned at top (purple accent)
    - "Nearest sunny escape" banner when Zürich < 6h
    - Expandable cards with:
      - Daily forecast (3 days)
      - Hourly timeline bar (custom SwiftUI view)
      - Destination highlights (bundled data from DEST_HIGHLIGHTS)
      - Google Maps links (open in Maps app)
    - Sort: sunshine hours / distance
    - Filter: all / sunny / partly / cloudy
    - Collapse to top 10 with "Show all" button
    - **Client-side fallback**: Direct Open-Meteo fetch if worker fails

13. **Snow view**
    - `SnowViewModel`: fetch snow data, manage sort/filter
    - MapKit map with circle overlays (color/size by snowfall)
    - 7-day snowfall chart (custom SwiftUI bars)
    - Fresh powder alert banner (>40cm)
    - Badges: drive time, altitude, snow depth
    - Sort: snowfall / distance
    - Filter: all / heavy / moderate / light
    - **Client-side fallback**: Direct Open-Meteo fetch if worker fails

### Phase 4: Remaining Views + Polish

**Goal**: Complete feature parity with PWA.

14. **Weekend planner**
    - Saturday + Sunday cards with weather icons
    - Morning + afternoon activity suggestions
    - "Shuffle" button for new picks

15. **Lunch view**
    - Restaurant list + MapKit map
    - Filter: all / saved / open / outdoor / vegetarian
    - 5-star rating (stored locally in SwiftData)
    - "Surprise Me" random pick
    - Custom restaurant form

16. **Deals view**
    - Static data bundled in `Deals.json`
    - Filter: all / free / deals / tips
    - City-aware + month-aware filtering
    - Cards with badge (free/deal/tip), open URL in SFSafariViewController

17. **Settings**
    - City picker (7 cities)
    - Language toggle (en/de)
    - Theme toggle (light/dark/system)
    - Upcoming holidays list
    - App version, about, feedback link

18. **Internationalization**
    - `Localizable.xcstrings` with all 150+ strings (en/de)
    - Server returns both `name` and `nameDE` — pick based on `AppState.language`
    - Number/date formatting respects locale

### Phase 5: Native Enhancements (Beyond PWA)

**Goal**: Features only possible (or significantly better) on native iOS.

19. **WidgetKit home screen widgets**
    - **Small widget**: Current weather + temperature for selected city
    - **Medium widget**: Weather + top headline + transport status
    - **Medium sunshine widget**: Top 3 sunniest destinations this weekend
    - Shared `APIClient` via App Group for widget data access
    - Timeline refresh every 30 minutes

20. **Push notifications** (future — requires backend work)
    - Transport disruption alerts
    - Fresh powder alerts (>40cm snowfall)
    - Sunshine opportunity alerts (when nearby destination has >8h sun)
    - Uses APNs via Cloudflare Worker (new endpoint needed)

21. **Siri Shortcuts**
    - "What's the weather in Zürich?"
    - "Where is sun this weekend?"
    - "What's happening today?"
    - App Intents framework

22. **Live Activities** (Dynamic Island)
    - Active transport disruptions on commute route
    - Weekend countdown with weather preview

23. **Spotlight integration**
    - Index activities, events, destinations for system search
    - CSSearchableItem for each activity/restaurant

24. **Apple Maps integration**
    - Open directions in Apple Maps (not Google Maps)
    - "Find playgrounds nearby" → MapKit search
    - Walking/driving time estimates via MKDirections

25. **Haptics**
    - Subtle haptic feedback on filter selection, pull-to-refresh, surprise me
    - UIImpactFeedbackGenerator for interactions

---

## Technical Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Min iOS version | iOS 17 | `@Observable` macro, modern SwiftUI APIs, SwiftData |
| Navigation | `TabView` + `NavigationStack` | Native tab bar + push navigation within each tab |
| Maps | MapKit (SwiftUI) | Native, no dependency, better iOS integration than Leaflet |
| Local storage | SwiftData + `@AppStorage` | SwiftData for cache/saved items, AppStorage for preferences |
| Networking | URLSession + async/await | No dependency needed, built-in retry/caching support |
| Charts | Swift Charts | Native framework for sunshine timeline, snow bars, weather hourly |
| i18n | String Catalogs | Xcode 15+ native localization |
| Image loading | AsyncImage | Built-in, sufficient for weather icons |
| Dependencies | Zero external | MapKit, SwiftData, Swift Charts, WidgetKit — all Apple frameworks |

### Zero External Dependencies

The app needs no third-party packages:
- **Maps**: MapKit (replaces Leaflet)
- **Charts**: Swift Charts (replaces custom HTML/CSS bars)
- **Networking**: URLSession (replaces fetch API)
- **Persistence**: SwiftData + @AppStorage (replaces localStorage)
- **Widgets**: WidgetKit (replaces widget.html)
- **Location**: CoreLocation (replaces navigator.geolocation)
- **Sharing**: ShareLink (replaces navigator.share)
- **Browser**: SFSafariViewController (for external links)

---

## Data Model Mapping (API JSON → Swift)

Key structs that map directly to existing API responses:

```swift
// GET / → NewsResponse
struct NewsResponse: Codable {
    let weather: Weather
    let transport: Transport
    let holidays: [Holiday]
    let schoolHolidays: [SchoolHoliday]
    let history: HistoryFact
    let categories: NewsCategories
    let trending: TrendingTopic?
    let briefing: Briefing?
    let city: CityInfo
    let timestamp: String
}

// GET /activities → ActivitiesResponse
struct ActivitiesResponse: Codable {
    let activities: [Activity]
    let cityEvents: [CityEvent]
    let weather: Weather
    let city: CityInfo
}

// GET /sunshine → SunshineResponse
struct SunshineResponse: Codable {
    let destinations: [SunshineDestination]
    let weekendDates: WeekendDates
    let timestamp: String
}

// GET /snow → SnowResponse
struct SnowResponse: Codable {
    let destinations: [SnowDestination]
    let weekDates: WeekDates
    let timestamp: String
}
```

---

## Migration Strategy

The iOS app and PWA can coexist:
- **Same backend**: Both consume the same Cloudflare Worker API
- **PWA stays live**: Users without iOS keep using swiss-news.pages.dev
- **Smart App Banner**: Add `<meta name="apple-itunes-app">` to PWA HTML to prompt iOS users to install the native app
- **Universal Links**: Configure so `swiss-news.pages.dev` URLs open in the native app when installed
- **Data migration**: On first native app launch, no migration needed — user starts fresh (no way to transfer localStorage to app)

---

## Estimated Scope

| Phase | Views/Features | Files |
|-------|---------------|-------|
| Phase 1 | News, navigation, caching, theming | ~25 files |
| Phase 2 | Activities, Events, location | ~15 files |
| Phase 3 | Sunshine, Snow, maps | ~12 files |
| Phase 4 | Weekend, Lunch, Deals, Settings, i18n | ~12 files |
| Phase 5 | Widgets, Siri, Live Activities, Spotlight | ~8 files |
| **Total** | **Full feature parity + native extras** | **~72 files** |
