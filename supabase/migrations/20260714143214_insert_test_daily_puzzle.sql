-- One-off smoke-test row from the backend bring-up. Superseded by the real content
-- seed (tool/corpus/output/words_import.sql + supabase/seed/seed_daily_puzzles.sql);
-- kept here only to mirror the exact applied migration history of soz-jangi-prod so
-- `supabase db push` against that project is a clean no-op. A fresh project may skip it.
insert into public.words (word, length, tier, theme, is_answer_candidate)
values ('KITOB', 5, 'oson', 'buyum', true)
returning id;

insert into public.daily_puzzles (puzzle_number, puzzle_date, word_id)
select 5, current_date, id from public.words where word = 'KITOB';
