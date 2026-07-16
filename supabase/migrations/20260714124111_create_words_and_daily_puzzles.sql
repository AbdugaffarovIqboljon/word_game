
-- Dictionary of valid Uzbek words. Not secret: used to validate that a guess is a real word.
create table if not exists public.words (
  id bigint generated always as identity primary key,
  word text not null unique,
  normalized_word text generated always as (upper(word)) stored,
  length smallint not null,
  tier text not null default 'standart',
  theme text,
  is_answer_candidate boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists words_length_idx on public.words (length);
create unique index if not exists words_normalized_idx on public.words (normalized_word);
create index if not exists words_answer_candidate_idx on public.words (is_answer_candidate) where is_answer_candidate;

alter table public.words enable row level security;

create policy "words are publicly readable"
  on public.words for select
  to anon, authenticated
  using (true);

-- No insert/update/delete policy for anon/authenticated -> default deny.
-- Only service_role (used by Edge Functions / admin tooling) can write.

-- The daily answer. This table has RLS enabled with ZERO select policies for anon/authenticated,
-- so it is fully unreadable from the client by design. Only service_role (Edge Functions) can read it.
create table if not exists public.daily_puzzles (
  id bigint generated always as identity primary key,
  puzzle_number int not null unique,
  puzzle_date date not null unique,
  word_id bigint not null references public.words(id),
  theme_override text,
  created_at timestamptz not null default now()
);

alter table public.daily_puzzles enable row level security;
-- Intentionally no select/insert/update/delete policies for anon/authenticated here.

-- Safe public view: exposes only non-secret metadata for today-or-past puzzles.
-- security_invoker = off (security definer) so it can read the locked-down daily_puzzles table
-- internally, while only ever emitting the safe columns listed below.
create or replace view public.daily_puzzle_public
with (security_invoker = off) as
select
  dp.puzzle_number,
  dp.puzzle_date,
  w.length as word_length,
  coalesce(dp.theme_override, w.theme) as theme
from public.daily_puzzles dp
join public.words w on w.id = dp.word_id
where dp.puzzle_date <= current_date;

grant select on public.daily_puzzle_public to anon, authenticated;
