#!/usr/bin/env python3
"""Build the So'z Jangi word assets from the verified sources.

Inputs (see SOURCES.md for provenance + licences):
  * hunspell stems : uz_Latn_UZ.dic  (CC0)          -> real, non-proper lexicon
  * wiki frequency : wiki_freq.tsv   (CC BY-SA 4.0)  -> commonness + inflections
  * exclusions     : exclusions/offensive_uz.txt     -> content moderation

Outputs (--out dir, default tool/corpus/out):
  * answers.txt          one common guessable 5-logical-letter word per line
  * answers_tiered.tsv   word \t tier(1=easy..3=hard) \t wiki_freq
  * valid_guesses.txt    broad accepted-guess list (superset of answers)
  * validation_report.md counts, letter distribution, 30 samples/tier
  * build_stats.json     machine-readable stats

A "5-logical-letter word" is defined by uz_letters.tokenize (oʻ/gʻ/sh/ch/ng each
count as ONE letter). Determinism: a fixed seed drives the sample selection only;
the lists themselves are fully determined by the inputs + thresholds below.
"""

from __future__ import annotations

import argparse
import json
import os
import random
from collections import Counter

import uz_letters as U

HERE = os.path.dirname(os.path.abspath(__file__))

# --- tunables ----------------------------------------------------------------
MIN_ANSWER_FREQ = 2      # a stem must appear at least this often in wiki to be a
                         # guessable answer (drops ultra-rare/technical lemmas)
MAX_ANSWERS = 3000       # upper bound of the answer pool (task target 1500-3000)
MIN_ANSWERS = 1500       # lower bound; if unmet, MIN_ANSWER_FREQ is relaxed to 1
VG_FREQ_KEEP = 5         # a non-lexicon wiki 5LL form is accepted as a valid guess
                         # only if it occurs at least this often (drops junk)
PROPER_TITLE_RATIO = 0.85  # >= this share of Titlecase occurrences (and not in the
PROPER_MIN_TOTAL = 4        # lexicon) flags a token as a proper noun -> excluded
SAMPLE_PER_TIER = 30
SEED = 20250710

# Surface suffixes (longest first) used to validate a wiki word-form as an
# inflection of a real hunspell stem. One strip level; the frequency path below
# covers what this misses. Not linguistically exhaustive — precision over recall.
SUFFIXES = sorted({
    # plural + case + possessive (nominal)
    "larimizni", "laringizni", "larimiz", "laringiz", "larini", "larida",
    "laridan", "lariga", "larim", "laring", "larni", "larga", "larda",
    "lardan", "lari", "lar", "imizni", "ingizni", "ningni", "imiz", "ingiz",
    "imni", "ingni", "niki", "ini", "ida", "idan", "iga", "im", "ing", "si",
    "ni", "ning", "ga", "ka", "qa", "da", "ta", "dan", "cha", "day", "dek",
    "roq", "gina", "kina", "mi",
    # verbal
    "yapman", "yapsan", "yapti", "moqda", "gandi", "kandi", "qandi", "gan",
    "kan", "qan", "yap", "sa", "sang", "sak", "masa", "may", "mas", "mang",
    "ib", "ver", "gani", "kani", "moq", "di", "ti", "dim", "ding", "dik",
    "gan", "sin", "sizlar",
}, key=len, reverse=True)


# Standard literary-Uzbek nominal morphology. Uzbek suffixes are (unlike Turkish)
# largely invariant to vowel harmony; the real variation is consonant-driven, so
# these rules produce correct surface forms for the vast majority of stems.
_VOWELS = frozenset(["a", "e", "i", "o", "u", "o" + U.TURNED_COMMA])
_VOICELESS = frozenset(["p", "t", "k", "q", "s", "sh", "ch", "f", "x", "h"])


