-- The "words"/"daily_puzzles" RLS policies currently let anon/authenticated read the
-- plaintext answer directly (words.word, and via FK-embedded join on daily_puzzles),
-- and prior grants also allowed INSERT/UPDATE/DELETE/TRUNCATE. Only the evaluate-guess
-- Edge Function (service_role) should ever touch these tables; everyone else reads the
-- restricted daily_puzzle_public view.
drop policy if exists "words are publicly readable" on public.words;
drop policy if exists "public metadata visible for today or past puzzles" on public.daily_puzzles;

revoke all on public.words from anon, authenticated;
revoke all on public.daily_puzzles from anon, authenticated;

-- Extend the public view with the WS4 locked first-letter reveal, and keep the
-- original "no future puzzle spoilers" behavior the dropped daily_puzzles policy had.
create or replace view public.daily_puzzle_public as
select
  dp.puzzle_number,
  dp.puzzle_date,
  w.length as word_length,
  coalesce(dp.theme_override, w.theme) as theme,
  left(w.normalized_word, 1) as locked_prefix
from public.daily_puzzles dp
join public.words w on w.id = dp.word_id
where dp.puzzle_date <= current_date;

revoke all on public.daily_puzzle_public from anon, authenticated;
grant select on public.daily_puzzle_public to anon, authenticated;
