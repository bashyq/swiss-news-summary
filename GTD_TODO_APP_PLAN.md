# GTD Todo App — Architecture & Implementation Plan

## Overview

A cross-platform GTD (Getting Things Done) task manager with full Horizons of Focus support, native iOS/Mac widgets, a web app, and file attachment support (PPTX, Excel, PDF, images). Syncs across all devices in real-time.

---

## 1. Platform Strategy

| Platform | Technology | Why |
|----------|-----------|-----|
| **iOS app** | SwiftUI | Native widgets (WidgetKit), offline support, share sheet for quick capture |
| **Mac app** | SwiftUI (Catalyst/native) | Shared codebase with iOS, Mac widgets, menu bar quick-capture |
| **Web app** | React + TypeScript | Desktop browser access, works on Android/Linux via PWA |
| **Shared logic** | Supabase SDK (Swift + JS) | Same sync/auth layer across all platforms |

SwiftUI lets you share ~80% of code between iOS and Mac, including widgets. The web app covers Android users and desktop browsers.

---

## 2. Backend: Supabase (Recommended)

### Why Supabase over alternatives

| Requirement | Supabase | Cloudflare D1+R2 | Firebase |
|-------------|----------|-------------------|----------|
| Real-time sync | Built-in (Postgres LISTEN/NOTIFY) | Manual (WebSockets/Durable Objects) | Built-in |
| Relational data (GTD model) | Native Postgres | SQLite (limited) | Document DB (poor fit) |
| File storage | S3-compatible, signed URLs | R2 works well | Firebase Storage |
| Offline sync | Via local cache + conflict resolution | Manual | Built-in (Firestore) |
| Auth | Built-in (email, OAuth, Apple Sign-In) | Manual | Built-in |
| Swift SDK | Official `supabase-swift` | None | Official |
| Cost at small scale | Free tier generous | Free tier generous | Free tier generous |
| Self-host option | Yes (Docker) | No | No |

**Verdict**: Supabase wins because GTD data is inherently relational (projects contain tasks, tasks have contexts, areas contain projects) and Postgres handles this naturally. Real-time sync and auth are included. If you ever want to self-host, you can.

### Supabase services used

- **Postgres** — All structured data (tasks, projects, contexts, areas, etc.)
- **Supabase Storage** — File attachments (PPTX, Excel, PDF, images) in private buckets
- **Supabase Auth** — Apple Sign-In (iOS/Mac), email/password, OAuth
- **Supabase Realtime** — Cross-device sync via Postgres changes broadcast
- **Edge Functions** (optional) — Weekly review reminders, recurring task generation

---

## 3. Data Model

### Core GTD Entities

```
┌─────────────────────────────────────────────────────┐
│                   HORIZONS OF FOCUS                  │
│                                                     │
│  Purpose & Principles  (horizon 5)                  │
│       ↓                                             │
│  Vision               (horizon 4)                   │
│       ↓                                             │
│  Goals (1-2 years)    (horizon 3)                   │
│       ↓                                             │
│  Areas of Focus       (horizon 2)                   │
│       ↓                                             │
│  Projects             (horizon 1)                   │
│       ↓                                             │
│  Next Actions         (ground level)                │
│       ↓                                             │
│  Tasks with Notes & Attachments                     │
└─────────────────────────────────────────────────────┘
```

### Database Schema (Postgres)

