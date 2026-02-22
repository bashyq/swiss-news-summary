# SwissPortal iOS App - Architecture Review

**Date:** 2026-02-22
**Branch:** `claude/plan-ios-app-4aOQo`
**Build Status:** COMPILES & RUNS on real device (iPhone 18,1 / iOS 26.3)
**Runtime Status:** All tabs functional — News, Activities, Events, Weekend, Lunch, Sunshine, Snow, Deals

---

## 1. Architecture Overview

```
iOS App (SwiftUI + MVVM)
    ↓ HTTPS
Cloudflare Worker (swiss-news-worker.swissnews.workers.dev)
    ↓
RSS feeds, Open-Meteo, Swiss Transport API, Claude API
```

The iOS app is a thin presentation layer over the same Cloudflare Worker API that the PWA uses. All data aggregation, RSS parsing, and Claude AI categorization happen server-side. The app handles:
- Caching (file-based, per-endpoint TTL)
- Offline resilience (show cached data, fetch fresh in background)
- Client-side fallback for Sunshine/Snow (direct Open-Meteo when worker is rate-limited)
- Location services for "Near me" filtering
- Widget extension for home screen widgets

### API Endpoints Used

| Endpoint | Swift Model | Tab |
|----------|-------------|-----|
| `GET /` | `NewsResponse` | News, Events |
| `GET /activities` | `ActivitiesResponse` | Activities, Events |
| `GET /weekend` | `WeekendResponse` | Weekend Planner |
| `GET /lunch` | `LunchResponse` | Lunch |
| `GET /sunshine` | `SunshineResponse` | Where to go? (Sunshine) |
| `GET /snow` | `SnowResponse` | Where to go? (Snow) |
| (static) | `DealsData` | Deals & Free |

---

## 2. Project Structure

```
SwissPortal/
├── App/           (3 files) - Entry point, AppState, ContentView
├── Extensions/    (4 files) - Color theme, Date helpers, Location, Localization
├── Models/        (8 files) - Codable structs per endpoint
├── Services/      (3 files) - APIClient, CacheManager, LocationManager
├── ViewModels/    (8 files) - One per feature, @Observable
├── Views/         (42 files) - Organized by feature
├── Resources/     (4 files) - Static data (deals, destinations, resorts)
└── Preview Content/ (1 file) - PreviewData

TodayInSwitzerlandWidget/
├── WidgetBundle.swift      - @main entry, bundles both widgets
├── TodayWidget.swift       - News + weather + transport widget (small/medium)
├── SunshineWidget.swift    - Weekend sunshine top 3 widget (medium)
├── WidgetDataProvider.swift - API client + lightweight Codable models
└── Info.plist              - NSExtension configuration
```

