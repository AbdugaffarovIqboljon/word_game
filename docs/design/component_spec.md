# Component Spec — So'z Jangi

Source: same Claude Design project, `Board.dc.html` and `Keyboard.dc.html` (the two live
component partials, read directly — these are the actual implementation the screens
import via `<dc-import>`, not just illustrations), plus the "Uzbek keyboard · 29 keys"
reference frame and every screen that renders these components in `Soz Jangi.dc.html`.

All hex/size values below are cross-referenced against `design_tokens.md` — see that
document for the full token tables and flagged inconsistencies. This document is the
per-component implementation spec.

---

## (a) Keyboard — 29-key Uzbek layout

### Row layout (exact, as designed)

```
Row 1 (10 keys): Q  E  R  T  Y  U  I  O  P  Oʻ
Row 2 (10 keys): A  S  D  F  G  H  J  K  L  Gʻ
Row 3 (11 items): ENTER  Z  X  V  B  N  M  Sh  Ch  Ng  ⌫(DEL)
```

**29-key confirmation:** Row 1 = 10 letter keys, Row 2 = 10 letter keys, Row 3 = 9 letter
keys (Z X V B N M Sh Ch Ng) + 2 action keys (ENTER, DEL). 10 + 10 + 9 = **29 letter/compound
keys**, matching the design's own header ("29 keys") and its explicit note "no C, no W."
The 5 compound letters (**Oʻ, Gʻ, Sh, Ch, Ng**) are each a single key — not two keys or a
long-press variant — with a two-character label.

DEL is rendered as the Unicode backspace glyph **⌫** (`U+232B`), not the text "DEL", in
the actual component (`label: label === 'DEL' ? '⌫' : label`). ENTER renders as the
literal word "ENTER" — there is no localized Uzbek label for it in the source.

### Sizing