def generate_inflections(stem, pos=None):
    """Regular inflections + productive derivations of a stem.

    Handles the consonant sandhi that matters for correctness:
      * dative      -ga / -ka (after k) / -qa (after q)
      * locative    -da / -ta  and ablative -dan / -tan after a voiceless final
      * possessive  k -> g, q -> gʻ softening before a vowel-initial suffix
                    (yurak+i -> yuragi, qishloq+im -> qishlogʻim)
    Nominal case/number/possessive suffixes apply to any stem. The productive
    DERIVATIONAL suffixes (-li "with", -siz "without", -cha diminutive,
    -day/-dek "like") are restricted to noun stems, where they always yield a
    genuine Uzbek word. Verb morphology is left to the hunspell -moq lemmas.
    Caller filters to exactly 5 logical letters.
    """
    toks = U.tokenize(stem)
    if not toks:
        return ()
    last = toks[-1]
    ends_vowel = last in _VOWELS
    voiceless = last in _VOICELESS
    out = {stem + "lar", stem + "ni", stem + "ning"}
    out.add(stem + ("ka" if last == "k" else "qa" if last == "q" else "ga"))
    out.add(stem + ("ta" if voiceless else "da"))
    out.add(stem + ("tan" if voiceless else "dan"))
    if ends_vowel:
        out.update({stem + "m", stem + "ng", stem + "si"})
    else:
        soft = stem[:-1] + "g" if last == "k" else \
            stem[:-1] + "g" + U.TURNED_COMMA if last == "q" else stem
        out.update({soft + "im", soft + "ing", soft + "i"})
    if pos == "noun":
        out.update({stem + "li", stem + "siz", stem + "cha",
                    stem + "day", stem + "dek"})
    return out


def load_hunspell(path):
    """Return (hun_all, hun_5ll, hun_pos) from normalised well-formed lowercase stems.

    Original-uppercase entries (proper nouns / abbreviations like FHDYO) are
    skipped. hun_all keeps any length >=2 for suffix-stem lookups; hun_pos maps
    every stem to its `po:` part-of-speech tag (or None) so derivation can be
    restricted to nouns.
    """
    hun_all, hun_5ll, hun_pos = set(), set(), {}
    with open(path, encoding="utf-8") as f:
        next(f)  # leading count line
        for line in f:
            line = line.rstrip("\n")
            if not line:
                continue
            raw_stem = line.split("/")[0].split("\t")[0].split(" ")[0]
            if not raw_stem or raw_stem[:1].isupper():
                continue
            po = None
            if "po:" in line:
                po = line.split("po:", 1)[1].split()[0].strip()
            toks = U.logical_letters(raw_stem)
            if toks is None or len(toks) < 2:
                continue
            norm = U.normalize(raw_stem)
            hun_all.add(norm)
            hun_pos[norm] = po
            if len(toks) == 5:
                hun_5ll.add(norm)
    return hun_all, hun_5ll, hun_pos


def load_wiki(path):
    """Return {token: (total, title)} for well-formed normalised tokens."""
    freq = {}
    if not os.path.exists(path):
        return freq
    with open(path, encoding="utf-8") as f:
        for line in f:
            if line.startswith("#") or not line.strip():
                continue
            parts = line.rstrip("\n").split("\t")
            if len(parts) < 3:
                continue
            tok, total, title = parts[0], int(parts[1]), int(parts[2])
            freq[tok] = (total, title)
    return freq


def load_exclusions(path):
    exact, roots = set(), []
    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            term = U.normalize(line)
            exact.add(term)
            if len(term) >= 4:
                roots.append(term)
    def is_offensive(word):
        if word in exact:
            return True
        return any(r in word for r in roots)
    return is_offensive


def is_inflected_of_hunspell(token, hun_all):
    """True if stripping one surface suffix yields a real hunspell stem.

    Guarantees the accepted word is genuinely Uzbek (root is in the lexicon), so
    it is safe against foreign/markup tokens that merely happen to use only Uzbek
    letters. Reverses the possessive/dative consonant softening (yuragi->yurak,
    qishlogʻi->qishloq) and tolerates a stem final vowel dropped in the surface.
    """
    gcomma = "g" + U.TURNED_COMMA
    for suf in SUFFIXES:
        if token.endswith(suf) and len(token) - len(suf) >= 2:
            stem = token[: -len(suf)]
            if stem in hun_all:
                return True
            # reverse softening: g -> k, gʻ -> q
            if stem.endswith(gcomma) and (stem[:-2] + "q") in hun_all:
                return True
            if stem.endswith("g") and (stem[:-1] + "k") in hun_all:
                return True
            # tolerate a stem final vowel absorbed by the suffix (bola+si)
            if any(stem + v in hun_all for v in ("a", "i", "o", "u", "e")):
                return True
    return False


