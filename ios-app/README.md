# Today in Switzerland — Native iOS App

A native SwiftUI iOS app for Swiss news, weather, family activities, sunshine/snow forecasts, and more. Consumes the same Cloudflare Worker API as the [PWA](https://swiss-news.pages.dev).

## Requirements

- **macOS** 14+ (Sonoma or later)
- **Xcode** 15.4+ (for iOS 17 SDK, `@Observable`, SwiftData, String Catalogs)
- **iOS** 17.0+ deployment target
- **Apple Developer Account** (free for simulator, $99/year for device + App Store)

## Quick Start (5 minutes)

### 1. Create the Xcode Project

Since Xcode project files (`.xcodeproj`) can't be reliably generated without Xcode, you'll create the project in Xcode and add the source files:

1. Open **Xcode** → File → New → Project
2. Choose **iOS → App**
3. Configure:
   - **Product Name**: `TodayInSwitzerland`
   - **Team**: Your Apple Developer team
   - **Organization Identifier**: `com.todayinswitzerland` (or your own)
   - **Interface**: SwiftUI
   - **Language**: Swift
   - **Storage**: None (we use our own caching)
   - **Include Tests**: Yes
4. Save to a temporary location
5. **Delete** the auto-generated `ContentView.swift` and `TodayInSwitzerlandApp.swift` from the project

### 2. Add Source Files

1. In Xcode's Project Navigator, right-click the `TodayInSwitzerland` group
2. Choose **Add Files to "TodayInSwitzerland"...**
3. Navigate to this repo's `TodayInSwitzerland/` folder
4. Select **all subfolders**: `App/`, `Models/`, `Services/`, `ViewModels/`, `Views/`, `Extensions/`, `Resources/`, `Preview Content/`
5. Ensure **"Copy items if needed"** is checked
6. Ensure **"Create groups"** is selected
7. Click **Add**

### 3. Add Widget Extension

1. File → New → Target → **Widget Extension**
2. Name: `TodayInSwitzerlandWidget`
3. **Uncheck** "Include Configuration App Intent"
4. Delete the auto-generated widget files
5. Add the files from `TodayInSwitzerlandWidget/` folder

### 4. Add Test Files

1. In the `TodayInSwitzerlandTests` group, delete the auto-generated test file
2. Add files from `TodayInSwitzerlandTests/` folder

### 5. Configure App Group (for Widget)

1. Select the project in Navigator → **TodayInSwitzerland** target → Signing & Capabilities
2. Click **+ Capability** → App Groups
3. Add group: `group.com.todayinswitzerland`
4. Repeat for the **TodayInSwitzerlandWidget** target

### 6. Configure Info.plist

Add these entries for location permission:
- `NSLocationWhenInUseUsageDescription`: "Used to show nearby activities and sort destinations by distance"

### 7. Build & Run

- Select an **iOS 17+ Simulator** (iPhone 15 recommended)
- Press **Cmd+R** to build and run
- The app will fetch live data from the Cloudflare Worker API

## Architecture

```
MVVM + Services
├── Models (Codable)     → Match Cloudflare Worker JSON exactly
├── Services             → APIClient (actor), CacheManager (actor), LocationManager
├── ViewModels           → @Observable classes, one per view
├── Views                → SwiftUI views, composable components
├── Extensions           → Color theme, Date helpers, Location formatting
└── Resources            → Static bundled data (Deals, Destinations, Highlights)
```

### Zero External Dependencies

Everything uses Apple frameworks:
- **MapKit** → Maps (replaces Leaflet)
- **Swift Charts** → Weather charts, snowfall bars
- **SwiftData** → Local caching (replaces localStorage)
- **WidgetKit** → Home screen widgets
- **CoreLocation** → "Near me" features
- **ShareLink** → Native sharing

## API Endpoints (Cloudflare Worker)

The app consumes these existing endpoints:

| Endpoint | View | Cache TTL |
|----------|------|-----------|
| `GET /` | News | 2 hours |
| `GET /activities` | Activities | 2 hours |
| `GET /lunch` | Lunch | 30 min |
| `GET /weekend` | Weekend Planner | 1 hour |
| `GET /sunshine` | Sunshine | 30 min |
| `GET /snow` | Snow | 30 min |

**Base URL**: `https://swiss-news-worker.swissnews.workers.dev`

All endpoints accept `?lang={en|de}&city={cityId}`. Sunshine and Snow are always Zürich-based.

### Client-Side Fallback

If the worker is rate-limited by Open-Meteo, the app fetches directly from the Open-Meteo API (same pattern as the PWA).

## Project Structure

```
TodayInSwitzerland/
├── App/
│   ├── TodayInSwitzerlandApp.swift    # @main entry point
│   ├── AppState.swift                  # Global state (city, language, theme, saved items)
│   └── ContentView.swift               # TabView with 5 tabs
│
├── Models/
│   ├── City.swift                      # City enum + AppLanguage
│   ├── NewsResponse.swift              # News, Weather, Transport, Holiday models
│   ├── Activity.swift                  # Activity, CityEvent, filters
│   ├── SunshineResponse.swift          # Sunshine destinations + filters
│   ├── SnowResponse.swift              # Snow resorts + filters
│   ├── LunchResponse.swift             # Lunch spots + filters
│   ├── WeekendResponse.swift           # Weekend planner models
│   └── Deal.swift                      # Deals + filters
│
├── Services/
│   ├── APIClient.swift                 # URLSession actor, all fetch methods, retry logic
│   ├── CacheManager.swift              # File-based cache with TTL
│   └── LocationManager.swift           # CLLocationManager wrapper
│
├── ViewModels/                         # One @Observable class per view
│   ├── NewsViewModel.swift
│   ├── ActivitiesViewModel.swift
│   ├── EventsViewModel.swift
│   ├── SunshineViewModel.swift
│   ├── SnowViewModel.swift
│   ├── LunchViewModel.swift
│   ├── WeekendViewModel.swift
│   └── DealsViewModel.swift
│
├── Views/
│   ├── News/                           # 7 files (NewsView, cards, weather, transport)
│   ├── Activities/                     # 8 files (list, map, filters, surprise me)
│   ├── Events/                         # 4 files (calendar grid, day detail)
│   ├── Sunshine/                       # 5 files (map, cards, hourly timeline)
│   ├── Snow/                           # 4 files (map, cards, powder alert)
│   ├── Lunch/                          # 4 files (map, cards, filters)
│   ├── Weekend/                        # 2 files (day cards)
│   ├── Deals/                          # 2 files (cards, filter)
│   ├── Settings/                       # 1 file
│   └── Shared/                         # 5 files (loading, error, badges, filters, sort)
│
├── Extensions/
│   ├── Color+Theme.swift               # App color palette
│   ├── Date+Helpers.swift              # Date parsing, formatting, calendar
│   ├── CLLocation+Distance.swift       # Distance formatting
│   └── String+Localization.swift       # Localization helper
│
├── Resources/
│   ├── DealsData.swift                 # 28 bundled deals (static, no API)
│   ├── SunshineDestinations.swift      # 29 destination configs (client fallback)
│   ├── SnowResorts.swift               # 22 resort configs (client fallback)
│   └── DestinationHighlights.swift     # 57 curated attractions per destination
│
└── Preview Content/
    └── PreviewData.swift               # Sample data for SwiftUI previews

TodayInSwitzerlandWidget/
├── WidgetBundle.swift                  # Widget entry point
├── TodayWidget.swift                   # Small/Medium: weather + headline + transport
├── SunshineWidget.swift                # Medium: top 3 sunny destinations
└── WidgetDataProvider.swift            # Shared API fetching for widgets

TodayInSwitzerlandTests/
├── ModelDecodingTests.swift            # JSON decoding + model logic (30+ tests)
└── ViewModelTests.swift                # ViewModel filtering/sorting (20+ tests)
```

## Features (Matching PWA)

### Tab 1: News
- 5 categories with counts (Top Stories, Politics, Disruptions, Events, Culture, Local)
- Compact weather in header (tap for hourly forecast sheet)
- Transport disruptions widget
- "This Day in History" banner
- Trending topic highlight
- Pull-to-refresh
- Share summary via native ShareLink

### Tab 2: Activities
- 100+ curated family activities per city
- 8 filters: All, Near Me, Indoor, Outdoor, Free, Saved, Seasonal, Stay Home
- Age filter: All / 2-3 / 4-5 years
- MapKit map with activity pins
- "Surprise Me!" random picker
- Custom activity creation
- 40 stay-home activities (sensory, art, active, pretend, kitchen)

### Tab 3: Events
- Interactive calendar grid with colored dots
- Day detail panel (holidays, festivals, school holidays, recurring)
- 7 event type filters
- Weather-based activity suggestions for today

### Tab 4: Weather (Sunshine / Snow)
- **Sunshine**: 29 destinations, weekend forecast, MapKit map, hourly timeline, destination highlights
- **Snow**: 22 ski resorts, weekly forecast, 7-day snowfall chart, powder alerts
- Sort by value or by distance (uses geolocation)
- Filter by intensity level

### Tab 5: More
- Weekend Planner (smart Sat/Sun activity suggestions)
- Lunch (OSM restaurants with map, ratings, filters)
- Deals & Free (28 curated money-saving tips)
- Settings (city, language, theme, holidays)

### Widgets
- **Today Widget** (Small/Medium): Weather + headline + transport status
- **Sunshine Widget** (Medium): Top 3 sunniest weekend destinations

## Localization

Full English/German support. All API responses include `name`/`nameDE` pairs — the app picks based on `AppState.language`. Static strings use helper methods.

## Caching Strategy

- **File-based** (Caches directory) with TTL per endpoint
- On launch: show cached data immediately, fetch fresh in background
- Pull-to-refresh bypasses cache
- Cache keys: `news-{city}-{lang}`, `activities-{city}`, `sunshine-v2`, `snow-v1`

## Testing

```bash
# Run all tests in Xcode
Cmd+U

# Or via command line (requires xcodebuild)
xcodebuild test -scheme TodayInSwitzerland -destination 'platform=iOS Simulator,name=iPhone 15'
```

### Test Coverage

- **ModelDecodingTests** (30+ tests): Verifies all Codable models decode from real API JSON shapes, tests computed properties (weather symbols, free detection, age filtering, snowfall levels), date helpers, city properties, static data integrity
- **ViewModelTests** (20+ tests): Tests filtering logic, category selection, month navigation, date selection, deals filtering, saved items, localization

## Troubleshooting

### "No such module" errors
Make sure all `.swift` files are added to the correct target. Select a file → File Inspector → check "Target Membership" for `TodayInSwitzerland`.

### Widget not showing data
1. Ensure both targets share the `group.com.todayinswitzerland` App Group
2. The widget reads city/language from the shared `UserDefaults(suiteName:)` — ensure the main app writes to the same suite

### API not responding
The Cloudflare Worker base URL is hardcoded in `APIClient.swift`. If you redeploy the worker to a different URL, update it there.

### Maps not showing
MapKit requires no API key, but the simulator must have network access. On device, ensure Location permission is granted.

## Future Enhancements (Phase 5)

These are planned but not yet implemented:
- Siri Shortcuts ("Where is sun this weekend?")
- Live Activities on Dynamic Island (transport disruptions)
- Spotlight indexing for activities and events
- Push notifications (requires backend APNs endpoint)
- Apple Pay donations (via Stripe)
