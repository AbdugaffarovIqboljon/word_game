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
MIN_VG_ATTEST = 10       # uniform wiki-attestation floor for BOTH inflection paths:
                         # a generated (path b) or wiki-validated (path c) 5LL form
                         # is kept only if it occurs at least this often in running
                         # text. Lifts the guess list off the freq-1 long tail while
                         # leaving genuine forms (verb tenses, vazni/vaznga) intact.
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
    # verbal: past/converb/conditional/progressive
    "yapman", "yapsan", "yapti", "moqda", "gandi", "kandi", "qandi", "gan",
    "kan", "qan", "yap", "sa", "sang", "sak", "masa", "may", "mas", "mang",
    "ib", "ver", "gani", "kani", "moq", "di", "ti", "dim", "ding", "dik",
    "gan", "sin", "sizlar",
    # verbal: aorist / future-habitual ("noaniq kelasi-hozirgi zamon"), e.g.
    # kel+adi=keladi, o'qi+ydi=o'qiydi, kel+ar=kelar, yasha+r=yashar. -adi/-ar
    # follow a consonant-final stem, -ydi/-r a vowel-final one (same allomorph
    # pairing already used for -di/-ti and -ga/-ka/-qa above).
    "adi", "ydi", "ar", "r",
}, key=len, reverse=True)

# The aorist suffixes are the shortest in SUFFIXES (1-3 letters), so stripping
# them off an unrelated noun stem (rang+ar, but+ar) coincidentally lands on a
# real hunspell entry far more often than the longer suffixes above do. Since
# hunspell stores each verb as its bare `-moq` infinitive (kelmoq, bormoq —
# never the bare root "kel"/"bor"), is_inflected_of_hunspell's normal stem
# lookup can't confirm these are genuinely verbal. Reconstructing the
# infinitive (stem + "moq") and checking THAT against hun_all is the actual
# verb-root check, so it is required for these four specifically.
AORIST_SUFFIXES = frozenset({"adi", "ydi", "ar", "r"})

# POS classification of every surface suffix, for the path-(c) validation gate.
# A stripped suffix only confirms a wiki form as a real inflection when it
# attaches to the RIGHT class of stem:
#   * VERBAL tense/aspect/mood endings need a VERB. Hunspell stores every verb
#     only as its "-moq" infinitive (kelmoq, never the bare root "kel") with no
#     `po:` tag, so the verb-root check is `stem + "moq" in hun_all` — the same
#     technique the aorist already uses. This blocks the "biyti" bug class: a
#     verbal ending stripped off a noun that merely ends in those letters
#     (biy[noun] + -ti), which the old bare-stem lookup wrongly confirmed.
#   * NOMINAL case/number/possessive/derivation endings need a NOMINAL stem
#     (noun/adj/num/pron — the declinable classes), never a conjunction/adverb
#     (yoʻq[conj] + -ing) or a verb.
# Endings that attach to any class (question -mi, focus -gina/-kina) are left
# ungated. AORIST_SUFFIXES ⊂ VERBAL_SUFFIXES (they keep their extra allomorph
# guard); every member of SUFFIXES is in exactly one of these two sets or is a
# neutral clitic above.
VERBAL_SUFFIXES = frozenset({
    "yapman", "yapsan", "yapti", "moqda", "gandi", "kandi", "qandi", "gan",
    "kan", "qan", "yap", "sa", "sang", "sak", "masa", "may", "mas", "mang",
    "ib", "ver", "gani", "kani", "moq", "di", "ti", "dim", "ding", "dik",
    "sin", "sizlar", "adi", "ydi", "ar", "r",
})
NOMINAL_SUFFIXES = frozenset({
    "larimizni", "laringizni", "larimiz", "laringiz", "larini", "larida",
    "laridan", "lariga", "larim", "laring", "larni", "larga", "larda",
    "lardan", "lari", "lar", "imizni", "ingizni", "ningni", "imiz", "ingiz",
    "imni", "ingni", "niki", "ini", "ida", "idan", "iga", "im", "ing", "si",
    "ni", "ning", "ga", "ka", "qa", "da", "ta", "dan", "cha", "day", "dek",
    "roq",
})
NOMINAL_POS = frozenset({"noun", "adj", "num", "pron"})
# Dative allomorphs: -ka after a k-final stem, -qa after q, -ga otherwise
# (mirrors generate_inflections). Guarded so zam+"ka"=zamka never validates.
DATIVE_SUFFIXES = frozenset({"ka", "qa", "ga"})