| Property | Value |
|---|---|
| Key height | 50px, fixed, all rows |
| Row-to-row gap | 7px |
| Key-to-key gap (within a row) | 5px |
| Letter key width | `flex: 1` |
| Compound key width (Oʻ/Gʻ/Sh/Ch/Ng) | `flex: 1.35` |
| ENTER / DEL width | `flex: 1.7` |
| Letter key label font | 17px / 600 Space Grotesk |
| Compound key label font | 15px / 600 Space Grotesk |
| ENTER/DEL label font | 15px / 600 Space Grotesk |
| Key corner radius | **7px** (hardcoded in `Keyboard.dc.html` — conflicts with the declared `key` token of 8px in the tokens doc; use 7px, it's the live component value, not the doc-chrome legend) |
| Key shadow | `0 2px 0 rgba(0,0,0,.35)` on every key (a flat "bevel" bottom edge, not a soft blur) |
| Total footer height | ≈178px including all gaps — validated by the design to fit both the 844pt and 640pt target viewports |

### 4 key states + compound-key accent

| State | Background | Foreground | Applies to |
|---|---|---|---|
| `default` | `#3A4A6B` | `#F4F7FC` | Untouched letter/compound key |
| `absent` | `#212D45` | `#5E6D8C` | Letter guessed, not in word |
| `present` | `#C2952B` | `#0B1220` | Letter guessed, wrong position |
| `correct` | `#3E9B54` | `#FFFFFF` | Letter guessed, correct position |

**Action keys (ENTER, DEL) are exempt from the 4-state system** — they are always
`background:#4A5B80, color:#F4F7FC, border:none` regardless of game state.

**Compound-key accent border:** any compound key (Oʻ/Gʻ/Sh/Ch/Ng) that is still in its
`default` state (or has no state entry at all) additionally gets `border: 1.5px solid
#C2952B` — a visual hint that these are the "extra" Uzbek letters. Once a compound key
receives an `absent`/`present`/`correct` state, the accent border is dropped and only the
state color applies (per the component logic: `if (isCompound && (!st[label] ||
st[label] === 'default')) border = '1.5px solid #C2952B'`).

### State-priority note

Not explicitly stated in the source, but implied by wordle-family conventions and worth
confirming with design before implementation: when a letter has appeared in multiple
guesses with different outcomes (e.g. `present` in guess 2, then `correct` in guess 4),
the key should show the best-known state (`correct` > `present` > `absent`). The design
data (`kbMid`, `kbFail` objects) only ever encodes a single final state per letter, so this
priority rule is inferred, not shown. Flagged in Open Questions.

---

## (b) Letter tile

### Sizing per context (all confirmed from live screen data, not estimated)

| Context | Tile size | Letter font |
|---|---|---|
| Main gameplay board (Daily Board a/b/c) | 56×56px | 28px |
| Onboarding step 3 / Hint-sheet blurred backdrop | 52×52px | 26px |
| Failed-state compact 6-row board | 42×42px | 21px |
| Solved-state mini recap board | 30×30px | 15px |

Grid gap is **6px** in both directions (row gap and column gap) at every size — the Board
component uses a single `gap:6px` flex-column of flex rows, each row also `gap:6px`.

Tile corner radius: **6px** (matches the declared `tile` token — no conflict here, unlike
the keyboard).

Letter rendering: `font-weight:700`, `text-transform:uppercase`, `line-height:1`, Space
Grotesk.

### 5 tile states

| State | Background | Border | Foreground |
|---|---|---|---|
| `empty` | `transparent` | `2px solid #2E3E60` | `#F4F7FC` |
| `typing` (filled, not submitted) | `#16233F` | `2px solid #56688F` | `#FFFFFF` |
| `absent` | `#35435F` | none | `#D5DDEC` |
| `present` | `#C2952B` | none | `#0B1220` |
| `correct` | `#3E9B54` | none | `#FFFFFF` |

Note this is a **5-state** system (tile) vs. the keyboard's 4-state system — `typing` has
no keyboard equivalent, since a key only ever reflects a letter's *submitted* outcome, not
whether it's currently staged in an unsubmitted guess.

### Animations

| Animation | Spec |
|---|---|
| **Flip (reveal on submit)** | 150ms per tile, staggered 100ms between tiles left-to-right within the submitted row. Transform: `rotateX(0) → rotateX(90deg) → rotateX(0)` over the 150ms, with the tile's background/text color swapped at the 50% keyframe (i.e. exactly when the tile is edge-on and invisible, so the color change itself is imperceptible — only the reveal is seen). |
| **Shake (invalid word)** | Full row, ±8px horizontal amplitude, **500ms, single-shot**. Keyframe curve (from the source's own `@keyframes shake`): `10%/90% → -2px`, `20%/80% → 4px`, `30%/50%/70% → -8px`, `40%/60% → 8px`. No tile color change during a shake — tiles keep whatever `typing`/`empty` color they already had. |

**Flag:** the raw CSS in the source loops the shake animation infinitely at 600ms
(`animation:shake .6s ease-in-out infinite`) so the static mockup demonstrates it
continuously — this is a preview-only artifact. The screen's own text annotation states
the real spec is 500ms, single shot. Implement 500ms/one-shot, not 600ms/infinite.

### Invalid-word toast (appears with the shake)

Background `#F4F7FC`, text color `#0B1220` (i.e. inverted — light pill on dark screen),
font 13px/700 Space Grotesk, padding `9px 16px`, border-radius 8px, shadow
`0 6px 18px rgba(0,0,0,.5)`. Copy: "Soʻz lugʻatda yoʻq" ("Word not in dictionary").
**Auto-dismisses after 1.4s** (per the screen's own annotation).

---

## (c) Buttons, dialogs, share card, counters

### Primary CTA button

Full-width (or near-full-width) filled button. Two brand-color variants observed:
- **Green** (`#3E9B54`) — default/success actions: "Boshlash", "Davom etish",
  "Streakni tiklash", "Reklama koʻring va oling".
- **Telegram blue** (`#229ED9`) — share-specific actions only: "Natijani ulashish",
  "Telegramda ulashish", "Ulashish".

| Property | Value |
|---|---|
| Height | 54px standard; 52px inside modal dialogs; 56px on the fail-state compact share button |
| Border radius | 14px |
| Border | none |
| Label | 16px/700 Space Grotesk (15px/700 in the compact fail-state variant) |
| Shadow | `inset 0 1px 0 rgba(255,255,255,.20–.24)` + `0 10px 24–26px -8px [brand]/.55–.6` + `0 2px 6px rgba(0,0,0,.35)` — a 3-layer "raised glow" recipe, not one of the declared e1–e3 elevations (see `design_tokens.md` §5.2) |

### Secondary button (2 visual sub-variants)

**Filled-secondary** (e.g. "Stories", "Nusxa"): background `--surface-2` (`#1A2740`),
border `1px solid --border` (`#2A3A5C`), radius 12px, label 14px/600 Space Grotesk, height
46px.

**Outline-secondary** (e.g. "Mashq qilish" on the share screen): transparent background,
border `1.5px solid #3E9B54`, text color `#5FBE73` (note: NOT `#3E9B54` — the text uses the
lighter untokenized green, the border uses the darker `--correct` green; this is
intentional contrast, not a typo — see `design_tokens.md` §1.4), radius 12px, height 48px,
label 14px/700.

### Icon-only button (header actions: settings, hint, back, close, share)

34×34px square, background `--surface-2`, border `1px solid --border`, radius **10px**
(not in the declared radius scale — see tokens doc §4.2), icon 17–20px depending on
context. Icon tint varies by semantic role: `#F5A623` (hint/amber), `#A5B2CC` (neutral
back/settings/share), `#6B7A99` (close, on darker dialog surfaces).

### Disabled / locked button state

Distinct palette, not derived from any declared token: background `#131C2C`, border
`1px solid #22304C`, text/icon `#5E6D8C`, `cursor:not-allowed`. Used on the
insufficient-coins hint sheet for coin-price buttons the user can't afford.

### Dialogs (modal cards)

Background `--surface-3`... **correction:** actually `#0E1420` (a darker surface not in
the declared `swSurface` list at all — closest declared value is `--bg` `#0B1220`, but this
is a distinct hex; flag as another untokenized surface color), border `1px solid
--border`, radius **22px** (not 16 "card" or 28 "sheet" — a third, undeclared dialog
radius), padding ≈26px 22px, centered text. Backdrop: `rgba(5,8,14,.55–.6)` scrim over a
dimmed+blurred (`opacity:.22–.28`, `filter:blur(1px)`) background snapshot of whatever
screen triggered the dialog.

**Rewarded-ad offer dialog specifically:** its close (`X`) button is present from first
render but **only becomes tappable after a 2-second delay** — this is a stated behavior,
not just a visual, and must be implemented as an actual disabled-then-enabled state, not
merely styled to look inactive.

### Bottom sheet

Background `#0E1420` (same undeclared surface as dialogs), `border-top: 1px solid
--border`, top-corner radius 28px (matches declared `sheet` token), drag handle 40×4px
`--border` fill with 2px radius centered 14px below the top edge, padding `12px 20px 26px`,
shadow `0 -16px 40px rgba(0,0,0,.6)` (upward-facing — not literally the declared `e3`
value, which has no directional y-offset specified as negative; treat as its own token,
see tokens doc §5.2).

### Share card (emoji-grid, Result/Share screen)

| Element | Spec |
|---|---|
| Card | background `#0E1420`, border `1px solid --border`, radius 16px, padding 18px, shadow `0 4px 14px rgba(0,0,0,.5)` |
| Header row | "Soʻz Jangi #142 · 4/6 · 🔥12" — puzzle number, attempt count, streak, all inline on one 15px/700 line |
| Emoji grid | literal emoji characters (⬛🟨🟩), NOT rendered app tiles — one line per guess row, `font-size:24px`, `line-height:1.34`, `letter-spacing:3px` |
| Footer | `soz-jangi.uz` domain, 12px, `--text-3` |
| Below-card caption | "Telegramga aynan shu koʻrinishda joylashadi" ("appears exactly like this on Telegram"), 11px, `--text-3`, centered |

**Note:** the emoji grid is generated from the same per-tile state data as the real board
(`absent→⬛, present→🟨, correct→🟩`) — implementation should derive it from game state
directly, not maintain a separate emoji-mapping data path.

### Coin/gem/streak counters (header chips)

All chips share the same base recipe: background `--surface-2`, border `1px solid
--border`, radius 20px (pill), value text 13px/700 Space Grotesk color `--text`.

| Chip | Icon | Icon color | Padding | Value font | Extra |
|---|---|---|---|---|---|
| Coin | `coins` | `#F2C14E` (`--coin`) | `6px 10px` | 13px/700 | — |
| Gem | `gem` | `#7BC8FF` (`--gem`) | `6px 10px` | 13px/700 | — |
| Streak/flame | `flame` | `#F5A623` (`--fire`) | `6px 11px 6px 9px` (asymmetric) | 15px/700 (larger than coin/gem) | Icon animates: `firepulse` keyframe, scale `1 → 1.12`, 1.6s ease-in-out infinite loop |

Streak chip in the failed-state header uses a dimmed variant: icon color `#4A5B80`, value
color `--text-3`, value "0" — no animation (loop presumably stops when streak is 0, though
this isn't explicitly stated — flag).

---

## OPEN QUESTIONS

1. **Keyboard key-state priority is not specified** — when a letter's best-known outcome
   across multiple guesses should win (`correct` > `present` > `absent`) is inferred from
   genre convention, not shown in the design data.
2. **Dialog/bottom-sheet surface color (`#0E1420`) is not in the declared color token
   list at all** — it's distinct from every `swSurface` value. Needs to be added as a
   formal token (e.g. `--surface-modal`) rather than implemented as a magic hex.
3. **Streak-chip fire animation at zero streak** — whether the `firepulse` loop should
   stop when the streak count is 0 (as shown, dimmed, in the failed-state header) is not
   explicitly stated; the dimmed color change is confirmed but the animation state is not.
4. Keyboard radius (7px) vs. declared `key` token (8px) — flagged here and in
   `design_tokens.md` §4.2; use the live component's 7px.
5. Dialog radius (22px) is a third, previously-undeclared radius value on top of the two
   already flagged in `design_tokens.md` (14px-vs-16px "card" split, 7px-vs-8px "key"
   split) — recommend a single pass to reconcile the entire radius scale before
   implementation rather than fixing these piecemeal.
