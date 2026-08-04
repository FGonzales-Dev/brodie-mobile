# Rider App — Tech Spec & Implementation Roadmap

## 1. Overview
A Flutter app for bikers and motorcyclists to set destinations, navigate, and run **group rides** where members can see each other's live location.

---

## 2. Tech Stack

### Frontend
| Layer | Choice |
|---|---|
| Framework | Flutter (iOS + Android) |
| State management | Riverpod (`flutter_riverpod`, `riverpod_annotation`) |
| Navigation | `go_router` |
| Models/serialization | `freezed` + `json_serializable` |
| Env/secrets | `envied` |
| Architecture | MVVM + Repository pattern, feature-first folder structure |

### Maps & Location
| Purpose | Choice |
|---|---|
| Map rendering & styling | Mapbox (`mapbox_maps_flutter`) |
| Routing | Mapbox Directions API |
| GPS tracking (fg/bg) | `flutter_background_geolocation` (or `geolocator` + `flutter_background_service`) |
| Permissions | `permission_handler` |

### Backend
| Purpose | Choice |
|---|---|
| Database | Supabase Postgres + PostGIS |
| Auth | Supabase Auth |
| Live group location | Supabase Realtime (Presence + Broadcast) |
| File storage | Supabase Storage |
| Server logic (business rules, multi-table writes) | **Postgres stored procedures (RPC functions)**, called from Flutter via `supabase.rpc()` |
| Server logic (external/webhook/scheduled) | Supabase Edge Functions |

### Firebase
| Purpose | Choice |
|---|---|
| Push notifications | FCM |
| Analytics | Firebase Analytics |
| Crash reporting | Firebase Crashlytics |

### Infra / Tooling
| Purpose | Choice |
|---|---|
| Deep linking | `app_links` + own domain (App Links / Universal Links) |
| CI/CD | Codemagic |
| Testing | `flutter_test`, `integration_test` |

---

## 3. Key Architectural Decisions

- **MVVM + Repository pattern**: Widgets (View) → Riverpod Notifiers (ViewModel) → Repositories → Supabase/Mapbox/Firebase. No SDK calls directly inside widgets or UI-facing providers.
- **Group ride location** uses Supabase **Broadcast**, not per-tick DB writes — cheap, fast, ephemeral. DB writes only for ride history snapshots (batched).
- **Location broadcast interval**: 5 seconds during active group ride.
- **Route re-fetching**: only when a rider deviates >100m from route, not continuously.
- **Permissions**: request "While Using App" first (solo nav); only request "Always"/background when the user actually starts/joins a group ride.
- **No offline mode for v1.**
- **SOS**: manual button in v1; automatic crash detection (`sensors_plus`) deferred to v2.
- **Deep links**: own domain + App Links/Universal Links, not Firebase Dynamic Links (deprecated) or Branch.io.
- **Database logic lives in stored procedures (Postgres functions), not the Flutter app.** See section below.

---

## 3.1 Stored Procedure Strategy (Supabase RPC)

Instead of scattering business logic across the Flutter repositories (multiple round-trip queries, client-side transaction risk), core operations are implemented as **Postgres stored procedures** (`plpgsql` functions), exposed to Flutter via `supabase.rpc('function_name', params)`.

