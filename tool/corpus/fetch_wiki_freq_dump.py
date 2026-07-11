#!/usr/bin/env python3
"""Build the Uzbek word-frequency table from the full uz.wikipedia dump.

Preferred over the API sampler (`fetch_wiki_freq.py`) when a high-coverage table
is needed: the API sampler reaches only a few thousand articles, which
under-covers everyday vocabulary; the dump covers ALL ~349k articles, so every
lexicon word gets a real frequency and difficulty tiering is meaningful.

Input : uzwiki-latest-pages-articles.xml.bz2  (uz.wikipedia, CC BY-SA 4.0)
Output: <out>/wiki_freq.tsv   ->  token \t total_count \t title_count
        (same schema as the API sampler, so build_corpus.py is unchanged)

Streaming: bz2 is decompressed on the fly and parsed with iterparse, clearing
each page, so memory stays bounded regardless of dump size.
"""

from __future__ import annotations

import bz2
import os
import re
import sys
import time
from collections import Counter
from xml.etree import ElementTree as ET

import uz_letters as U

REDIRECT_RE = re.compile(r"^\s*#\s*(redirect|yo\S*naltirish)", re.I)
COMMENT_RE = re.compile(r"<!--.*?-->", re.S)
REF_RE = re.compile(r"<ref[^>/]*>.*?</ref>|<ref[^>]*/>", re.S | re.I)
TAG_RE = re.compile(r"<[^>]+>")
TABLE_RE = re.compile(r"\{\|.*?\|\}", re.S)
TEMPLATE_RE = re.compile(r"\{\{[^{}]*\}\}")
FILECAT_RE = re.compile(r"\[\[(?:File|Image|Fayl|Rasm|Category|Turkum|Kategoriya)\s*:[^\]]*\]\]", re.I)
LINK_PIPE_RE = re.compile(r"\[\[[^\]|]*\|([^\]]*)\]\]")   # [[target|text]] -> text
LINK_RE = re.compile(r"\[\[([^\]]*)\]\]")                  # [[text]] -> text
EXTLINK_RE = re.compile(r"\[https?://\S+\s+([^\]]*)\]")    # [url text] -> text
URL_RE = re.compile(r"https?://\S+")
BOLDITAL_RE = re.compile(r"'{2,}")                         # wiki '' / ''' markup
STRIP_CHARS = "«»\"'()[]{}.,;:!?—–-…·*/\\|<>@#%&+=~`^“”‘’„“”0123456789"


def clean_markup(text: str) -> str:
    text = COMMENT_RE.sub(" ", text)
    text = REF_RE.sub(" ", text)
    text = TABLE_RE.sub(" ", text)
    for _ in range(6):  # unwind nested templates
        new = TEMPLATE_RE.sub(" ", text)
        if new == text:
            break
        text = new
    text = FILECAT_RE.sub(" ", text)
    text = LINK_PIPE_RE.sub(r"\1", text)
    text = LINK_RE.sub(r"\1", text)
    text = EXTLINK_RE.sub(r"\1", text)
    text = URL_RE.sub(" ", text)
    text = TAG_RE.sub(" ", text)
    text = BOLDITAL_RE.sub(" ", text)
    return text


def count_text(text: str, total: Counter, title: Counter) -> None:
    for raw in text.split():
        raw = raw.strip(STRIP_CHARS)
        if not raw:
            continue
        norm = U.normalize(raw)
        toks = U.tokenize(norm)
        if toks is None or not (2 <= len(toks) <= 12):
            continue
        total[norm] += 1
        if raw[:1].isupper():
            title[norm] += 1


def local(tag: str) -> str:
    return tag.rsplit("}", 1)[-1]


def main() -> int:
    if len(sys.argv) < 2:
        print("usage: fetch_wiki_freq_dump.py <dump.xml.bz2> [out_dir]", file=sys.stderr)
        return 2
    dump_path = sys.argv[1]
    out_dir = sys.argv[2] if len(sys.argv) > 2 else os.path.dirname(dump_path)
    out_path = os.path.join(out_dir, "wiki_freq.tsv")

    total: Counter = Counter()
    title: Counter = Counter()
    pages = arts = 0
    start = time.time()

    with bz2.open(dump_path, "rt", encoding="utf-8") as fh:
        ns_cur = None
        is_redirect = False
        for event, elem in ET.iterparse(fh, events=("start", "end")):
            tag = local(elem.tag)
            if event == "start":
                if tag == "page":
                    ns_cur, is_redirect = None, False
                continue
            # end events
            if tag == "ns":
                ns_cur = (elem.text or "").strip()
            elif tag == "redirect":
                is_redirect = True
            elif tag == "text":
                if ns_cur == "0" and not is_redirect:
                    txt = elem.text or ""
                    if not REDIRECT_RE.match(txt):
                        count_text(clean_markup(txt), total, title)
                        arts += 1
            elif tag == "page":
                pages += 1
                elem.clear()
                if pages % 25000 == 0:
                    print(f"[dump] pages={pages} articles={arts} types={len(total)} "
                          f"elapsed={int(time.time()-start)}s", flush=True)

    tmp = out_path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        f.write(f"# uz.wikipedia FULL dump frequency (CC BY-SA 4.0) — "
                f"articles={arts} types={len(total)}\n")
        for tok, c in total.most_common():
            f.write(f"{tok}\t{c}\t{title.get(tok, 0)}\n")
    os.replace(tmp, out_path)
    print(f"[done] pages={pages} articles={arts} types={len(total)} "
          f"elapsed={int(time.time()-start)}s -> {out_path}", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