def build(sources_dir, out_dir):
    dic = os.path.join(sources_dir, "uz_Latn_UZ.dic")
    wiki = os.path.join(sources_dir, "wiki_freq.tsv")
    excl = os.path.join(HERE, "exclusions", "offensive_uz.txt")

    hun_all, hun_5ll, hun_pos = load_hunspell(dic)
    freq = load_wiki(wiki)
    is_offensive = load_exclusions(excl)

    def total(tok):
        return freq.get(tok, (0, 0))[0]

    def is_proper(tok):
        t, ti = freq.get(tok, (0, 0))
        if tok in hun_all:
            return False
        return t >= PROPER_MIN_TOTAL and ti / t >= PROPER_TITLE_RATIO

    stats = {"hun_all": len(hun_all), "hun_5ll": len(hun_5ll), "wiki_types": len(freq)}

    # --- ANSWERS: common, guessable, lexicon lemmas ------------------------
    off_removed = sum(1 for w in hun_5ll if is_offensive(w))
    min_freq = MIN_ANSWER_FREQ
    def answer_candidates(mf):
        return [w for w in hun_5ll if not is_offensive(w) and total(w) >= mf]
    cands = answer_candidates(min_freq)
    if len(cands) < MIN_ANSWERS:  # relax so we always reach the floor
        min_freq = 1
        cands = answer_candidates(min_freq)
    cands.sort(key=lambda w: (-total(w), w))
    answers = cands[:MAX_ANSWERS]

    # tier by frequency rank: tier 1 = most frequent (easy) .. tier 3 = hard
    n = len(answers)
    cut1, cut2 = n // 3, (2 * n) // 3
    tier = {}
    for i, w in enumerate(answers):
        tier[w] = 1 if i < cut1 else (2 if i < cut2 else 3)

    # --- VALID GUESSES: broad accepted list, superset of answers -----------
    vg = set(answers)
    src = Counter()
    for w in answers:
        src["answer"] += 1
    # 1) every real 5LL lexicon stem
    for w in hun_5ll:
        if w in vg or is_offensive(w):
            continue
        vg.add(w); src["hunspell_stem"] += 1
    # 2) deterministic regular inflections of short lexicon stems (CC0-derived,
    #    correct morphology) — the reliable volume driver for the guess list
    for stem in hun_all:
        if not (2 <= len(U.tokenize(stem) or []) <= 4):
            continue
        for form in generate_inflections(stem, hun_pos.get(stem)):
            if form in vg or is_offensive(form) or not U.is_game_word(form):
                continue
            vg.add(form); src["generated_inflection"] += 1
    # 3) wiki 5LL forms attested in running text AND validated as a real
    #    inflection of a lexicon stem. We deliberately do NOT admit words on raw
    #    frequency alone: the full dump contains English/markup tokens that use
    #    only Uzbek letters (state, there, align, ...), so every guess must be
    #    hunspell-rooted to stay genuinely Uzbek.
    for tok, (t, ti) in freq.items():
        if tok in vg or is_offensive(tok) or is_proper(tok):
            continue
        toks = U.tokenize(tok)
        if toks is None or len(toks) != 5:
            continue
        # Validation (not frequency) is what guarantees the word is real Uzbek,
        # so a single attestation is enough once the root is in the lexicon.
        if is_inflected_of_hunspell(tok, hun_all):
            vg.add(tok); src["wiki_inflection"] += 1

    valid_guesses = sorted(vg)
    answers_sorted = sorted(answers)

    # --- write assets -------------------------------------------------------
    os.makedirs(out_dir, exist_ok=True)
    with open(os.path.join(out_dir, "answers.txt"), "w", encoding="utf-8") as f:
        f.write("\n".join(answers_sorted) + "\n")
    with open(os.path.join(out_dir, "answers_tiered.tsv"), "w", encoding="utf-8") as f:
        for w in answers_sorted:
            f.write(f"{w}\t{tier[w]}\t{total(w)}\n")
    with open(os.path.join(out_dir, "valid_guesses.txt"), "w", encoding="utf-8") as f:
        f.write("\n".join(valid_guesses) + "\n")

    # --- stats + report -----------------------------------------------------
    tier_counts = Counter(tier.values())
    stats.update({
        "answers_total": n,
        "answers_min_freq_used": min_freq,
        "tier_1_easy": tier_counts[1], "tier_2_mid": tier_counts[2], "tier_3_hard": tier_counts[3],
        "valid_guesses_total": len(valid_guesses),
        "answers_offensive_removed": off_removed,
        "vg_sources": dict(src),
        "answers_with_compound": sum(1 for w in answers if U.has_compound(w)),
        "answers_with_ng": sum(1 for w in answers if U.has_letter(w, "ng")),
    })
    assert set(answers_sorted) <= set(valid_guesses), "answers must be subset of valid_guesses"

    _write_report(out_dir, stats, answers_sorted, tier, total)
    with open(os.path.join(out_dir, "build_stats.json"), "w", encoding="utf-8") as f:
        json.dump(stats, f, ensure_ascii=False, indent=2)
    return stats


