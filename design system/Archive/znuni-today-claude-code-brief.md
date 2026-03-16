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

---

## 4. TODAY SCREEN — VIEW STRUCTURE

### Tab rename
In your tab bar / main navigation:
- Rename "News" label to "Today"
- Replace `NewsView` with `TodayView`
- `TodayView` contains the news section at its bottom — `NewsView` is no longer a standalone tab destination

### TodayView composition

```
TodayView
├── TodayHeaderView          // navy/dark header with weather + session + context banner
├── ScrollView
│   ├── TransportAlertView   // conditional — only if disruption active
│   ├── AgendaView           // THE NEW SECTION — replaces static picks
│   │   ├── AgendaLoadingView    // skeleton while API call in progress
│   │   ├── AgendaTimelineView   // timeline of slots (good weather)
│   │   └── BadWeatherAgendaView // home activities + single outing (bad weather)
│   ├── ThisDayInHistoryView // existing component, unchanged
│   └── LocalNewsSectionView // existing news cards, demoted to bottom
└── (Tab bar — existing)
```

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
    
    Available activities:
    \(activities.map { $0.agendaDescription }.joined(separator: "\n"))
    
    Available restaurants:
    \(restaurants.map { $0.agendaDescription }.joined(separator: "\n"))
    
    Return the JSON agenda now.
    """
}

// Extension helpers
extension Activity {
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
- Create TodayView with sections in correct order
- Header with weather logic (good/bad weather modes)
- Wire session pill
- Context banner logic
- News section at bottom (reuse existing components)

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

## 12. THINGS NOT TO BUILD IN THIS PASS

- Push notifications ("It's sunny Saturday — here's your day")
- "Liked" / favourites persistence beyond the heart icon already on activity cards
- Multi-day planning (Weekend tab owns that)
- Restaurant booking integration
- Real-time open/closed status (use structured hours for display only, not live status)

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