# Standard literary-Uzbek nominal morphology. Uzbek suffixes are (unlike Turkish)
# largely invariant to vowel harmony; the real variation is consonant-driven, so
# these rules produce correct surface forms for the vast majority of stems.
_VOWELS = frozenset(["a", "e", "i", "o", "u", "o" + U.TURNED_COMMA])
_VOICELESS = frozenset(["p", "t", "k", "q", "s", "sh", "ch", "f", "x", "h"])


def generate_inflections(stem, pos=None):
    """Regular inflections + productive derivations of a NOMINAL stem.

    Handles the consonant sandhi that matters for correctness:
      * dative      -ga / -ka (after k) / -qa (after q)
      * locative    -da / -ta  and ablative -dan / -tan after a voiceless final
      * possessive  k -> g, q -> gʻ softening before a vowel-initial suffix
                    (yurak+i -> yuragi, qishloq+im -> qishlogʻim)
    Every suffix this generator emits is NOMINAL (case/number/possessive plus the
    derivations -li/-siz/-cha/-day/-dek), so the whole function is POS-gated to
    the declinable classes: it fires only for stems tagged noun/adj/num/pron in
    hunspell (NOMINAL_POS) and returns nothing for conjunctions, verbs, adverbs
    and untagged stems. This is the same gate path (c)'s NOMINAL_SUFFIXES use in
    is_inflected_of_hunspell, and it is the root-cause fix for junk like
    vash[conj]+im=vashim: those forms are never generated at all rather than
    relying on their happening to be rare in wiki. The DERIVATIONAL suffixes stay
    further restricted to plain nouns, where they always yield a genuine Uzbek
    word. Verb morphology is left to the hunspell -moq lemmas. Caller filters to
    exactly 5 logical letters.
    """
    if pos not in NOMINAL_POS:
        return ()
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


def load_exclusions(path, root_match=True):
    """Return a predicate `is_excluded(word)` from a term list.

    root_match=True  (offensive list): exact OR substring for terms >=4 chars,
                     so a root also removes its derivations.
    root_match=False (non-answers list): EXACT match only — every answer is
                     exactly 5 logical letters, so exact is sufficient and avoids
                     accidentally deleting a good word that merely contains a
                     proper-noun substring.
    """
    exact, roots = set(), []
    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            term = U.normalize(line)
            exact.add(term)
            if root_match and len(term) >= 4:
                roots.append(term)
    def is_excluded(word):
        if word in exact:
            return True
        return any(r in word for r in roots)
    return is_excluded


def assign_tiers(answers):
    """Split a frequency-rank-ordered answer list into 3 balanced tiers.

    `answers` must already be sorted most-frequent first. Tier 1 = easy (most
    common) .. tier 3 = hard (least common). Returns {word: tier}. Shared by the
    full build and the `recurate` re-tiering path so both stay identical.
    """
    n = len(answers)
    cut1, cut2 = n // 3, (2 * n) // 3
    return {w: (1 if i < cut1 else 2 if i < cut2 else 3)
            for i, w in enumerate(answers)}


