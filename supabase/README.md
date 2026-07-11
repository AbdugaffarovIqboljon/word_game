# Supabase — daily puzzle distribution

Minimal v1 backend: one table (`daily_puzzles`), read-only to clients, gated so
only released dates are visible. No leaderboards, no profiles.

## Files
- `migrations/20260710000001_daily_puzzles.sql` — table + RLS.
- `seed/seed_from_schedule.py` — turns a generated `schedule.json` into an
  idempotent SQL upsert (`seed/seed_daily_puzzles.sql`), and can push directly
  via the REST API.

## Security model (RLS)
- `anon` + `authenticated` roles have **SELECT only**, and only for rows with
  `date <= tomorrow (Asia/Tashkent)`. Future answers are never exposed.
- No INSERT/UPDATE/DELETE is granted to clients; with RLS on and no write policy
  those are denied. Seeding uses the **service_role** key, which bypasses RLS.

## Apply the migration

**Option A — Supabase CLI (recommended, local → remote):**
```bash
supabase db push          # applies supabase/migrations/*.sql to the linked project
```

**Option B — psql / SQL editor:**
```bash
psql "$SUPABASE_DB_URL" -f supabase/migrations/20260710000001_daily_puzzles.sql
```

**Option C — MCP (this environment):** apply the migration file's contents with
the Supabase `apply_migration` tool against your project ref.

## Seed the 90-day schedule
```bash
# 1. (re)generate the schedule if needed
python3 tool/generator/generate_schedule.py \
    --answers tool/corpus/out/answers_tiered.tsv \
    --start 2026-07-10 --days 90 --seed 142 \
    --out tool/generator/out/schedule.json

# 2a. produce idempotent SQL, then run it however you applied the migration
python3 supabase/seed/seed_from_schedule.py \
    --schedule tool/generator/out/schedule.json \
    --out supabase/seed/seed_daily_puzzles.sql
psql "$SUPABASE_DB_URL" -f supabase/seed/seed_daily_puzzles.sql

# 2b. …or push straight to the project via REST (service role bypasses RLS)
export SUPABASE_URL="https://<ref>.supabase.co"
export SUPABASE_SERVICE_ROLE_KEY="<service-role-key>"
python3 supabase/seed/seed_from_schedule.py \
    --schedule tool/generator/out/schedule.json --push
```
The seed is idempotent (`on conflict (date) do update`), so re-running to extend
or correct the schedule is safe.

## Client wiring (app)
The Flutter app reads this table through `lib/data/dictionary_datasource.dart`
(`SupabaseAssetDictionary`), using the project URL + **anon** key. It fetches a
7-day window, caches it, and falls back to the bundled `schedule.json.gz` when
offline — so the daily word keeps working with no network.
