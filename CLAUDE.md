# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

"Today in Switzerland" is a PWA + native iOS app that aggregates Swiss news, weather, transport disruptions, holidays, historical facts, family activities for toddlers (ages 2-5), weekend sunshine/snow forecasts, and deals. It uses Claude AI for news categorization and consists of a modular Cloudflare Worker backend (12 modules), a 3-file frontend (HTML shell + CSS + JS), and a SwiftUI iOS app.

**GitHub:** https://github.com/bashyq/swiss-news-summary

## Deployment

```bash
# Deploy worker (backend API)
cd C:\Users\bashy\Documents\swiss-news-summary\worker && npx wrangler deploy

# Deploy frontend (Cloudflare Pages)
cd C:\Users\bashy\Documents\swiss-news-summary && npx wrangler pages deploy frontend --project-name=swiss-news --branch=main
```

**URLs:**
- Frontend: `https://swiss-news.pages.dev`
- Worker API: `https://swiss-news-worker.swissnews.workers.dev`

## Architecture

```
Cloudflare Pages (frontend/)
    ↓ HTTP GET /?lang={en|de}&city={zurich|basel|bern|geneva|lausanne}
Cloudflare Worker (worker/src/)
    ↓
1. [PARALLEL] Fetch RSS feeds, weather, and transport disruptions
2. Get Swiss holidays and "This Day in History" facts (sync, instant)
3. Call Claude API (Haiku) for news categorization
4. Return JSON response

    ↓ HTTP GET /activities?lang={en|de}&city={cityId}
1. Fetch weather for activity recommendations
2. Return curated family activities (sorted by weather)
3. Include city events/festivals (getCityEvents)

    ↓ HTTP GET /weekend?lang={en|de}&city={cityId}
1. Fetch weather for weekend activity filtering
2. Return weekend-appropriate activities

    ↓ HTTP GET /sunshine?lang={en|de}
1. Fetch weekend (Fri/Sat/Sun) sunshine forecasts for 28 destinations
2. Single multi-location Open-Meteo API call (all destinations in one request)
3. Return destinations ranked by total sunshine hours

    ↓ HTTP GET /snow?lang={en|de}
1. Fetch weekly (Mon–Sun) snowfall forecasts for 22 ski resorts
2. Single multi-location Open-Meteo API call (snowfall_sum, snow_depth)
3. Return resorts ranked by weekly snowfall total
```

## File Structure

```
swiss-news-summary/
├── frontend/
│   ├── index.html      # Slim HTML shell (~36 lines)
│   ├── styles.css      # Design system + all component styles
│   ├── app.js          # Full JS app: state, views, components, utils (~2800 lines)
│   ├── widget.html     # Compact widget page
│   ├── sw.js           # Service worker (cache v40)
│   ├── manifest.json   # PWA manifest with shortcuts
│   └── icon.svg        # App icon
├── worker/
│   ├── src/
│   │   ├── index.js      # Router, CORS, entry point
│   │   ├── data.js       # Cities config, holidays, school holidays, history facts
│   │   ├── weather.js    # Open Meteo integration
│   │   ├── transport.js  # Swiss Transport API
│   │   ├── news.js       # RSS parsing, Claude API, news assembly
│   │   ├── activities.js # All activities data + handler
│   │   ├── events.js     # City events/festivals data
│   │   ├── weekend.js    # Weekend planner logic
│   │   ├── lunch.js      # Overpass API + lunch handler
│   │   ├── sunshine.js   # Weekend sunshine forecast (29 destinations, Zürich baseline)
│   │   └── snow.js       # Weekly snowfall forecast (22 ski resorts)
│   └── wrangler.toml   # Worker config (main = "src/index.js")
├── ios-app/
│   ├── SwissPortal.xcodeproj
│   └── SwissPortal/
│       ├── App/                  # App entry, AppState, ContentView
│       ├── Models/               # Codable models (Activity, LunchSpot, etc.)
│       ├── ViewModels/           # @Observable view models
│       ├── Views/                # SwiftUI views by feature
│       │   ├── Activities/
│       │   ├── Deals/            # DealsView, DealCard
│       │   ├── Events/
│       │   ├── Explore/          # ExploreView, ExploreHeroBanner, NearYouSection, BrowseByTypeSection, CategoryDetailView, ExploreMapOverlay
│       │   ├── Lunch/            # LunchView, LunchCard, LunchMapView, LunchSurpriseSheet, AddRestaurantSheet
│       │   ├── News/             # NewsView, NewsHeroBanner, NewsCard, BriefingCard, HistoryBanner, TransportWidget, etc.
│       │   ├── Settings/         # SettingsView, HomeAddressSheet
│       │   ├── Shared/           # Reusable components (Skeleton, Toast, MapLegend, FlowLayout, etc.)
│       │   ├── Snow/
│       │   ├── Sunshine/
│       │   ├── Today/            # TodayView, TodayHeroBanner, AgendaTimelineView, AgendaSlotCard, CalendarSwipeView, CalendarSyncBanner, YourDayConfigSection, ExecHeaderView, TravelConnectorView
│       │   └── Weekend/          # WeekendView, WeekendDayCard
│       ├── Resources/            # DealsData, DestinationHighlights, SnowResorts, SunshineDestinations, Fonts/
│       ├── Services/             # LocationManager, CacheManager, APIClient, ReminderManager, CalendarService, AnchorStore, AgendaComposer, TemplateEngine, GapAnalysisEngine, FreshnessScorer
│       └── Info.plist            # URL scheme (swissportal://), NSCalendarsFullAccessUsageDescription
├── CLAUDE.md
└── README.md
```

## iOS App

Native SwiftUI app (iOS 17+) consuming the same Worker API as the PWA.

