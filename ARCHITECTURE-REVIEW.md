# SwissPortal iOS App - Architecture Review

**Date:** 2026-02-22
**Branch:** `claude/plan-ios-app-4aOQo`
**Build Status:** COMPILES (xcodebuild succeeds for simulator)
**Runtime Status:** Partially functional - JSON decoding errors on some endpoints

---

## 1. Build Verdict

```
** BUILD SUCCEEDED **
```

The app compiles cleanly from command line for iPhone 17 Pro Simulator (iOS 26.2 SDK). Zero warnings, zero errors. It launches and the News tab works after our `Briefing` model fix. Activities also load after fixing the `recurring` field type.

---

## 2. Project Structure (What's Good)

The overall MVVM architecture is solid and well-organized:

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
```

**Good decisions:**
- Zero external dependencies (no CocoaPods, no SPM packages)
- Proper use of `@Observable` (iOS 17+) instead of `ObservableObject`
- Actor-based services (`APIClient`, `CacheManager`) for thread safety
- File-based caching with TTL per endpoint type
- Clean separation: Models know nothing about Views
- Widget extension has its own lightweight Codable models (doesn't import the main app's)

---

## 3. What's Broken / Messy

### A. CRITICAL: Models Don't Match the API (Root cause of all runtime crashes)

The Swift Codable models were written based on the PLAN document, not the actual API responses. Multiple fields are wrong:

| Model | Field | Expected | Actual API |
|-------|-------|----------|------------|
| `Briefing.topStory` | `String?` | **Full NewsItem object** |
| `Briefing.suggestedActivity` | `String?` | **Full Activity object** |
| `Activity.recurring` | `RecurringSchedule` struct | **Plain string** (`"Tue & Fri 6:00-11:00"`) |
| `CacheTTL` | Raw value enum | Duplicate raw values (Swift doesn't allow) |
| `DestinationHighlights` | Defined once | **Defined twice** (Resources + SunshineCard) |
| `Activity` | Missing field | Missing `availableMonths: [Int]?` |
| `Activity` | Missing field | Missing `priceDE` in API (but model has it) |
| `ActivitiesResponse` | Missing field | Missing `timestamp` |
| `TrendingTopic` | Missing field | Missing `url` |
| `Holiday` | Extra fields | API has `cantons`, `isToday` (harmless, ignored) |
| `TrainDelay` | Extra fields | API has `platform` (harmless, ignored) |
| `NewsItem` | Extra fields | Model has `headlineDE`, `summaryDE`, `detailDE` that API doesn't send (harmless, nil) |
| `SnowCard` | Type error | `.tertiary` is `ShapeStyle`, not `Color` |
| `SettingsView` | Bindable error | Passing `AppState` where `Bindable<AppState>` expected |

**We've fixed all of the above during this session.** But the pattern is clear: the models were generated from docs, not validated against the live API.

### B. CRITICAL: Widget Extension Target Missing

The `TodayInSwitzerlandWidget/` directory has 4 complete Swift files:
- `WidgetBundle.swift` (with `@main`)
- `TodayWidget.swift`
- `SunshineWidget.swift`
- `WidgetDataProvider.swift`

**But there is NO widget extension target in the Xcode project.** These files are completely orphaned - they exist on disk but are never compiled. The project only has 3 targets:
1. SwissPortal (app)
2. SwissPortalTests
3. SwissPortalUITests

To make widgets work, you need to add a Widget Extension target in Xcode.

### C. No Location Permission Declared

The app has a `LocationManager` service and "Near Me" activity filtering, but `NSLocationWhenInUseUsageDescription` is not set anywhere - not in a custom Info.plist, not in build settings. The app will crash when requesting location.

### D. Deployment Target is iOS 26.2

`IPHONEOS_DEPLOYMENT_TARGET = 26.2` - this is whatever your Xcode defaulted to. The code uses `@Observable` which requires iOS 17+. If you want anyone besides beta testers to use this, lower it to iOS 17.0.

### E. Tests Won't Pass

The test files (`ModelDecodingTests.swift`, `ViewModelTests.swift`) test against the old model shapes:
- They create `Briefing` with string arguments (old shape)
- They reference `RecurringSchedule` (deleted)
- PreviewData used in tests has been updated but the test assertions may still reference old field paths

### F. `Color("AppPrimary")` References Missing Asset

`Color+Theme.swift` line 6: `static let appPrimary = Color("AppPrimary", bundle: nil)` - but there's no asset catalog with an "AppPrimary" color set. This will silently fall back to clear/default at runtime.

---

## 4. Code Quality Issues (Not Blocking, But Messy)

### Preview Code Bloat
Almost every view file has a `#Preview` block at the bottom that manually constructs full model objects with 15+ parameters. This creates massive maintenance burden - every model change requires updating 5-10 preview blocks. PreviewData.swift was supposed to centralize this but many views have their own inline sample data instead.

### Localization is DIY
Instead of using String Catalogs or `.strings` files, every view manually calls `appState.localized(en: "...", de: "...")`. This is ~200 inline localization calls scattered across views. Works, but doesn't scale to more languages and can't leverage Xcode's localization tools.

### Error Handling Shows Raw Errors
`APIError.decodingError` shows `error.localizedDescription` which gives the user useless messages like "The data couldn't be read because it isn't in the correct format." Should show a user-friendly message and log the actual decoding path for debugging.

### `AppState` is a God Object
`AppState.swift` holds: selected city, language, theme, saved activities, lunch ratings, custom activities, AND provides localization helpers. It's the single `@Observable` environment object. This works for now but will get unwieldy.

### Hardcoded Easter Calculation
`SettingsView.swift` has a full Computus (Easter date calculation algorithm) - 20 lines of math. Fine for correctness, but this logic is duplicated from the worker's `data.js`.

---

## 5. What's Actually Good

- **The MVVM split is clean.** ViewModels fetch data, Views render it. No business logic in views.
- **Actor-based networking is correct.** `APIClient` and `CacheManager` are proper Swift actors.
- **The widget architecture is smart** - lightweight Codable models that don't import the main app, preventing bloat.
- **Client-side fallback for Open-Meteo** is well-implemented. When the worker gets rate-limited, the app fetches directly.
- **The tab structure maps 1:1 to the PWA** which makes feature parity easy to verify.
- **Zero dependencies** means no supply chain risk, no version conflicts, no build complexity.

---

## 6. Recommended Fix Priority

### Must Fix (Before App Store)
1. ~~Models vs API mismatches~~ (DONE in this session)
2. Add `NSLocationWhenInUseUsageDescription` to build settings
3. Lower deployment target to iOS 17.0
4. Add Widget Extension target to Xcode project
5. Fix/update unit tests for new model shapes

### Should Fix (Before Beta)
6. Add `Color("AppPrimary")` to asset catalog (or remove the reference)
7. Add better error messages for decoding failures (log the keyPath)
8. Validate ALL endpoint responses against models (lunch, weekend, snow, sunshine)

### Nice to Have
9. Centralize all preview data in PreviewData.swift, remove inline #Preview constructors
10. Consider String Catalogs for localization
11. Add App Group capability for widget data sharing

---

## 7. Files Changed in This Session

| File | Change |
|------|--------|
| `Models/NewsResponse.swift` | Rewrote `Briefing` from strings to objects, added `url` to `TrendingTopic` |
| `Models/Activity.swift` | Changed `recurring` from `RecurringSchedule?` to `String?`, added `availableMonths`, added `timestamp` to response |
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
