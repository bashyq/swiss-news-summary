# Znüni — Analytics & Plan Sharing Spec
## For TestFlight / Friends & Family Release
### v1.0 — March 2026

> **This document defines two features for the TestFlight release:**
> 1. Lightweight analytics via TelemetryDeck — what are people actually doing?
> 2. Plan sharing via native iOS share sheet — does anyone share plans?
>
> Both are low-effort, zero-infrastructure additions that produce signal for the "do we need user accounts / household sync?" decision.

---

## 1. ANALYTICS — TELEMETRYDECK

### 1a. Why TelemetryDeck

- Privacy-first, EU-based (German company), no GDPR/ATT headaches
- Free tier: 100K signals/month — more than enough for 10-20 TestFlight users
- SwiftUI-native SDK via SPM, ~5 min integration
- Built-in funnels, session tracking, retention dashboards
- No user PII ever leaves the device — identifiers are double-hashed
- Cookieless — no ATT prompt required

### 1b. Setup

```swift
// Package.swift / Xcode SPM
// Add: https://github.com/TelemetryDeck/SwiftSDK
// Rule: Up to Next Major Version

// ZnuniApp.swift
import SwiftUI
import TelemetryDeck

@main
struct ZnuniApp: App {
    init() {
        let config = TelemetryDeck.Config(appID: "<APP-ID-FROM-DASHBOARD>")
        TelemetryDeck.initialize(config: config)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

### 1c. Event schema

Events are organised by user flow, not by screen. The goal is to answer specific questions, not log everything.

#### Core questions we need answered

| # | Question | Events that answer it |
|---|----------|----------------------|
| Q1 | Do people use the planner at all? | `plan.generated`, `plan.generated.fallback` |
| Q2 | Do they interact with plans or just look? | `plan.slot.swapped`, `plan.slot.suggestAnother`, `plan.rebuilt` |
| Q3 | Do people actually go do the plan? | `plan.letsGo`, `execution.slot.done` |
| Q4 | Do they share plans? | `plan.shared` |
| Q5 | What's the main entry point? | `tab.switched` with tab parameter |
| Q6 | Is the session config used? | `session.changed` |
| Q7 | Do people use Discover or just Plan? | `discover.nudge.tapped`, `discover.category.tapped` |
| Q8 | How much do sunshine/snow features get used? | `discover.sunshine.opened`, `discover.snow.opened` |
| Q9 | Does the app retain day-over-day? | Built-in TelemetryDeck DAU/retention — no custom event needed |

#### Event definitions

**Naming convention:** `{flow}.{action}` — dot-separated, lowercase, no abbreviations.

```swift
// MARK: - Analytics Events

enum ZnuniEvent {
    
    // --- Tab navigation ---
    // Q5: What's the main entry point?
    static func tabSwitched(to tab: String) {
        TelemetryDeck.signal("tab.switched", parameters: ["tab": tab])
    }
    
    // --- Plan flow ---
    // Q1: Do people use the planner?
    static func planGenerated(source: String, city: String, slotCount: Int, badWeather: Bool) {
        TelemetryDeck.signal("plan.generated", parameters: [
            "source": source,           // "api" or "template_fallback"
            "city": city,               // "zurich", "lugano", etc.
            "slotCount": "\(slotCount)",
            "badWeather": "\(badWeather)"
        ])
    }
    
    // Q2: Do they interact with plans?
    static func planSlotSwapped(slotType: String) {
        TelemetryDeck.signal("plan.slot.swapped", parameters: ["slotType": slotType])
    }
    
    static func planSlotSuggestAnother() {
        TelemetryDeck.signal("plan.slot.suggestAnother")
    }
    
    static func planRebuilt() {
        TelemetryDeck.signal("plan.rebuilt")
    }
    
    static func planSlotEdited(action: String) {
        // action: "editTime", "replaceCustom", "lock", "remove"
        TelemetryDeck.signal("plan.slot.edited", parameters: ["action": action])
    }
    
    // Q3: Do people actually go?
    static func planLetsGo() {
        TelemetryDeck.signal("plan.letsGo")
    }
    
    static func executionSlotDone(slotType: String, minutesDelta: Int) {
        TelemetryDeck.signal("execution.slot.done", parameters: [
            "slotType": slotType,
            "minutesDelta": "\(minutesDelta)"  // positive = late, negative = early
        ])
    }
    
    static func executionGetDirections(slotType: String) {
        TelemetryDeck.signal("execution.getDirections", parameters: ["slotType": slotType])
    }
    