### Build & Run
```bash
cd ios-app
open SwissPortal.xcodeproj
# Build: Cmd+B, Run: Cmd+R (requires Xcode 15+)

# CLI build:
xcodebuild -project SwissPortal.xcodeproj -scheme SwissPortal \
  -destination 'platform=iOS Simulator,name=iPhone 16' build
```

### Znuni Design System (migrated from Alpine/Classic brand system)

The iOS app uses the **Znuni** warm editorial design system. All colors, typography, spacing, and shadows are centralized in `Color+Theme.swift` and the Asset Catalog.

#### Color Tokens (Asset Catalog — automatic Light/Dark mode)
| Token | Light | Dark | Usage |
|---|---|---|---|
| `znNavy` | #1A3A5C | #4A8AC4 | Primary brand, accent, `Color.brand` alias |
| `znTerracotta` | #C4623A | #D4724A | Warm accent, outdoor activity borders |
| `znCream` | #F5F0E8 | #1A1814 | Page backgrounds |
| `znSurface` | #FAF8F4 | #242018 | Card backgrounds |
| `znBorder` | #E8E0D0 | #2E2A24 | Card borders, dividers |
| `znInk` | #1C1A16 | #F0EBE0 | Primary text |
| `znBody` | #4A5568 | #A09888 | Body text |
| `znMuted` | #8A8070 | #6A6058 | Captions, eyebrow text |
| `znPositive` | #3A7D5C | #4A9D74 | Free badges, success states |
| `znNegative` | #B04040 | #D06060 | Error states |
| `znAlertBg` | #FDF0EA | #2A1E18 | Alert/error backgrounds |
| `znInnerDivider` | #F0EBE3 | #2A2620 | Card internal dividers |
| `znNeutralTagBg` | #EDE8DF | #302C26 | Neutral tag pill background |
| `znNeutralTagText` | #6B6355 | #9A9080 | Neutral tag pill text |
| `znChevron` | #C8C0B4 | #4A4640 | Chevron/arrow icons |

**Important**: Color tokens are auto-generated by Xcode from Asset Catalog colorsets. Do NOT redeclare them in `Color+Theme.swift` — only add legacy aliases there.

#### Typography (Playfair serif + SF Pro sans)
- `Font.heroTitle` — Playfair 30pt regular weight (matches mockup `font-weight: 400`; NOT semibold)
- `Font.displayTitle` — Playfair 32pt (large display text)
- `Font.sectionHeadline` — Playfair 22pt regular (matches mockup `.section-heading`)
- `Font.sectionTitle` — Playfair 22pt semibold (legacy alias)
- `Font.cardHeadline` / `Font.cardTitle` — Playfair 17pt semibold (card names)
- `Font.znEyebrow` — system 11pt medium, uppercase with tracking
- `Font.znLabel` — system 12pt medium
- `Font.znMono` — monospaced caption (times, distances)
- Body/caption text: system font (SF Pro, standing in for DM Sans)
- Playfair variable font files: `Resources/Fonts/Playfair-VariableFont_opsz,wdth,wght.ttf` + italic variant, registered in Info.plist `UIAppFonts`

#### Spacing & Shadow Tokens (`Color+Theme.swift`)
- `AppSpacing.cardPadding` = 16, `cardRadius` = 16, `borderStripWidth` = 3
- `AppShadow.card` = black 8% opacity, 8 radius, y=2
- `AppShadow.subtle` = black 5% opacity, 4 radius, y=2
- `CardStyle` / `SubtleCardStyle` ViewModifiers: centralized card styling with znSurface bg, rounded corners, optional left accent bar

#### Design HTML Mockups (source of truth for layout/spacing/typography)
Reference HTML files in `/Users/bq/Documents/SwissPortal/design system/`:
- `znuni-news-and-explore-2.html` — **Primary mockup**: News hero, Explore hero, category drill-down, near-you chips, browse-by-type grid, news accordion cards
- `znuni-activities-expanding-cards.html` — Expanding card accordion pattern
- `znuni-activities.html` — Activities view layout
- `znuni-app-icon-spec.pdf` — App icon design specification
- Other `znuni-*.html` files for each view's design spec

#### Design Patterns

**Edge-to-edge hero banners**: Use VStack content with `.background {}` modifier — NOT ZStack with Color fill (which expands infinitely). Content drives the height naturally. Pattern used in both `NewsHeroBanner` and `ExploreHeroBanner`:
```swift
VStack(alignment: .leading, spacing: 0) {
    // hero content
}
.padding(.horizontal, 24)
.padding(.top, 18)
.padding(.bottom, 24)
.background {
    ZStack(alignment: .bottomTrailing) {
        Color.znNavy
        RadialGradient(/* warm terracotta glow */)
        skylineIllustration.opacity(0.09)
    }
}
```

**Canvas skyline illustration**: White building silhouettes drawn with SwiftUI `Canvas` at 9% opacity, positioned bottom-right of hero banners. Used in News, Explore, and Lunch heroes (Lunch uses cutlery+buildings variant).

**Glass button pattern**: Frosted white-on-transparent hero buttons (`white.opacity(0.12)` bg, `RoundedRectangle(cornerRadius: 10)`). Used in Lunch hero (add, map toggle, city selector) and CategoryDetailView hero (map toggle, city selector). Implemented as `glassButton()` helper.

**Accordion card pattern**: `@Binding var expandedID: String?` — only one card expanded at a time. Used in ActivityCard, NewsCard, LunchCard, SunshineCard, SnowCard. Collapse with spring animation, haptic on toggle.

**R2 photo loading**: `APIClient.shared.photoURL(for: activityId)` returns `{baseURL}/photo/{activityId}`. Only activities (not events/deals) have R2 photos. Exclude `custom-` prefix and `stayhome` category. Always provide gradient+icon fallback for loading/failure states.