```sql
-- Users (managed by Supabase Auth, extended here)
CREATE TABLE profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id),
  display_name TEXT,
  default_context_id UUID,
  weekly_review_day INT DEFAULT 0,  -- 0=Sunday
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Horizons of Focus (levels 2-5)
CREATE TABLE areas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id) NOT NULL,
  name TEXT NOT NULL,
  description TEXT,
  horizon INT DEFAULT 2,  -- 2=Area, 3=Goal, 4=Vision, 5=Purpose
  parent_id UUID REFERENCES areas(id),  -- Goals link to Areas, Vision links to Goals
  sort_order INT DEFAULT 0,
  archived BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Projects (horizon 1) — multi-step outcomes
CREATE TABLE projects (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id) NOT NULL,
  area_id UUID REFERENCES areas(id),  -- optional link to Area of Focus
  name TEXT NOT NULL,
  description TEXT,
  status TEXT DEFAULT 'active' CHECK (status IN ('active', 'completed', 'on_hold', 'someday')),
  due_date DATE,
  review_date DATE,
  sort_order INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Contexts (e.g., @home, @office, @errands, @phone, @computer)
CREATE TABLE contexts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id) NOT NULL,
  name TEXT NOT NULL,          -- "@office"
  icon TEXT,                   -- emoji or SF Symbol name
  sort_order INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Tasks (ground level — next actions, waiting-for, someday/maybe, inbox)
CREATE TABLE tasks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id) NOT NULL,
  project_id UUID REFERENCES projects(id),       -- optional
  context_id UUID REFERENCES contexts(id),        -- optional
  delegated_to TEXT,                               -- for waiting-for
  title TEXT NOT NULL,
  notes TEXT,                                      -- rich text / markdown
  status TEXT DEFAULT 'inbox' CHECK (status IN (
    'inbox',          -- unclarified capture
    'next_action',    -- clarified, actionable
    'waiting_for',    -- delegated, awaiting response
    'someday_maybe',  -- not now, maybe later
    'reference',      -- not actionable, just info
    'completed',
    'trashed'
  )),
  energy TEXT CHECK (energy IN ('low', 'medium', 'high')),  -- GTD energy level
  time_estimate INT,           -- minutes
  due_date DATE,
  start_date DATE,             -- "tickler" — hidden until this date
  completed_at TIMESTAMPTZ,
  sort_order INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Attachments (files linked to tasks)
CREATE TABLE attachments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  task_id UUID REFERENCES tasks(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES profiles(id) NOT NULL,
  file_name TEXT NOT NULL,          -- original filename
  file_type TEXT NOT NULL,          -- MIME type
  file_size BIGINT NOT NULL,        -- bytes
  storage_path TEXT NOT NULL,       -- path in Supabase Storage bucket
  thumbnail_path TEXT,              -- generated thumbnail for images/PDFs
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Tags (flat labels, separate from contexts)
CREATE TABLE tags (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id) NOT NULL,
  name TEXT NOT NULL,
  color TEXT,
  UNIQUE(user_id, name)
);

CREATE TABLE task_tags (
  task_id UUID REFERENCES tasks(id) ON DELETE CASCADE,
  tag_id UUID REFERENCES tags(id) ON DELETE CASCADE,
  PRIMARY KEY (task_id, tag_id)
);

-- Weekly Review tracking
CREATE TABLE reviews (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id) NOT NULL,
  started_at TIMESTAMPTZ DEFAULT now(),
  completed_at TIMESTAMPTZ,
  inbox_cleared BOOLEAN DEFAULT false,
  projects_reviewed BOOLEAN DEFAULT false,
  someday_reviewed BOOLEAN DEFAULT false,
  waiting_reviewed BOOLEAN DEFAULT false,
  calendar_reviewed BOOLEAN DEFAULT false,
  notes TEXT
);

-- Row Level Security: every table filtered by user_id
ALTER TABLE tasks ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users see own tasks" ON tasks
  FOR ALL USING (auth.uid() = user_id);
-- (repeat for all tables)

-- Indexes for common queries
CREATE INDEX idx_tasks_user_status ON tasks(user_id, status);
CREATE INDEX idx_tasks_context ON tasks(user_id, context_id) WHERE status = 'next_action';
CREATE INDEX idx_tasks_project ON tasks(project_id) WHERE status != 'trashed';
CREATE INDEX idx_tasks_due ON tasks(user_id, due_date) WHERE due_date IS NOT NULL;
CREATE INDEX idx_tasks_start ON tasks(user_id, start_date) WHERE start_date IS NOT NULL;
CREATE INDEX idx_attachments_task ON attachments(task_id);
```

### Storage Bucket Structure

```
attachments/
  {user_id}/
    {task_id}/
      {uuid}-{original_filename}
    thumbnails/
      {uuid}-thumb.jpg
```

**File size limit**: 50MB per file. Supabase Storage handles signed upload URLs for direct client-to-storage uploads (no server bottleneck).

---

## 4. GTD Workflow Mapping

### Capture (Inbox)

