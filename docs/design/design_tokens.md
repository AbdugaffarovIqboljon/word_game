# Design Tokens — So'z Jangi

Source of truth: Claude Design project `So'z Jangi Mobile Game Design`
(`d384c2d8-340f-4481-a44f-846039db2072`), file `Soz Jangi.dc.html`, section **00 — Design Tokens**,
cross-checked against every screen frame in the same file and against the two live
component partials `Board.dc.html` and `Keyboard.dc.html`.

This document is a literal transcription of declared token values plus a reconciliation
against how those tokens are actually used across the 22 designed screen states. Where a
screen uses a value that doesn't match a declared token, it is called out under **Open
Questions** rather than silently rounded or merged — per instruction, nothing here is invented.

---

## 1. Color

### 1.1 Surfaces (`swSurface`)

| Token | Hex | Usage observed |
|---|---|---|
| `--bg` | `#0B1220` | Phone-screen root background (the actual in-app background, not the design-canvas background — see Open Questions) |
| `--surface` | `#121C2E` | Cards: hint cards, tier buttons, stat tiles, coin-breakdown card, freeze slots |
| `--surface-2` | `#1A2740` | Chips (streak/coin/gem pills), icon buttons, secondary buttons, bottom-sheet buttons |
| `--surface-3` | `#223152` | Section-number badge chips (doc chrome only, not seen in-app) |
| `--border` | `#2A3A5C` | Default 1px card/chip/sheet border everywhere |
| `--border-strong` | `#3A4E78` | Emphasized borders: gem SKU cards, hint-bundle card, freeze buy buttons |

### 1.2 Tile & key states (`swState`)

| Token | Hex (bg) | Border | Foreground | Used by |
|---|---|---|---|---|
| `--tile-empty` | `transparent` | `2px solid #2E3E60` | `#F4F7FC` | Board tile, no letter |
| `--tile-filled` | `#16233F` | `2px solid #56688F` | `#FFFFFF` | Board tile, letter typed, not submitted (`typing` state) |
| `--absent` | `#35435F` | none | `#D5DDEC` | Board tile / key, letter not in word |
| `--present` | `#C2952B` | none | `#0B1220` | Board tile / key, letter in word, wrong position |
| `--correct` | `#3E9B54` | none | `#FFFFFF` | Board tile / key, letter correct position |
| `--key-default` | `#3A4A6B` | none | `#F4F7FC` | Keyboard key, untouched |
| `--key-absent` | `#212D45` | none | `#5E6D8C` | Keyboard key, absent (darker than tile `--absent`, deliberately lower-contrast — flagged below) |
| `--danger` | `#E5484D` | none | `#FFFFFF` | Invalid-word label tint, streak-broken iconography, starter-pack accent |

**Note:** `--absent` (tile) and `--key-absent` (keyboard) are two different hexes (`#35435F` vs `#212D45`) for the same semantic state — this is intentional per the design (keys recede further than tiles) and is NOT a bug; documented here so implementers don't "fix" it into one shared value.

### 1.3 Accents & text (`swAccent`)

| Token | Hex | Usage |
|---|---|---|
| `--fire` | `#F5A623` | Streak flame icon, hint "reveal letter" icon |
| `--coin` | `#F2C14E` | Coin icon/value everywhere |
| `--gem` | `#7BC8FF` | Gem icon/value, link color (`a{color:#7BC8FF}`), "harflarni tozalash" hint icon |
| `--telegram` | `#229ED9` | Telegram share CTA |
| `--text` | `#F4F7FC` | Primary text / headings |
| `--text-2` | `#A5B2CC` | Secondary text (subtitles, body copy) |
| `--text-3` | `#6B7A99` | Tertiary text (captions, footer, `.lbl` micro-label color) |
| `--divider` | `#1B2436` | Hairline separators between doc sections (chrome only) |

### 1.4 Colors used in screens with NO declared token (flag, do not silently map)