def is_inflected_of_hunspell(token, hun_all, hun_pos):
    """True if stripping one surface suffix yields a real hunspell stem of the
    part-of-speech that suffix can actually attach to.

    Guarantees the accepted word is genuinely Uzbek (root is in the lexicon) AND
    morphologically well-formed, so it is safe against foreign/markup tokens that
    merely happen to use only Uzbek letters, and against a suffix landing on an
    unrelated stem that just ends in those letters. Two guards make the pairing
    real (see VERBAL_SUFFIXES/NOMINAL_SUFFIXES/DATIVE_SUFFIXES):
      * verbal endings validate only against a verb root (stem+"moq" in lexicon);
      * nominal endings validate only against a nominal stem (noun/adj/num/pron),
        and the dative -ka/-qa/-ga must match the stem's final-consonant allomorph.
    Reverses the possessive consonant softening (yuragi->yurak, qishlogʻi->qishloq)
    and tolerates a stem final vowel dropped in the surface (bola+si).
    """
    gcomma = "g" + U.TURNED_COMMA
    for suf in SUFFIXES:
        if not (token.endswith(suf) and len(token) - len(suf) >= 2):
            continue
        stem = token[: -len(suf)]
        stem_toks = U.tokenize(stem)
        if not stem_toks:
            continue
        slast = stem_toks[-1]
        ends_vowel = slast in _VOWELS

        if suf in VERBAL_SUFFIXES:
            # Verbs live in hunspell only as their "-moq" infinitive, so the
            # verb-root check is stem+"moq" — this both confirms the root is a
            # real verb and POS-gates the ending (a verbal suffix never
            # validates against a noun/adj that merely ends in those letters).
            if suf in AORIST_SUFFIXES:
                # allomorph: -ar/-adi after a consonant-final stem, -r/-ydi
                # after a vowel-final one (kel+ar=kelar, yasha+r=yashar — never
                # the reverse; skips e.g. "surt"+"r"). The stem vowel is kept in
                # the surface here, so no vowel-absorption branch is needed.
                if ends_vowel != (suf in ("r", "ydi")):
                    continue
                if stem + "moq" in hun_all:
                    return True
                continue
            if stem + "moq" in hun_all:
                return True
            # A converb/tense ending starting with a vowel (-ib) absorbs a
            # vowel-final verb root's last vowel (tani+b -> tanib, stripped to
            # "tan"), so also try restoring it: tani+moq=tanimoq is the real
            # verb. Still POS-gated — a real -moq infinitive must exist.
            if any(stem + v + "moq" in hun_all for v in ("a", "i", "o", "u", "e")):
                return True
            continue

        # --- nominal suffixes -------------------------------------------------
        if suf in DATIVE_SUFFIXES:
            # allomorph: -ka after k, -qa after q, -ga otherwise. Reject the
            # mismatched pairing (zam+"ka"=zamka, zal+"ka"=zalka) that would
            # otherwise land on an unrelated k/q-free noun.
            want = "ka" if slast == "k" else "qa" if slast == "q" else "ga"
            if suf != want:
                continue

        # Resolve the actual lexicon entry this suffix stripped back to.
        cand = None
        if stem in hun_all:
            cand = stem
        elif stem.endswith(gcomma) and (stem[:-2] + "q") in hun_all:  # gʻ -> q
            cand = stem[:-2] + "q"
        elif stem.endswith("g") and (stem[:-1] + "k") in hun_all:     # g -> k
            cand = stem[:-1] + "k"
        else:
            for v in ("a", "i", "o", "u", "e"):  # stem final vowel absorbed
                if stem + v in hun_all:
                    cand = stem + v
                    break
        if cand is None:
            continue
        # POS-gate nominal case/number/possessive/derivation endings; neutral
        # clitics (-mi/-gina/-kina) are not in NOMINAL_SUFFIXES and stay ungated.
        if suf in NOMINAL_SUFFIXES and hun_pos.get(cand) not in NOMINAL_POS:
            continue
        return True
    return False


WORD_CONTENT_PATH = os.path.join(
    HERE, "..", "generator", "word_content_uz.tsv")


def load_word_content(path=None):
    """{word: (theme, definition_uz)} from the WS-B content master."""
    path = path or WORD_CONTENT_PATH
    content = {}
    if not os.path.exists(path):
        return content
    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.rstrip("\n")
            if not line or line.startswith("#"):
                continue
            word, theme, definition = line.split("\t")
            content[word] = (theme, definition)
    return content


def write_answers_tiered(out_dir, answers_sorted, tier, total):
    """answers_tiered.tsv: word, tier, freq, theme, definition_uz.

    The theme/definition columns come from the WS-B content master
    (tool/generator/word_content_uz.tsv) and are REQUIRED for every answer —
    the hint features (Mavzu + Lugʻat) must cover the whole pool, so a new
    answer without authored content fails the build rather than shipping a
    silent gap.
    """
    content = load_word_content()
    missing = [w for w in answers_sorted if w not in content]
    assert not missing, (
        f"{len(missing)} answers missing theme/definition in "
        f"word_content_uz.tsv: {missing[:15]}")
    with open(os.path.join(out_dir, "answers_tiered.tsv"), "w",
              encoding="utf-8") as f:
        for w in answers_sorted:
            theme, definition = content[w]
            f.write(f"{w}\t{tier[w]}\t{total(w)}\t{theme}\t{definition}\n")


def assert_answer_invariants(answers, valid_guesses=None, hun_pos=None):
    """Hard build gate — raises AssertionError (build FAILS) on any violation:

      1. exclusions applied: excluded ∩ answers = ∅ (offensive + non_answers);
      2. every answer is exactly 5 logical letters;
      3. answers ⊆ valid_guesses (when the guess list is available);
      4. noun-only: every answer is a hunspell noun lemma (when POS is available).

    Called by build_corpus (full build), recurate (re-cut) and
    generate_schedule (schedule generation), so an exclusion added to
    exclusions/*.txt can never silently reappear downstream — the regression
    that let MANOT back into the schedule.
    """
    excl_dir = os.path.join(HERE, "exclusions")
    is_off = load_exclusions(os.path.join(excl_dir, "offensive_uz.txt"))
    is_non = load_exclusions(os.path.join(excl_dir, "non_answers.txt"),
                             root_match=False)
    leaked = sorted(w for w in answers if is_off(w) or is_non(w))
    assert not leaked, f"excluded words leaked into answers: {leaked[:20]}"

    bad_len = sorted(w for w in answers
                     if len(U.logical_letters(w) or []) != 5)
    assert not bad_len, f"answers not 5 logical letters: {bad_len[:20]}"

    if valid_guesses is not None:
        missing = sorted(set(answers) - set(valid_guesses))
        assert not missing, f"answers missing from valid_guesses: {missing[:20]}"

    if hun_pos is not None:
        non_noun = sorted(w for w in answers if hun_pos.get(w) != "noun")
        assert not non_noun, f"non-noun answers: {non_noun[:20]}"


