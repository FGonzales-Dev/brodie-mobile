# brodie

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Local Supabase development

Schema, RLS policies, and stored procedures are developed locally and tracked
as migrations in `supabase/`, never edited directly in the hosted dashboard.

**Prerequisites:** [Docker Desktop](https://www.docker.com/products/docker-desktop/)
running, and the [Supabase CLI](https://supabase.com/docs/guides/local-development/cli/getting-started).

```bash
supabase start   # brings up local Postgres+PostGIS, Auth, Realtime, Storage, Studio
```

`supabase start` prints a `.env`-shaped block (API URL, publishable key, etc.).
Copy `.env.example` to `.env` and fill in the `SUPABASE_URL` /
`SUPABASE_PUBLISHABLE_KEY` values from that output — `.env` is gitignored, so
each developer keeps their own local instance's keys. After changing `.env`,
regenerate the `envied` config class:

```bash
dart run build_runner build --delete-conflicting-outputs
```

To create a new schema change:

```bash
supabase migration new <description>   # e.g. create_ride_groups_table
```

Write the SQL in the generated migration file, then run:

```bash
supabase db reset   # wipes the local DB, reapplies every migration from scratch
```

This proves the schema is fully reproducible from the migration history alone
— run it before every push. Commit the migration file alongside the app code
that depends on it, in the same PR.

Other useful commands:

```bash
supabase stop     # tear down the local stack
supabase status   # show local URLs/keys again without restarting
```
