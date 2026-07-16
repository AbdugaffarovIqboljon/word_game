
drop view if exists public.daily_puzzle_public;

-- Real row-level policy instead of a security-definer bypass: only today-or-past puzzles
-- are visible at all, so future answers are never queryable in any form, by any role
-- other than service_role (used only inside the evaluate-guess Edge Function).
create policy "public metadata visible for today or past puzzles"
  on public.daily_puzzles for select
  to anon, authenticated
  using (puzzle_date <= current_date);

-- Now a plain (invoker-rights) view is safe: RLS on daily_puzzles already restricts rows,
-- and words is already fully public, so no security definer is needed.
create view public.daily_puzzle_public as
select
  dp.puzzle_number,
  dp.puzzle_date,
  w.length as word_length,
  coalesce(dp.theme_override, w.theme) as theme
from public.daily_puzzles dp
join public.words w on w.id = dp.word_id;

grant select on public.daily_puzzle_public to anon, authenticated;
