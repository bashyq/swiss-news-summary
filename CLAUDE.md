# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

"Today in Switzerland" is a PWA that aggregates Swiss news, weather, transport disruptions, holidays, historical facts, and family activities for toddlers (ages 2-5). It uses Claude AI for news categorization and consists of a modular Cloudflare Worker backend (9 modules) and a 3-file frontend (HTML shell + CSS + JS).

## Deployment

```bash
# Deploy worker (backend API)
cd C:\Users\bashy\Documents\swiss-news-summary\worker && npx wrangler deploy

# Deploy frontend (Cloudflare Pages)
cd C:\Users\bashy\Documents\swiss-news-summary && npx wrangler pages deploy frontend --project-name=swiss-news
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
```

## File Structure

```
swiss-news-summary/
├── frontend/
│   ├── index.html      # Slim HTML shell (~36 lines)
│   ├── styles.css      # Design system + all component styles
│   ├── app.js          # Full JS app: state, views, components, utils (~1200 lines)
│   ├── widget.html     # Compact widget page
│   ├── sw.js           # Service worker (cache v21)
│   ├── manifest.json   # PWA manifest with shortcuts
│   └── icon.svg        # App icon
├── worker/
│   ├── src/
│   │   ├── index.js      # Router, CORS, entry point
│   │   ├── data.js       # Cities config, holidays, history facts
│   │   ├── weather.js    # Open Meteo integration
│   │   ├── transport.js  # Swiss Transport API
│   │   ├── news.js       # RSS parsing, Claude API, news assembly
│   │   ├── activities.js # All activities data + handler
│   │   ├── events.js     # City events/festivals data
│   │   ├── weekend.js    # Weekend planner logic
│   │   └── lunch.js      # Overpass API + lunch handler
│   └── wrangler.toml   # Worker config (main = "src/index.js")
├── CLAUDE.md
└── README.md
```

## Features

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
- **Filters**: All, Near me, Indoor, Outdoor, Saved, Seasonal
- **"Near me"**: Uses geolocation, shows distance badges
- **Weather-based**: Indoor prioritized when rainy/cold
- **Custom activities**: Users can add their own
- **Recurring events**: Farmers markets, play groups, story times
- **Seasonal activities**: Christmas markets, ice skating, swimming pools, pumpkin farms
- **"Surprise me!" button**: Random weather-appropriate activity picker
- **Age filter**: Toggle between All ages, 2-3 years, or 4-5 years

### Events Calendar
- Aggregates holidays, news events, recurring activities, seasonal activities, and city festivals
- **Filters**: All, Holidays, Events, Recurring, Seasonal, Festivals
- **Calendar grid**: Purple dots for festivals, red for holidays, blue for recurring
- **City events**: ~70 hardcoded 2026 festivals/events served via `getCityEvents()` in worker
- **Date-range awareness**: Multi-day festivals show dots on all days, filter by date overlap
- **Festival cards**: Show date ranges, toddler-friendly (👶) and free (🆓) badges

### Weekend Planner
- Smart activity filtering based on weather and day-of-week
- Uses `isAvailableOnDate()` for recurring/seasonal filtering

### Lunch Page
- Restaurant recommendations with compact map strip + list
- "Surprise me!" random restaurant picker

### Stay-Home Activities
- 40 at-home toddler activities (sensory/art/active/pretend/kitchen)
- Separate "Stay home" filter tab, excluded from other filters

### Settings (Hamburger Menu)
- **City selector**: Zürich, Basel, Bern, Geneva, Lausanne, Luzern, Winterthur
- **Language toggle**: English / German
- **Theme toggle**: Light / Dark mode
- **Holidays display**: Upcoming Swiss holidays

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
  "history": { "year": 1958, "event": "...", "eventDE": "..." },
  "categories": {
    "disruptions": [{ "headline": "...", "summary": "...", "source": "NZZ", "url": "..." }],
    "events": [...],
    "politics": [...],
    "culture": [...],
    "local": [...]
  },
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

## Storage

**localStorage keys:**
- `lang` - Language preference (en/de)
- `city` - Selected city
- `theme` - Theme preference (light/dark)
- `savedActivities` - Array of saved activity IDs
- `customActivities` - Array of user-created activities
- `installDismissed` - PWA install prompt dismissed
- `notificationsEnabled` - Push notifications enabled
- `newsCache-{city}-{lang}` - Cached news data per city/language (2hr TTL)
- `activitiesCache-{city}` - Cached activities data per city

**Cloudflare KV:**
- Key format: `activities-{cityId}`
- Value: JSON array of activity objects

## Recent Changes (Session)

1. Redesigned layout - weather compact in header, history under title, holidays in menu
2. Added transport disruptions from Swiss Transport API
3. Added "Near me" geolocation filter for activities
4. Added coordinates to all activities
5. Added recurring events (farmers market, story time, etc.)
6. Added activities for Basel, Bern, Geneva, Lausanne
7. Created widget.html for compact view
8. Added manifest shortcuts
9. Added custom activity entry form
10. Removed wttr.in (was returning wrong temperature data)
11. Added **seasonal activities** (winter: Christmas markets, ice skating; summer: swimming pools, water playgrounds; autumn: pumpkin farms; spring: tulip gardens, Sechseläuten)
12. Added **"Surprise me!" button** - picks random weather-appropriate activity with fun modal
13. Added **age filter** - toggle between "All ages", "2-3 years", and "4-5 years"
14. Added seasonal badge display with season-specific colors
15. Added "Seasonal" filter button to show only seasonal activities
16. Added **Luzern** city with sources (Luzerner Zeitung RSS, Google News) and 8 activities (Verkehrshaus, Gletschergarten, Pilatus, etc.)
17. Added **Winterthur** city with sources (Tagesanzeiger, Google News) and 8 activities (Technorama, Wildpark Bruderhaus, Piratolino, etc.)
18. Added seasonal activities for Luzern (Fasnacht, Christmas market, lake swimming) and Winterthur (Christmas market, ice skating, Technorama outdoor)
19. **Performance: Parallel fetching** - Weather, transport, and RSS feeds now fetch in parallel (saves ~1-2s)
20. **Performance: Cache-first loading** - Shows cached data instantly on load, fetches fresh in background (instant perceived load for repeat visitors)
21. Added **swipe navigation** between category tabs
22. Added **sentiment badges** (positive/neutral/negative) and freshness indicators
23. Added **trending topics banner** (clickable with URLs)
24. Added **morning briefing card** (top story + suggested activity, dismissible per-day)
25. Added **Events Calendar page** (aggregates holidays, events, recurring, seasonal activities)
26. Added **Weekend Planner page** (smart activity filtering with `/weekend` endpoint)
27. Added **Lunch page** with "Surprise me!" random restaurant picker and compact map
28. Added **"Stay home" filter tab** with 40 at-home toddler activities (sensory/art/active/pretend/kitchen)
29. Added **City events/festivals** — ~70 hardcoded 2026 events across 7 cities via `getCityEvents()`, integrated into Events Calendar with purple dots, date-range awareness, and Festivals filter

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

## First-time Setup

```bash
npm install -g wrangler
wrangler login
cd worker
wrangler secret put CLAUDE_API_KEY  # Enter your Claude API key
wrangler deploy
cd ..
npx wrangler pages deploy frontend --project-name=swiss-news
```