| Entry point | How |
|-------------|-----|
| iOS/Mac app | "+" button, share sheet, Siri Shortcut |
| iOS widget | Quick-capture widget (text field + submit) |
| Mac | Menu bar quick-capture (global hotkey) |
| Web | Quick-add bar (always visible at top) |
| Email | Forward to a Supabase Edge Function (future) |

All captures land as `status = 'inbox'` with no project/context assigned.

### Clarify & Organize (Processing)

The app guides you through inbox items one at a time:

```
Is it actionable?
├── No → Reference or Trash or Someday/Maybe
└── Yes
    ├── Takes < 2 min? → Do it now (mark complete)
    ├── Delegate? → Waiting For (set delegated_to)
    └── Defer → Set as Next Action
        ├── Assign Context (@home, @office, etc.)
        ├── Assign Project (optional)
        ├── Set energy level (optional)
        ├── Set time estimate (optional)
        └── Set due date / start date (optional)
```

The processing view shows one task at a time with swipe gestures or button taps for quick decisions.

### Organize Views

| GTD List | App View | Query |
|----------|----------|-------|
| **Inbox** | Inbox tab | `status = 'inbox'` |
| **Next Actions** | By context | `status = 'next_action'` grouped by `context_id` |
| **Projects** | Projects list | All `active` projects with their next actions |
| **Waiting For** | Waiting tab | `status = 'waiting_for'` with `delegated_to` shown |
| **Someday/Maybe** | Someday tab | `status = 'someday_maybe'` |
| **Reference** | Reference tab | `status = 'reference'` |
| **Calendar** | Calendar view | Tasks with `due_date` set, integrated view |
| **Tickler** | Auto-surfaced | Tasks where `start_date <= today` move to inbox |

### Review (Weekly Review)

Guided workflow with checklist:

1. **Clear inbox** — Process every item to zero
2. **Review Next Actions** — Still relevant? Contexts correct?
3. **Review Projects** — Each project has a defined next action?
4. **Review Waiting For** — Follow up needed?
5. **Review Someday/Maybe** — Anything to activate?
6. **Review Calendar** — Upcoming commitments captured?
7. **Review Horizons** — Areas, Goals, Vision still aligned?

Progress saved to `reviews` table. Can be resumed if interrupted.

### Horizons of Focus

Dedicated section for higher-level thinking:

- **Areas of Focus** (horizon 2) — Ongoing responsibilities (Health, Finance, Career, Family)
- **Goals** (horizon 3) — 1-2 year outcomes, linked to Areas
- **Vision** (horizon 4) — 3-5 year vision statements
- **Purpose & Principles** (horizon 5) — Life purpose, core values

Each Area shows its linked Projects, giving a top-down view of commitments.

---

## 5. Attachment Handling

### Upload Flow

```
Client (iOS/Mac/Web)
  → Request signed upload URL from Supabase Storage
  → Upload file directly to storage (client-to-S3)
  → Create attachment record in Postgres
  → Generate thumbnail (Edge Function or client-side for images)
```

### Supported File Types

| Type | MIME | Preview | Thumbnail |
|------|------|---------|-----------|
| **PPTX** | `application/vnd.openxmlformats-officedocument.presentationml.presentation` | Open in native app / Quick Look | First slide (Edge Function) |
| **Excel** | `application/vnd.openxmlformats-officedocument.spreadsheetml.sheet` | Open in native app / Quick Look | Icon placeholder |
| **PDF** | `application/pdf` | In-app viewer (iOS PDFKit / web pdf.js) | First page thumbnail |
| **Images** | `image/*` | In-app gallery | Auto-generated resize |

### iOS/Mac Quick Look

On Apple platforms, use `QLPreviewController` to preview any file type natively — PPTX, Excel, PDF all render without any custom code.

### Web Preview

- **PDF**: Use `pdf.js` or `<iframe>` embed
- **Images**: Native `<img>` with lightbox
- **Office files**: Link to download + "Open in Google Docs/Office Online" option

---

## 6. Sync Strategy

### Real-time Sync (Online)

```
Device A makes change
  → Writes to Supabase Postgres
  → Supabase Realtime broadcasts change
  → Device B receives change via WebSocket
  → Device B updates local state
```

### Offline Support

| Platform | Strategy |
|----------|----------|
| **iOS/Mac** | SwiftData (local) + sync queue. Changes queued offline, replayed on reconnect |
| **Web** | IndexedDB (via Dexie.js) + sync queue. Service worker caches app shell |

