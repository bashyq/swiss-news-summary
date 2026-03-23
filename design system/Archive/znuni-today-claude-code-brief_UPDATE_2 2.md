# Znüni — Today Screen & Agenda Composer
## Claude Code Implementation Brief

---

## 1. CONTEXT

Znüni is a SwiftUI iOS app for Zürich families. It has five tabs: Today (formerly News), Activities, Explore, Weekend, Settings. This document covers the implementation of the **Today tab** and its **AI-powered agenda composer**.

Design system tokens, component patterns, and visual language are already established. All new work must follow the existing system — do not introduce new colours, fonts, or spacing values.

**Design system reference:**
- Primary: `#1A3A5C` (Navy)
- Accent: `#C4623A` (Terracotta)
- Background: `#F5F0E8` (Cream)
- Surface/cards: `#FAF8F4`
- Border: `#E8E0D0`
- Positive: `#3A7D5C`, Negative: `#B04040`
- Fonts: Playfair Display (headers/titles), DM Sans (all body/UI)

---

## 2. SCOPE OF THIS WORK

### What changes
1. Rename "News" tab → "Today" (tab label and associated view)
2. Replace the News screen with the Today screen (news feed becomes a section at bottom)
3. Add the Agenda Composer — an AI-powered daily planner for families
4. Add Session Config — who is today's outing for
5. Add bad weather home mode
6. Add swap mechanic on agenda slots

### What does NOT change
- Activities tab, Explore tab, Weekend tab, Settings tab
- Existing activity card component
- Existing news card component (reused at bottom of Today)
- Design system, colour tokens, typography

---

## 3. DATA MODEL CHANGES REQUIRED FIRST

Before building any UI, update the data models. The agenda composer depends on structured data.

### 3a. Activity model additions

```swift
struct Activity: Identifiable, Codable {
    // EXISTING fields — do not remove
    let id: String
    let name: String
    let category: String
    let description: String
    let indoorOutdoor: IndoorOutdoor
    let durationMinutes: ClosedRange<Int>
    let openingHoursDisplay: String   // keep for display
    let priceDisplay: String
    let ageDisplay: String
    let distanceKm: Double
    
    // NEW fields — add these
    let neighbourhood: String         // e.g. "Kreis 1", "Seefeld", "Kreis 5"
    let ageMin: Int                   // minimum recommended age
    let ageMax: Int                   // maximum recommended age (99 = all ages)
    let openDays: [Weekday]           // structured open days
    let openingHour: Int              // 24h, e.g. 10
    let closingHour: Int              // 24h, e.g. 17
    let isFree: Bool
    let priceAdult: Double?           // CHF, nil if free
    let priceChild: Double?           // CHF, nil if free or same as adult
}

enum Weekday: String, Codable, CaseIterable {
    case monday, tuesday, wednesday, thursday, friday, saturday, sunday
}

enum IndoorOutdoor: String, Codable {
    case indoor, outdoor, both
}
```

### 3b. Restaurant model additions

```swift
struct Restaurant: Identifiable, Codable {
    // EXISTING fields — do not remove
    let id: String
    let name: String
    let description: String
    let cuisine: String
    let priceDisplay: String
    let distanceKm: Double
    
    // NEW fields — add these
    let neighbourhood: String
    let kidFriendly: Bool
    let servesLunch: Bool
    let servesDinner: Bool
    let priceRange: Int               // 1 = budget, 2 = mid, 3 = expensive
    let openingHour: Int
    let closingHour: Int
    let openDays: [Weekday]
    let bookingAdvised: Bool
}
```

### 3c. New models

```swift
// Who is today's outing for
struct FamilySession: Codable {
    var soloParent: Bool
    var children: [Child]
    
    struct Child: Codable, Identifiable {
        let id: UUID
        var name: String
        var age: Int
    }
}

// One slot in the day's agenda
struct AgendaSlot: Codable, Identifiable {
    let id: String                    // "morning", "lunch", "afternoon", "dinner"
    let time: String                  // display string e.g. "10:00"
    let type: SlotType
    let venueName: String
    let venueId: String?              // links to Activity or Restaurant id
    let reason: String                // Claude's reasoning, shown as subtext
    let durationDisplay: String?
    let travelNote: String?           // e.g. "8 min walk from home"
    let swaps: [SwapOption]
    
    enum SlotType: String, Codable {
        case activity, lunch, dinner
    }
    
    struct SwapOption: Codable, Identifiable {
        let id: String
        let venueName: String
        let detail: String            // e.g. "Free · 12 min walk"
    }
}

// Full agenda for one day
struct DayAgenda: Codable {
    let date: Date
    let sessionSnapshot: FamilySession
    let theme: String                 // e.g. "Rainy Saturday with Mia"
    let weatherNote: String
    let badWeatherMode: Bool
    let slots: [AgendaSlot]
    let homeActivities: HomeActivities?
    
    struct HomeActivities: Codable {
        let baking: HomeActivity?
        let movie: MoviePick?
        let craft: HomeActivity?
        
        struct HomeActivity: Codable {
            let idea: String
            let reason: String
            let durationDisplay: String
            let ageNote: String?
        }
        
        struct MoviePick: Codable {
            let title: String
            let year: Int
            let reason: String
            let platform: String
            let durationMinutes: Int
            let isFree: Bool
        }
    }
}
```

### 3d. Supporting stores

```swift
// Tracks what has been shown recently to avoid repetition
class RecentlyShownStore {
    private let key = "znuni.recentlyShown"
    private let expiryDays = 14
    
    func recordShown(venueId: String) { /* write to UserDefaults with timestamp */ }
    func recentlyShownIds() -> [String] { /* return ids shown within 14 days */ }
    func clear() { /* for testing */ }
}

// Caches today's agenda keyed by date + session hash
class AgendaCache {
    func cachedAgenda(for date: Date, session: FamilySession) -> DayAgenda?
    func store(_ agenda: DayAgenda, for date: Date, session: FamilySession)
    func invalidate() // called when session changes
}
```

### 3e. Anchor model

```swift
struct DayAnchor: Codable, Identifiable {
    let id: UUID
    var label: String          // free text — "Birthday party", "Football match"
    var time: Date             // full Date with today's date + chosen time
    var neighbourhood: String? // optional — used for travel clustering
    var durationMinutes: Int?  // optional — used to determine what fits after
    let createdDate: Date      // date anchor was created — used for end-of-day purge
}

// Stored in UserDefaults. Purged at start of each new day.
class AnchorStore {
    private let key = "znuni.dayAnchors"

    func anchors() -> [DayAnchor]
    func add(_ anchor: DayAnchor)
    func remove(id: UUID)
    func purgeIfNewDay()   // call on app foreground — deletes anchors from previous days
}
```

`purgeIfNewDay()` compares `anchor.createdDate` calendar day to today. If different, delete. Call from `TodayView.onAppear` and from `ScenePhase.active` in the app lifecycle. Anchors never persist beyond their creation day.

---

## 4. TODAY SCREEN — VIEW STRUCTURE

### Tab rename
In your tab bar / main navigation:
- Rename "News" label to "Today"
- Replace `NewsView` with `TodayView`
- News is no longer a separate tab — it lives inside TodayView behind a segment toggle

