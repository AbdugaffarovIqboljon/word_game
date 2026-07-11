#!/usr/bin/env bash
# Download the raw corpus sources into a target directory (default: ./data/raw).
# See SOURCES.md for provenance + licences. Large files are NOT committed.
#
#   ./fetch_sources.sh [dest_dir]
#
# Produces in dest_dir:
#   uz_Latn_UZ.dic / .aff     — MUNIS Uzbek Latin hunspell (CC0)
#   uzwiki.xml.bz2            — full uz.wikipedia dump (CC BY-SA 4.0), ~305 MB
# Then build the frequency table + assets:
#   python3 fetch_wiki_freq_dump.py "$dest/uzwiki.xml.bz2" "$dest"
#   python3 build_corpus.py --sources "$dest" --out out
set -euo pipefail

DEST="${1:-$(dirname "$0")/data/raw}"
mkdir -p "$DEST"

echo "→ MUNIS Uzbek Latin hunspell (CC0)"
curl -sSL -o "$DEST/uz_Latn_UZ.dic" \
  "https://github.com/uzbek-spell/spellchecker/releases/download/v1.0/uz_Latn_UZ.dic"
curl -sSL -o "$DEST/uz_Latn_UZ.aff" \
  "https://github.com/uzbek-spell/spellchecker/releases/download/v1.0/uz_Latn_UZ.aff"

echo "→ uz.wikipedia full dump (CC BY-SA 4.0, ~305 MB)"
curl -sSL -o "$DEST/uzwiki.xml.bz2" \
  "https://dumps.wikimedia.org/uzwiki/latest/uzwiki-latest-pages-articles.xml.bz2"

echo "done → $DEST"
echo "next: python3 fetch_wiki_freq_dump.py \"$DEST/uzwiki.xml.bz2\" \"$DEST\" && python3 build_corpus.py --sources \"$DEST\" --out out"