def _letter_distribution(words):
    c = Counter()
    for w in words:
        for lt in (U.tokenize(w) or []):
            c[lt] += 1
    return c


def _write_report(out_dir, stats, answers, tier, total):
    rng = random.Random(SEED)
    by_tier = {1: [], 2: [], 3: []}
    for w in answers:
        by_tier[tier[w]].append(w)
    letters = _letter_distribution(answers)
    first = Counter((U.tokenize(w) or [""])[0] for w in answers)
    total_letters = sum(letters.values()) or 1

    lines = []
    add = lines.append
    add("# So'z Jangi — Corpus Validation Report\n")
    add("_Generated by `tool/corpus/build_corpus.py`. All words are exactly 5 logical")
    add("letters, where **oʻ gʻ sh ch ng** each count as ONE letter._\n")
    add("## 1. Counts\n")
    add(f"- Hunspell lexicon stems (well-formed, ≥2 letters): **{stats['hun_all']}** "
        f"(of which 5-letter: **{stats['hun_5ll']}**)")
    add(f"- Wikipedia frequency types sampled: **{stats['wiki_types']}**")
    add(f"- **answers.txt: {stats['answers_total']}** "
        f"(min wiki freq used: {stats['answers_min_freq_used']})")
    add(f"  - Tier 1 (easy / most common): **{stats['tier_1_easy']}**")
    add(f"  - Tier 2 (mid): **{stats['tier_2_mid']}**")
    add(f"  - Tier 3 (hard / least common): **{stats['tier_3_hard']}**")
    add(f"- **valid_guesses.txt: {stats['valid_guesses_total']}** "
        f"(superset of answers ✓)")
    add(f"  - provenance: {stats['vg_sources']}")
    add(f"- Offensive stems removed from answer pool: {stats['answers_offensive_removed']}")
    add(f"- Answers containing a compound letter: {stats['answers_with_compound']} "
        f"(of which `ng`: {stats['answers_with_ng']})\n")

    add("## 2. Letter distribution (answers, position-agnostic)\n")
    add("Sanity check: no logical letter should be absent or wildly dominant.\n")
    add("| letter | count | % | | letter | count | % |")
    add("|---|---:|---:|---|---|---:|---:|")
    ordered = sorted(U.ALPHABET, key=lambda l: -letters.get(l, 0))
    half = (len(ordered) + 1) // 2
    for i in range(half):
        l1 = ordered[i]
        c1 = letters.get(l1, 0)
        row = f"| `{l1}` | {c1} | {100*c1/total_letters:.1f}% |"
        j = i + half
        if j < len(ordered):
            l2 = ordered[j]; c2 = letters.get(l2, 0)
            row += f" | `{l2}` | {c2} | {100*c2/total_letters:.1f}% |"
        else:
            row += " | | | |"
        add(row)
    add("")
    missing = [l for l in U.ALPHABET if letters.get(l, 0) == 0]
    add(f"Letters never appearing in answers: {missing if missing else 'none ✓'}\n")

    add("## 3. First-letter distribution (top 12)\n")
    add("| letter | count |  | letter | count |")
    add("|---|---:|---|---|---:|")
    top = first.most_common(12)
    for i in range(0, len(top), 2):
        a = f"| `{top[i][0]}` | {top[i][1]} |"
        b = f" `{top[i+1][0]}` | {top[i+1][1]} |" if i + 1 < len(top) else " | |"
        add(a + b)
    add("")

    add(f"## 4. Random samples for human review ({SAMPLE_PER_TIER} per tier)\n")
    names = {1: "Tier 1 — easy (most common)", 2: "Tier 2 — mid", 3: "Tier 3 — hard (least common)"}
    for t in (1, 2, 3):
        pool = by_tier[t]
        pick = sorted(rng.sample(pool, min(SAMPLE_PER_TIER, len(pool))))
        add(f"### {names[t]}  ({len(pool)} words)\n")
        add("`" + "`, `".join(f"{w} [{total(w)}]" for w in pick) + "`\n")
    with open(os.path.join(out_dir, "validation_report.md"), "w", encoding="utf-8") as f:
        f.write("\n".join(lines))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--sources", required=True, help="dir with uz_Latn_UZ.dic + wiki_freq.tsv")
    ap.add_argument("--out", default=os.path.join(HERE, "out"))
    args = ap.parse_args()
    stats = build(args.sources, args.out)
    print(json.dumps(stats, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