### Sub-view toggle: Plan / News

`TodayView` has two sub-views toggled by a **Plan / News segment control** in the header. This is the primary navigation between planning and news consumption within the Today tab.

```swift
enum TodaySubView {
    case plan
    case news
}

// In TodayView:
@State private var subView: TodaySubView = .plan
```

The segment control appears in the header on every Today state — browsing, execution, and news. Its visual weight adapts per mode:
- **Browsing mode**: Full-size segment, right-aligned next to the "Today in Zürich" title
- **News mode**: Full-size segment, same position (News segment active)
- **Execution mode**: Smaller, subdued variant (`seg-control-exec`) top-right of header — available but not drawing attention away from logistical info

### TodayView composition

```
TodayView
├── TodayHeaderView
│   ├── Status bar
│   ├── Eyebrow (date)
│   ├── Title + SegmentControl (Plan / News)   ← always present
│   ├── [if .plan + browsing]  WeatherRow + SessionPill + ContextBanner
│   ├── [if .plan + executing] ProgressDots + CurrentSlotHero + UpNextStrip
│   └── [if .news]             NewsCount + CategoryFilters
│
├── [if subView == .plan]
│   └── ScrollView
│       ├── TransportAlertView       // conditional
│       ├── AgendaView
│       │   ├── AgendaLoadingView
│       │   ├── AgendaTimelineView   // good weather
│       │   └── BadWeatherAgendaView // bad weather
│       └── LetGoButton / EditPlanLink
│
└── [if subView == .news]
    └── ScrollView
        ├── TransportAlertView       // conditional — same component
        ├── ThisDayInHistoryView     // existing
        └── NewsFeedView             // existing news cards + category tabs
```

### Key structural decisions

**News moves entirely to the News sub-view.** It no longer appears at the bottom of the Plan scroll. When the user is in the Plan sub-view, there is no news content — the two are completely separate. This keeps execution mode clean: no news bleeding into logistical view.

**Transport alerts appear in both sub-views.** A disruption is relevant whether you're planning or reading news. Same `TransportAlertView` component, rendered at the top of both scrolls.

**ThisDayInHistory and news cards move to the News sub-view.** They were previously demoted to the bottom of Plan. They now belong entirely in News — better thematic fit, cleaner Plan.

**Category filters move to the header when News is active.** "Top Stories · Politics · Events · Culture" pill row sits in the header below the story count, not at the top of the scroll content. This keeps the news header consistent with how the rest of the app uses headers as navigation/filter surfaces.

---

## 5. HEADER — TodayHeaderView

The header adapts based on weather condition.

### Good weather (temp ≥ 10° OR no heavy rain/snow)
- Background: Navy `#1A3A5C`
- All existing styling from current News header

### Bad weather (temp < 10° AND heavy rain or snow)
- Background: `#2C2018` (dark warm brown)
- Text: `#F5E8D4` for title, `#F0D0A8` for temperature
- Context banner: warm amber tones
- Everything else same structure

### Bad weather trigger condition
```swift
var isBadWeatherDay: Bool {
    guard let weather = currentWeather else { return false }
    let coldEnough = weather.currentTemp < 10
    let badCondition = weather.condition == .heavyRain 
                    || weather.condition == .snow 
                    || weather.condition == .heavySnow
    return coldEnough && badCondition
}
```

### Session config pill
Sits between weather row and context banner. Always visible in header.

```swift
// Tapping opens SessionConfigSheet
SessionPillView(session: familySession)
    .onTapGesture { showSessionConfig = true }
    .sheet(isPresented: $showSessionConfig) {
        SessionConfigSheet(session: $familySession)
    }
```

`SessionConfigSheet` is a simple form:
- Toggle: Solo parent / Both parents
- List of children with names and ages (add/remove)
- "Done" closes sheet, changing session invalidates AgendaCache and triggers rebuild

### Anchor pill

Sits directly below the session config pill. Always visible in browsing mode header. Hidden in execution mode (anchors cannot be edited once the day is underway).

**Empty state** (no anchors):
```
[ + Got plans today? ]
```
Single pill, outlined style, terracotta text. Tapping opens `AnchorFormSheet`.

**With one anchor**:
```
[ 🎂 Birthday party · 15:00 · Wiedikon  ✕ ]
```
Filled pill, navy background, white text. Label truncated to 20 chars if needed. ✕ removes the anchor immediately (with confirmation if agenda already built). Tapping the pill body opens `AnchorFormSheet` pre-filled for editing.

**With multiple anchors** (up to 3):
Each anchor gets its own pill on a new row. A "+ Add another" pill appears after the last one.

```swift
// In TodayHeaderView:
AnchorPillRowView(anchors: anchors, onAdd: { showAnchorForm = true }, onRemove: { id in
    anchorStore.remove(id: id)
    agendaCache.invalidate()
    Task { await buildAgenda() }    // rebuild immediately
})
.sheet(isPresented: $showAnchorForm) {
    AnchorFormSheet(anchor: $editingAnchor, onSave: { anchor in
        anchorStore.add(anchor)
        agendaCache.invalidate()
        Task { await buildAgenda() }  // rebuild with new anchor
    })
}
```

**Effect on agenda cache:** Any anchor change (add, edit, remove) invalidates the cache and triggers an immediate rebuild. The skeleton loader appears while the new agenda composes.

### AnchorFormSheet

Minimal — three fields only:

1. **What** — text field, placeholder "e.g. Birthday party, Football match"
2. **When** — time picker row, same style as `CustomSlotFormSheet`. Defaults to nearest half-hour from now.
3. **Where** (optional) — neighbourhood chips, same component as `CustomSlotFormSheet`. Labelled "Helps us plan what's nearby — optional."

No duration field in v1 — Claude infers a reasonable duration from the label ("birthday party" implies ~2hrs, "coffee with friend" implies ~1hr). Add structured duration if inference proves unreliable.

No lock toggle — anchors are always locked by definition.

Save button: "Add to today" (new) or "Update" (editing existing). Full width, navy fill.

### Context banner
One sentence. Driven by `isBadWeatherDay` and the agenda state:

```swift
var contextBannerText: String {
    if isBadWeatherDay {
        return "Stay-home day — \(weather.tempDisplay) and \(weather.conditionDisplay). Cosy morning at home, one afternoon outing."
    } else if weather.condition == .partlyCloudy || weather.condition == .sunny {
        return "Good day for getting out. Built a full day around \(session.childrenDisplay) — mostly outdoors."
    } else {
        return "Mixed conditions today. Mix of indoor and outdoor suggestions."
    }
}
```

---

## 6. AGENDA COMPOSER — FULL SPECIFICATION

### 6a. Flow

```
TodayView appears
    ↓
Check AgendaCache for today's date + current FamilySession hash
    ↓
Cache hit? → Display immediately
    ↓
No cache → Show AgendaLoadingView (skeleton)
    ↓
Build prompt → POST to Anthropic API
    ↓
Parse JSON response → DayAgenda
    ↓
Store in AgendaCache
    ↓
Display AgendaTimelineView or BadWeatherAgendaView
    ↓
API failure / timeout (>5s) → Fall back to TemplateEngine
```

### 6b. API call

