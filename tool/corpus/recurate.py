#!/usr/bin/env python3
"""Re-curate the answer pool from the already-built frequency data.

The full pipeline (build_corpus.py) needs the ~305 MB Wikipedia dump + hunspell
sources to (re)build valid_guesses.txt. But applying the answer-only exclusions
(exclusions/non_answers.txt — proper nouns / loanwords / slang) does NOT: every
answer's Wikipedia frequency is already captured in out/answers_tiered.tsv, so we
can drop the excluded tokens and re-tier the survivors deterministically without
re-downloading anything. valid_guesses.txt is intentionally left untouched (the
excluded words stay legitimate guesses).

Reuses build_corpus.load_exclusions / assign_tiers / _write_report so the tiering
and report are byte-for-byte the same as a full rebuild.

Usage:
  python3 recurate.py                 # in-place: reads + rewrites out/
  python3 recurate.py --out other_dir
"""

from __future__ import annotations

import argparse
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import build_corpus as B  # noqa: E402  (path set above)
import uz_letters as U     # noqa: E402


def load_answers_tiered(path):
    """Return [(word, freq)] from an existing answers_tiered.tsv (word\ttier\tfreq)."""
    rows = []
    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.rstrip("\n")
            if not line:
                continue
            parts = line.split("\t")
            word = parts[0]
            freq = int(parts[2]) if len(parts) >= 3 else 0
            rows.append((word, freq))
    return rows


def recurate(out_dir):
    tiered = os.path.join(out_dir, "answers_tiered.tsv")
    prev_stats_path = os.path.join(out_dir, "build_stats.json")
    off = os.path.join(HERE, "exclusions", "offensive_uz.txt")
    non_ans = os.path.join(HERE, "exclusions", "non_answers.txt")

    prev = {}
    if os.path.exists(prev_stats_path):
        with open(prev_stats_path, encoding="utf-8") as f:
            prev = json.load(f)

    is_offensive = B.load_exclusions(off)
    is_non_answer = B.load_exclusions(non_ans, root_match=False)

    rows = load_answers_tiered(tiered)
    freq_map = {w: fr for w, fr in rows}
    total = lambda w: freq_map.get(w, 0)  # noqa: E731

    off_removed = sum(1 for w, _ in rows if is_offensive(w))

    survivors = [w for w, _ in rows if not is_offensive(w) and not is_non_answer(w)]
    survivors.sort(key=lambda w: (-total(w), w))  # frequency-rank order
    tier = B.assign_tiers(survivors)
    n = len(survivors)

    # Total removed by the non-answer curation, measured against the original
    # answer count (vg_sources["answer"]) so the stat stays correct even when
    # recurate is run repeatedly on already-curated output (idempotent input).
    orig_answers = int((prev.get("vg_sources") or {}).get("answer", n))
    non_ans_removed = max(orig_answers - n, 0)

    answers_sorted = sorted(survivors)

    # --- write answer assets (valid_guesses.txt stays untouched) ------------
    with open(os.path.join(out_dir, "answers.txt"), "w", encoding="utf-8") as f:
        f.write("\n".join(answers_sorted) + "\n")
    with open(os.path.join(out_dir, "answers_tiered.tsv"), "w", encoding="utf-8") as f:
        for w in answers_sorted:
            f.write(f"{w}\t{tier[w]}\t{total(w)}\n")

    # --- stats: carry unchanged guess-list fields, refresh answer fields ----
    from collections import Counter
    tier_counts = Counter(tier.values())
    stats = dict(prev)
    stats.update({
        "answers_total": n,
        "answers_min_freq_used": prev.get("answers_min_freq_used", 2),
        "tier_1_easy": tier_counts[1],
        "tier_2_mid": tier_counts[2],
        "tier_3_hard": tier_counts[3],
        "answers_offensive_removed": prev.get("answers_offensive_removed", off_removed),
        "answers_non_answer_removed": non_ans_removed,
        "answers_with_compound": sum(1 for w in answers_sorted if U.has_compound(w)),
        "answers_with_ng": sum(1 for w in answers_sorted if U.has_letter(w, "ng")),
        "recurated": True,
    })
    # valid_guesses_total / vg_sources / hun_* / wiki_types are carried unchanged.

    B._write_report(out_dir, stats, answers_sorted, tier, total)
    with open(prev_stats_path, "w", encoding="utf-8") as f:
        json.dump(stats, f, ensure_ascii=False, indent=2)

    assert n == tier_counts[1] + tier_counts[2] + tier_counts[3]
    return stats, non_ans_removed


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=os.path.join(HERE, "out"))
    args = ap.parse_args()
    stats, removed = recurate(args.out)
    print(f"re-curated answers: removed {removed} non-answer tokens -> "
          f"{stats['answers_total']} answers "
          f"(t1={stats['tier_1_easy']} t2={stats['tier_2_mid']} t3={stats['tier_3_hard']})")


if __name__ == "__main__":
    main()
