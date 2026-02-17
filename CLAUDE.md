# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

"Today in Switzerland" is a PWA that aggregates Swiss news, weather, transport disruptions, holidays, historical facts, family activities for toddlers (ages 2-5), and weekend sunshine forecasts. It uses Claude AI for news categorization and consists of a modular Cloudflare Worker backend (10 modules) and a 3-file frontend (HTML shell + CSS + JS).

**GitHub:** https://github.com/bashyq/swiss-news-summary

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

    ↓ HTTP GET /sunshine?lang={en|de}
1. Fetch weekend (Fri/Sat/Sun) sunshine forecasts for 28 destinations
2. Single multi-location Open-Meteo API call (all destinations in one request)
3. Return destinations ranked by total sunshine hours
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
│   │   ├── lunch.js      # Overpass API + lunch handler
│   │   └── sunshine.js   # Weekend sunshine forecast (29 destinations, Zürich baseline)
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
| `loadSunshine(forceRefresh)` | Load sunshine data (worker + client fallback) |
| `renderSunshineView()` | Render sunshine map + card list |
| `initSunshineMap()` | Init Leaflet map with sunshine markers |
| `setSunshineSort(sort)` | Sort by 'sunshine' or 'distance' |
| `setSunshineFilter(filter)` | Filter by 'all'/'sunny'/'partly'/'cloudy' |
| `getBaselineDest()` | Get Zürich baseline entry from sunshine data |
| `fetchSunshineClientSide()` | Client-side Open-Meteo fallback |

## Storage

**localStorage keys:**
- `lang` - Language preference (en/de)
- `city` - Selected city
- `theme` - Theme preference (light/dark)
- `view` - Active view (news/activities/lunch/events/weekend/sunshine), persisted across refresh
- `savedActivities` - Array of saved activity IDs
- `customActivities` - Array of user-created activities
- `installDismissed` - PWA install prompt dismissed
- `notificationsEnabled` - Push notifications enabled
- `newsCache-{city}-{lang}` - Cached news data per city/language (2hr TTL)
- `activitiesCache-{city}` - Cached activities data per city
- `sunshineCache-v2` - Cached sunshine data with Zürich baseline (30min TTL)

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
npx wrangler pages deploy frontend --project-name=swiss-news
```