These hexes recur across multiple components but do not appear in `swSurface`, `swState`,
or `swAccent`. Each is listed with every context it was observed in so a designer/PM can
decide whether to formalize it as a token or replace it with an existing one.

| Hex | Contexts observed |
|---|---|
| `#5FBE73` | "Mashq qilish" outline-button text, opened-chest title text, stats checkmark note text/icon, skins-locked lock accent |
| `#C6D0E2` | Skin-card usage tag fallback text, motion-annotation body text, various card body copy — sits between `--text` and `--text-2` in the hierarchy but isn't named |
| `#8493B0` | Tier subtitle, hint-card description, stat-tile sublabel, session-stat sublabel, skin-lock sublabel, freeze-CTA sublabel — the single most-reused untokenized color in the whole file |
| `#4A5B80` | Disabled chevron, empty-freeze-slot icon/text, ENTER/DEL key fill, dimmed streak-icon in repair dialog |
| `#F08488` | Starter-pack "package" icon, repair-offer countdown text |
| `#E5A0A2` | Starter-pack subtitle text, insufficient-coins hint-sheet subtitle text |
| `#A9D9B6` | Daily-chest ×2 card sublabel |
| `#E8C98A` | Streak-detail card sublabel ("kunlik streak · shaxsiy rekord") |
| `#3A2A00` | Text-on-gold: reward-granted coin-icon color, daily-chest ×2 amount label color |
| `#F2Cf6a` (mixed-case for `#F2CF6A`) | Gradient stop in reward-granted coin badge and in the "Oltin" (gold) tile-skin preview — a distinct amber from `--coin` (`#F2C14E`); written in inconsistent hex case in source |

### 1.5 Design-canvas background vs. app background (flag)

The outer canvas / doc-chrome background is `#0A0C10` (set on `<body>` and every
`data-screen-group` wrapper). The actual phone-screen mockups all use `#0B1220`
(`--bg` token) as their own background. **`#0A0C10` is not an app color** — it exists only
to frame the spec document itself. Do not use it in Flutter; the real scaffold background
is `--bg` = `#0B1220`.

---

## 2. Typography

Two families, both required to render the full Uzbek Latin set including the
modifier letters **`ʻ`** (U+02BB, MODIFIER LETTER TURNED COMMA — used in Oʻ/Gʻ/soʻz/etc.)
and **`ʼ`** (U+02BC, MODIFIER LETTER APOSTROPHE) — both appear explicitly in the design's
own glyph test string ("Oʻzbek gʻisht choʻl sanʼat").

- **Space Grotesk** — display, titles, tile letters, all numerals (scores, counters, timers).
- **Manrope** — body copy, descriptions, captions, UI microcopy.

Google Fonts import declared in the source: `Space+Grotesk:wght@400;500;600;700` and
`Manrope:wght@400;500;600;700;800`.

### 2.1 Declared type scale (`typescale`, the doc's own "law" table)

| Role | Spec (size/weight) | Font | Sample |
|---|---|---|---|
| Display | 40px / 700 | Space Grotesk | numeral display ("12 842") |
| Title | 26px / 800 | Space Grotesk | "Soʻz Jangi" |
| Section | 18px / 600 | Space Grotesk | "Mashq qilish" |
| Body | 15px / 500 | Manrope | "Kunlik soʻzni toping" |
| Caption | 13px / 500 | Manrope | "Keyingi soʻzgacha" |
| Micro | 11px / 600 | Space Grotesk | "STREAK · COINS" (matches `.lbl` class: 11px/600, letter-spacing .14em, uppercase, color `--text-3`) |
| Tile | 28px / 700 | Space Grotesk | "QALAM" |

### 2.2 Open question — font-weight 800 on Space Grotesk