def build(sources_dir, out_dir):
    dic = os.path.join(sources_dir, "uz_Latn_UZ.dic")
    wiki = os.path.join(sources_dir, "wiki_freq.tsv")
    excl = os.path.join(HERE, "exclusions", "offensive_uz.txt")
    non_ans = os.path.join(HERE, "exclusions", "non_answers.txt")

    hun_all, hun_5ll, hun_pos = load_hunspell(dic)
    freq = load_wiki(wiki)
    is_offensive = load_exclusions(excl)
    # Proper nouns / raw loanwords / slang: removed from ANSWERS only. They remain
    # legitimate valid_guesses (a player may type them), so this filter is applied
    # to the answer pool below and never to the guess list.
    is_non_answer = load_exclusions(non_ans, root_match=False)

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
    non_ans_removed = sum(
        1 for w in hun_5ll if is_non_answer(w) and not is_offensive(w))
    min_freq = MIN_ANSWER_FREQ
    # Answers are restricted to nouns: a common concrete noun is the fairest,
    # most guessable daily target. Adjectives/verbs/adverbs/pronouns/conjunctions
    # (and untagged stems) stay legitimate valid_guesses but are never the answer.
    def answer_candidates(mf):
        return [w for w in hun_5ll
                if not is_offensive(w) and not is_non_answer(w)
                and hun_pos.get(w) == "noun" and total(w) >= mf]
    cands = answer_candidates(min_freq)
    if len(cands) < MIN_ANSWERS:  # relax so we always reach the floor
        min_freq = 1
        cands = answer_candidates(min_freq)
    cands.sort(key=lambda w: (-total(w), w))
    answers = cands[:MAX_ANSWERS]

    # tier by frequency rank: tier 1 = most frequent (easy) .. tier 3 = hard
    n = len(answers)
    tier = assign_tiers(answers)

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
            # wiki-attestation gate: a generated form is kept only if it occurs
            # at least MIN_VG_ATTEST times in running text. generate_inflections
            # is a morphological generator (every rule fires on every nominal
            # stem), so this is what separates real, current surface words
            # (bogʻ+im=bogʻim, attested) from grammatical-but-unused ones
            # (yoʻq+im=yoʻgʻim, freq 0) and the freq-1 long tail.
            if total(form) < MIN_VG_ATTEST:
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
        if t < MIN_VG_ATTEST:  # uniform attestation floor, shared with path (b)
            continue
        toks = U.tokenize(tok)
        if toks is None or len(toks) != 5:
            continue
        # Validation guarantees the word is real Uzbek (root in the lexicon +
        # well-formed morphology); the MIN_VG_ATTEST floor above additionally
        # requires it to be a form that actually recurs in running text.
        if is_inflected_of_hunspell(tok, hun_all, hun_pos):
            vg.add(tok); src["wiki_inflection"] += 1

    valid_guesses = sorted(vg)
    answers_sorted = sorted(answers)

    # --- write assets -------------------------------------------------------
    os.makedirs(out_dir, exist_ok=True)
    with open(os.path.join(out_dir, "answers.txt"), "w", encoding="utf-8") as f:
        f.write("\n".join(answers_sorted) + "\n")
    write_answers_tiered(out_dir, answers_sorted, tier, total)
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
        "answers_non_answer_removed": non_ans_removed,
        "vg_sources": dict(src),
        "answers_with_compound": sum(1 for w in answers if U.has_compound(w)),
        "answers_with_ng": sum(1 for w in answers if U.has_letter(w, "ng")),
    })
    # hard gate: exclusions applied, 5LL, noun-only, answers ⊆ valid_guesses
    assert_answer_invariants(answers_sorted, valid_guesses, hun_pos)

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
    add(f"- Proper nouns / loanwords / slang removed from answer pool "
        f"(kept in valid_guesses): {stats.get('answers_non_answer_removed', 0)}")
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
