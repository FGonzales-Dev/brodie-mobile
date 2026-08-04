# Brodie — Getting Started Plan (Phase 0: Project Foundation)

## Context
`brodie` is a brand-new repo containing only `tech-spec-and-roadmap.md` — no app code exists yet. The spec's own roadmap (section 4) defines Phase 0 as the starting point: get an empty Flutter app building and talking to Supabase/Firebase before any features are built. Environment checks during planning found:
- **Flutter SDK is not usable yet.** A copy exists at `OneDrive\Documents\flutter` but `bin/` is missing `flutter.bat`/`dart.exe` — it never fully synced/downloaded, so it's not runnable. I'll install a fresh copy outside OneDrive.
- **Android Studio + Android SDK are already installed and complete** (`%LOCALAPPDATA%\Android\Sdk` has platform-tools, build-tools, emulator, platforms), including a bundled JDK at `C:\Program Files\Android\Android Studio\jbr`. No Android reinstall needed — Flutter just needs to be pointed at it.
- The `brodie` repo itself lives under OneDrive too. This is lower-risk than the SDK case right now (repo is tiny), but once `build/`, `.dart_tool/`, `android/.gradle` etc. exist, OneDrive syncing thousands of small build files is a known source of file-lock errors and slow builds on Windows. Flagged below as something to watch for, not something to act on now.
- **Supabase local dev doesn't require a hosted project.** `supabase start` runs the full stack (Postgres+PostGIS, Auth, Realtime, Storage, Studio) locally via Docker and hands back a local URL + anon key that `supabase_flutter` uses identically to a hosted project. So hosted Supabase account creation is pushed later in this plan — it's only needed for sharing builds off this machine or testing the CI migration pipeline, not for day-to-day app development.

Steps marked **[You]** require manual action (web console signups) I can't perform. Steps marked **[Me]** I'll do directly once you say go.

---

## Step 1 — [Me] Install Flutter SDK
1. `git clone` the `stable` channel of the Flutter SDK to `C:\src\flutter` — outside OneDrive, avoiding the exact corruption issue just found and the OneDrive lock/slowdown problems that hit Flutter/Gradle builds.
2. Add `C:\src\flutter\bin` to your user PATH via `setx` (persists for new shells; won't affect the current one — I'll invoke the full path directly for the remaining steps in this session).
3. Point Flutter at the existing Android SDK instead of reinstalling it: `flutter config --android-sdk "$env:LOCALAPPDATA\Android\Sdk"`.
4. Accept Android SDK licenses non-interactively (`flutter doctor --android-licenses` normally prompts per-license, so I'll auto-confirm each one via `sdkmanager --licenses`).
5. Run `flutter doctor -v` and confirm Android toolchain is ✅. iOS toolchain will show as missing/unsupported — expected on Windows, since the spec already plans to build iOS via Codemagic CI (a macOS runner), not locally.

**Note:** the initial clone pulls the full Flutter SDK (~2-3 GB) and can take a few minutes depending on connection speed.

---

## Step 2 — [Me] Scaffold the Flutter project
Once `flutter` is confirmed working:
1. `flutter create` the app inside this repo (name: `brodie`), targeting iOS + Android.
2. Feature-first folder structure per spec section 2: `lib/core/`, `lib/data/`, `lib/domain/`, `lib/features/`, `lib/shared/`.
3. `pubspec.yaml` with the Phase 0–relevant dependencies from the spec: `flutter_riverpod`, `riverpod_annotation`, `go_router`, `freezed`/`json_serializable`, `envied`, `supabase_flutter`, `google_fonts`. (Mapbox, location, and Firebase packages get added when Phase 2/0 config actually needs them, to avoid unused deps sitting broken with no config behind them.)
4. `analysis_options.yaml` and Flutter's standard `.gitignore` (covers `build/`, `.dart_tool/`, `android/.gradle`, `ios/Pods`, etc.).
5. `ThemeData` (light + dark, `ThemeMode.system` default) wired from the exact color tokens and fonts in spec section 6.
6. `go_router` skeleton with the 4 bottom-nav tabs (Map / Groups / History / Profile) from section 7, each a placeholder screen for now.

**Checkpoint:** app builds and runs on an emulator/device showing the 4-tab shell, themed correctly.

---

## Step 3 — [Me] Local-first Supabase setup
Per spec section 3.2 — no hosted account needed for this step:
1. `supabase init` inside the repo (creates `supabase/` folder, migrations tracked in git from day one).
2. `supabase start` to bring up the local Docker stack (Postgres+PostGIS, Auth, Realtime, Storage, Studio).
3. Set up `envied` with a `dev` env pointed at the local Supabase URL + local anon key `supabase start` prints out.
4. Initialize `supabase_flutter` in `main.dart` against that local instance.
5. Document the `supabase start` / `supabase db reset` workflow in a short README section so Phase 1 schema work starts from a clean, reproducible local DB.

**Checkpoint:** app builds and its Supabase client successfully connects to the **local** instance — no hosted project required yet.

---

## Step 4 — [You] Create Firebase project
1. Create a Firebase project, register iOS + Android apps.
2. Download `google-services.json` and `GoogleService-Info.plist` and hand them to me.

(Supabase hosted project and Codemagic account creation are deferred to Step 6, once you're ready to share a build or wire up CI.)

---

## Step 5 — [Me] Wire up Firebase
Once you hand me the Firebase config files:
1. Drop them into the project, initialize Crashlytics + Analytics.
2. Fire one test event/crash to confirm both report correctly in the Firebase console.

**Checkpoint:** matches the spec's Phase 0 goal — "empty app that builds, connects to Supabase, and reports to Firebase" (Supabase here being the local instance, which is a faithful stand-in for this checkpoint during development).

---

## Step 6 — [You + Me] Hosted Supabase + CI pipeline
Do this when you're ready to share a build off this machine, or want CI running:
1. **[You]** Create the hosted Supabase project, grab the project URL + anon key. Create a Codemagic account and connect this GitHub repo.
2. **[Me]** Add a `staging`/`prod` `envied` env pointed at the hosted project. Write `codemagic.yaml` (build + lint on push, store deploy skipped for now) and the `supabase-migrations.yml` GitHub Action from spec section 3.3.
3. **[You]** Add the three GitHub repo secrets (`SUPABASE_ACCESS_TOKEN`, `SUPABASE_PROJECT_ID`, `SUPABASE_DB_PASSWORD`), then confirm the Codemagic build goes green and migrations push to the hosted project.

---

## After this
Once Phase 0's goal checkpoint passes, next up per the roadmap is **Phase 1 — Auth & Profile** (Supabase Auth, `profiles`/`vehicles` tables, `create_profile_on_signup()` stored procedure, RLS) — not part of this plan, picked up as a separate task.

## Verification
- `flutter doctor -v` clean (Android ✅, iOS entry present but not required locally).
- `flutter run` launches the 4-tab shell on an emulator, correct light/dark theming.
- `supabase start` + `supabase db reset` succeed locally with zero migrations (proves the local pipeline works before any schema exists).
- App startup logs a successful Supabase client init (against local instance) and a Firebase Analytics/Crashlytics test event, visible in the Firebase dashboard.