### Conflict Resolution

- **Last-write-wins** with `updated_at` timestamp (simple, sufficient for single-user)
- If multi-user is added later: field-level merge with conflict UI

---

## 7. iOS & Mac Widgets (WidgetKit)

### Widget Types

| Widget | Size | Content |
|--------|------|---------|
| **Inbox Count** | Small | Number of inbox items, tap to open inbox |
| **Quick Capture** | Medium | Text field + submit button (iOS 17+ interactive widget) |
| **Next Actions** | Medium/Large | Top 3-5 next actions for a chosen context |
| **Today** | Medium/Large | Tasks due today + calendar items |
| **Weekly Review** | Small | Days since last review, tap to start |

### Implementation

- SwiftUI `Widget` protocol with `TimelineProvider`
- Shared data via App Group container (SwiftData store accessible to both app and widget)
- Background refresh via `BGAppRefreshTask`
- Interactive widgets (iOS 17+) for quick capture and task completion

---

## 8. App Structure

### iOS/Mac (SwiftUI)

```
GTDApp/
├── App/
│   ├── GTDApp.swift              # Entry point, tab bar
│   ├── AppState.swift            # Global state (ObservableObject)
│   └── Navigation/
│       ├── TabRouter.swift       # Tab bar: Inbox, Actions, Projects, Review, More
│       └── DeepLinks.swift       # URL scheme handling
├── Core/
│   ├── Models/                   # SwiftData models (mirror Postgres schema)
│   ├── Sync/
│   │   ├── SyncEngine.swift      # Supabase ↔ SwiftData sync
│   │   ├── SyncQueue.swift       # Offline change queue
│   │   └── ConflictResolver.swift
│   ├── Storage/
│   │   ├── AttachmentManager.swift  # Upload/download/cache files
│   │   └── ThumbnailGenerator.swift
│   └── Auth/
│       └── AuthManager.swift     # Supabase Auth + Apple Sign-In
├── Features/
│   ├── Inbox/
│   │   ├── InboxView.swift       # List of unclarified items
│   │   └── ProcessView.swift     # One-at-a-time clarify flow
│   ├── Actions/
│   │   ├── NextActionsView.swift # Grouped by context
│   │   ├── WaitingForView.swift
│   │   └── SomedayView.swift
│   ├── Projects/
│   │   ├── ProjectsListView.swift
│   │   └── ProjectDetailView.swift
│   ├── Review/
│   │   ├── WeeklyReviewView.swift  # Guided checklist
│   │   └── HorizonsView.swift      # Areas, Goals, Vision, Purpose
│   ├── Calendar/
│   │   └── CalendarView.swift
│   ├── TaskDetail/
│   │   ├── TaskDetailView.swift    # Edit task, notes, attachments
│   │   ├── NotesEditor.swift       # Rich text / markdown editor
│   │   └── AttachmentsList.swift   # File list with Quick Look
│   └── Capture/
│       ├── QuickCaptureView.swift  # Modal quick-add
│       └── ShareExtension/         # iOS share sheet target
├── Widgets/
│   ├── InboxCountWidget.swift
│   ├── QuickCaptureWidget.swift
│   ├── NextActionsWidget.swift
│   └── TodayWidget.swift
└── Shared/
    ├── Components/                 # Reusable SwiftUI components
    └── Extensions/
```

### Web (React + TypeScript)

```
gtd-web/
├── src/
│   ├── app/
│   │   ├── layout.tsx
│   │   └── page.tsx
│   ├── features/
│   │   ├── inbox/
│   │   ├── actions/
│   │   ├── projects/
│   │   ├── review/
│   │   ├── calendar/
│   │   └── capture/
│   ├── lib/
│   │   ├── supabase.ts          # Supabase client + real-time subscriptions
│   │   ├── sync.ts              # Offline sync with IndexedDB
│   │   └── storage.ts           # Attachment upload/download
│   ├── components/              # Shared UI components
│   └── types/                   # TypeScript types (mirror DB schema)
├── public/
│   ├── sw.js                    # Service worker for offline
│   └── manifest.json            # PWA manifest
└── package.json
```

---

## 9. Implementation Phases