### Why stored procedures here
- **Atomicity** — e.g. "create a ride group + add creator as first member" happens in one DB transaction, not two separate client calls that could partially fail.
- **Security** — sensitive logic (e.g. validating invite codes, checking group membership before granting access) runs server-side inside the function, not trusted to client code.
- **Performance** — one round trip to the DB instead of several sequential queries from the Flutter app, which matters on spotty mobile connections/mid-ride.
- **Consistency with RLS** — functions can run as `SECURITY DEFINER` to safely perform actions a user's normal RLS policy wouldn't directly allow (e.g. reading a group's invite code to validate it before the user is officially a member).
- **Single source of truth** — business rules live in one place (the DB) instead of being duplicated if you ever add a second client (web dashboard, admin panel).

### Candidate functions per feature

**Auth / Profile**
- `create_profile_on_signup()` — trigger function, auto-creates a `profiles` row when a new `auth.users` row is created

**Solo Ride**
- `save_completed_ride(ride_data jsonb)` — validates and inserts a finished ride + related stats in one call
- `get_ride_history(user_id uuid, limit int, offset int)` — paginated ride history query

**Group Ride** *(highest priority — most multi-step logic)*
- `create_ride_group(name text, destination jsonb)` — creates the group **and** inserts the creator as the first member, atomically; returns the invite code
- `join_ride_group(invite_code text)` — validates the code, checks the group is still active/not full, inserts the membership row, returns group details
- `leave_ride_group(group_id uuid)` — removes membership, and if the leaving member was the last one, closes/archives the group
- `get_active_group_members(group_id uuid)` — returns current members + their last known status, respecting RLS (only returns data if caller is a member)
- `end_ride_group(group_id uuid)` — leader-only action, marks group as ended, triggers cleanup

**Ride History / Stats**
- `get_group_ride_summary(group_id uuid)` — aggregate stats (total distance, duration, member count) for a completed group ride

**Notifications trigger support**
- Database trigger functions that call `pg_notify` or write to a `notification_queue` table, which an Edge Function polls/consumes to send FCM pushes (keeps the "what triggers a notification" logic in the DB, and the "how to send it" logic in Edge Functions)

### Division of responsibility
| Logic type | Where it lives |
|---|---|
| Multi-table writes, validation, atomic operations | **Postgres stored procedures (RPC)** |
| Simple single-table CRUD, reads | Direct Supabase client calls (`select`, `insert`) from Repository layer — no need to wrap trivial queries in RPC |
| External API calls (FCM, Mapbox server-side calls if any), scheduled jobs, webhooks | Supabase Edge Functions |
| Live location streaming | Supabase Realtime (Presence/Broadcast) — not RPC, not stored procedures |

### Flutter integration pattern
Repositories call stored procedures the same way they'd call any Supabase method — this stays fully wrapped behind the Repository layer, so ViewModels/widgets never know or care whether a given repository method is a direct query or an RPC call underneath:

```dart
class GroupRideRepository {
  final SupabaseClient _client;

  Future<RideGroup> createGroup(String name, LatLng destination) async {
    final response = await _client.rpc('create_ride_group', params: {
      'name': name,
      'destination': {'lat': destination.latitude, 'lng': destination.longitude},
    });
    return RideGroup.fromJson(response);
  }

  Future<RideGroup> joinGroup(String inviteCode) async {
    final response = await _client.rpc('join_ride_group', params: {
      'invite_code': inviteCode,
    });
    return RideGroup.fromJson(response);
  }
}
```

### Roadmap impact
Stored procedures are written **alongside the schema/RLS work in Phase 1 and Phase 3** (not a separate later phase) — each table's core write operations should ship with its corresponding function from the start, rather than retrofitting later.

---

## 3.2 Local-First Database Development & Migrations

Schema changes are developed and tracked locally, never edited directly in the hosted Supabase dashboard, so every change to tables, RLS policies, and stored procedures has a reviewable, ordered history in git.

### Setup (one-time)
```bash
npm install -g supabase
supabase init                                    # creates supabase/ folder in the repo
supabase start                                    # local Postgres + Studio + Auth + Realtime via Docker
supabase link --project-ref <your-project-id>     # connects local repo to the hosted project
```

### Workflow for every schema change
```bash
supabase migration new create_ride_groups_table
# → supabase/migrations/20260804120000_create_ride_groups_table.sql
```
1. Write the SQL (table definitions, RLS policies, or stored procedure) in that migration file
2. Run `supabase db reset` — wipes the local DB and reapplies **every** migration from scratch, proving the schema is fully reproducible from git history alone
3. Test the app locally against `supabase start`'s local instance
4. Commit the migration file alongside the app code that depends on it (e.g. a new repository method) in the same PR

### Rules
- **Never edit schema directly in the hosted Supabase dashboard** — always via a migration file, committed to git
- Every table, RLS policy, and stored procedure change is its own migration file — small, atomic, reviewable in a PR
- `supabase db reset` locally before every push — this is what catches "works on my machine but migration order is broken" issues before they hit production

---

## 3.3 CI/CD: GitHub → Supabase Production

Goal: pushing/merging to `main` automatically applies pending migrations to the production Supabase project — no manual `supabase db push` from a laptop.

### 1. Get credentials from Supabase
- **Access token**: Supabase Dashboard → Account → Access Tokens → generate one
- **Project ref**: found in Project Settings → General (or in the URL of your project dashboard)
- **DB password**: Project Settings → Database

### 2. Add them as GitHub repo secrets
`Settings → Secrets and variables → Actions`, add:
- `SUPABASE_ACCESS_TOKEN`
- `SUPABASE_PROJECT_ID`
- `SUPABASE_DB_PASSWORD`

### 3. GitHub Actions workflow
Create `.github/workflows/supabase-migrations.yml`:

```yaml
name: Deploy Supabase Migrations

on:
  push:
    branches: [main]
    paths:
      - "supabase/migrations/**"

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: supabase/setup-cli@v1
        with:
          version: latest

      - name: Link project
        run: supabase link --project-ref $SUPABASE_PROJECT_ID
        env:
          SUPABASE_ACCESS_TOKEN: ${{ secrets.SUPABASE_ACCESS_TOKEN }}
          SUPABASE_PROJECT_ID: ${{ secrets.SUPABASE_PROJECT_ID }}

      - name: Push migrations to production
        run: supabase db push
        env:
          SUPABASE_ACCESS_TOKEN: ${{ secrets.SUPABASE_ACCESS_TOKEN }}
          SUPABASE_DB_PASSWORD: ${{ secrets.SUPABASE_DB_PASSWORD }}
```

This triggers **only** when files under `supabase/migrations/` change and land on `main` — app-only code changes won't trigger a DB deploy.

### 4. Recommended branch strategy
| Branch | Supabase project | Purpose |
|---|---|---|
| Feature branches | Local (`supabase start`) | Develop + test migrations locally |
| `develop` / `staging` | Separate staging Supabase project | Optional but recommended — test migrations against a real hosted project before prod |
| `main` | Production Supabase project | Auto-deployed via the GitHub Action above |

Running two Supabase projects (staging + prod) is worth it once the app has real users — the free tier's "2 active projects" limit conveniently fits exactly this dev/staging-or-prod split mentioned earlier.

### 5. Safety notes
- Never let the CI workflow run destructive migrations (`DROP TABLE`, etc.) without a manual approval step — consider adding a `workflow_dispatch` manual trigger + required PR review as a gate before merging to `main`, rather than fully automatic deploys, once the app has real production data
- Keep a rollback plan: Supabase migrations are forward-only by default, so a bad migration needs a new migration to fix it, not an automatic revert — test thoroughly on staging first

---

## 3.4 Future Migration Path: Supabase → AWS (if cost becomes a problem at scale)

Supabase is Postgres + open-source services underneath, so the lock-in is shallower than a typical proprietary BaaS — **as long as the app's architecture keeps Supabase-specific code isolated**, which is already the plan (Repository pattern + stored procedures in plain SQL).

### Option A — Self-host the Supabase stack on AWS (lowest effort)
Run the same open-source Supabase stack (Postgres, GoTrue/Auth, Realtime, Storage, PostgREST) on your own AWS infra (ECS/EKS + RDS Postgres).
- **No app rewrite** — `supabase_flutter`, RPC calls, and Realtime channels all work identically
- Only the hosting/billing changes — AWS compute + RDS costs instead of Supabase's managed pricing
- This is the practical answer if the *only* reason to leave is cost, not features

### Option B — Migrate to AWS-native managed services (more effort, full control)

| Supabase piece | AWS equivalent | Migration difficulty |
|---|---|---|
| Postgres + PostGIS | RDS/Aurora PostgreSQL (PostGIS supported) | **Easy** — standard `pg_dump` / `pg_restore` |
| Stored procedures | Same SQL runs as-is on RDS/Aurora | **Easy** — this is why business logic lives in plain Postgres functions, not Supabase-proprietary Edge Functions |
| Storage | S3 directly (Supabase Storage is already S3-backed) | **Easy–Medium** — copy objects, update URLs |
| Edge Functions | AWS Lambda | **Medium** — logic is portable, rewritten per runtime |
| Auth | AWS Cognito, or self-hosted GoTrue | **Hard** — user table + password hashes don't map 1:1 to Cognito |
| Realtime (Presence/Broadcast) | AWS AppSync subscriptions, IoT Core, self-hosted GoTrue Realtime, or a 3rd-party (Ably) | **Hard** — no drop-in AWS equivalent, needs real re-architecture |

**Auth and Realtime are the genuinely hard parts.** Database and storage are close to a lift-and-shift.

### What keeps this option open (already part of the plan)
1. **Stored procedures** — plain Postgres SQL, portable to any Postgres host with no rewrite
2. **Repository pattern** — all Supabase-specific calls (`supabase.rpc()`, `.from()`, Realtime channels, Auth calls) are isolated behind `AuthRepository`, `GroupRideRepository`, etc. — never called directly from ViewModels/widgets

### When to actually act on this
Not now. This is a "confirm the exit exists" step, not a "build for it today" step. Revisit seriously if/when Realtime connection or message volume grows to the point where Supabase's usage-based billing starts approaching the cost of self-hosting (Option A) — at that scale, migrating the Realtime layer specifically (e.g. to self-hosted or Ably) is usually the first and most cost-effective move, before considering a full AWS-native rebuild (Option B).

---

## 4. Implementation Roadmap

Build in this order — each phase produces a working, testable slice before moving on.

### Phase 0 — Project Foundation
1. Init Flutter project, set up folder structure (feature-first: `core/`, `data/`, `domain/`, `features/`, `shared/`)
2. Set up `envied` with dev/staging/prod flavors
3. Create Supabase project → get API keys
4. Create Firebase project → add iOS/Android apps → add `google-services.json` / `GoogleService-Info.plist`
5. Set up Codemagic pipeline (build + lint on push, skip store deploy until later)
6. Add Crashlytics + Analytics SDKs, verify a test crash/event reports correctly

**Goal:** empty app that builds, connects to Supabase, and reports to Firebase.

---

### Phase 1 — Auth & Profile
1. Supabase Auth setup (email/password minimum; OAuth optional later)
2. `AuthRepository` + auth Riverpod providers
3. Login / signup / onboarding screens
4. `profiles` table (user info) + `vehicles` table (bike/motorcycle info)
5. `create_profile_on_signup()` trigger function (stored procedure)
6. Profile screen (view/edit)
7. Row Level Security: users can only read/write their own profile

**Goal:** user can sign up, log in, set up their profile and vehicle.

---

### Phase 2 — Map & Solo Navigation
1. Integrate `mapbox_maps_flutter`, get a basic map rendering
2. `permission_handler` flow: request "While Using App" location
3. `LocationService` (foreground high-accuracy stream)
4. Destination search + Mapbox Directions API integration
5. Render route on map, live user position marker
6. Turn-by-turn or basic route-follow UI
7. `save_completed_ride()` and `get_ride_history()` stored procedures
8. Save completed rides via RPC call, display ride history

**Goal:** user can set a destination, get routed, navigate, and see ride history.

---

### Phase 3 — Group Ride (core differentiator)
1. Schema: `ride_groups`, `ride_group_members` tables + RLS (members-only visibility)
2. Stored procedures: `create_ride_group()`, `join_ride_group()`, `leave_ride_group()`, `get_active_group_members()`, `end_ride_group()`
3. `GroupRideRepository`: wraps the above RPC calls
4. Deep linking: `app_links` setup, invite link → join screen (handles app-installed and not-installed cases)
5. Supabase Realtime Presence: track online members in a ride room
6. Supabase Broadcast: stream location every 5s while in active group ride
7. Request "Always"/background location permission at this point (not earlier)
8. `groupMembersProvider` (StreamProvider) → render all riders as live markers on map
9. Member list UI, join/leave notifications
10. `untrack()` on leave to stop broadcasts immediately

**Goal:** multiple riders can join a group ride and see each other's live position on the map.

---

### Phase 4 — Background Reliability & Notifications
1. Background location service hardening (battery optimization exemption prompts on Android, background modes on iOS)
2. FCM setup: push notifications for ride invites, "rider fell behind," ride start/end
3. Supabase Edge Function to trigger FCM sends on relevant DB/Realtime events
4. Test background tracking across app-killed / phone-locked / low-battery states

**Goal:** group ride tracking survives real-world background/battery conditions, and users get notified of key events.

---

### Phase 5 — Safety & Polish
1. Manual SOS button (send location + alert to emergency contact)
2. Testing pass: unit tests on repositories/notifiers, widget tests on map + group ride screens, one end-to-end integration test (create group → join → see live location)
3. UI/UX polish, ride stats screen, edge case handling (no signal, permission denied, GPS drift)
4. Store prep (icons, screenshots, privacy policy, App Store background-location justification) — *only once features are stable*

**Goal:** app is safe, tested, and store-submission ready.

---

### Deferred to v2+
- Automatic crash detection (`sensors_plus`)
- Offline maps / offline-first data sync
- Voice-guided turn-by-turn
- Advanced ride analytics (elevation, speed graphs)
- Motorcycle-specific routing (curvy road preference, avoid highways) via custom routing profile

---

## 5. Suggested Starting Point

**Start with Phase 0 → Phase 1 → Phase 2 before touching group ride features.**
Solo navigation is simpler, validates your Mapbox + location pipeline, and gives you a stable foundation. Group ride (Phase 3) is the highest-complexity, highest-risk feature — it depends on Auth, Map, and Location all already working correctly.

---

## 6. Branding

### App Name Options
| Name | Vibe |
|---|---|
| **Convoy** | Simple, evokes group riding immediately, easy to say/remember |
| **Ridr** | Short, modern, app-store friendly |
| **PackTrail** | "Riding in a pack" + trail/route implication |
| **Throttle** | Punchy, motorcycle-specific energy |
| **Waypoint** | Navigation-forward, works for solo + group |
| **Roadkin** | "Road kin" — riders as family/crew, distinctive and memorable |
| **Slipstream** | Riding term (drafting behind others), doubles as a metaphor for group sync |

**Top picks: Convoy or Roadkin** — both are immediately understandable, not generic, and work whether riding solo or in a group.

### Color Scheme

Dark-first design, high contrast for outdoor/night readability, energetic but not childish.

| Role | Color | Hex |
|---|---|---|
| Background (dark mode primary) | Near-black asphalt | `#121417` |
| Surface/cards | Charcoal | `#1E2126` |
| Primary accent | Signal Orange | `#FF5A1F` |
| Secondary accent | Electric Amber | `#FFB800` |
| Success/online status | Racing Green | `#2ECC71` |
| Danger/SOS | Alert Red | `#E23D3D` |
| Text primary | Off-white | `#F2F2F0` |
| Text secondary | Muted gray | `#9CA3AF` |

**Rationale:**
- Dark-first is the right default for a navigation app used outdoors and at night — less glare, better OLED battery, feels more "instrument cluster" than "consumer social app"
- Orange as primary accent reads as energetic/road-safety without leaning on the red-motorcycle cliché
- Green/red reserved specifically for rider status (online/offline) and SOS, so they carry clear meaning and aren't overused decoratively

### Color Tokens — Light & Dark

Both modes are fully supported; **dark is the default** (matches system preference on first launch, with a manual override in Settings).

| Role | Dark | Light |
|---|---|---|
| Background | `#121417` | `#F7F7F5` |
| Surface/cards | `#1E2126` | `#FFFFFF` |
| Primary accent | `#FF5A1F` | `#FF5A1F` (same — works on both) |
| Secondary accent | `#FFB800` | `#E6A400` (darker for contrast on light bg) |
| Success/online status | `#2ECC71` | `#219653` |
| Danger/SOS | `#E23D3D` | `#D32F2F` |
| Text primary | `#F2F2F0` | `#121417` |
| Text secondary | `#9CA3AF` | `#6B7280` |

Implemented in Flutter via `ThemeData` (light + dark) with `ThemeMode.system` default.

### Font Family

| Use | Font |
|---|---|
| App name / branding, big stat numbers (speed, distance, ETA) | **Rajdhani** (Bold) — condensed, technical/industrial feel |
| Body text, labels, buttons, lists | **Inter** (Regular/Medium) |
| Section headers, emphasis | **Inter** (Semibold) |

**Why:** Inter is designed specifically for UI/screens, highly legible at small sizes, and glanceable while moving. Rajdhani adds a "dashboard" feel for headline numbers but should be used sparingly (not body text) since condensed fonts hurt readability in longer copy. Both are free via Google Fonts and supported in Flutter through the `google_fonts` package — no manual font bundling needed.

---

## 7. Navigation Structure

**Bottom navigation, 4 tabs** — correct pattern for a small set of frequently-switched top-level destinations, thumb-reachable, always visible.

```
[ Map ]   [ Groups ]   [ History ]   [ Profile ]
```

- **Map** (home/default tab) — set destination, start solo/group ride, live navigation view
- **Groups** — active group ride, create/join, past group rides, invites
- **History** — past solo + group rides, ride detail, filters
- **Profile** — user/vehicle info, emergency contacts, settings, sign out

**Notifications**: kept as a bell icon (with badge count) in the top app bar rather than a 5th tab, to keep the bottom nav uncluttered — surfaces ride invites, regroup/fell-behind alerts, and SOS alerts.

**Ride Mode**: when a ride (solo or group) is active, collapse/hide the bottom nav in favor of a full-screen map with a stat overlay (speed, distance, ETA) — minimal chrome, since riders are glancing at this while moving, not browsing tabs.

---

## 8. Screen Inventory

Full list of screens beyond the 4 tab roots, grouped by where they're triggered from.

### Auth / Onboarding (pre-tab flow)
- Splash screen
- Sign up / Log in
- Onboarding carousel (what the app does, permissions primer)
- Vehicle setup (add bike/motorcycle — type, name, photo)
- Location permission rationale screen (shown before the OS prompt)

### From Map tab
- Destination search screen (address/place search)
- Route preview screen (route drawn, distance/ETA, "Start Ride" CTA)
- Active Solo Ride screen (full-screen nav, ride-mode UI)
- Active Group Ride screen (map + live rider markers + member strip)
- Ride summary screen (shown right after finishing — stats, save/discard)
- SOS confirmation screen (big button + countdown/cancel, triggered from ride mode)

### From Groups tab
- Create Group Ride screen (name, destination, settings)
- Invite screen (share link/code, QR code option)
- Join Group screen (enter code, or via deep link)
- Group Ride Lobby (pre-start: who's joined, waiting for leader to start)
- Group Detail screen (members, leader controls, live status per rider)
- Member Profile (tap a rider's marker/name → mini profile, vehicle, distance from you)
- Past Group Rides list

### From History tab
- Ride Detail screen (map replay of route, stats, photos if added)
- Filter/sort screen (modal or inline)

### From Profile tab
- Edit Profile
- Vehicle management (add/edit/delete bikes/motorcycles)
- Emergency Contacts (add/edit — used for SOS)
- Settings
  - Theme (light/dark/system)
  - Units (km/mi)
  - Notification preferences
  - Background location permission status/link to OS settings
  - Broadcast interval / battery saver toggle (advanced)
- Privacy Policy / Terms
- About / App version
- Sign out / Delete account

### Cross-cutting / modal screens (not tied to one tab)
- Notification list (bell-icon overlay)
- Error/no-signal state screen (GPS lost, no connectivity mid-ride)
- Permission denied recovery screen ("you need location access — open settings")
- Onboarding-to-app deep link handler (invisible screen — processes an invite link and routes to Join Group)