```swift
class AgendaComposer {
    private let apiURL = URL(string: "https://api.anthropic.com/v1/messages")!
    
    func compose(
        weather: WeatherData,
        session: FamilySession,
        activities: [Activity],
        restaurants: [Restaurant],
        recentlyShown: [String],
        homeNeighbourhood: String,
        currentTime: Date
    ) async throws -> DayAgenda {
        
        let prompt = buildPrompt(
            weather: weather,
            session: session,
            activities: activities,
            restaurants: restaurants,
            recentlyShown: recentlyShown,
            homeNeighbourhood: homeNeighbourhood,
            currentTime: currentTime
        )
        
        let request = AnthropicRequest(
            model: "claude-sonnet-4-20250514",
            maxTokens: 1500,
            system: systemPrompt,
            messages: [.init(role: "user", content: prompt)]
        )
        
        // POST, parse response, extract JSON from content[0].text
        // Strip any markdown fences if present
        // Decode as DayAgenda
    }
}
```

### 6c. System prompt

```
You are a family day planner for Zürich, Switzerland. You build structured daily agendas for families with children.

Your job is to compose a single day's agenda as valid JSON. Return ONLY the JSON object — no explanation, no markdown fences, no preamble.

Rules:
1. All suggested venues must come from the provided activities and restaurants data. Do not invent venues.
2. Slots must be geographically coherent — lunch should be near the morning activity, dinner near the afternoon activity.
3. Age-appropriateness is non-negotiable. Match activities to the children's ages.
4. Never suggest a venue from the recentlyShownIds list.
5. For bad weather days (temp < 10 AND heavy rain or snow): set badWeatherMode to true, populate homeActivities, include only ONE afternoon slot and ONE dinner slot in the slots array.
6. For good weather days: include morning activity, lunch, afternoon activity, dinner — four slots.
7. The "reason" field for each slot must be 1–2 sentences explaining why this fits this specific family today. Be specific about age, weather, geography.
8. Each slot must include 2–3 swap alternatives drawn from the provided data.
9. For homeActivities: baking ideas and craft ideas should be Zürich/Swiss themed where possible. Movie picks should be available on Swiss streaming (SRF Play Kids, Netflix CH, Disney+).
10. Travel notes between slots: calculate approximate walk time if venues are in the same neighbourhood, or name the tram line if different neighbourhoods.
11. If anchors are provided: treat them as immovable locked slots. Build all other slots around them. Do not schedule anything that overlaps with an anchor. If the anchor is in the afternoon, suggest morning activity + lunch only, then dinner after the anchor ends if time permits (before 20:30 for families with young children). If an anchor duration is not provided, infer a reasonable duration from its label.
12. Anchor slots must appear in the JSON output as regular AgendaSlot entries with source "userAnchor" and isLocked true. Include swaps: [] and reason: "" for anchor slots — do not invent alternatives or reasoning for user commitments.

Output schema: [paste DayAgenda Codable struct here at runtime]
```

### 6d. User prompt template

```swift
func buildPrompt(...) -> String {
    """
    Build a day agenda for:
    - Date: \(date.formatted(.dateTime.weekday(.wide).day().month()))
    - Weather: \(weather.condition), \(weather.currentTemp)°C, H:\(weather.highTemp)° L:\(weather.lowTemp)°
    - Family: \(session.soloParent ? "Solo parent" : "Both parents"), children: \(session.childrenDescription)
    - Home neighbourhood: \(homeNeighbourhood)
    - Current time: \(currentTime.formatted(.dateTime.hour().minute())) — only suggest slots from now onwards
    - Recently shown venues (DO NOT suggest these): \(recentlyShown.joined(separator: ", "))
    \(anchors.isEmpty ? "" : """
    Anchors — build around these, treat as locked:
    \(anchors.map { $0.promptDescription }.joined(separator: "\n"))
    """)
    
    Available activities:
    \(activities.map { $0.agendaDescription }.joined(separator: "\n"))
    
    Available restaurants:
    \(restaurants.map { $0.agendaDescription }.joined(separator: "\n"))
    
    Return the JSON agenda now.
    """
}

// Extension helpers
extension Activity {

extension DayAnchor {
    var promptDescription: String {
        var parts = ["\"(label)\" at \(time.formatted(.dateTime.hour().minute()))"]
        if let n = neighbourhood { parts.append("in \(n)") }
        if let d = durationMinutes { parts.append("~\(d) min") }
        return parts.joined(separator: ", ")
    }
}
    var agendaDescription: String {
        "[\(id)] \(name) | \(neighbourhood) | ages \(ageMin)–\(ageMax) | \(indoorOutdoor.rawValue) | open \(openDays.map(\.rawValue).joined(separator: "/")) \(openingHour):00–\(closingHour):00 | \(isFree ? "free" : "CHF \(priceAdult ?? 0)")"
    }
}

extension Restaurant {
    var agendaDescription: String {
        "[\(id)] \(name) | \(neighbourhood) | \(kidFriendly ? "kid-friendly" : "adults") | lunch:\(servesLunch) dinner:\(servesDinner) | price:\(priceRange) | \(openDays.map(\.rawValue).joined(separator: "/")) \(openingHour):00–\(closingHour):00"
    }
}
```

---

## 7. AGENDA UI — AgendaTimelineView

### Timeline structure (good weather)
Vertical timeline with 4 slots connected by travel connectors.

Each `AgendaSlotCard`:
- Left accent bar (3px): Navy for activities, Terracotta for lunch, `#7B5EA7` for dinner
- Timeline dot matches accent colour
- Time label above dot (10px, muted)
- Card content: type eyebrow, venue name (Playfair 15/600), reason text (DM Sans 12/300), tags row, footer with travel note + swap button

Travel connectors between slots:
- Dashed vertical line (2px, border colour)
- Chip showing transport: "🚶 12 min walk" or "🚃 Tram 4 · 2 stops"

### Swap tray
Revealed when user taps "⇄ N swaps" button. Expands inline below the card footer.
- Horizontal scroll of `SwapOptionCard` items
- Tapping a swap: replaces slot content, updates travel connectors for adjacent slots
- If swap venue is different neighbourhood: show brief "travel updated" animation on adjacent connector
- No second API call needed for swap — just re-label travel connectors based on neighbourhood comparison

### Rebuild button
Small secondary button in section header. Invalidates cache, triggers new API call. Shows loading state while rebuilding.

### Lunch slot — "Suggest another" button

The lunch slot has an additional interaction not present on activity or dinner slots: a **"Suggest another nearby →"** button below the card. This is local filtering only — no API call, instant response.

**How it works:**
1. The `DayAgenda` lunch slot carries a `targetNeighbourhood` field — the neighbourhood of the morning activity (set by Claude at compose time)
2. On tap, filter the full restaurant list: `servesLunch == true` + neighbourhood matches `targetNeighbourhood` or an adjacent neighbourhood + not in `recentlyShownIds` + not the currently shown restaurant
3. Pick randomly from the filtered pool
4. Replace lunch card content with fade transition (`easeInOut`, 0.2s)
5. Record new restaurant in `RecentlyShownStore`
6. If pool is exhausted, widen to adjacent neighbourhoods before giving up

**Neighbourhood adjacency map** — add as a static lookup. Fill in all Zürich Kreise you use in the data:

```swift
static func adjacentNeighbourhoods(_ neighbourhood: String) -> [String] {
    switch neighbourhood {
    case "Kreis 1":  return ["Kreis 2", "Kreis 4", "Seefeld"]
    case "Kreis 2":  return ["Kreis 1", "Kreis 3", "Enge"]
    case "Kreis 3":  return ["Kreis 2", "Kreis 4", "Wiedikon"]
    case "Kreis 4":  return ["Kreis 1", "Kreis 3", "Kreis 5"]
    case "Kreis 5":  return ["Kreis 4", "Kreis 6", "Kreis 1"]
    case "Kreis 6":  return ["Kreis 5", "Kreis 7", "Kreis 1"]
    case "Kreis 7":  return ["Kreis 6", "Kreis 8", "Witikon"]
    case "Kreis 8":  return ["Kreis 7", "Kreis 1", "Seefeld"]
    case "Seefeld":  return ["Kreis 1", "Kreis 8", "Kreis 7"]
    case "Wiedikon": return ["Kreis 3", "Kreis 2", "Kreis 4"]
    default:         return ["Kreis 1"]
    }
}
```

**DayAgenda model addition** — the lunch slot needs the target neighbourhood:

```swift
// In AgendaSlot, add:
let targetNeighbourhood: String?  // only populated for lunch slots
```

**LunchSlotCard implementation:**

```swift
struct LunchSlotCard: View {
    @State private var displayedRestaurant: Restaurant
    let targetNeighbourhood: String
    let allRestaurants: [Restaurant]
    let recentlyShown: RecentlyShownStore

    var nearbyPool: [Restaurant] {
        let exact = allRestaurants.filter {
            $0.servesLunch &&
            $0.neighbourhood == targetNeighbourhood &&
            !recentlyShown.recentlyShownIds().contains($0.id) &&
            $0.id != displayedRestaurant.id
        }
        if !exact.isEmpty { return exact }
        // Widen to adjacent
        let adjacent = adjacentNeighbourhoods(targetNeighbourhood)
        return allRestaurants.filter {
            $0.servesLunch &&
            adjacent.contains($0.neighbourhood) &&
            !recentlyShown.recentlyShownIds().contains($0.id) &&
            $0.id != displayedRestaurant.id
        }
    }

    func suggestAnother() {
        guard let next = nearbyPool.randomElement() else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            displayedRestaurant = next
        }
        recentlyShown.recordShown(venueId: next.id)
    }

    var body: some View {
        VStack(spacing: 0) {
            AgendaSlotCard(/* display displayedRestaurant */)
            
            // Suggest another button — lunch slot only
            Button(action: suggestAnother) {
                HStack {
                    Text("Suggest another nearby")
                    Image(systemName: "arrow.right")
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color("znuni.terra"))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color("znuni.surface"))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color("znuni.border"), lineWidth: 1.5)
                )
                .cornerRadius(12)
            }
            .padding(.top, 8)
            .disabled(nearbyPool.isEmpty)
            .opacity(nearbyPool.isEmpty ? 0.4 : 1)
        }
    }
}
```

