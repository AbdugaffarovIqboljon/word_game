-- WS-B hint content: per-word Uzbek definition for the Lugʻat hint.
-- Populated by tool/corpus/output/words_import.sql (answer candidates only;
-- guess-only rows stay NULL). Not exposed via daily_puzzle_public — the
-- daily definition ships in the bundled schedule asset; the server copy keeps
-- words/dictionary as the single converged store.
alter table public.words
  add column if not exists definition_uz text;
