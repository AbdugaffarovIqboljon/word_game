-- So'z Jangi — daily puzzle distribution
-- Minimal v1: one table, read-only to clients, gated to released dates only.
-- No leaderboards, no profiles (intentionally out of scope for v1).

create table if not exists public.daily_puzzles (
    date          date primary key,
    word          text        not null,
    definition_uz text,                       -- nullable: definitions are optional
    difficulty    smallint    not null check (difficulty between 1 and 3),
    created_at    timestamptz not null default now()
);

comment on table  public.daily_puzzles is 'One answer word per calendar day (Asia/Tashkent). Client-readable only for released dates.';
comment on column public.daily_puzzles.word          is 'Answer, normalised lowercase Uzbek Latin (apostrophes = U+02BB), exactly 5 logical letters.';
comment on column public.daily_puzzles.difficulty    is '1 = easy, 2 = mid, 3 = hard (matches the practice-mode tiers).';
comment on column public.daily_puzzles.definition_uz is 'Optional Uzbek one-line definition, shown on the fail screen.';

-- ---------------------------------------------------------------------------
-- Row Level Security
-- ---------------------------------------------------------------------------
alter table public.daily_puzzles enable row level security;

-- Privilege hygiene: clients get SELECT only. INSERT/UPDATE/DELETE are never
-- granted to anon/authenticated, and with RLS on and no write policy they are
-- denied regardless. Seeding is done with the service_role key, which bypasses
-- RLS, so no write policy is needed here.
revoke all on public.daily_puzzles from anon, authenticated;
grant select on public.daily_puzzles to anon, authenticated;

-- Anonymous + logged-in clients may read a puzzle only once it is "released":
-- up to and including tomorrow in Uzbekistan time. This lets a device that is a
-- day ahead of UTC still fetch its current puzzle, while never exposing the
-- back-catalogue of future answers.
drop policy if exists daily_puzzles_read_released on public.daily_puzzles;
create policy daily_puzzles_read_released
    on public.daily_puzzles
    for select
    to anon, authenticated
    using ( date <= ((now() at time zone 'Asia/Tashkent')::date + 1) );