    // Q4: Do they share?
    static func planShared(method: String) {
        // method: "messages", "whatsapp", "copy", "other"
        TelemetryDeck.signal("plan.shared", parameters: ["method": method])
    }
    
    // --- Session ---
    // Q6: Is session config used?
    static func sessionChanged(childCount: Int, soloParent: Bool) {
        TelemetryDeck.signal("session.changed", parameters: [
            "childCount": "\(childCount)",
            "soloParent": "\(soloParent)"
        ])
    }
    
    // --- Discover flow ---
    // Q7/Q8: Do people use Discover?
    static func discoverNudgeTapped(type: String) {
        TelemetryDeck.signal("discover.nudge.tapped", parameters: ["type": type])
    }
    
    static func discoverSunshineOpened() {
        TelemetryDeck.signal("discover.sunshine.opened")
    }
    
    static func discoverSnowOpened() {
        TelemetryDeck.signal("discover.snow.opened")
    }
    
    static func discoverCategoryTapped(category: String) {
        TelemetryDeck.signal("discover.category.tapped", parameters: ["category": category])
    }
    
    static func discoverPlanThis(source: String) {
        // source: "sunshine_city", "snow_resort", "event", "activity_card"
        TelemetryDeck.signal("discover.planThis", parameters: ["source": source])
    }
    
    // --- Errors (silent, for debugging) ---
    static func apiError(endpoint: String, error: String) {
        TelemetryDeck.signal("error.api", parameters: [
            "endpoint": endpoint,
            "error": error
        ])
    }
}
```

#### Where to fire events — integration points

| Event | Fire location |
|-------|---------------|
| `tab.switched` | `ContentView` tab selection `onChange` |
| `plan.generated` | `AgendaComposer.compose()` on success, `TemplateEngine` on fallback |
| `plan.slot.swapped` | `SwapOptionCard` tap handler |
| `plan.slot.suggestAnother` | `LunchSlotCard.suggestAnother()` |
| `plan.rebuilt` | Rebuild button tap handler |
| `plan.slot.edited` | `SlotEditMenu` action handlers |
| `plan.letsGo` | "Let's go →" button tap |
| `execution.slot.done` | "Done ✓" tap handler in execution mode |
| `execution.getDirections` | "Get Directions" CTA tap |
| `plan.shared` | Share sheet completion handler (see §2) |
| `session.changed` | `SessionConfigSheet` "Done" handler |
| `discover.*` | Respective tap handlers in `DiscoverView` |
| `error.api` | `AgendaComposer` catch block |

### 1d. TelemetryDeck dashboard setup

Create these custom insights after first signals arrive:

1. **Funnel: Plan → Interact → Go → Share**
   - `plan.generated` → `plan.slot.swapped` OR `plan.rebuilt` → `plan.letsGo` → `plan.shared`
   
2. **Funnel: Discover → Plan This**
   - `discover.category.tapped` OR `discover.sunshine.opened` → `discover.planThis`

3. **Top N: Most common share methods**
   - Group `plan.shared` by `method` parameter

4. **Daily active users** — built-in, no config needed

### 1e. App Store privacy declaration

TelemetryDeck requires declaring "Analytics" usage in App Store Connect:
- Data type: **Diagnostics** (crash data, performance data)
- Data type: **Usage Data** (product interaction)
- Both marked as: **Not linked to identity**, **Not used to track**
- No ATT prompt required

---

## 2. PLAN SHARING — FORMATTED SUMMARY

### 2a. What gets shared

When a user taps "Share", the app generates a formatted text summary of the current `DayAgenda`. This is not a deep link, not an image, not a PDF — it's a clean text block optimised for iMessage/WhatsApp readability.

### 2b. Share button placement

**Browsing mode:** Floating button at bottom of agenda timeline, below the last slot card.

```
[slots...]

┌─────────────────────────────────┐
│  📤 Share this plan             │
└─────────────────────────────────┘

