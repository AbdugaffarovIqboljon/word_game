#!/usr/bin/env python3
"""Loanword sweep over the So'z Jangi answer pool (WS7).

Purpose: find Russian / European borrowings that are unfit for a *pure Uzbek*
answer pool — especially the hard (tier-3) band — and emit them so they can be
appended to `exclusions/non_answers.txt` (removed from ANSWERS, kept in
valid_guesses). Heuristics, in decreasing confidence:

  1. initial consonant cluster — native Uzbek has NO word-initial CC, so any word
     whose first two logical letters are both consonants is a borrowing
     (st-, sk-, shk-, sht-, br-, gr-, kr-, pr-, tr-, pl-, kl-, fl-, spr-, …).
  2. terminal -tsiya / -siya — the Russian -ция noun ending.
  3. curated Russian/European lexicon — assimilated-but-foreign items with native
     phonotactics the cluster rule cannot see (titan, modul, gramm, gauss, …).

Everything flagged here is *unfit for any tier* and goes to non_answers.txt. The
common, fully-assimilated "doktor-class" words (which have native phonotactics and
are NOT on the curated list) are intentionally NOT flagged: they may remain in
tier 1/2, and — being high-frequency — never fall into the re-cut tier 3 anyway.

Usage:
  python3 loanword_sweep.py                 # report only
  python3 loanword_sweep.py --emit          # also print the non_answers block
"""

from __future__ import annotations

import argparse
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import uz_letters as U  # noqa: E402

VOWELS = frozenset(["a", "e", "i", "o", "u", "o" + U.TURNED_COMMA])

# Initial clusters the task calls out explicitly (for the human-readable report);
# the general "first two logical letters are consonants" rule is the real test and
# is a strict superset of this list.
NAMED_CLUSTERS = (
    "st", "sk", "shk", "sht", "shp", "shtr", "br", "gr", "kr", "pr", "tr",
    "pl", "kl", "fl", "sp", "sl", "sm", "sn", "sv", "sf", "dr", "fr", "vl",
    "vr", "gl", "bl", "kv", "kn", "ps", "pn", "tv",
)

# Curated Russian / European borrowings with *native* phonotactics that the
# cluster rule cannot catch. Hand-picked from the current answer pool; each is a
# real 5-logical-letter token that stays a legal guess but must not be a daily
# answer. This set is exactly the non-cluster tokens we remove, so
# `--emit` == the block appended to non_answers.txt.
#
# Deliberately NOT listed (kept as tier 1/2, "doktor-class" assimilated): the
# common business terms `aktiv`, `audit`, `tarif`, `bonus` (high-frequency, so
# they never fall into the re-cut tier 3), and everyday assimilated nouns with
# native phonotactics (palto=coat, kafel=tile, lavash=food, gilos=cherry).
CURATED_LOANWORDS = frozenset({
    # science / units / technical
    "titan", "litiy", "modul", "gauss", "aktin", "argon", "binar", "foton",
    "triod",
    # finance / office
    "debet", "diler", "lizing",
    # objects / culture that read as raw loans
    "gotik", "lobbi", "langet",
    # foreign / ethnonym leftovers
    "dariy", "mariy", "guano",
})


def load_pool(path):
    rows = []
    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.rstrip("\n")
            if not line:
                continue
            parts = line.split("\t")
            word = parts[0]
            tier = int(parts[1]) if len(parts) >= 2 else 0
            freq = int(parts[2]) if len(parts) >= 3 else 0
            rows.append((word, tier, freq))
    return rows


def initial_cluster(word):
    toks = U.logical_letters(word)
    if not toks or len(toks) < 2:
        return None
    if toks[0] not in VOWELS and toks[1] not in VOWELS:
        return toks[0] + toks[1]
    return None


def terminal_tsiya(word):
    n = U.normalize(word)
    return n.endswith("tsiya") or n.endswith("siya")


def classify(word):
    """Return a reason string if the word looks like a borrowing, else None."""
    cl = initial_cluster(word)
    if cl is not None:
        return f"initial-cluster:{cl}"
    if terminal_tsiya(word):
        return "terminal:-siya"
    if U.normalize(word) in CURATED_LOANWORDS:
        return "curated"
    return None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--answers",
                    default=os.path.join(HERE, "out", "answers_tiered.tsv"))
    ap.add_argument("--emit", action="store_true",
                    help="print the block to append to non_answers.txt")
    args = ap.parse_args()

    rows = load_pool(args.answers)
    flagged = []
    for word, tier, freq in rows:
        reason = classify(word)
        if reason:
            flagged.append((word, tier, freq, reason))

    flagged.sort(key=lambda r: (r[3], -r[2]))
    by_reason = {}
    for w, t, fr, r in flagged:
        by_reason.setdefault(r.split(":")[0], []).append((w, t, fr, r))

    print(f"# loanword sweep — {len(flagged)} flagged / {len(rows)} answers\n")
    for group in sorted(by_reason):
        items = by_reason[group]
        print(f"## {group}  ({len(items)})")
        for w, t, fr, r in sorted(items, key=lambda x: (-x[2], x[0])):
            print(f"  {w:12s} tier={t} freq={fr:>7} [{r}]")
        print()

    if args.emit:
        print("\n# ===== append to exclusions/non_answers.txt =====")
        words = sorted({w for w, _, _, _ in flagged})
        for w in words:
            print(w)


if __name__ == "__main__":
    main()