**Design decisions:**
- Zero external dependencies (no CocoaPods, no SPM packages)
- `@Observable` (iOS 17+) instead of `ObservableObject`
- Actor-based services (`APIClient`, `CacheManager`) for thread safety
- File-based caching with TTL per endpoint type
- Clean separation: Models know nothing about Views
- Widget extension has its own lightweight Codable models (doesn't import main app)
- Deployment target: iOS 17.0

---

## 3. Issues Found & Fixed

### Session 1: Compilation Fixes (11 errors)

| # | Issue | Fix |
|---|-------|-----|
| A | `Briefing` model expected strings, API sends objects | Rewrote as `BriefingItem`/`BriefingActivity` structs |
| B | `Activity.recurring` was `RecurringSchedule` struct, API sends plain string | Changed to `String?` |
| C | `CacheTTL` enum had duplicate raw values | Removed raw values, used computed `seconds` |
| D | `DestinationHighlights` defined twice (Resources + SunshineCard) | Removed 290-line duplicate |
| E | `SnowCard` used `.tertiary` (`ShapeStyle`) where `Color` expected | Changed to `Color.gray` |
| F | `SettingsView` passed `AppState` where `Bindable<AppState>` needed | Fixed binding pass-through |
| G | Missing `availableMonths` field on `Activity` | Added `availableMonths: [Int]?` |
| H | Missing `timestamp` on `ActivitiesResponse` | Added `timestamp: String?` |
| I | Missing `url` on `TrendingTopic` | Added `url: String?` |
| J | DayDetailView/EventsView referenced `RecurringSchedule` struct | Simplified to use `String` |
| K | PreviewData complex expressions wouldn't type-check | Broke into sub-expressions |

### Session 2: Runtime & Localization Fixes

| # | Issue | Fix |
|---|-------|-----|
| L | `NewsItem.timeAgo` always nil — parser required date-only format | Added `parseISODateTime()` with fractional-seconds fallback |
| M | Deal category mismatch — `"museum"` vs `"museums"` | DealCard now matches both singular/plural |
| N | 6 German umlaut typos across 3 files | Fixed `Öffnen`, `Küchenspass`, `Aktivitäten`, `verfügbar`, `Familienpässe` |
| O | 5 shared views had hardcoded English | Added `@Environment(AppState.self)` for localization |
| P | Duplicate activities in Events "all" filter | Deduplicated by ID before appending |
| Q | Unused variable warning in ActivityCard | Changed `if let` to `if != nil` |
| R | Stale unit test JSON for Briefing model | Updated test data to match new object shape |

### Session 3: Xcode Project + API Model Fixes

| # | Issue | Fix |
|---|-------|-----|
| S | ContentView used iOS 18+ `Tab()` API | Rewrote to `.tabItem{}` + `.tag()` (iOS 17) |
| T | No `NSLocationWhenInUseUsageDescription` | Added to build settings (Debug + Release) |
| U | Deployment target was iOS 26.2 | Lowered to iOS 17.0 (all targets) |
| V | Widget Extension target missing from Xcode project | Added full target to project.pbxproj (PBXNativeTarget, build phases, configs) |
| W | Widget Info.plist missing `NSExtension` dictionary | Created Info.plist with `NSExtensionPointIdentifier` |
| X | `Color("AppPrimary")` referenced missing asset | Changed to `Color.purple` |
| Y | Widget UI text not localized | Added `localized(en:de:)` helpers to both widget files |
| Z | `transport.summary` can be `null` | Made `TransportSummary?` optional, updated TransportWidget |
| AA | `WeekendDay.weather` can be `null` (Sunday) | Made `DayWeather?` optional, added `if let` guard in WeekendDayCard |
| AB | Lunch API has no `city`/`timestamp` at top level | Made `city: CityInfo?` optional |
| AC | `LunchSpot.vegetarian` is `String?` not `Bool?` | Changed type, updated all `== true` to `== "yes"` (4 files) |
| AD | `Activity.materials` can be string OR array | Added `StringOrArray` Codable type that handles both |
| AE | Added detailed DecodingError logging | `APIClient.detailedDecodingError()` shows field path + type in UI |

---

## 4. Known Issues (Not Yet Fixed)

### Code Quality (Non-blocking)

| Issue | Severity | Notes |
|-------|----------|-------|
| `filteredEvents()` returns `[Any]` | Low | Should use enum `EventItem` with associated values |
| Preview code bloat | Low | Many views have inline sample data instead of using PreviewData.swift |
| DIY localization (~200 inline calls) | Medium | Uses `appState.localized(en:de:)` instead of String Catalogs |
| `AppState` is a god object | Medium | Holds city, language, theme, saved data, AND localization helpers |
| Hardcoded Easter calculation | Low | 20-line Computus algorithm duplicated from worker's data.js |
| Error messages show raw paths (debug) | Low | `detailedDecodingError` is useful for dev but should be user-friendly for production |

### Future Improvements

| Improvement | Priority |
|-------------|----------|
| Replace `[Any]` in `filteredEvents()` with typed enum | Should do |
| Centralize preview data in PreviewData.swift | Nice to have |
| Consider String Catalogs for localization | Nice to have |
| Add App Group capability for widget data sharing | Should do |
| Remove debug error logging before App Store submission | Must do |
| Add offline indicator when no cached data available | Nice to have |

---

## 5. Files Changed (All Sessions)

### Session 1 — Compilation Fixes (12 files)

| File | Change |
|------|--------|
| `Models/NewsResponse.swift` | Rewrote `Briefing` from strings to objects, added `url` to `TrendingTopic` |
| `Models/Activity.swift` | Changed `recurring` from `RecurringSchedule?` to `String?`, added `availableMonths`, `timestamp` |
| `Services/CacheManager.swift` | Fixed `CacheTTL` enum (no raw values), changed generics to `Codable` |
| `Views/Sunshine/SunshineCard.swift` | Removed 290-line duplicate `DestinationHighlights` enum |
| `Views/Snow/SnowCard.swift` | Fixed `.tertiary` to `Color.gray` |
| `Views/Settings/SettingsView.swift` | Fixed `$state` binding pass-through |
| `Views/Events/DayDetailView.swift` | Simplified `recurring` display (string, not struct) |
| `Views/Events/EventsView.swift` | Simplified `recurring` display (string, not struct) |
| `Preview Content/PreviewData.swift` | Broke up complex expressions, updated for new model shapes |
| `Views/Activities/ActivityCard.swift` | Added `availableMonths` parameter |
| `Views/Activities/StayHomeSection.swift` | Added `availableMonths` parameter |
| `Views/Activities/SurpriseMeSheet.swift` | Added `availableMonths` parameter |

### Session 2 — Runtime & Localization Fixes (12 files)

| File | Change |
|------|--------|
| `Extensions/Date+Helpers.swift` | Fixed `isoDateTimeFormatter`, added fractional-seconds fallback |
| `Models/NewsResponse.swift` | Fixed `timeAgo` to use `parseISODateTime` |
| `Views/Deals/DealCard.swift` | Fixed category mismatch + 2 umlauts |
| `Views/Activities/StayHomeSection.swift` | Fixed 3 umlauts |
| `Views/Activities/SurpriseMeSheet.swift` | Fixed 1 umlaut |
| `Views/Shared/BadgeView.swift` | Localized FreeBadge + ToddlerFriendlyBadge |
| `Views/Shared/LoadingView.swift` | Localized InlineLoadingView |
| `Views/Shared/ErrorView.swift` | Localized "Try again" |
| `Views/Shared/SortPicker.swift` | Localized ShowAllButton |
| `Views/Activities/ActivityCard.swift` | Fixed unused variable |
| `ViewModels/EventsViewModel.swift` | Deduplicated activities in "all" filter |
| `SwissPortalTests/.../ModelDecodingTests.swift` | Updated test JSON |

### Session 3 — Xcode Project + API Model Fixes (18 files)

| File | Change |
|------|--------|
| `App/ContentView.swift` | Rewrote Tab API from iOS 18+ to iOS 17 compatible |
| `SwissPortal.xcodeproj/project.pbxproj` | Lowered deployment target to 17.0, added location plist key, added full Widget Extension target |
| `TodayInSwitzerlandWidget/Info.plist` | **NEW** — NSExtension dictionary for widget |
| `Extensions/Color+Theme.swift` | Changed `Color("AppPrimary")` to `Color.purple` |
| `TodayInSwitzerlandWidget/TodayWidget.swift` | Localized all widget strings |
| `TodayInSwitzerlandWidget/SunshineWidget.swift` | Localized all widget strings |
| `Models/NewsResponse.swift` | Made `Transport.summary` optional |
| `Models/WeekendResponse.swift` | Made `WeekendDay.weather` optional |
| `Models/LunchResponse.swift` | Made `city` optional, changed `vegetarian` to `String?` |
| `Models/Activity.swift` | Added `StringOrArray` type, changed `materials`/`materialsDE` |
| `Views/News/TransportWidget.swift` | Optional chaining for `summary?.status` |
| `Views/Weekend/WeekendDayCard.swift` | `if let weather` guard for nil weather |
| `Views/Lunch/LunchCard.swift` | `vegetarian == "yes"`, fixed preview sample |
| `Views/Lunch/LunchMapView.swift` | `vegetarian == "yes"` |
| `Views/Lunch/LunchView.swift` | `vegetarian == "yes"` |
| `ViewModels/LunchViewModel.swift` | `vegetarian == "yes"` in filter |
| `Services/APIClient.swift` | Added detailed DecodingError logging with field paths |
| `Preview Content/PreviewData.swift` | Updated `vegetarian` and `materials` types |
| `Views/Activities/StayHomeSection.swift` | Updated `materials` to `StringOrArray` |
