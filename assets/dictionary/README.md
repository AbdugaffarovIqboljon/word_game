# Dictionary assets

The **real** word content for the daily game, produced by `tool/corpus` +
`tool/generator`. These have now landed and are wired through
`lib/data/dictionary_datasource.dart` (`SupabaseAssetDictionary`), a drop-in
`Dictionary` that replaces the seeded `InMemoryDictionary` fake.

Files (gzipped):

- `valid_guesses.txt.gz` — accepted-guess dictionary, 16,096 words (superset of answers)
- `answers_tiered.tsv.gz` — 2,900 answers, `word \t tier(1..3) \t freq` (practice mode)
  (proper nouns / loanwords / slang curated out of the answer pool via
  `tool/corpus/exclusions/non_answers.txt`; they remain valid guesses)
- `schedule.json.gz` — 90-day daily schedule (offline fallback for the daily word)

Every word is exactly 5 logical letters under the game's `WordTokenizer`
(`oʻ gʻ sh ch ng` each count as one). To regenerate, see `tool/corpus/SOURCES.md`.

## Licence / attribution (required)
These data files are derived from Uzbek Wikipedia word frequencies and are
distributed under **CC BY-SA 4.0**:

> Word content derived from Uzbek Wikipedia (uz.wikipedia.org), CC BY-SA 4.0,
> and the MUNIS Uzbek Latin hunspell dictionary (CC0). See tool/corpus/SOURCES.md.

This applies to the data files only; it does not affect the app source licence.