**Visual spec for the button:**
- Full width, same horizontal padding as the card above it (16px from screen edges)
- Height: 44px
- Style: secondary outlined — `znuni.surface` fill, `znuni.border` stroke (1.5px), 12px corner radius
- Text: "Suggest another nearby →" in `znuni.terra` (#C4623A), DM Sans 13/500
- Disabled state: 40% opacity when pool is empty
- No spinner — the swap is instant, animation is the card content fading

---

## 8. BAD WEATHER UI — BadWeatherAgendaView

### Structure
```
HomeActivitiesSection
    ├── BakingCard
    ├── MovieCard  
    └── CraftCard
SectionDivider ("One outing — if you dare")
AgendaTimelineView (single afternoon slot + dinner only)
```

### HomeActivityCard
- Thumbnail on left (76px wide): gradient background with emoji
  - Baking: warm gold gradient
  - Movie: cool blue-purple gradient
  - Craft: warm terracotta gradient
- Body: label (eyebrow, terracotta), name (Playfair), description, tags

### Dark header
When `isBadWeatherDay` is true, `TodayHeaderView` uses `#2C2018` background. All text shifts to warm amber tones. This is the only place in the app with this background colour — do not reuse it elsewhere.

---

## 9. OPTION A — TEMPLATE ENGINE FALLBACK

Called when API fails or times out after 5 seconds.

```swift
class TemplateEngine {
    func buildAgenda(
        weather: WeatherData,
        session: FamilySession,
        activities: [Activity],
        restaurants: [Restaurant],
        recentlyShown: [String]
    ) -> DayAgenda {
        let archetype = selectArchetype(weather: weather, session: session)
        return archetype.build(
            activities: activities,
            restaurants: restaurants,
            recentlyShown: recentlyShown
        )
    }
    
    private func selectArchetype(weather: WeatherData, session: FamilySession) -> Archetype {
        switch (weather.isBadWeather, weather.isSunny, session.soloParent, session.youngestChildAge) {
        case (true, _, _, _):           return .badWeatherHomeDay
        case (_, true, true, ..<5):     return .sunnyDaySoloToddler
        case (_, true, true, 5...):     return .sunnyDaySoloOlderKid
        case (_, true, false, _):       return .sunnyDayBothParents
        case (_, false, true, ..<5):    return .rainyDaySoloToddler
        case (_, false, true, 5...):    return .rainyDayMuseumSolo
        default:                        return .rainyDayMuseumFamily
        }
    }
}
```

Each archetype references activity IDs and restaurant IDs from the data. Rotation logic:
- Each archetype has a pool of 4–6 activity options per slot
- `RecentlyShownStore` filters the pool before selection
- If pool is exhausted (all shown recently), reset that archetype's rotation

---

## 10. LOADING STATE

While the API call is in progress, show `AgendaLoadingView`:

```swift
struct AgendaLoadingView: View {
    var body: some View {
        VStack(spacing: 12) {
            // Section header skeleton
            HStack {
                RoundedRectangle(cornerRadius: 4).frame(width: 100, height: 20)
                Spacer()
                RoundedRectangle(cornerRadius: 4).frame(width: 60, height: 14)
            }
            // Three card skeletons
            ForEach(0..<3) { _ in
                RoundedRectangle(cornerRadius: 16).frame(height: 110)
            }
        }
        .padding(.horizontal, 16)
        .redacted(reason: .placeholder)
        .shimmering() // use Shimmer package or custom shimmer modifier
    }
}
```

---

## 11. BUILD ORDER

Do these in sequence. Each step is independently testable.

**Step 1 — Data model** (prerequisite for everything)
- Add new fields to Activity, Restaurant
- Create FamilySession, AgendaSlot, DayAgenda, HomeActivities models
- Create RecentlyShownStore (UserDefaults wrapper)
- Create AgendaCache (UserDefaults, keyed by date + session hash)
- Update all existing hardcoded activity/restaurant data with new fields

**Step 2 — Session config**
- SessionConfigSheet view (simple form)
- SessionPillView component
- Wire to UserDefaults persistence

**Step 3 — Template engine (Option A fallback)**
- Build all 7 archetypes referencing real activity IDs
- Wire rotation logic via RecentlyShownStore
- Test independently: call `TemplateEngine.buildAgenda()` and verify output

**Step 4 — Today screen shell**
- Rename News tab to Today
- Create `TodaySubView` enum (.plan / .news)
- Create TodayView with Plan/News segment control
- Header: weather logic (good/bad weather), segment control in all three states
- Wire session pill
- Context banner logic (plan mode) and news category filters (news mode)
- NewsFeedView — move existing news cards + ThisDayInHistory + category tabs here
- TransportAlertView — shared between both sub-views

**Step 5 — Agenda UI**
- AgendaLoadingView (skeleton)
- AgendaSlotCard component (base — used for activity and dinner slots)
- LunchSlotCard component (extends AgendaSlotCard, adds "Suggest another nearby" button)
- TravelConnectorView component
- SwapTray component
- AgendaTimelineView (composes the above — uses LunchSlotCard for lunch slot, AgendaSlotCard for all others)
- BadWeatherAgendaView + HomeActivityCard

**Step 6 — API integration**
- AgendaComposer class with full prompt builder
- Wire to TodayView: on appear, check cache, fire composer if needed
- Parse DayAgenda JSON from response
- Handle errors gracefully → fall back to TemplateEngine
- Cache successful responses

**Step 7 — Polish**
- Rebuild button + animation
- Swap interaction (replace slot, update travel connectors)
- Session change → cache invalidation → rebuild
- Test bad weather trigger at boundary conditions (exactly 10°, mixed conditions)

**Step 8 — Execution mode**
- Add `AgendaMode` enum and `@State var agendaMode` to TodayView
- Update `AgendaSlot` — replace `time: String` with `slotDate: Date`, add `travelMinutesToNext: Int?`
- `ExecHeaderView` — progress dots, current slot hero, "Up next" strip, leave-at calculation
- Update `AgendaSlotCard` to render done/active/future states based on mode
- `TravelConnectorView` — urgent style for upcoming connector in execution mode
- "Let's go →" button — triggers mode transition with crossfade
- "Done ✓" secondary button on active card — advances slot index
- "← Edit plan" escape link — returns to browsing
- Persist `agendaMode` to UserDefaults keyed by date
- Completion state for final slot

**Step 9 — Custom slots and slot editing**
- Add `SlotSource` enum and `isLocked: Bool` to `AgendaSlot`
- `SlotEditSheet` — bottom sheet with options: Edit time / Replace with my own / Lock / Remove
- `CustomSlotFormSheet` — venue text field, time picker row, neighbourhood chips, lock toggle, Save button
- Custom slot card rendering — dashed border, green accent bar, "✏️ Your plans" badge, no swap/suggest buttons
- Locked slot card rendering — solid navy border, "🔒 Locked" badge, reason text hidden
- Tight travel warning — when gap between slot end and next slot start is < 20 min, show amber warning chip on connector
- Stale slot dimming — when custom slot changes neighbourhood/time, dim downstream AI slots at 45% opacity with "⚠️ May need updating" type label
- Reflow banner — appears below custom slot after save: "Lunch updated. Recalculate afternoon + dinner?" with Rebuild / Keep
- Reflow API call — passes locked slots as constraints, requests only unlocked slots; same composer flow as initial build
- "Let's go →" button disabled (50% opacity) while reflow banner is showing — user must resolve before executing

**Step 10 — Check-in, timeline shift, and notifications**
- Add `latitude: Double` and `longitude: Double` to `Activity` and `Restaurant` models
- Add `checkInTime: Date?`, `checkOutTime: Date?`, `wasAutoCheckedIn: Bool` to `AgendaSlot`
- `CheckInRecord` model — venueId, scheduledTime, actualTime, delta, source, date
- `CheckInStore` — UserDefaults-backed log, 90-day cap, feeds `RecentlyShownStore` on day completion
- `TimelineShifter` — takes delta + slots array, returns shifted slots; pure function, no side effects
- `FeasibilityChecker` — checks opening hours, dinner-after-20:00, activity duration squeeze against shifted times
- Wire "Done ✓" button in execution mode → check-in → `TimelineShifter` → update slot dates → animate time changes on cards
- Trim suggestion banner — shown when feasibility check fails; single specific resolution, two buttons only
- `GeofenceMonitor` (optional enhancement, requires Always location permission)
  - `startMonitoring(slots:)` — called on "Let's go →"
  - `stopMonitoring()` — called on day completion or "← Edit plan"
  - On region entry: fires check-in, records to `CheckInStore`
  - On region exit: records check-out time
  - Fallback prompt: if 30 min past scheduled start with no check-in, fire once: "Are you at [venue]?"
- Local notifications via `UNUserNotificationCenter` (no server, no push certificates)
  - "Leave now" nudge: fires at `nextSlot.slotDate - travelMinutesToNext - 5 minutes` while user still checked in to current slot
  - Label: "Time to leave for [next venue] — [transport] in [N] min"
  - Scheduled at execution mode start, cancelled and rescheduled whenever `TimelineShifter` runs
  - Fallback check-in prompt: fires 30 min past scheduled start if no geofence triggered
- Permission ask: request notification permission on first "Let's go →" tap only, with contextual explanation before the system prompt
- Permission ask: request Always location permission only after user has completed one execution session, never on first run

**Step 11 — Anchor slots**
- Add `DayAnchor` model and `AnchorStore` (section 3e)
- Add `purgeIfNewDay()` call in `TodayView.onAppear` and `ScenePhase.active`
- `AnchorPillRowView` — renders empty "+ Got plans today?" pill and filled anchor pills
- `AnchorFormSheet` — three fields: label, time picker row, optional neighbourhood chips
- Wire anchor add/edit/remove → `AnchorStore` → cache invalidate → rebuild
- Update `AgendaComposer.buildPrompt()` — inject anchors block when `anchors` is non-empty
- Add `.userAnchor` handling in `AgendaTimelineView` — anchor cards render like locked cards but with no edit affordance (no `···` button) and no swap tray
- Add `DayAnchor.promptDescription` extension
- Test: add birthday party anchor at 15:00 → verify agenda has no afternoon activity slot, morning + lunch only, dinner after 17:00

---


---

## 11b. EXECUTION MODE

When the user taps "Let's go →", the agenda transitions from browsing to execution. This is a mode change, not a navigation push — the same TodayView, different state.

### State model

```swift
enum AgendaMode {
    case browsing
    case executing(currentSlotIndex: Int)
}

// In TodayView:
@State private var agendaMode: AgendaMode = .browsing
```

Persisted to UserDefaults keyed by todays date — if the user leaves the app mid-day and returns, they come back to execution mode at the correct slot.

### "Let's go →" button

- Position: Below the timeline in browsing mode, full width, terracotta fill, 100px corner radius
- Colour: `znuni.terra` (#C4623A) with shadow `rgba(196,98,58,0.35)` blur 16px
- Label: "Let's go →"
- On tap: `agendaMode = .executing(currentSlotIndex: firstSlotIndex)`
- Transition: crossfade 0.3s — header morphs, cards shift state

### Header transformation

Browsing header → Execution header. Key changes:

- Background deepens: `#1A3A5C` → `#0F2238`
- Subtle grid texture overlay (repeating lines at 2% opacity)
- Weather row removed
- Session pill removed
- Context banner ("Built a full day...") → "Up next" strip
- New elements added:
  - Eyebrow: "Slot N of 4"
  - Progress dots: 4 dots connected by lines. Done = positive green. Active = terracotta with glow ring. Future = 15% white
  - Current slot hero: slot type label, venue name (Playfair 26px), large time (38px/300 weight), duration
  - "Up next" strip: next venue name + time + "Leave at HH:MM" chip (terracotta tint)

```swift
struct ExecHeaderView: View {
    let agenda: DayAgenda
    let currentSlotIndex: Int
    
    var currentSlot: AgendaSlot { agenda.slots[currentSlotIndex] }
    var nextSlot: AgendaSlot? {
        currentSlotIndex + 1 < agenda.slots.count
            ? agenda.slots[currentSlotIndex + 1] : nil
    }
    
    // "Leave in N min" — calculated from nextSlot.time minus travel duration
    var leaveAtDisplay: String? {
        guard let next = nextSlot,
              let travelMins = currentSlot.travelMinutesToNext else { return nil }
        // parse next.time "13:30" → subtract travelMins → format as "13:20"
        return formattedLeaveTime(slotTime: next.time, travelMinutes: travelMins)
    }
}
```

### AgendaSlot model addition

```swift
// Add to AgendaSlot:
let travelMinutesToNext: Int?   // used for "Leave at" calculation in execution mode
                                // Claude sets this at compose time
```

### Card states in execution mode

**Done cards** (slots before currentSlotIndex):
- Opacity 0.5
- Left accent bar → positive green
- Timeline dot → positive green fill
- Content collapsed: "✓ Done" label + venue name only, no tags, no reason
- Not tappable

**Active card** (currentSlotIndex):
- Full opacity, elevated shadow, navy border 1px `rgba(26,58,92,0.1)`
- Timeline dot: terracotta with pulsing glow ring (`@State var pulse` animation)
- Time shown large (22px) with open status
- Reason text hidden
- Swap button hidden
- Shows "Get directions" CTA (full width, filled):
  - Activity/morning/afternoon: navy fill
  - Lunch/dinner: terracotta fill
  - Dinner: `#7B5EA7` fill
- "Get directions" opens Apple Maps with venue coordinates

**Future cards** (slots after currentSlotIndex):
- Opacity 0.75
- Reason text hidden
- Swap button hidden
- Tags row visible
- No CTA
- Not expandable until they become active

### Travel connectors in execution mode

- Done travel connectors: 40% opacity
- Upcoming connector (between active and next slot): urgent style
  - Background `rgba(196,98,58,0.08)`, border `rgba(196,98,58,0.25)`, text terracotta
  - Shows "🚃 Leave at HH:MM · Tram N" or "🚶 Leave at HH:MM · N min walk"
- Future connectors: standard style, 50% opacity

### Advancing slots

No automatic advancement. User manually marks a slot done by tapping the active card's "Done ✓" secondary button (small, below "Get directions"):

```swift
Button("Done ✓") {
    withAnimation(.easeInOut(duration: 0.3)) {
        agendaMode = .executing(currentSlotIndex: currentSlotIndex + 1)
    }
}
.font(.system(size: 12, weight: .medium))
.foregroundColor(Color("znuni.muted"))
```

If tapped on the last slot (dinner), transition to a simple "Great day! 🎉" completion state — just a card with a warm message, no further action needed.

### "Edit plan" escape hatch

Always visible in execution mode, bottom of screen, centred, small:
- Label: "← Edit plan"
- Style: plain text, `znuni.muted` colour, 12px
- On tap: `agendaMode = .browsing` — returns to browsing mode preserving all swaps
- Does NOT regenerate the agenda

### Slot times as Date objects

Execution mode requires time calculation ("Leave in 12 min"). Slot times must be stored as actual `Date` objects, not display strings. Update `AgendaSlot`:

```swift
// Replace:
let time: String   // "10:00"

// With:
let slotDate: Date              // full Date with todays date + slot time
var timeDisplay: String {       // computed display string
    slotDate.formatted(.dateTime.hour().minute())
}
```

Claude returns times as "HH:MM" strings — the app constructs the full `Date` by combining todays calendar date with the parsed hour/minute at decode time.

### What does NOT change in execution mode

- Tab bar — unchanged
- Tapping an active card still expands it in place (same as browsing)
- Future cards: tapping does nothing until they become active
- Bad weather home activity cards: no execution mode (home activities have no directions or timing logic)


---

## 11c. CUSTOM SLOTS AND SLOT EDITING

### SlotSource and isLocked — model additions

```swift
enum SlotSource: String, Codable {
    case aiGenerated   // Claude composed this
    case userCustom    // user entered manually
    case userSwapped   // user picked from swap tray
    case userAnchor    // pre-existing commitment entered before compose
}

// Add to AgendaSlot:
let source: SlotSource
var isLocked: Bool     // true = never replaced by reflow
var customVenueName: String?      // only set when source == .userCustom
var customNeighbourhood: String?  // used for travel connector logic
```

### SlotEditSheet

Bottom sheet presented when user taps `···` on any slot. Content adapts by source:

**For AI-generated slots:**
- Edit time → `TimeEditSheet` (time picker only)
- Replace with my own → `CustomSlotFormSheet`
- Lock this slot → toggles `isLocked`, dismisses sheet, shows lock badge on card
- Remove slot → removes from agenda, recalculates travel connectors

**For custom slots:**
- Edit → re-opens `CustomSlotFormSheet` pre-filled
- Lock / Unlock → toggles `isLocked`
- Remove slot

**No "Replace with my own" for activity slots** (morning/afternoon) — only lunch and dinner support custom entry. Activity slots support "Edit time" and "Lock" only. This keeps scope manageable.

### CustomSlotFormSheet

Three fields:

1. **Where** — plain text field, no autocomplete needed in this pass
2. **Time** — horizontal row of 4 time buttons (pre-populated with sensible options for the slot type: lunch shows 11:00/11:30/12:00/12:30, dinner shows 17:30/18:00/18:30/19:00). Selected state: navy fill, white text
3. **Neighbourhood** — horizontal scroll of neighbourhood chips. Pre-selects the neighbourhood of the nearest slot. Used only for travel connector calculation — optional, user can skip
4. **Lock toggle** — "Won't be changed if you rebuild the plan" — defaults ON for custom slots

Save button: "Save [slot type] plans" — full width, navy fill, 100px radius

### Custom slot card visual spec

```
Border:      1.5px dashed rgba(58,125,92,0.35)
Background:  rgba(58,125,92,0.03)
Accent bar:  positive green #3A7D5C
Timeline dot: positive green fill
Badge:       "✏️ Your plans" — green pill, top-left before type label
Hidden:      reason text, swap button, suggest another button
Visible:     venue name, time, neighbourhood (as distance/location line)
```

### Locked slot card visual spec

```
Border:      1.5px solid rgba(26,58,92,0.15)
Accent bar:  unchanged (navy/terra/purple per slot type)
Badge:       "🔒 Locked" — navy pill, top-left
Hidden:      reason text, swap button, suggest another button
Visible:     venue name, time, tags row
```

### Tight travel warning

When the gap between a slot's end time and the next slot's start time (minus estimated travel) is less than 20 minutes:

```swift
var isTightConnection: Bool {
    guard let endTime = self.estimatedEndDate,
          let nextStart = nextSlot?.slotDate,
          let travelMins = travelMinutesToNext else { return false }
    let bufferMins = Calendar.current.dateComponents([.minute], from: endTime, to: nextStart).minute ?? 0
    return (bufferMins - travelMins) < 20
}
```

Travel connector chip style when tight:
```
Background: rgba(176,64,64,0.07)
Border:     rgba(176,64,64,0.20)
Text:       #B04040 (znuni.negative)
Label:      "⚠️ Tight — N min to [next venue]"
```

### Stale downstream slots

When a custom slot changes time or neighbourhood, downstream AI-generated slots may no longer be geographically or temporally coherent. Mark them stale:

```swift
var isStale: Bool  // true when upstream slot changed after this was composed
```

Stale card rendering:
- 45% opacity on the entire `tl-item`
- Type label overridden: "⚠️ May need updating" in terracotta
- Swap and suggest buttons hidden

### Reflow banner

Appears below the custom slot card immediately after saving. Dismisses when user taps Rebuild or Keep:

```swift
struct ReflowBanner: View {
    let slotType: String      // "lunch", "dinner"
    let onRebuild: () -> Void
    let onKeep: () -> Void
}
```

"Rebuild" fires a new API call to `AgendaComposer` with locked slots passed as constraints. Prompt addition:

```
Locked slots (do not change these):
- [slot type]: [venue], [time], [neighbourhood]

Please suggest only: [remaining unlocked slot types]
Constraints: starts no earlier than [time after locked slot], spatially coherent with [locked slot neighbourhood]
```

While rebuild is in progress: show skeleton on stale cards. "Let's go →" button is disabled (50% opacity) until resolved.

"Keep" dismisses the banner and clears the stale state — user accepts the old suggestions despite the mismatch.

### Edit affordance visibility

`···` edit button is visible in browsing mode only. Hidden in execution mode — no editing once the day is underway. If the user returns to browsing via "← Edit plan", edit buttons reappear.

---

## 11d. CHECK-IN, TIMELINE SHIFT AND NOTIFICATIONS

### Data model additions

```swift
// Add to Activity and Restaurant:
let latitude: Double
let longitude: Double

// Add to AgendaSlot:
var checkInTime: Date?         // actual arrival time
var checkOutTime: Date?        // actual departure time
var wasAutoCheckedIn: Bool     // true if geofence triggered, false if manual

// New model:
struct CheckInRecord: Codable {
    let venueId: String
    let venueName: String
    let scheduledTime: Date
    let actualTime: Date
    let delta: TimeInterval        // positive = late, negative = early
    let source: CheckInSource
    let date: Date
}

enum CheckInSource: String, Codable {
    case manual     // user tapped Done ✓
    case geofence   // CLLocationManager region entry
}
```

### CheckInStore

```swift
class CheckInStore {
    private let key = "znuni.checkIns"
    private let maxAgeDays = 90

    func record(_ checkIn: CheckInRecord)
    func recentRecords(days: Int) -> [CheckInRecord]

    // Called at end of day — marks all checked-in venues as recently shown
    func flushToRecentlyShown(_ store: RecentlyShownStore)

    // Average delta for a given time-of-day slot — seed for Concept 3 later
    func averageDelta(forHour hour: Int) -> TimeInterval?
}
```

### TimelineShifter

Pure function — no side effects, no API calls, returns new slot array:

```swift
struct TimelineShifter {
    // Apply a uniform delta to all slots after fromIndex
    static func shift(
        slots: [AgendaSlot],
        fromIndex: Int,
        delta: TimeInterval
    ) -> [AgendaSlot] {
        var result = slots
        for i in (fromIndex + 1)..<result.count {
            result[i].slotDate = result[i].slotDate.addingTimeInterval(delta)
        }
        return result
    }
}
```

Called from `TodayView` whenever "Done ✓" is tapped or a geofence check-in fires.

### FeasibilityChecker

Runs after every `TimelineShifter` call. Returns an array of `FeasibilityWarning`:

```swift
struct FeasibilityWarning {
    let slotId: String
    let type: WarningType
    let message: String           // display string
    let suggestedResolution: Resolution?

    enum WarningType {
        case venueClosedAtShiftedTime
        case dinnerTooLate            // dinner shifted past 20:00
        case activityDurationSqueezed // < 30 min before next slot
    }

    enum Resolution {
        case skipSlot(slotId: String)
        case shortenSlot(slotId: String, newEndTime: Date)
    }
}
```

Only surface warnings where `suggestedResolution` exists — silent otherwise. Show as a trim banner below the affected slot, same pattern as reflow banner:

```
"Running late — dinner now at 20:15. Skip Rieterpark and head straight to Lily's at 18:30?"
[Yes, skip it]  [Keep as is]
```

One banner maximum at a time. If multiple warnings exist, surface the most critical (dinner too late > venue closed > duration squeezed).

### Check-in flow — manual

"Done ✓" button already exists on the active slot card in execution mode. Wire it:

```swift
func handleCheckIn(slot: AgendaSlot) {
    let actualTime = Date()
    let delta = actualTime.timeIntervalSince(slot.slotDate)

    // 1. Record check-in
    checkInStore.record(CheckInRecord(
        venueId: slot.venueId ?? slot.venueName,
        scheduledTime: slot.slotDate,
        actualTime: actualTime,
        delta: delta,
        source: .manual,
        date: Calendar.current.startOfDay(for: Date())
    ))

    // 2. Shift timeline if delta is meaningful (> 10 min)
    if abs(delta) > 600 {
        let shifted = TimelineShifter.shift(
            slots: agenda.slots,
            fromIndex: currentSlotIndex,
            delta: delta
        )
        agenda = agenda.with(slots: shifted)

        // 3. Check feasibility
        let warnings = FeasibilityChecker.check(slots: agenda.slots)
        activeWarning = warnings.first

        // 4. Reschedule notifications
        notificationScheduler.reschedule(for: agenda.slots)
    }

    // 5. Advance to next slot
    withAnimation(.easeInOut(duration: 0.3)) {
        agendaMode = .executing(currentSlotIndex: currentSlotIndex + 1)
    }
}
```

### Time update animation

When `TimelineShifter` runs, slot times update on screen. Don't snap — animate:

- Fade out old time value (0.15s)
- Fade in new time value (0.15s)
- Apply to: timeline dot time labels, card time displays, travel connector chips, header "Up next" time and "Leave at" chip
- Total animation: 0.3s, feels like a quiet recalibration not an alarm

### GeofenceMonitor (optional enhancement)

Only instantiated if "Always" location permission is granted. Completely independent of the manual check-in flow — they share the same `handleCheckIn` function, just with `source: .geofence`.

```swift
class GeofenceMonitor: NSObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    private var monitoredSlots: [AgendaSlot] = []
    var onCheckIn: ((AgendaSlot, Date) -> Void)?
    var onCheckOut: ((AgendaSlot, Date) -> Void)?

    func startMonitoring(slots: [AgendaSlot]) {
        monitoredSlots = slots
        for slot in slots {
            guard let lat = slot.venue?.latitude,
                  let lng = slot.venue?.longitude else { continue }
            let region = CLCircularRegion(
                center: CLLocationCoordinate2D(latitude: lat, longitude: lng),
                radius: 150,           // metres
                identifier: slot.id
            )
            region.notifyOnEntry = true
            region.notifyOnExit = true
            locationManager.startMonitoring(for: region)
        }
    }

    func stopMonitoring() {
        locationManager.monitoredRegions.forEach {
            locationManager.stopMonitoring(for: $0)
        }
    }

    func locationManager(_ manager: CLLocationManager,
                         didEnterRegion region: CLRegion) {
        guard let slot = monitoredSlots.first(where: { $0.id == region.identifier })
        else { return }
        onCheckIn?(slot, Date())
    }

    func locationManager(_ manager: CLLocationManager,
                         didExitRegion region: CLRegion) {
        guard let slot = monitoredSlots.first(where: { $0.id == region.identifier })
        else { return }
        onCheckOut?(slot, Date())
    }
}
```

Geofence radius of 150m works for most Zürich venues. For venues in very dense areas (Kreis 1 city centre), consider reducing to 100m — add an optional `geofenceRadius: Double?` field to `Activity`/`Restaurant`, defaulting to 150 if nil.

### Local notification scheduling

```swift
class AgendaNotificationScheduler {

    func schedule(for slots: [AgendaSlot]) {
        // Cancel all existing agenda notifications
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers:
                slots.map { "leave_\($0.id)" } +
                slots.map { "checkin_prompt_\($0.id)" }
            )

        for i in 0..<slots.count {
            let slot = slots[i]

            // "Leave now" notification for current slot
            if let travelMins = slot.travelMinutesToNext {
                let leaveAt = slots[i + 1 < slots.count ? i + 1 : i]
                    .slotDate
                    .addingTimeInterval(Double(-travelMins - 5) * 60)
                scheduleLeaveNotification(slotId: slot.id,
                    venue: slot.venueName,
                    nextVenue: i + 1 < slots.count ? slots[i+1].venueName : "",
                    travelMins: travelMins,
                    fireAt: leaveAt)
            }

            // Fallback check-in prompt — 30 min after scheduled start
            let promptAt = slot.slotDate.addingTimeInterval(30 * 60)
            scheduleCheckInPrompt(slotId: slot.id,
                venue: slot.venueName,
                fireAt: promptAt)
        }
    }

    func reschedule(for slots: [AgendaSlot]) {
        // Called after TimelineShifter runs — cancel and re-schedule
        schedule(for: slots)
    }

    private func scheduleLeaveNotification(
        slotId: String, venue: String,
        nextVenue: String, travelMins: Int, fireAt: Date
    ) {
        let content = UNMutableNotificationContent()
        content.title = "Time to leave for \(nextVenue)"
        content.body = "\(travelMins) min journey — head off now"
        content.sound = .default
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents(
                [.hour,.minute], from: fireAt), repeats: false)
        let request = UNNotificationRequest(
            identifier: "leave_\(slotId)",
            content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
}
```

### Permission request timing

**Notifications:** Request on first "Let's go →" tap. Show a custom in-app explanation screen before the system prompt:

> "Want a nudge when it's time to leave for your next stop? Znüni can remind you — no other notifications."
> [Turn on reminders]  [Not now]

Only show once. If declined, never ask again in-app. The "Leave at" chip in execution mode still works — it's just not a pushed notification.

**Always location (for geofencing):** Never ask on first run. Request only after the user has completed their first full execution session (reached the last slot). Show a custom in-app explanation:

> "Znüni can check you in automatically when you arrive at each stop — no tapping needed. This uses location in the background."
> [Enable automatic check-in]  [I'll check in manually]

If declined: manual check-in works exactly the same. Geofences simply never start. Log the preference so you never ask again.

### What Concept 3 would use from this

`CheckInStore.averageDelta(forHour:)` is the seed. Once you have 10+ check-ins, you can start adjusting suggested slot times in the agenda composer prompt — e.g. "this family typically starts 45 min later than scheduled in the morning." That's a single line addition to the user prompt in `AgendaComposer.buildPrompt()`. Nothing else changes. Defer until you have real data.
## 12. THINGS NOT TO BUILD IN THIS PASS

- Push notifications ("It's sunny Saturday — here's your day")
- "Liked" / favourites persistence beyond the heart icon already on activity cards
- Multi-day planning (Weekend tab owns that)
- Restaurant booking integration
- Real-time open/closed status (use structured hours for display only, not live status)
- Concept 3 — adaptive timing learning from check-in history (`CheckInStore.averageDelta` is stubbed, do not implement the learning layer yet)
- Always location permission request on first run — defer until after first execution session completes
- Server-side push notifications — all notifications in this pass are local `UNUserNotificationCenter` only
- Geofence radius tuning per-venue — use 150m flat for all venues in this pass
- Recurring anchors (e.g. "swimming lessons every Saturday") — anchors are one-off, single-day only, purged at midnight
- Anchor duration field in UI — Claude infers duration from label in v1; add explicit duration picker only if inference proves unreliable after testing
- Anchor suggestions or autocomplete — free text field only, no venue lookup or smart suggestions in this pass

These are future features. Do not add them speculatively.

---

## 13. FILES LIKELY TO BE CREATED OR MODIFIED

**New files:**
- `TodayView.swift`
- `TodayHeaderView.swift`
- `SessionConfigSheet.swift` + `SessionPillView.swift`
- `AgendaComposer.swift`
- `TemplateEngine.swift`
- `AgendaTimelineView.swift`
- `AgendaSlotCard.swift`
- `LunchSlotCard.swift`
- `ExecHeaderView.swift`
- `Models/AgendaMode.swift`
- `Models/TodaySubView.swift`
- `Models/SlotSource.swift`
- `SlotEditSheet.swift`
- `AnchorFormSheet.swift`
- `AnchorPillRowView.swift`
- `Models/DayAnchor.swift`
- `Models/AnchorStore.swift`
- `CheckInStore.swift`
- `TimelineShifter.swift`
- `FeasibilityChecker.swift`
- `GeofenceMonitor.swift`
- `AgendaNotificationScheduler.swift`
- `Models/CheckInRecord.swift`
- `Models/CheckInSource.swift`
- `Models/FeasibilityWarning.swift`
- `CustomSlotFormSheet.swift`
- `TimeEditSheet.swift`
- `NewsFeedView.swift`
- `NeighbourhoodAdjacency.swift`
- `SwapTray.swift`
- `TravelConnectorView.swift`
- `BadWeatherAgendaView.swift`
- `HomeActivityCard.swift`
- `AgendaLoadingView.swift`
- `RecentlyShownStore.swift`
- `AgendaCache.swift`
- `Models/FamilySession.swift`
- `Models/AgendaSlot.swift`
- `Models/DayAgenda.swift`

**Modified files:**
- `Activity.swift` — add new fields
- `Restaurant.swift` — add new fields  
- `ContentView.swift` or main tab view — rename News → Today
- `ActivityData.swift` — populate new fields for all existing entries
- `RestaurantData.swift` — populate new fields for all existing entries
