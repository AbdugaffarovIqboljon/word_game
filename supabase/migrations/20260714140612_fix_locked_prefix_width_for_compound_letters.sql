drop view public.daily_puzzle_public;

create view public.daily_puzzle_public as
select
  dp.puzzle_number,
  dp.puzzle_date,
  w.length as word_length,
  coalesce(dp.theme_override, w.theme) as theme,
  left(w.normalized_word, 2) as locked_prefix_raw
from public.daily_puzzles dp
join public.words w on w.id = dp.word_id
where dp.puzzle_date <= current_date;

grant select on public.daily_puzzle_public to anon, authenticated;
