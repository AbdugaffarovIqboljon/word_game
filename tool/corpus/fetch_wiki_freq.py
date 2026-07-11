#!/usr/bin/env python3
"""Derive an Uzbek word-frequency table directly from uz.wikipedia (CC BY-SA 4.0).

Why we build our own instead of using a ready-made list: the convenient
pre-built Uzbek frequency corpora (e.g. Leipzig Corpora Collection) are released
under CC BY-NC, which is incompatible with a monetised app. uz.wikipedia text is
CC BY-SA 4.0 and may be used commercially with attribution + share-alike, so we
sample it through the public MediaWiki API and count words ourselves. The
resulting table (and any corpus derived from it) is therefore redistributed as
CC BY-SA 4.0 with attribution to Wikipedia — see tool/corpus/SOURCES.md.

The table is used only to (a) rank answer candidates into difficulty tiers and
(b) admit common inflected word-forms into the valid-guess list. It is a build
input, not shipped verbatim.

Output: <out>/wiki_freq.tsv   ->  token \t total_count \t title_count
  * token       : normalised, well-formed logical word (any length)
  * total_count : occurrences (any case)
  * title_count : occurrences whose raw form was Titlecase/UPPER (proper-noun signal)

Resumable & checkpointed: safe to Ctrl-C; partial output is valid.
"""

from __future__ import annotations

import json
import os
import ssl
import sys
import time
import urllib.parse
import urllib.request
from collections import Counter

import uz_letters as U

API = "https://uz.wikipedia.org/w/api.php"
UA = "SozJangiCorpusBuilder/1.0 (daily word game; contact: coderikhbolsheikh@gmail.com)"

# The python.org macOS build ships no root store; use certifi's bundle if present
# so HTTPS to Wikimedia verifies correctly.
try:
    import certifi
    _SSL_CTX = ssl.create_default_context(cafile=certifi.where())
except Exception:  # pragma: no cover - fall back to system default
    _SSL_CTX = ssl.create_default_context()

MAX_REQUESTS = int(os.environ.get("WIKI_MAX_REQUESTS", "900"))
MAX_SECONDS = int(os.environ.get("WIKI_MAX_SECONDS", "1100"))
BATCH = 20  # articles per request (API cap when using plaintext extracts)
SLEEP = float(os.environ.get("WIKI_SLEEP", "0.15"))


def api_get(params: dict) -> dict:
    url = API + "?" + urllib.parse.urlencode(params)
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=45, context=_SSL_CTX) as resp:
        return json.load(resp)


def count_text(text: str, total: Counter, title: Counter) -> None:
    # Split on whitespace, then peel leading/trailing non-letters per raw token.
    for raw in text.split():
        raw = raw.strip("«»\"'()[]{}.,;:!?—–-…·*/\\|<>@#%&+=~`^“”‘’")
        if not raw:
            continue
        norm = U.normalize(raw)
        toks = U.tokenize(norm)
        if toks is None or not (2 <= len(toks) <= 12):
            continue
        total[norm] += 1
        # Proper-noun signal: raw token started with an uppercase letter and is
        # not all-lowercase. (Sentence-initial noise is tolerated; we only ever
        # use a very high ratio as an exclusion trigger downstream.)
        if raw[:1].isupper():
            title[norm] += 1


def write_checkpoint(out_path: str, total: Counter, title: Counter, articles: int) -> None:
    tmp = out_path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        f.write(f"# uz.wikipedia frequency sample (CC BY-SA 4.0) — articles={articles} types={len(total)}\n")
        for tok, c in total.most_common():
            f.write(f"{tok}\t{c}\t{title.get(tok, 0)}\n")
    os.replace(tmp, out_path)


def main() -> int:
    out_dir = sys.argv[1] if len(sys.argv) > 1 else "."
    out_path = os.path.join(out_dir, "wiki_freq.tsv")
    total: Counter = Counter()
    title: Counter = Counter()
    seen_pages: set[int] = set()
    articles = 0
    start = time.time()

    for req_i in range(1, MAX_REQUESTS + 1):
        if time.time() - start > MAX_SECONDS:
            print(f"[stop] time budget reached at request {req_i}", flush=True)
            break
        try:
            data = api_get({
                "action": "query", "format": "json", "formatversion": "2",
                "generator": "random", "grnnamespace": "0", "grnlimit": str(BATCH),
                "prop": "extracts", "explaintext": "1", "exintro": "1",
                "exlimit": str(BATCH),
            })
        except Exception as exc:  # transient network / API hiccup: back off, retry loop
            print(f"[warn] req {req_i} failed: {exc}", flush=True)
            time.sleep(1.5)
            continue

        pages = data.get("query", {}).get("pages", [])
        for p in pages:
            pid = p.get("pageid")
            if pid in seen_pages:
                continue
            seen_pages.add(pid)
            ext = p.get("extract") or ""
            if ext:
                count_text(ext, total, title)
                articles += 1

        if req_i % 25 == 0:
            write_checkpoint(out_path, total, title, articles)
            print(f"[ckpt] req={req_i} articles={articles} types={len(total)} "
                  f"elapsed={int(time.time()-start)}s", flush=True)
        time.sleep(SLEEP)

    write_checkpoint(out_path, total, title, articles)
    print(f"[done] articles={articles} types={len(total)} -> {out_path}", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