### Phase 1 — Foundation (Weeks 1-3)
- [ ] Set up Supabase project (database, auth, storage bucket)
- [ ] Run database migrations (schema above)
- [ ] iOS/Mac app scaffold with SwiftUI + SwiftData
- [ ] Supabase Auth integration (Apple Sign-In)
- [ ] Basic task CRUD (create, read, update, delete)
- [ ] Inbox view — capture and list items

### Phase 2 — Core GTD (Weeks 4-6)
- [ ] Processing flow — clarify inbox items one at a time
- [ ] Contexts — create, assign to tasks, view by context
- [ ] Projects — create, link tasks, project detail view
- [ ] Next Actions view (grouped by context)
- [ ] Waiting For view
- [ ] Someday/Maybe view
- [ ] Due dates and start dates (tickler)

### Phase 3 — Notes & Attachments (Weeks 7-8)
- [ ] Rich notes editor on tasks (markdown or rich text)
- [ ] File upload to Supabase Storage (PPTX, Excel, PDF, images)
- [ ] Attachment list on task detail
- [ ] Quick Look preview (iOS/Mac)
- [ ] Thumbnail generation for images and PDFs

### Phase 4 — Sync & Offline (Weeks 9-10)
- [ ] Supabase Realtime subscriptions (live sync)
- [ ] SwiftData local persistence
- [ ] Offline change queue + replay on reconnect
- [ ] Conflict resolution (last-write-wins)

### Phase 5 — Widgets & Quick Capture (Weeks 11-12)
- [ ] Inbox Count widget (small)
- [ ] Quick Capture widget (interactive, iOS 17+)
- [ ] Next Actions widget (medium/large)
- [ ] Today widget
- [ ] Share Extension (capture from any app)
- [ ] Mac menu bar quick capture

### Phase 6 — Weekly Review & Horizons (Weeks 13-14)
- [ ] Guided weekly review workflow
- [ ] Review tracking and history
- [ ] Areas of Focus
- [ ] Goals, Vision, Purpose views
- [ ] Link Projects → Areas → Goals hierarchy

### Phase 7 — Web App (Weeks 15-17)
- [ ] React + TypeScript scaffold
- [ ] Supabase integration (same backend)
- [ ] All GTD views (inbox, actions, projects, review)
- [ ] File attachments (upload + preview)
- [ ] PWA setup (offline via service worker)
- [ ] Responsive design (mobile + desktop)

### Phase 8 — Polish (Weeks 18-20)
- [ ] Search across tasks, notes, projects
- [ ] Keyboard shortcuts (Mac + web)
- [ ] Drag and drop reordering
- [ ] Dark mode
- [ ] Notification reminders (due dates, review day)
- [ ] Data export (JSON/CSV)
- [ ] App Store submission

---

## 10. Tech Stack Summary

| Layer | Technology |
|-------|-----------|
| **iOS/Mac** | SwiftUI, SwiftData, WidgetKit |
| **Web** | React, TypeScript, Next.js or Vite |
| **Database** | Supabase (Postgres) |
| **File storage** | Supabase Storage (S3-compatible) |
| **Auth** | Supabase Auth (Apple Sign-In, email) |
| **Real-time sync** | Supabase Realtime (WebSocket) |
| **Offline (mobile)** | SwiftData + sync queue |
| **Offline (web)** | IndexedDB + service worker |
| **Hosting (web)** | Vercel or Cloudflare Pages |
| **CI/CD** | Xcode Cloud (iOS/Mac), GitHub Actions (web) |

---

## 11. Key Design Decisions

1. **Supabase over Firebase** — GTD data is relational (projects → tasks → contexts). Postgres handles this naturally; Firestore's document model would require denormalization and complex queries.

2. **SwiftUI over React Native** — You need WidgetKit, Share Extensions, Quick Look, and menu bar integration. These are all native Apple APIs. React Native would require bridges for each and widgets wouldn't be possible.

3. **Web as separate React app** — Keeps the web app lightweight and independent. Shares the same Supabase backend but doesn't need to replicate native Apple features.

4. **Offline-first architecture** — GTD apps must work everywhere. Airplane mode, bad WiFi, underground — capture must never fail. SwiftData on Apple, IndexedDB on web.

5. **Single Supabase project** — One database, one auth system, one storage bucket. All clients connect to the same backend. Simplest possible infrastructure.