### iOS-Specific Features
- **Tab bar layout**: News, Activities, Explore, Weekend, Settings — custom `ZnuniTabBar` with Canvas-drawn icons, tint is `.znNavy`
- **Quick city picker**: Toolbar title menu (tap nav title → city dropdown) on News, Activities, Lunch
- **Visual design**: Playfair serif headlines on cards, 3px colored left border strips, navy brand gradient buttons, Znuni warm cream/surface backgrounds
- **Card border colors**: News (category color), Activities (indoor=navy/outdoor=terracotta/free=positive), Lunch (cuisine), Sunshine (hours), Snow (snowfall)
- **Brand navy accent**: All accent UI uses znNavy via `Color.brand` / `LinearGradient.brand`; tab bar tint is `.znNavy` (not `.brand` red)
- **Gradient buttons**: "Surprise me!" uses navy brand gradient; selected filter chips use solid navy bg
- **News hero banner** (`NewsHeroBanner.swift`): Edge-to-edge navy gradient hero with Playfair 30pt "Good morning, _Zürich_" title, temperature + weather row, skyline Canvas illustration, radial terracotta glow. Replaces old `HeroBanner` component on News tab.
- **Explore hero banner** (`ExploreHeroBanner.swift`): Edge-to-edge navy gradient hero with Playfair 30pt "Explore _Zürich_" title, filter pills, map/grid toggle icons, skyline Canvas illustration.
- **Explore screen redesign**: Mini map (160pt, dark navy tint overlay) → "Near you" horizontal chips with Canvas illustrations (museum, park, cafe, zoo, institution) → "Browse by type" 2×2 grid → Category drill-down via `CategoryDetailView`. Explore → Restaurants pushes `LunchView` within Explore's `NavigationStack`.
- **ExploreNavigationStack**: Separate struct in `ContentView.swift` managing its own `NavigationPath` so re-tapping the Explore tab pops to root. Routes: `"lunch"` → LunchView, `ExploreCategory` → CategoryDetailView.
- **Category detail view** (`CategoryDetailView.swift`): Featured venue card with R2 photo (AsyncImage), filter sub-categories, compact venue rows with thumbnails. Photos loaded via `APIClient.shared.photoURL(for: activityId)` with gradient+icon fallbacks. Museums/Parks categories have MapKit map toggle + city selector glass buttons in hero header.
- **WeekendTabView**: Container in `ContentView.swift` with navy hero banner and 3 segment pills (Sunshine/Snow/Planner) that switch between `SunshineView`, `SnowView`, and `WeekendView`.
- **Expanding activity cards (accordion)**: ActivityCard has collapsed/expanded states with `@Binding var expandedID: String?` — only one card open at a time. Collapsed: category eyebrow, Playfair title, 2-line description, flow-wrapped tag pills (FlowLayout), footer with distance + "Tap to expand" CTA. Expanded: photo panel slides from top (200px), detail panel slides from bottom with 2×2 metadata grid, "Get directions" + website buttons. Accent bar fades when expanded.
- **Tab bar icons**: Custom `ZnuniTabBar` with Canvas-drawn SVG icons (news grid, star, mountain, person bust, gear)
- **Weather background tint**: Subtle orange/blue/gray tint on News and Activities based on weather code
- **Numeric transitions**: Count labels animate with `.contentTransition(.numericText())`
- **Sensory feedback**: Haptic on card expand/collapse (all expandable cards) and heart/save toggle (LunchCard, ActivityCard)
- **Map gradient fade**: Bottom gradient overlay on all 4 map views (Lunch, Activities, Sunshine, Snow)
- **Badge borders**: Filled badges have subtle stroke overlay
- **Filter chip bounce**: Scale effect with spring animation on selected chips
- **Skeleton loading**: Shimmer placeholders during initial load (no cache)
- **Lunch hero banner** (`LunchView.swift`): Edge-to-edge navy gradient hero with "RESTAURANTS · ZÜRICH" eyebrow, Playfair 28pt title, cutlery+buildings Canvas skyline, glass buttons (add, map toggle, city selector), and filter pills (Near Me, Open, Terrace, Saved, Cuisine dropdown).
- **Lunch filter enums**: `LunchToggle` (`.nearMe`, `.open`, `.terrace`, `.saved`) for multi-select filter pills; `CuisineFilter` (`.all`, `.italian`, `.asian`, `.kebab`, `.cafe`, `.fastfood`, `.international`) for single-select cuisine dropdown. Both in `LunchResponse.swift`.
- **Lunch sort sheet**: `LunchSort` enum (`.nearest`, `.topRated`, `.priceLow`, `.priceHigh`) with radio-select bottom sheet (`LunchSortSheet`, `.height(280)` detent). Smart defaults: auto-switches to `.nearest` when "Near Me" is activated, reverts to `.topRated` when deactivated. Sort button in results row shows current sort name.
- **Lunch card accordion** (`LunchCard.swift`): Collapsed: 94px photo thumbnail + name + star rating + open/closed status + tags (price tier, Terrace, Takeaway) + distance + chevron. Expanded: opening hours pill (split per-day), 2×2 metadata grid, action buttons (Directions, Website, Heart, Delete for custom spots).
- **Price tier**: `LunchSpot.priceTier` computed property based on amenity type (café=1 `$`, fast_food=2 `$$`, restaurant=3 `$$$`). Shown as dimmed dollar signs on collapsed cards. Used for price sort.
- **Custom restaurants**: `CustomLunchSpot` model (in `AddRestaurantSheet.swift`) with `id`, `name`, `cuisineCategory`, `notes`, `rating: Int?`, `photoData: Data?`. Stored in UserDefaults key `"customLunch"`. Static `find(_:)` lookup. `AddRestaurantSheet` uses `PhotosPicker` (PhotosUI) for photo selection, JPEG compression at 50% quality, and interactive 5-star rating (terracotta). Custom photos/ratings displayed on `LunchCard` and `LunchSurpriseSheet`.
- **Lunch display limit**: 50 spots shown by default, "Show all" to expand
- **Lunch map collapsed**: Map starts hidden, toggle via glass button in hero
- **"Closed" badge**: Gray badge on lunch cards when `openForLunch == false`
- **Lunch card tap → map zoom**: Tapping a card shows the map and zooms to that restaurant
- **Lunch distance → directions**: Tapping the distance badge opens walking directions in Apple Maps
- **"Open for lunch" filter**: Filter renamed from "Open now" to accurately reflect 11:00-14:00 check
- **Calendar "Today" button**: Pill appears when viewing non-current month
- **Near Me map focus**: Tapping "Near me" / "Near" sort centers map on user location
- **URL deep linking**: `swissportal://lunch` → Explore tab, `swissportal://events` → Explore tab, `swissportal://weather` / `weekend` → Weekend tab, `swissportal://settings` → Settings tab
- **Toast notifications**: Save/unsave feedback via ToastManager
- **Pull-to-refresh**: On list views (not triggered by horizontal filter scroll)
- **Task cancellation**: `.task(id:)` auto-cancels in-flight requests on city/language change (News, Activities, Lunch)
- **Stale cache fallback**: On network failure, shows expired cached data instead of error screen
- **Cached DateFormatters**: Sunshine/Snow date range formatting uses static cached formatters via `DateHelpers.formatDateRange()`
- **Today tab — Plan mode**: AI-powered agenda composer builds a full-day plan (morning activity, lunch, afternoon activity, dinner) around user-defined anchors. Two sub-modes toggled by "News / Plan" pills: News mode (default landing) and Plan mode (agenda composer). `TodayHeroBanner` with greeting, weather, and mode toggle.
- **Anchor system**: `AnchorEvent` entries represent immovable commitments (manual, calendar-imported, or city events). `AnchorStore` persists anchors per date. `AnchorFormSheet` for add/edit. Anchors feed into `GapAnalysisEngine` which determines open planning slots.
- **Agenda composer**: `AgendaComposer` sends anchor context + gap analysis to Claude API, which selects venues to fill open slots. `TemplateEngine` provides 7 day archetypes (Chill, Explorer, Foodie, Culture, Nature, Budget, Social) as fallback when API unavailable. `AgendaCache` disk-caches composed plans per date.
- **Agenda timeline**: `AgendaTimelineView` renders the composed plan as a vertical timeline with `AgendaSlotCard` entries. Slot cards show venue name, time, duration, reason. Swappable via `SlotSwapSheet`. `FreshnessScorer` rates plan freshness.
- **Your Day config section** (`YourDayConfigSection.swift`): Inline configuration panel in Plan mode showing active anchors, kid count, vibe selector, and compose trigger. Left-aligned layout.
- **Execution mode**: Real-time day execution with check-in system. `ExecHeaderView` shows current/next slot with countdown. `TravelConnectorView` shows transit between slots.
- **Multi-day planning**: `MultiDayPlanStore` persists plans across days. Day pill selector for switching between today/tomorrow/weekend dates. Timeline shift detection adjusts plans when time passes.
- **Home address**: `HomeAddressSheet` in Settings for setting home location, used for travel time calculations in execution mode.
- **Calendar Sync — Read flow**: Two-way EventKit integration. `CalendarService` wraps `EKEventStore` for permission + CRUD. `CalendarSyncChecker` detects new calendar events not yet imported or discarded. On Plan mode appear, presents `CalendarSwipeView` (Tinder-style card stack) for accept/discard. Accepted events become `AnchorEvent` entries with `source: .calendar`. `CalendarDiscardStore` persists discarded event IDs. `CalendarSyncBanner` shows "New calendar event detected" for second-open case.
- **Calendar Sync — Write flow**: "Save to Calendar" ghost button exports composed plan slots as EKEvents. `CalendarExportStore` tracks exported event IDs per slot. Auto-updates calendar events on slot swap. Plan rebuild clears exported events.
- **Calendar Sync — Sync button**: "Sync" pill alongside "Rebuild" in agenda header. Runs `CalendarSyncChecker`, presents swipe screen or "up to date" toast.
- **Calendar Sync — Settings**: Calendar section in SettingsView with default calendar picker and "Clear discarded events" button with confirmation alert.
- **Calendar Sync — Conflict detection**: Post-accept check for overlapping anchor time ranges. Warning banner displayed above agenda when conflicts detected.