[ ── Let's go → ── ]
```

**Execution mode:** In the navigation bar as a share icon (standard `square.and.arrow.up`).

### 2c. Formatted output

```swift
struct PlanShareFormatter {
    
    static func format(_ agenda: DayAgenda, city: String = "Zürich") -> String {
        var lines: [String] = []
        
        // Header
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEEE, d MMMM"
        let dayString = dayFormatter.string(from: agenda.date)
        
        lines.append("📋 \(dayString) in \(city)")
        lines.append(agenda.weatherNote)
        lines.append("")
        
        // Slots
        for slot in agenda.slots {
            let emoji = slotEmoji(slot.type)
            lines.append("\(emoji) \(slot.time) — \(slot.venueName)")
            if let travel = slot.travelNote {
                lines.append("   \(travel)")
            }
        }
        
        // Home activities (bad weather mode)
        if let home = agenda.homeActivities {
            lines.append("")
            lines.append("🏠 Back home")
            if let baking = home.baking {
                lines.append("   🧁 \(baking.idea)")
            }
            if let movie = home.movie {
                lines.append("   🎬 \(movie.title) (\(movie.year))")
            }
            if let craft = home.craft {
                lines.append("   ✂️ \(craft.idea)")
            }
        }
        
        lines.append("")
        lines.append("Made with Znüni")
        
        return lines.joined(separator: "\n")
    }
    
    private static func slotEmoji(_ type: AgendaSlot.SlotType) -> String {
        switch type {
        case .activity: return "🎯"
        case .lunch: return "🍽️"
        case .dinner: return "🍷"
        }
    }
}
```

**Example output:**

```
📋 Saturday, 22 March in Zürich
Sunny, 14°C — great day for getting out

🎯 10:00 — Zürich Zoo
   🚃 Tram 6 · 15 min from Kreis 4
🍽️ 12:30 — Hiltl Sihlpost
   🚶 8 min walk
🎯 14:30 — Chinagarten
   🚃 Tram 2 · 10 min
🍷 18:00 — Markthalle im Viadukt
   🚶 12 min walk

Made with Znüni
```

### 2d. Share sheet integration

```swift
struct SharePlanButton: View {
    let agenda: DayAgenda
    let city: String
    @State private var showShareSheet = false
    
    var body: some View {
        Button {
            showShareSheet = true
        } label: {
            Label("Share this plan", systemImage: "square.and.arrow.up")
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: [PlanShareFormatter.format(agenda, city: city)])
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )
        controller.completionWithItemsHandler = { activityType, completed, _, _ in
            if completed {
                let method: String
                switch activityType {
                case .message: method = "messages"
                case .copyToPasteboard: method = "copy"
                default:
                    if activityType?.rawValue.contains("whatsapp") == true {
                        method = "whatsapp"
                    } else {
                        method = activityType?.rawValue ?? "other"
                    }
                }
                ZnuniEvent.planShared(method: method)
            }
        }
        return controller
    }
    
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
```

### 2e. Future: Rich share (not for TestFlight)

If sharing proves popular, the next step is a richer format:

- **Deep link** (`znuni://plan/{id}`) that opens the plan in-app if installed
- **Visual card** — a rendered image of the plan timeline (like Spotify Wrapped)
- **Apple Maps links** per venue for one-tap directions

Don't build any of this now. The text format tells you whether sharing is a real behaviour first.

---

## 3. IMPLEMENTATION SEQUENCE

Both features are independent and can be built in either order. Estimated effort assumes familiarity with the codebase.

| Step | Task | Effort | Dependency |
|------|------|--------|------------|
| 1 | Add TelemetryDeck SPM package, initialise in App struct | 15 min | None |
| 2 | Create `ZnuniEvent` enum with all signal definitions | 30 min | Step 1 |
| 3 | Wire events into existing view/model code | 1-2 hrs | Step 2. Touch ~12 files |
| 4 | Set up TelemetryDeck dashboard: funnels, top-N | 30 min | Step 3 + first signals |
| 5 | Create `PlanShareFormatter` | 30 min | None |
| 6 | Create `ShareSheet` wrapper + `SharePlanButton` | 30 min | Step 5 |
| 7 | Wire share button into agenda views (browsing + execution) | 30 min | Step 6 |
| 8 | Fire `plan.shared` in completion handler | 5 min | Steps 2 + 6 |

**Total: ~4-5 hours of work.**

---

## 4. WHAT THIS TELLS YOU ABOUT USERS/ACCOUNTS

After 2-4 weeks of TestFlight data, you'll have answers to:

| Signal | What it means | What to build next |
|--------|---------------|-------------------|
| High `plan.generated`, low `plan.letsGo` | Plans are interesting but not actionable | Fix plan quality before adding features |
| High `plan.shared` | Sharing is real behaviour | Build rich share cards, then consider household sync |
| Zero `plan.shared` | Couples don't share this way | Don't build CloudKit sync — they're just showing each other their phone |
| High `plan.letsGo`, low `execution.slot.done` | People start but don't complete execution mode | Execution mode might be overengineered |
| Low `discover.*` | Nobody browses Discover | Planner is the product, not the discovery layer |
| High `session.changed` | People actively configure family profiles | FamilySession matters, invest in richer profiles |

**The user/account decision is downstream of this data.** Ship analytics first, watch for 2-4 weeks, then decide.
