# CLAUDE.md

## Project Overview

"Znuni" (formerly "Today in Switzerland") — PWA + native iOS app aggregating Swiss news, weather, transport, holidays, history, family activities (ages 2-5), sunshine/snow forecasts, and deals. Cloudflare Worker backend (12 modules), 3-file frontend (HTML + CSS + JS), SwiftUI iOS app (iOS 17+).

**GitHub:** https://github.com/bashyq/swiss-news-summary

## Build & Deploy

```bash
# Worker (backend API)
cd worker && npx wrangler deploy

# Frontend (Cloudflare Pages)
npx wrangler pages deploy frontend --project-name=swiss-news --branch=main

# iOS app
cd ios-app && open SwissPortal.xcodeproj  # Cmd+B to build, Cmd+R to run
# CLI: xcodebuild -project SwissPortal.xcodeproj -scheme SwissPortal \
#   -destination 'platform=iOS Simulator,name=iPhone 16' build
```

**URLs:** Frontend `https://swiss-news.pages.dev` · Worker `https://swiss-news-worker.swissnews.workers.dev`

## File Structure

```
├── frontend/           # PWA: index.html, styles.css, app.js (~2800 lines)
├── worker/src/         # CF Worker: index.js (router), data.js, weather.js, transport.js,
│                       #   news.js, activities.js, events.js, weekend.js, lunch.js,
│                       #   sunshine.js, snow.js
├── ios-app/Znuni/
│   ├── App/            # ZnuniApp, AppState, ContentView
│   ├── Models/         # Codable models
│   ├── ViewModels/     # @Observable view models
│   ├── Views/          # SwiftUI views by feature (Today/, News/, Explore/, Lunch/,
│   │                   #   Activities/, Weekend/, Snow/, Sunshine/, Settings/, Shared/)
│   ├── Services/       # CalendarService, AgendaComposer, TemplateEngine, CacheManager,
│   │                   #   APIClient, LocationManager, AnchorStore, GapAnalysisEngine
│   └── Resources/      # Fonts (Playfair), bundled data files
└── docs/
    └── api-reference.md  # Full API response schemas
```

## Znuni Design System

The iOS app uses a warm editorial design system. Colors, typography, spacing, and shadows are centralized in `Color+Theme.swift` and the Asset Catalog.

### Color Tokens (Asset Catalog — auto Light/Dark)
| Token | Usage |
|---|---|
| `znNavy` | Primary brand, accent (`Color.brand` alias) |
| `znTerracotta` | Warm accent, outdoor borders |
| `znCream` / `znSurface` | Page / card backgrounds |
| `znBorder` / `znInnerDivider` | Card borders, internal dividers |
| `znInk` / `znBody` / `znMuted` | Primary / body / caption text |
| `znPositive` / `znNegative` | Success / error states |
| `znAlertBg` | Alert backgrounds |
| `znNeutralTagBg` / `znNeutralTagText` | Neutral pill backgrounds/text |
| `znChevron` | Chevron icons |

**Important**: Color tokens are auto-generated from Asset Catalog colorsets. Do NOT redeclare them in `Color+Theme.swift` — only add legacy aliases there.

### Typography (Playfair serif + SF Pro sans)
- `Font.heroTitle` — Playfair 30pt regular (NOT semibold)
- `Font.sectionHeadline` — Playfair 22pt regular
- `Font.cardHeadline` — Playfair 17pt semibold
- `Font.znEyebrow` — system 11pt medium, uppercase with tracking
- `Font.znLabel` — system 12pt medium
- `Font.znMono` — monospaced caption
- Body/caption: system font (SF Pro)

### Spacing & Shadows
- `AppSpacing.cardPadding` = 16, `cardRadius` = 16, `borderStripWidth` = 3
- `AppShadow.card` = black 8%, radius 8, y=2
- `CardStyle` / `SubtleCardStyle` ViewModifiers for centralized card styling

### Design Patterns

**Hero banners** — VStack with `.background {}` (NOT ZStack with Color fill). Content drives height:
```swift
VStack(alignment: .leading, spacing: 0) { /* content */ }
.padding(.horizontal, 24).padding(.top, 18).padding(.bottom, 24)
.background { ZStack(alignment: .bottomTrailing) { Color.znNavy; RadialGradient(/*...*/); skyline.opacity(0.09) } }
```

**Canvas skyline** — White building silhouettes at 9% opacity, bottom-right of hero banners.

**Glass buttons** — `white.opacity(0.12)` bg, `RoundedRectangle(cornerRadius: 10)`. Helper: `glassButton()`.

**Accordion cards** — `@Binding var expandedID: String?`, one card expanded at a time, spring animation + haptic.

**R2 photos** — `APIClient.shared.photoURL(for: activityId)`. Only activities (not events/deals), exclude `custom-` prefix and `stayhome`. Always provide gradient+icon fallback.

### Design Mockups (source of truth)
HTML files in `/Users/bq/Documents/SwissPortal/design system/`:
- `znuni-news-and-explore-2.html` — Primary: News hero, Explore hero, cards
- `znuni-activities-expanding-cards.html` — Accordion pattern
- Other `znuni-*.html` files per view

## Key Conventions

- **iOS 17 @Observable** — all view models use Observation framework
- **CacheManager** — disk cache with per-endpoint TTLs; `getStale()` for expired fallback on network failure
- **Task cancellation** — `.task(id:)` auto-cancels on city/language change
- **Xcode auto-discovery** — `PBXFileSystemSynchronizedRootGroup`, no manual file references
- **7 cities**: zurich, basel, bern, geneva, lausanne, luzern, winterthur
- **Bilingual** — all content has `name`/`nameDE`, `description`/`descriptionDE` pairs
- **Sunshine/Snow always Zürich-based** — not affected by city selector
- **Open-Meteo rate limits** — worker IP can hit daily quota; client-side fallback in app.js
- **Tab bar**: Today, Activities, Explore, Weekend, Settings — custom `ZnuniTabBar`, tint `.znNavy`
- **URL scheme**: `swissportal://lunch`, `swissportal://events`, etc.
- **Environment**: `CLAUDE_API_KEY` (wrangler secret), `ACTIVITIES_KV` (KV namespace)
