#!/usr/bin/env python3
"""Assign daily So'z Jangi puzzles N days ahead.

Rules:
  * difficulty smoothing by weekday
        Mon, Tue           -> tier 1 (easy)
        Wed, Thu, Fri      -> tier 2 (mid)
        Sat, Sun           -> tier 3 (hard)
  * no answer repeats within 365 days (checked against prior history + this run)
  * deterministic given (--seed, inputs, --start, --days, history)
  * outputs JSON consumed by the Supabase seed script and bundled as the app's
    offline fallback schedule

Determinism: each tier's word list is sorted then shuffled with a seeded PRNG, so
identical inputs always yield an identical schedule. Re-running with the same seed
but a longer --days simply extends the same deterministic ordering.

Usage:
  python3 generate_schedule.py \
      --answers ../corpus/out/answers_tiered.tsv \
      --start 2026-07-10 --days 90 --seed 142 \
      --out out/schedule.json [--history out/history.json]
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import random
import sys

# corpus tooling (exclusion lists + the shared hard-assert gate)
_CORPUS = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "corpus")
sys.path.insert(0, os.path.abspath(_CORPUS))
import build_corpus as B  # noqa: E402

# weekday() : Mon=0 .. Sun=6
TIER_BY_WEEKDAY = {0: 1, 1: 1, 2: 2, 3: 2, 4: 2, 5: 3, 6: 3}
NO_REPEAT_DAYS = 365


def load_tiers(path):
    tiers = {1: [], 2: [], 3: []}
    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.rstrip("\n")
            if not line:
                continue
            parts = line.split("\t")
            word, tier = parts[0], int(parts[1])
            tiers.setdefault(tier, []).append(word)
    for t in tiers:
        tiers[t] = sorted(set(tiers[t]))
    return tiers


def load_content(path):
    """{word: (theme, definition_uz)} — the WS-B content master. Keyed by word
    so content survives a tier re-cut / schedule regeneration — it re-attaches
    to whichever dates keep the word. Every answer MUST have content (enforced
    below), so hints cover the whole pool."""
    return B.load_word_content(path)


def load_history(path):
    """{'YYYY-MM-DD': word} of already-assigned days (previous schedules)."""
    if not path or not os.path.exists(path):
        return {}
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    # a full schedule object: {"puzzles": [{date, word, ...}, ...]}
    if isinstance(data, dict) and "puzzles" in data:
        return {p["date"]: p["word"] for p in data["puzzles"]}
    # a plain {"YYYY-MM-DD": "word"} history map
    if isinstance(data, dict):
        return dict(data)
    # a bare list of puzzle objects
    return {p["date"]: p["word"] for p in data}


def build_schedule(tiers, start, days, seed, history, start_number=1):
    rng = random.Random(seed)
    queues = {}
    for t in (1, 2, 3):
        pool = list(tiers.get(t, []))
        rng.shuffle(pool)
        queues[t] = pool

    # last-used date per word, seeded from history
    last_used = {}
    for date_str, word in history.items():
        d = dt.date.fromisoformat(date_str)
        if word not in last_used or d > last_used[word]:
            last_used[word] = d

    puzzles = []
    for i in range(days):
        date = start + dt.timedelta(days=i)
        tier = TIER_BY_WEEKDAY[date.weekday()]
        word = _pick(queues, tier, date, last_used)
        last_used[word] = date
        puzzles.append({
            # Monotonic id matching the server's daily_puzzles.puzzle_number, so
            # the bundled offline fallback reports the same puzzle number as the
            # backend view for a given date.
            "puzzle_number": start_number + i,
            "date": date.isoformat(),
            "word": word,
            "difficulty": tier,
            "theme": None,
            "definition_uz": None,
        })
    return puzzles


def _pick(queues, tier, date, last_used):
    """Next word from `tier` not used within NO_REPEAT_DAYS of `date`.

    Falls back to adjacent tiers only if a tier is genuinely exhausted (should not
    happen for a 90-day run against tiers of hundreds of words), keeping the run
    robust rather than crashing.
    """
    order = [tier, tier - 1, tier + 1, tier - 2, tier + 2]
    for t in order:
        q = queues.get(t)
        if not q:
            continue
        rotated = 0
        while rotated < len(q):
            cand = q[0]
            prev = last_used.get(cand)
            if prev is None or (date - prev).days > NO_REPEAT_DAYS:
                q.pop(0)
                return cand
            q.append(q.pop(0))  # defer; try next
            rotated += 1
    raise RuntimeError(f"no eligible word for {date} tier {tier} — pools exhausted")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--answers", required=True, help="answers_tiered.tsv (word\\ttier\\tfreq)")
    ap.add_argument("--start", default=dt.date.today().isoformat(), help="YYYY-MM-DD")
    ap.add_argument("--start-number", type=int, default=1,
                    help="puzzle_number of the first day (continues the live series)")
    ap.add_argument("--days", type=int, default=90)
    ap.add_argument("--seed", type=int, default=142)
    ap.add_argument("--history", default=None, help="prior schedule/history JSON (optional)")
    ap.add_argument("--content",
                    default=os.path.join(os.path.dirname(__file__), "word_content_uz.tsv"),
                    help="word->theme/definition_uz master (WS-B)")
    ap.add_argument("--out", default=os.path.join(os.path.dirname(__file__), "out", "schedule.json"))
    args = ap.parse_args()

    tiers = load_tiers(args.answers)
    # Hard gate (WS-DC): the input pool AND therefore every scheduled word must
    # be exclusion-clean and 5LL. This is the layer that let MANOT reappear —
    # the generator used to trust answers_tiered.tsv blindly, so an exclusion
    # applied anywhere downstream (DB, schedule edit) silently regressed on the
    # next regeneration. Now the build fails instead.
    B.assert_answer_invariants([w for pool in tiers.values() for w in pool])
    history = load_history(args.history)
    content = load_content(args.content)
    start = dt.date.fromisoformat(args.start)
    puzzles = build_schedule(tiers, start, args.days, args.seed, history,
                             start_number=args.start_number)

    # Attach theme + definition by word (WS-B). A definition must never contain
    # its own answer word — the dialog shows it *without* revealing the word.
    # Coverage is total by construction (write_answers_tiered asserts it), so a
    # scheduled word without content is a hard failure, not a null.
    missing = []
    for p in puzzles:
        theme, d = content.get(p["word"], (None, None))
        if d and p["word"] in d.lower():
            raise SystemExit(f"definition for '{p['word']}' reveals the word: {d!r}")
        p["theme"] = theme
        p["definition_uz"] = d
        if not d or not theme:
            missing.append(p["word"])
    if missing:
        raise SystemExit(f"scheduled words missing theme/definition: {missing}")

    # invariants
    words = [p["word"] for p in puzzles]
    assert len(words) == len(set(words)), "duplicate within generated window"

    out = {
        "generated_at": dt.datetime.now(dt.timezone.utc).isoformat(),
        "seed": args.seed,
        "start_date": args.start,
        "start_number": args.start_number,
        "days": args.days,
        "no_repeat_days": NO_REPEAT_DAYS,
        "tier_by_weekday": {str(k): v for k, v in TIER_BY_WEEKDAY.items()},
        "puzzles": puzzles,
    }
    os.makedirs(os.path.dirname(args.out), exist_ok=True)
    with open(args.out, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=2)

    tier_counts = {t: sum(1 for p in puzzles if p["difficulty"] == t) for t in (1, 2, 3)}
    print(f"wrote {len(puzzles)} puzzles {puzzles[0]['date']}..{puzzles[-1]['date']} "
          f"-> {args.out}")
    print(f"tier counts: {tier_counts}")
    print(f"theme+definition attached: {len(puzzles)}/{len(puzzles)}")
    print("first 7:", ", ".join(f"{p['date']}={p['word']}(t{p['difficulty']})" for p in puzzles[:7]))


if __name__ == "__main__":
    main()