Space Grotesk is used at **font-weight 800** extensively and load-bearingly: the "Title"
role itself (26/800), the masthead logo (34/800), every section `<h2>` (24/800), dialog
titles (20–22/800), the streak counter (44/800), and stat numerals (30/700, some 800).
But the Google Fonts `@import` for Space Grotesk only requests weights
**400;500;600;700** — and Space Grotesk's variable font on Google Fonts does not ship an
800 (ExtraBold) cut at all; it tops out at 700 (Bold). Every "800" instance in this design
will render as 700 (or a browser-synthesized fake-bold) in practice. **This needs a design
decision before implementation**: either (a) treat all "800" specs as 700, or (b) confirm
a different typeface/weight source is intended for Title-and-above roles. Flutter's
`google_fonts` package will silently clamp to the nearest available weight, which will
quietly diverge from the visual weight in the design mockup screenshots if not addressed.

### 2.3 Sizes observed in screens but absent from the declared 7-role scale (flag, not merged)

The declared scale above is what the tokens section calls "the single source of truth,"
but the 22 screen frames use roughly 30 additional one-off `font-size` values that don't
map onto it. Listed with weight and a representative usage so an implementer can decide
whether to fold each into an existing role or add a new one — **do not silently round
these to the nearest declared size**:

- 44px/800 — streak counter big numeral (streak detail screen)
- 34px/800 — masthead app title (doc chrome, but same value reused nowhere in-app)
- 32px/700 — "Keyingi soʻz" countdown timer (solved state)
- 30px/700 — stats screen numerals (Played/Win%/Streak/Best)
- 26px/800 — "Ajoyib!" win headline; also fail-state answer word (26/800, letter-spacing .16em)
- 24px/700–800 — section `<h2>`s (chrome); onboarding step-2 title
- 22px/800 — shop gem-pack hero price; repair-dialog title
- 21px — fail-board tile letter (compact board variant)
- 20px/800 — onboarding hero title bump; hint-sheet "Yordam" sheet title context; rewarded-ad dialog title
- 19px/800 — bottom-sheet nav-style title
- 18px/700 — tier-card name (Section role is 18/**600** — weight mismatch), streak repair price
- 17px/800 — nav-bar title ("Natija", "Doʻkon", "Mashq", "Statistika", "Streak")
- 16px/700 — most primary-CTA button labels, onboarding body copy, dialog secondary titles
- 15px/700 — card titles (hint cards, chest, share-card header, freeze CTA), secondary CTAs
- 14px/600–700 — chip values, tier reward, secondary buttons, breakdown totals
- 13.5px — result/subtitle copy, repair-dialog body (both sit between Body-15 and Caption-13)
- 13px/500–700 — coin/gem chip values, breakdown line items, footer brand text
- 12.5px — fail-state definition text, hint-sheet subtitle, tier subtitle, tooltip caption
- 12px/500–700 — hint-card descriptions, stat sublabels, skin tag
- 11.5px — annotate callouts, chest sublabels, starter-pack subtitle
- 11px/500–700 — share-card caption, chip micro text, cross-promo label
- 10.5px — typescale spec label itself (doc chrome)
- 10px/700 — shop hero eyebrow badge
- 9px — icon-grid caption (doc chrome)

**Recommendation:** before implementation, collapse this list into a proper scale (e.g. an
8–10-step `TextTheme`) rather than porting ~37 distinct raw sizes into Flutter. This
document intentionally does not make that call — it's a product/design decision.

---

## 3. Spacing

### 3.1 Declared scale (`spacing`, 4pt grid)

| Token | Value |
|---|---|
| `space-1` | 4px |
| `space-2` | 8px |
| `space-3` | 12px |
| `space-4` | 16px |
| `space-5` | 20px |
| `space-6` | 24px |
| `space-8` | 32px |
| `space-12` | 48px |

All eight declared values are on-grid (multiples of 4).

### 3.2 4pt-grid violations (flag, not rounded)

The tokens panel claims "no ad-hoc spacing in any screen," but gaps/paddings/margins
off the 4pt grid recur constantly across the actual screens. These are the values that
repeat across **three or more** distinct components (i.e., not one-off optical nudges) —
listed with a couple of representative locations each:

| Off-grid value | Recurs in |
|---|---|
| 5px | keyboard key-to-key gap; color-token swatch grid gap |
| 6px | tile grid gap (row+column); masthead icon-label gap; icon-button internal gaps |
| 7px | keyboard row-to-row gap; chip icon-to-text gaps; stat-sublabel top margins |
| 9px | hint-card icon-to-copy gap; motion-list row gap; radius-swatch label margin |
| 10px | color-swatch internal gap; header chip gaps |
| 11px | card internal gaps (gems grid, histogram row, hint-icon-to-text) |
| 13px | frame-label-to-mockup gap (chrome); typescale row padding |
| 14px | numerous card paddings (hint cards, breakdown card, freeze card) — see also §4 radius note, these paddings correlate with the 14px-vs-16px radius split |
| 15px | tier-button / hint-card padding |
| 17–18px | shop-hero / starter-pack padding |
| 22px | dialog padding, token-panel padding (chrome) |
| 26px | dialog padding (rewarded-ad, reward-granted), title-bottom margins |
| 30px | reward-granted dialog top padding |
| 34px | screen-group gap (chrome) |
| 42px | fail-board tile size itself (not a spacing value but frequently confused with one — listed for clarity) |
| 46px | tooltip vertical offset (onboarding coach-mark) |
| 60px | outer page padding (chrome) |

**Recommendation:** treat this as two populations — (1) structural paddings that cluster
around 14/18/22px and should probably be formalized as `space-3.5`/`space-4.5`-style
half-steps or simply snapped to 12/16/20/24, vs. (2) small 5–11px "micro-gaps" between an
icon and its label, which are common in real UI work and don't need to be on a strict 4pt
grid. Do not snap either population without a design sign-off — that's a value judgment
this audit deliberately does not make.

---

## 4. Corner radius

### 4.1 Declared scale (`radii`)

| Token | Value | Used by (per design's own legend) |
|---|---|---|
| `tile` | 6px | Board tile |
| `key` | 8px | Keyboard key |
| `chip` | 12px | Pills / chips |
| `card` | 16px | Content cards |
| `sheet` | 28px | Bottom sheet top corners |
| `device` | 44px | Phone mockup frame (chrome only) |

### 4.2 Radius values actually used but NOT in the declared scale (flag)

| Radius | Where |
|---|---|
| 5px | mini tile-skin preview swatches (shop) |
| 7px | **keyboard key itself** — conflicts directly with the declared `key` token of 8px; `Keyboard.dc.html` hardcodes `border-radius:7px` |
| 10px | icon buttons (34×34 header buttons) — used dozens of times, never formalized |
| 11px | hint icon-avatar boxes, freeze buy-buttons |
| 14px | **~40% of "cards" use 14px instead of the declared `card`=16px**: session-stat tiles, coin-breakdown card, hint-bundle card, skin cards, freeze slots, next-word mini box (fail state), repair-offer inner box. The other ~60% of visually-identical cards (hint cards, tier buttons, stats tiles) correctly use 16px. This reads as an unintentional split in a single "card" pattern, not two deliberate tiers — flagging for design/eng to pick one. |
| 15px | shop-hero icon badge |
| 18px | shop hero card, streak-detail hero card, starter-pack card |
| 20px | daily-chest cards (all three states) |
| 22px | modal dialogs (rewarded-ad, reward-granted, streak-repair) |
| 24px | onboarding logo tile (larger version of the 14px masthead logo tile — see §4.3) |

### 4.3 Logo tile radius/size ratio inconsistency (minor, flag)

Masthead app-icon: 56×56px, radius 14px (ratio 0.25). Onboarding hero app-icon: 88×88px,
radius 24px (ratio 0.27). Close enough to be optical scaling and likely intentional, but
not a literal shared constant — noted so it isn't "fixed" into a single hardcoded radius.

---

## 5. Elevation / shadow

### 5.1 Declared elevations (`elevations`)

| Token | Shadow |
|---|---|
| `e1 · card` | `0 1px 2px rgba(0,0,0,.4)` |
| `e2 · popover` | `0 4px 14px rgba(0,0,0,.5)` |
| `e3 · sheet/modal` | `0 16px 40px rgba(0,0,0,.6)` |

### 5.2 Shadow values used in screens but not among the 3 declared elevations (flag)

| Shadow | Where |
|---|---|
| `0 2px 0 rgba(0,0,0,.35)` | Every keyboard key (a "hard" bottom-edge shadow, not a soft blur — different visual language from e1–e3) |
| `inset 0 1px 0 rgba(255,255,255,.20–.24), 0 10px 24–26px -8px [brand-color]/.55–.6, 0 2px 6px rgba(0,0,0,.35)` | Every primary CTA button (green or Telegram-blue) — a distinct "raised, colored glow" treatment, not in the neutral e1–e3 set |
| `0 6px 16px rgba(62,155,84,.35)` | Emphasized "watch ad" button (insufficient-coins hint sheet) |
| `0 6px 18px rgba(0,0,0,.5)` | Invalid-word toast pill |
| `0 -16px 40px rgba(0,0,0,.6)` | Bottom sheet (upward shadow — e3's blur/spread values but a negative y-offset, i.e. not literally e3) |
| `0 8px 24px rgba(62,155,84,.35)` | Masthead logo tile glow |
| `0 8px 20px rgba(242,193,78,.4)` | Reward-granted coin badge glow |

**Recommendation:** formalize a 4th "CTA glow" elevation/decoration token and a "key
bevel" token — both recur on every screen that has a primary button or a keyboard, so
they're structural, not one-offs.

---

## 6. Component dimensions

| Component | Value |
|---|---|
| Board tile (main gameplay) | 56×56px, 6px grid gap (row+column), 28px letter |
| Board tile (solved-recap, mini) | 30×30px, 15px letter |
| Board tile (failed-state, compact 6-row board) | 42×42px, 21px letter |
| Board tile (onboarding / hint-sheet blurred backdrop) | 52×52px, 26px letter |
| Keyboard key height | 50px (fixed, all rows) |
| Keyboard row-to-row gap | 7px |
| Keyboard key-to-key gap | 5px |
| Keyboard letter key width | `flex: 1` (≈30px at 360px viewport per the design's own annotation) |
| Keyboard compound key width (Oʻ Gʻ Sh Ch Ng) | `flex: 1.35`, label font 15px |
| Keyboard ENTER / DEL(⌫) width | `flex: 1.7`, label font 15px |
| Keyboard total footer height | ≈178px including gaps (design's own annotation, validated to fit both 844pt and 640pt viewports) |
| Header icon button (settings/hint/back/close/share) | 34×34px, 17–20px icon |
| Coin/gem/streak chip (pill) | height ≈34px (6px vertical padding + 15/13px text), 20px radius |
| Primary CTA button height | 54px (52px inside modal dialogs, 56px on fail-state share button) |
| Secondary button height | 46–48px |
| Hint-sheet card button height | 42px |
| Bottom sheet top-corner radius | 28px |
| Bottom sheet drag handle | 40×4px, 2px radius |
| Phone mockup frame | 390×844px (design's stated target; "scales to 360×640" is a text note only — no 360×640 frame is actually drawn anywhere in the source, see Open Questions) |
| Ad/dialog modal preview canvas | 340×520px (not a device frame — a generic modal-preview container) |
| Ad/dialog modal card | 280px wide, 22px radius |

---

## 7. Iconography

Library: **Lucide** (open-source), loaded via `unpkg.com/lucide@latest`.

### 7.1 Declared icon set (25 icons, `icons` token)

`flame, coins, gem, settings, lightbulb, share-2, x, gift, play, lock, check, snowflake,
calendar-days, refresh-cw, bar-chart-3, tv, copy, chevron-right, arrow-right, sparkles,
info, volume-2, circle-help, clock, shopping-bag`

### 7.2 Icons used in actual screens but missing from the declared set (flag)

`send` (Telegram share button), `image` (Stories share button), `dumbbell` (practice CTA),
`chevron-left` (every back button), `eye` (reveal-letter hint), `eraser` (clear-letters
hint), `book-open` (dictionary hint), `plus` (empty freeze slot), `package` (starter pack),
`shield-check` (shop hero decoration) — **10 icons in active use, absent from the token
list.**

### 7.3 Icons declared but never used in any of the 22 screen states (flag)

`play, calendar-days, refresh-cw, bar-chart-3, volume-2, circle-help, arrow-right,
shopping-bag` — **8 icons.** Some plausibly map to unbuilt screens (`bar-chart-3` →
Stats? `calendar-days` → a streak calendar view? `shopping-bag` → Shop nav icon not shown
in any header?) — flagged rather than guessed at; see `screen_inventory.md` Open Questions.

Not flagged: `signal`, `wifi`, `battery-full` — these are OS status-bar chrome in the
mockup, not app iconography, and are correctly excluded from the token list.

---

## 8. Motion (`motion`, annotated in source — implement in Flutter, no code given)

| Name | Spec |
|---|---|
| Tile flip | 150ms per tile, 100ms stagger between tiles in a row, `rotateX` transform, color reveal at the 50% keyframe (tile edge-on) |
| Key press | scale to 0.95, 90ms ease-out, spring back |
| Invalid word | row shake, 500ms, ±8px, no color change |
| Win | confetti burst — design explicitly references a specific external asset: LottieFiles "confetti" (lottiefiles.com/free-animation/confetti) |
| Streak fire | flame icon pulse, scale 1 → 1.12, 1.6s ease-in-out, loops infinitely |
| Coin reward | coins animate to balance chip + count-up, 600ms |

### 8.1 Open question — shake keyframe duration mismatch

The CSS `@keyframes shake` block in the source runs 600ms
(`animation:shake .6s ease-in-out infinite`, applied to the invalid-word frame for
*preview looping purposes*), but the motion token table and the invalid-word screen's own
annotation both state **500ms, single-shot**. Treat 500ms/one-shot as the real spec — the
`.6s infinite` only exists so the static mockup demonstrates the shake continuously for
reviewers. Flagging so nobody ports the literal 600ms/infinite values into Flutter.

---

## OPEN QUESTIONS (typography, color, spacing, radius, elevation, icons)

1. **Font-weight 800 does not exist in Space Grotesk's Google Fonts cut** (§2.2) — needs a
   product decision before any text style is implemented. This is the single highest-impact
   open question in this document; it affects nearly every heading and numeral in the app.
2. Declared 7-role type scale vs. ~30 additional undeclared sizes in actual screens (§2.3)
   — needs consolidation into a real `TextTheme` before implementation; not resolved here.
3. 10 untokenized colors recur across multiple screens (§1.4) — candidates for formal
   tokens (`#8493B0` and `#5FBE73` especially, each reused 4+ times).
4. Canvas background `#0A0C10` vs. app background `#0B1220` (§1.5) — make sure the wrong
   one doesn't get ported as `Scaffold.backgroundColor`.
5. Keyboard key radius (7px, hardcoded in `Keyboard.dc.html`) conflicts with the declared
   `key` token (8px) (§4.2).
6. Card radius is split ~60/40 between 16px and 14px across visually-equivalent card
   components (§4.2) — looks unintentional, needs a single decision.
7. No 4th "CTA glow" / "key bevel" shadow token exists despite both appearing on every
   screen with a button or keyboard (§5.2).
8. "Scales to 360×640" is asserted in the masthead subtitle but no 360×640 frame is
   actually designed anywhere in the source — small-screen behavior is unverified.
9. 8 declared icons are never used anywhere in the 22 designed screens, and 10 icons in
   active use were never added to the declared set (§7.2–7.3).