### Architecture
- **@Observable** view models (iOS 17 Observation framework)
- **CacheManager**: Disk cache with per-endpoint TTLs (show cached → fetch fresh); `getStale()` returns expired data as fallback
- **APIClient**: Centralized networking to Worker API; `photoURL(for:)` returns photo URLs for activity cards
- **LocationManager**: On-demand location for "Near me" features
- **ReminderManager**: Local notification scheduling for saved activities
- **ExploreViewModel**: Unified data source for Explore tab; `ExploreItem` enum (`.activity`, `.event`, `.deal`), `ExploreCategory` enum (`.museums`, `.parks`, `.restaurants`, `.events`, `.deals`), with `nearYouItems(location:limit:)`, `items(for:)`, `count(for:)` methods
- **DealsViewModel**: Loads deals from API with bundled `DealsData.all` fallback; `filteredDeals(city:)` filters by city, month validity, and `DealFilter` type
- **WeekendViewModel**: Loads weekend planner from API; `shuffle()` bypasses cache for fresh random picks
- **LunchViewModel**: `sortOrder: LunchSort` (default `.topRated`), `activeToggles: Set<LunchToggle>`, `cuisineFilter: CuisineFilter`, `filteredSpots()` applies all filters
- **Briefing model**: `NewsResponse` includes `briefing: Briefing?` with `topStory: BriefingItem?` and `suggestedActivity: Activity?` (raw Activity object from worker's `suggestedActivity` field)
- **SwissHolidayCalculator**: Utility for computing upcoming Swiss holidays, used in SettingsView
- **TodayViewModel**: Central view model for Today tab. Manages plan/news mode toggle, agenda composition, anchor CRUD, calendar sync, execution mode, multi-day planning. `composeAgendaForDate()` orchestrates gap analysis → Claude API → template fallback → cache. `swapSlot()`, `rebuildAgenda()`, `handleCalendarSync()`, `exportPlanToCalendar()`.
- **AnchorStore**: Persists `AnchorEvent` entries per date in UserDefaults. `anchors(for:)`, `add(_:)`, `remove(id:)`, `purgeOld()`. Calendar anchors use same flow as manual anchors.
- **AgendaComposer**: Builds Claude API prompt from anchors + gaps + preferences, parses structured JSON response into `DayAgenda` with `AgendaSlot` entries. Threads `planDate: Date` to set stored `slotDate` on each slot.
- **TemplateEngine**: Offline fallback with 7 day archetypes (Chill, Explorer, Foodie, Culture, Nature, Budget, Social). Each archetype has morning/lunch/afternoon/dinner venue selections. Threads `planDate: Date` for `slotDate` computation.
- **GapAnalysisEngine**: Analyzes anchors to find open time slots for planning. Returns `PlanningGap` entries with start/end times and suggested slot types.
- **FreshnessScorer**: Rates plan freshness based on age, weather changes, and anchor modifications. Drives "plan may be stale" indicators.
- **AgendaCache**: Disk cache for composed `DayAgenda` plans keyed by date. Invalidated on anchor changes, calendar sync accepts, and explicit rebuild.
- **CalendarService**: Singleton `EKEventStore` wrapper. `requestAccess()` (iOS 17+ full access), `fetchEvents(for:)` (filters all-day), `createEvent()`, `updateEvent()`, `deleteEvent()`. Reads/writes user's default or selected calendar.
- **CalendarSyncChecker**: Stateless filter — calendar events minus already-anchored minus discarded. Also provides `detectConflicts()` for overlapping anchor detection.
- **CalendarDiscardStore**: UserDefaults-backed `Set<String>` of discarded EKEvent IDs. Persists across sessions. Clearable from Settings.
- **CalendarExportStore**: UserDefaults-backed `[String: String]` mapping slotId → exported EKEvent ID. Tracks write-flow exports for update-on-swap and cleanup-on-rebuild.
- **TimelineShifter**: Detects when current time has passed planned slot times and adjusts the agenda display accordingly.
- **MultiDayPlanStore**: Persists composed plans for multiple dates (today, tomorrow, weekend). Enables day pill switching without recomposing.
- **PBXFileSystemSynchronizedRootGroup**: Xcode auto-discovers source files (no manual file references)
- **FlowLayout**: Custom SwiftUI `Layout` for wrapping tag pills in ActivityCard

## Features (PWA)

### News View (Landing Page)
- **5 Categories**: Politics, Disruptions, Events, Culture, Local (city-specific)
- **Compact Weather**: In header, tap to expand with hourly forecast
- **Transport Widget**: Real-time delays from Swiss Transport API
- **History Widget**: "This Day in Swiss History" inline under title
- **Holidays**: In hamburger menu (less prominent)
- **Category tabs**: With item counts
- **Pull-to-refresh**: Mobile gesture support
- **Share Summary**: Native share API

### Activities View ("What to do?")
- Curated family-friendly activities for toddlers (ages 2-5)
- **7 cities**: Zürich, Basel, Bern, Geneva, Lausanne, Luzern, Winterthur
- **Filters**: All, Near me, Indoor, Outdoor, Free, Saved, Seasonal
- **"Near me"**: Uses geolocation, shows distance badges
- **Weather-based**: Indoor prioritized when rainy/cold
- **Custom activities**: Users can add their own
- **Recurring events**: Farmers markets, play groups, story times
- **Seasonal activities**: Christmas markets, ice skating, swimming pools, pumpkin farms
- **"Surprise me!" button**: Random weather-appropriate activity picker
- **Age filter**: Toggle between All ages, 2-3 years, or 4-5 years

### Events View ("What's On") — accessed via Explore tab
- Combined calendar + daily digest — merged from separate Events Calendar and What's On views
- **Calendar grid**: Auto-selects today, purple dots for festivals, red for holidays, amber for school holidays, blue for recurring
- **Day detail panel**: Click any day to see detail below calendar:
  - Holidays on that date (purple banner)
  - School holidays on that date (amber banner with date range)
  - Festivals with date range overlap (purple left-border cards)
  - Recurring activities matching that day-of-week
  - Weather-based activity picks (today only — indoor when rainy/<5°C)
  - Trending news (today only)
- **School holidays**: Zürich 2026 dates (Sport, Easter, Spring, Ascension, Summer, Autumn, Christmas) from `getSchoolHolidays()` in worker
- **All Events list**: Below detail panel with filter bar (All, Holidays, School Holidays, Events, Recurring, Seasonal, Festivals)
- **City events**: ~70 hardcoded 2026 festivals/events served via `getCityEvents()` in worker
- **Date-range awareness**: Multi-day festivals show dots on all days, filter by date overlap
- **Festival cards**: Show date ranges, toddler-friendly and free badges
- Fetches news data (weather, trending, holidays) if not already loaded

### Weekend Planner
- Smart activity filtering based on weather and day-of-week
- Uses `isAvailableOnDate()` for recurring/seasonal filtering
- **iOS**: `WeekendView` shows Saturday/Sunday `WeekendDayCard` with weather rows, morning/afternoon activity sections (indoor/outdoor badges), and shuffle button. `WeekendViewModel` loads from `/weekend` API with `shuffle()` to bypass cache. `WeekendResponse` model: `saturday`/`sunday` `WeekendDay` structs with `weather: DayWeather?` and `plan: DayPlan` (morning/afternoon `PlannedActivity`).

### Lunch Page — accessed via Explore → Restaurants
- Restaurant recommendations with hero banner, filterable list, and toggleable map
- Accessed by pushing from Explore tab's "Browse by type" → Restaurants (not a standalone tab)
- Navy hero banner with "RESTAURANTS · ZÜRICH" eyebrow, cutlery skyline, glass buttons (add, map, city picker)
- Multi-select filter pills: Near Me, Open, Terrace, Saved + single-select Cuisine dropdown
- Sort bottom sheet: Nearest first, Top rated, Price low→high, Price high→low (smart defaults)
- Accordion cards: photo thumbnail, name, rating, status, price tier ($/$$/$$), tags, distance
- Custom restaurants: users can add with photo (PhotosPicker) and 5-star rating
- "Surprise me!" random restaurant picker

### Stay-Home Activities
- 40 at-home toddler activities (sensory/art/active/pretend/kitchen)
- Separate "Stay home" filter tab, excluded from other filters

### Settings (dedicated tab — iOS; hamburger menu — PWA)
- **City selector**: Zürich, Basel, Bern, Geneva, Lausanne, Luzern, Winterthur
- **Language toggle**: English / German
- **Theme toggle**: Light / Dark mode
- **Holidays display**: Upcoming Swiss holidays (via `SwissHolidayCalculator`)


### Sunshine Page ("Where is Sun?")
- Weekend sunshine forecast for 29 destinations (28 + Zürich baseline) within driving distance of Zürich
- **Zürich baseline**: Pinned first card with purple styling, always visible regardless of filter/sort
- **"Nearest sunny escape"**: When Zürich has <6h sunshine, shows closest destination with more sun (drive-time sorted)
- **Regions**: Ticino, Graubünden, Valais, Central Switzerland, Lake Geneva, Basel/Jura, Lake Constance, Lake Como
- **Interactive Leaflet map**: Circle markers colored/sized by sunshine level (gold/blue/gray), purple for Zürich
- **Ranked card list**: Sorted by total sunshine hours, collapsible (top 10 default)
- **Sort**: By sunshine hours or by distance from current location (geolocation)
- **Filter**: All / Sunny (>6h) / Partly (3-6h) / Cloudy (<3h)
- **Hourly timeline**: Shows which hours (6-20) have predicted sunshine per day
- **Drive time badges**: Minutes from Zürich
- **Client-side fallback**: If worker is rate-limited, fetches directly from Open-Meteo
- Always Zürich-based (not affected by city selector)
- **Expandable cards**: Tap to expand with "Things to do" section (accordion, one at a time)
- **Destination highlights**: `DEST_HIGHLIGHTS` in app.js — 2-3 curated toddler-friendly attractions per destination (57 total)
- **Overlap cities** (Basel, Lausanne, Luzern): Show "See all activities →" link to Activities view
- **Google Maps links**: "Find playgrounds" / "Find restaurants" near destination coordinates

### Snow Page ("Where is Snow?")
- Weekly snowfall forecast for 22 Swiss ski resorts within driving distance of Zürich
- **Regions**: Valais, Graubunden, Bernese Oberland, Central Switzerland, Eastern Switzerland
- **Interactive Leaflet map**: Circle markers with radius proportional to snowfall (deep blue/blue/gray)
- **Ranked card list**: Sorted by weekly snowfall, collapsible (top 10 default)
- **Sort**: By snowfall or by distance from current location (geolocation)
- **Filter**: All / Heavy (>30cm) / Moderate (10-30cm) / Light (<10cm)
- **7-day forecast**: Daily snowfall bars with weather icons and temperature
- **Badges**: Drive time, altitude, snow depth, distance
- **Fresh powder alert**: Banner when top resort has >40cm weekly snowfall
- **Client-side fallback**: If worker is rate-limited, fetches directly from Open-Meteo
- Always Zürich-based (not affected by city selector)
- **Cache keys**: Worker `snow-v1-{lang}`, Frontend `snowCache-v1` (30min TTL)

### Deals & Free View ("Best deals?")
- Curated list of free entry spots, family passes, and money-saving tips
- **PWA**: `DEALS` array (~30 static entries in app.js), `filterDeals(f)`, `renderDealsView()`, `renderDealCard(d)`
- **iOS**: `Deal` model with `DealType` enum (`.free`/`.deal`/`.tip`), `DealFilter` enum, `DealsViewModel` with `filteredDeals(city:)`, bundled `DealsData.all` fallback. `DealsView` + `DealCard` with type badges (green/blue/amber), filter pills with counts. Also integrated into ExploreViewModel as `ExploreItem.deal`.
- **Categories**: Museums, Outdoor, Transport, Family Passes, Seasonal
- **Types**: Free (green badge), Deal (blue badge), Tip (amber badge)
- **Filters**: All / Free / Deals / Tips
- **City-aware**: Shows only deals relevant to selected city + "all" deals
- **Month-aware**: Seasonal deals filtered by `validMonths` array
- **Free filter in Activities**: Activities with `free: true` (auto-tagged from `price` field) shown via "Free" filter tab

### Widget Page (`/widget.html`)
- Compact view: weather, top headline, transport status
- Auto-refreshes every 5 minutes
- Can be bookmarked as quick access

## API Endpoints

### Main News Endpoint
`GET /?lang={en|de}&city={cityId}&refresh={true}`

```json
{
  "weather": { "temperature": 1, "description": "Foggy", "weatherCode": 45, "windSpeed": 3, "hourly": [...] },
  "transport": {
    "delays": [{ "line": "IC 8", "destination": "Bern", "delay": 5, "scheduledTime": "23:02" }],
    "summary": { "totalDelayed": 3, "maxDelay": 10, "status": "minor" }
  },
  "holidays": [{ "name": "Easter", "nameDE": "Ostern", "daysUntil": 45 }],
  "schoolHolidays": [{ "name": "Summer", "nameDE": "Sommerferien", "startDate": "2026-07-13", "endDate": "2026-08-14", "type": "schoolHoliday" }],
  "history": { "year": 1958, "event": "...", "eventDE": "..." },
  "categories": {
    "disruptions": [{ "headline": "...", "summary": "...", "source": "NZZ", "url": "..." }],
    "events": [...],
    "politics": [...],
    "culture": [...],
    "local": [...]
  },
  "briefing": {
    "topStory": { "headline": "...", "summary": "...", "source": "NZZ", "url": "..." },
    "suggestedActivity": { "id": "zoo-zurich", "name": "Zoo Zürich", "indoor": false, ... }
  },
  "trending": { "topic": "...", "topicDE": "...", "articleCount": 5 },
  "city": { "id": "zurich", "name": "Zürich" },
  "timestamp": "2026-..."
}
```

### Activities Endpoint
`GET /activities?lang={en|de}&city={cityId}`

```json
{
  "activities": [
    {
      "id": "zoo-zurich",
      "name": "Zoo Zürich",
      "nameDE": "Zoo Zürich",
      "description": "...",
      "indoor": false,
      "ageRange": "2-5 years",
      "duration": "2-4 hours",
      "price": "CHF 29 adults, kids under 6 free",
      "url": "https://www.zoo.ch",
      "lat": 47.3849,
      "lon": 8.5743,
      "category": "animals",
      "minAge": 2,
      "maxAge": 5,
      "season": "winter"
    }
  ],
  "cityEvents": [
    {
      "id": "zh-sechselaeuten",
      "name": "Sechseläuten",
      "nameDE": "Sechseläuten",
      "city": "zurich",
      "startDate": "2026-04-20",
      "endDate": "2026-04-20",
      "description": "...",
      "descriptionDE": "...",
      "toddlerFriendly": true,
      "free": true,
      "url": "https://www.sechselaeuten.ch/"
    }
  ],
  "weather": { ... },
  "city": { "id": "zurich", "name": "Zürich" }
}
```

### Sunshine Endpoint
`GET /sunshine?lang={en|de}&refresh={true}`

```json
{
  "destinations": [
    {
      "id": "lugano", "name": "Lugano", "nameDE": "Lugano",
      "lat": 46.0037, "lon": 8.9511,
      "region": "Ticino", "regionDE": "Tessin", "driveMinutes": 150,
      "forecast": [
        {
          "date": "2026-02-20", "weatherCode": 1, "tempMax": 12, "tempMin": 3,
          "sunshineHours": 7.2, "precipMm": 0,
          "sunnyHours": [8,9,10,11,12,13,14,15,16],
          "description": { "en": "Mainly sunny", "de": "Überwiegend sonnig" }
        }
      ],
      "sunshineHoursTotal": 18.5
    }
  ],
  "weekendDates": { "friday": "2026-02-20", "saturday": "2026-02-21", "sunday": "2026-02-22" },
  "timestamp": "2026-..."
}
```

### Snow Endpoint
`GET /snow?lang={en|de}&refresh={true}`

```json
{
  "destinations": [
    {
      "id": "zermatt", "name": "Zermatt", "nameDE": "Zermatt",
      "lat": 46.0207, "lon": 7.7491,
      "region": "Valais", "regionDE": "Wallis", "driveMinutes": 195, "altitude": 1620,
      "forecast": [
        { "date": "2026-02-16", "snowfallCm": 5.2, "weatherCode": 73, "tempMax": -2, "tempMin": -8 }
      ],
      "snowfallWeekTotal": 28.5,
      "snowDepthCm": 145
    }
  ],
  "weekDates": { "monday": "2026-02-16", "sunday": "2026-02-22" },
  "timestamp": "2026-..."
}
```

## Data Sources

**News:**
- NZZ (Schweiz, Zürich feeds)
- SRF News
- 20 Minuten
- Google News Switzerland (aggregated)
- City-specific Google News feeds

**Weather:**
- Open Meteo API (primary, Celsius)
- ~~wttr.in~~ (removed - was returning incorrect data)

**Transport:**
- Swiss Transport API (`transport.opendata.ch`)
- Fetches stationboard for main station in each city
- Shows delays > 3 minutes

**Activities:**
- Curated list in worker (with coordinates for geolocation)
- Cloudflare KV storage (for custom lists)

## City Configuration

Each city has:
- `name`: Display name
- `lat`, `lon`: Coordinates for weather
- `station`: Main train station for transport API
- `sources`: RSS feeds for local news

**Supported cities:** zurich, basel, bern, geneva, lausanne, luzern, winterthur

## Environment Variables

| Variable | Location | Description |
|----------|----------|-------------|
| `CLAUDE_API_KEY` | Wrangler secret | Claude API key (required) |
| `ALLOWED_ORIGIN` | wrangler.toml | CORS origin (`*`) |
| `ACTIVITIES_KV` | wrangler.toml | KV namespace for activities |

**KV Namespace ID:** `5ed6acfc2de944a38ee9a767080b4290`

## Key Frontend Elements

| Element ID | Purpose |
|------------|---------|
| `weather-compact` | Compact weather in header |
| `weather-dropdown` | Expanded weather details |
| `transport-widget` | Transport disruptions |
| `history-inline` | History fact under title |
| `menu-holidays-list` | Holidays in menu |
| `activities-list` | Activities container |
| `add-activity-form` | Custom activity form |
| `events-list` | Events calendar list |
| `calendar-grid` | Calendar day grid |
| `calendar-month-label` | Calendar month/year display |
| `loading-bar` | Animated progress bar during data fetches |
| `pull-indicator` | Pull-to-refresh visual indicator |
| `toast-container` | Toast notification container |

## Key JavaScript Functions

| Function | Purpose |
|----------|---------|
| `fetchSummary(forceRefresh)` | Load news data |
| `loadActivities(forceRefresh)` | Load activities |
| `switchView(view)` | Toggle news/activities |
| `filterActivities(filter)` | Filter activities |
| `requestLocation()` | Get user geolocation |
| `calculateDistance(...)` | Haversine distance |
| `updateTransport(data)` | Render transport widget |
| `saveCustomActivity()` | Save user's custom activity |
| `openMenu()` / `closeMenu()` | Hamburger menu |
| `toggleTheme()` | Light/dark mode |
| `surpriseMe()` | Random activity picker |
| `setAgeFilter(age)` | Filter by age group |
| `showSurpriseModal(activity)` | Display surprise activity |
| `loadEventsCalendar()` | Load events calendar data |
| `renderCalendar()` | Render calendar grid with dots |
| `renderEventsList()` | Render filtered events list |
| `filterEvents(filter)` | Filter events by type |
| `loadWeekendPlanner()` | Load weekend planner |
| `loadSunshine(forceRefresh)` | Load sunshine data (worker + client fallback) |
| `renderSunshineView()` | Render sunshine map + card list |
| `initSunshineMap()` | Init Leaflet map with sunshine markers |
| `setSunshineSort(sort)` | Sort by 'sunshine' or 'distance' |
| `setSunshineFilter(filter)` | Filter by 'all'/'sunny'/'partly'/'cloudy' |
| `getBaselineDest()` | Get Zürich baseline entry from sunshine data |
| `fetchSunshineClientSide()` | Client-side Open-Meteo fallback |
| `renderDayDetail(dateStr)` | Render day detail panel for selected calendar day |
| `selectCalendarDay(dateStr)` | Toggle calendar day selection |
| `renderSunshineHighlights(dest)` | Render expandable highlights section for sunshine card |
| `renderHighlightItem(highlight)` | Render single destination highlight with directions link |
| `loadSnow(forceRefresh)` | Load snow data (worker + client fallback) |
| `renderSnowView()` | Render snow map + card list |
| `initSnowMap()` | Init Leaflet map with snow markers |
| `setSnowSort(sort)` | Sort by 'snowfall' or 'distance' |
| `setSnowFilter(filter)` | Filter by 'all'/'heavy'/'moderate'/'light' |
| `fetchSnowClientSide()` | Client-side Open-Meteo fallback for snow |
| `renderDealsView()` | Render deals & free view with filter bar |
| `renderDealCard(d)` | Render single deal card |
| `filterDeals(f)` | Filter deals by type (all/free/deal/tip) |
| `getSchoolHolidays()` | Worker: return Zürich 2026 school holiday dates |
| `showLoading()` | Show animated loading bar at top of page |
| `hideLoading()` | Hide loading bar with completion animation |

## Storage

**localStorage keys:**
- `lang` - Language preference (en/de)
- `city` - Selected city
- `theme` - Theme preference (light/dark)
- `view` - Active view (news/activities/lunch/events/weekend/sunshine/snow/deals), persisted across refresh
- `savedActivities` - Array of saved activity IDs
- `customActivities` - Array of user-created activities
- `installDismissed` - PWA install prompt dismissed
- `notificationsEnabled` - Push notifications enabled
- `newsCache-{city}-{lang}` - Cached news data per city/language (2hr TTL)
- `activitiesCache-{city}` - Cached activities data per city
- `sunshineCache-v2` - Cached sunshine data with Zürich baseline (30min TTL)
- `snowCache-v1` - Cached snow/ski resort data (30min TTL)

**Cloudflare KV:**
- Key format: `activities-{cityId}`
- Value: JSON array of activity objects

## Notes

- Open-Meteo rate limits: Worker IP can hit daily quota. Client-side fallback in app.js handles this.
- Sunshine uses multi-location API (single request for all 29 destinations incl. Zürich baseline) to avoid rate limits.
- Sunshine is always Zürich-based — `setCity()` doesn't affect it.

## Troubleshooting

**Weather showing wrong temperature:**
- Open Meteo is the only weather source now
- Add `?refresh=true` to force fresh data
- Check Cloudflare cache if stale

**News not loading:**
- Check Claude API key is set: `wrangler secret put CLAUDE_API_KEY`
- Check worker logs: `wrangler tail`

**Activities not loading:**
- Check `/activities` endpoint is deployed
- Verify city parameter is valid

**Sunshine showing "no data":**
- Worker may be rate-limited by Open-Meteo (daily quota on CF Worker IP)
- Client-side fallback should kick in automatically
- Add `?refresh=true` to bypass CF edge cache
- Check browser console for client-side fetch errors

## First-time Setup

```bash
npm install -g wrangler
wrangler login
cd worker
wrangler secret put CLAUDE_API_KEY  # Enter your Claude API key
wrangler deploy
cd ..
npx wrangler pages deploy frontend --project-name=swiss-news --branch=main
```
