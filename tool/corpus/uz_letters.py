"""Uzbek Latin logical-letter engine for So'z Jangi.

Single source of truth for how a raw Uzbek word is normalised and split into the
29-key logical alphabet used by the game keyboard. The Dart datasource
(`lib/data/dictionary_datasource.dart`) mirrors this logic byte-for-byte — if you
change a rule here, change it there too, or validity/answer lookup will diverge
between the corpus build and the running app.

The 29 logical letters (from the design's keyboard spec, "no C, no W"):

    24 single : a b d e f g h i j k l m n o p q r s t u v x y z
    5 compound: oʻ  gʻ  sh  ch  ng      (each is ONE key / ONE logical letter)

Apostrophe policy (from the design tokens doc):
  * U+02BB MODIFIER LETTER TURNED COMMA  -> the "belgi" in oʻ / gʻ  (KEEP)
  * U+02BC MODIFIER LETTER APOSTROPHE    -> "tutuq belgisi" / glottal stop
                                            (sanʼat, maʼno) -> word EXCLUDED
A raw apostrophe is disambiguated by the letter before it: after o/g it is the
turned comma (part of a compound letter); anywhere else it is tutuq belgisi.
"""

from __future__ import annotations

# --- apostrophe codepoints ---------------------------------------------------
TURNED_COMMA = "ʻ"  # ʻ  oʻ / gʻ
TUTUQ = "ʼ"         # ʼ  tutuq belgisi (excluded)

# Every apostrophe-like glyph observed across the source corpora, so we can fold
# them all onto the two canonical marks above.
_APOSTROPHES = frozenset(
    "'"          # U+0027 apostrophe
    "’"     # ’ right single quote
    "‘"     # ‘ left single quote
    "ʻ"     # ʻ turned comma (canonical o'/g')
    "ʼ"     # ʼ modifier apostrophe (canonical tutuq)
    "`"     # ` grave
    "´"     # ´ acute
    "′"     # ′ prime
    "‛"     # ‛ single high-reversed-9
    "ʹ"     # ʹ modifier prime
    "‵"     # ‵ reversed prime
    "＇"     # ＇ fullwidth apostrophe
)

# --- logical alphabet --------------------------------------------------------
SINGLE_LETTERS = frozenset("abdefghijklmnopqrstuvxyz")  # 24 (no c, no w)
COMPOUND_LETTERS = ("o" + TURNED_COMMA, "g" + TURNED_COMMA, "sh", "ch", "ng")
_COMPOUND_SET = frozenset(COMPOUND_LETTERS)

ALPHABET = tuple(sorted(SINGLE_LETTERS)) + COMPOUND_LETTERS  # 29 logical letters
WORD_LENGTH = 5  # logical letters per puzzle word


def normalize_apostrophes(word: str) -> str:
    """Fold every apostrophe glyph onto U+02BB (after o/g) or U+02BC (elsewhere)."""
    out: list[str] = []
    for ch in word:
        if ch in _APOSTROPHES:
            prev = out[-1] if out else ""
            out.append(TURNED_COMMA if prev in ("o", "g") else TUTUQ)
        else:
            out.append(ch)
    return "".join(out)


def normalize(word: str) -> str:
    """Trim, lowercase and unify apostrophes. No validation/tokenisation here."""
    return normalize_apostrophes(word.strip().lower())


def tokenize(word: str) -> list[str] | None:
    """Split a *normalised* word into logical letters using maximal munch.

    Compound letters (oʻ gʻ sh ch ng) are matched greedily before singles, which
    matches the game keyboard: an Ng/Sh/Ch/Oʻ/Gʻ key emits one logical letter.

    Returns ``None`` if the word contains any character that cannot be part of a
    valid logical letter — a foreign letter (c, w, ...), a digit, punctuation, a
    hyphen, a space, or the tutuq belgisi (U+02BC). That makes ``tokenize`` the
    single membership test for "is this a well-formed game word".
    """
    letters: list[str] = []
    i, n = 0, len(word)
    while i < n:
        if word[i : i + 2] in _COMPOUND_SET:
            letters.append(word[i : i + 2])
            i += 2
            continue
        ch = word[i]
        if ch in SINGLE_LETTERS:
            letters.append(ch)
            i += 1
            continue
        return None
    return letters


def logical_letters(word: str) -> list[str] | None:
    """Convenience: normalise then tokenise."""
    return tokenize(normalize(word))


def logical_len(word: str) -> int:
    """Logical-letter count, or -1 if the word is not well-formed."""
    toks = logical_letters(word)
    return -1 if toks is None else len(toks)


def is_game_word(word: str, length: int = WORD_LENGTH) -> bool:
    """True iff ``word`` normalises to exactly ``length`` valid logical letters."""
    toks = logical_letters(word)
    return toks is not None and len(toks) == length


def has_compound(word: str) -> bool:
    toks = logical_letters(word)
    return bool(toks) and any(t in _COMPOUND_SET for t in toks)


def has_letter(word: str, letter: str) -> bool:
    toks = logical_letters(word)
    return bool(toks) and letter in toks
