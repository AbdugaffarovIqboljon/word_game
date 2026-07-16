#!/usr/bin/env python3
"""Patch an existing schedule.json in place after an answer-pool curation pass.

Unlike a regeneration, this preserves every date/puzzle_number pairing and only
replaces words that are now excluded (exclusions/*.txt) — and only on dates
AFTER --cutoff (already-played/live dates are never touched, even if their word
is excluded; they are reported instead). Replacements come from the same tier
of the current clean pool, drawn deterministically (--seed), skipping anything
already used in this schedule or in --history within 365 days.

Also (re)attaches theme + definition_uz to EVERY puzzle from the WS-B content
master; a kept-but-excluded word (a live date) may carry inline fallback
content via KEPT_WORD_CONTENT since the master only covers clean answers.

Usage:
  python3 patch_schedule.py --schedule out/schedule.json --cutoff 2026-07-16
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import random
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.abspath(os.path.join(HERE, "..", "corpus")))
import build_corpus as B  # noqa: E402

NO_REPEAT_DAYS = 365

# Content for words that stay on past/live dates despite being excluded from
# the pool (the master has no entry for them). Same no-reveal rule applies.
KEPT_WORD_CONTENT = {
    "miting": ("Jamiyat",
               "Odamlarning ochiq maydonda talab bilan toʻplanishi."),
}


def load_pool(path):
    """{tier: [word]} + {word: (theme, definition)} from enriched TSV."""
    tiers, content = {1: [], 2: [], 3: []}, {}
    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.rstrip("\n")
            if not line:
                continue
            word, tier, _freq, theme, definition = line.split("\t")
            tiers[int(tier)].append(word)
            content[word] = (theme, definition)
    for t in tiers:
        tiers[t] = sorted(tiers[t])
    return tiers, content


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--schedule", default=os.path.join(HERE, "out", "schedule.json"))
    ap.add_argument("--answers",
                    default=os.path.join(HERE, "..", "corpus", "out",
                                         "answers_tiered.tsv"))
    ap.add_argument("--history", default=os.path.join(HERE, "out", "history.json"))
    ap.add_argument("--cutoff", required=True,
                    help="YYYY-MM-DD: dates <= cutoff are never modified")
    ap.add_argument("--seed", type=int, default=142)
    args = ap.parse_args()

    with open(args.schedule, encoding="utf-8") as f:
        sched = json.load(f)
    cutoff = dt.date.fromisoformat(args.cutoff)

    tiers, content = load_pool(args.answers)
    excl_dir = os.path.join(HERE, "..", "corpus", "exclusions")
    is_off = B.load_exclusions(os.path.join(excl_dir, "offensive_uz.txt"))
    is_non = B.load_exclusions(os.path.join(excl_dir, "non_answers.txt"),
                               root_match=False)
    excluded = lambda w: is_off(w) or is_non(w)  # noqa: E731

    # words already used anywhere (schedule + history) are off-limits
    used = {p["word"] for p in sched["puzzles"]}
    if os.path.exists(args.history):
        with open(args.history, encoding="utf-8") as f:
            hist = json.load(f)
        used |= set(hist.values()) if isinstance(hist, dict) else set()

    rng = random.Random(args.seed)
    queues = {}
    for t in (1, 2, 3):
        pool = [w for w in tiers[t] if w not in used]
        rng.shuffle(pool)
        queues[t] = pool

    replaced, kept_excluded = [], []
    for p in sched["puzzles"]:
        date = dt.date.fromisoformat(p["date"])
        if excluded(p["word"]):
            if date <= cutoff:
                kept_excluded.append((p["date"], p["word"]))
            else:
                tier = p["difficulty"]
                order = [tier, tier - 1, tier + 1]
                new = None
                for t in order:
                    if queues.get(t):
                        new = queues[t].pop(0)
                        break
                if new is None:
                    raise SystemExit(f"pool exhausted replacing {p['word']}")
                replaced.append((p["date"], p["word"], new, tier))
                p["word"] = new
                used.add(new)

    # attach/refresh theme + definition on every puzzle
    for p in sched["puzzles"]:
        c = content.get(p["word"]) or KEPT_WORD_CONTENT.get(p["word"])
        if c is None:
            raise SystemExit(f"no content for scheduled word {p['word']!r}")
        theme, definition = c
        if p["word"] in definition.lower():
            raise SystemExit(f"definition reveals {p['word']!r}")
        p["theme"], p["definition_uz"] = theme, definition

    # hard gates: no excluded word after cutoff; no duplicates in window
    future_words = [p["word"] for p in sched["puzzles"]
                    if dt.date.fromisoformat(p["date"]) > cutoff]
    B.assert_answer_invariants(future_words)
    words = [p["word"] for p in sched["puzzles"]]
    assert len(words) == len(set(words)), "duplicate word in schedule"

    sched["patched_at"] = dt.datetime.now(dt.timezone.utc).isoformat()
    with open(args.schedule, "w", encoding="utf-8") as f:
        json.dump(sched, f, ensure_ascii=False, indent=2)

    print(f"replaced {len(replaced)}:")
    for date, old, new, tier in replaced:
        print(f"  {date}  {old} -> {new}  (t{tier})")
    if kept_excluded:
        print(f"kept (<= cutoff, excluded): {kept_excluded}")
    print(f"themes attached: {len(sched['puzzles'])}/{len(sched['puzzles'])}")


if __name__ == "__main__":
    main()
