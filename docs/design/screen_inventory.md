# Screen Inventory — So'z Jangi

Source: same Claude Design project as `design_tokens.md`, all `data-screen-group` sections
of `Soz Jangi.dc.html`. 22 distinct screen/dialog states are designed across 10 named
sections, plus one component-reference frame (the keyboard spec, not a user-facing screen).

Route names below are proposals following this repo's GoRouter / feature-first convention
— they are not specified in the design itself (the design contains no navigation graph,
see Open Questions) and should be confirmed against actual app IA before wiring.

---

## 0. TOP-LINE FINDING — no navigation shell is designed

Before the per-screen inventory: **no screen in this design shows a tab bar, drawer,
bottom nav, or any other persistent navigation affordance.** Every screen is designed as
an isolated deep-link target. Concretely:

- The Daily Board header (all 5 states) only ever shows a **hint** button and a
  **settings** button — no icon links to Shop, Stats, Streak-detail, or Practice.
- Practice Hub's header only has a back-chevron and a coin chip — no forward links either.
- Shop, Stats, and Streak-detail screens all use a back-chevron header, implying they're
  pushed from somewhere, but nothing in the design shows the "somewhere."
- The streak/flame chip on the Daily Board is the only plausible tap-target for reaching
  Streak-detail (common pattern in word games), but this is inferred, not annotated.

**This is the single biggest gap for implementation planning** — flagged once here and
referenced from each screen below rather than repeated per-screen. See Open Questions §1
at the end of this document.

---

## 1. Daily Board (`Kunlik oʻyin`) — proposed route `/daily`

Home screen. 5×6 letter grid, top bar (streak chip · coin chip · gem chip · hint button ·
settings button), keyboard footer. One route, five visual states driven by game state —
**not** five separate routes.

Consumes: `--bg` scaffold, chip surfaces (`--surface-2`/`--border`), full tile state set
(§1.2 of tokens doc), full keyboard state set, Micro/Tile/Caption type roles, Board and
Keyboard components (see `component_spec.md`).

| State | What's different | Notes |
|---|---|---|
| **a. Fresh** | Empty 6×5 board, keyboard all-`default` | Header shows streak/coin/gem/hint/settings, all populated (e.g. streak "12") |
| **b. Mid-game** | Mixed tile states across 2 completed rows + 1 in-progress row; keyboard reflects guessed letters | Reference frame used elsewhere as the canonical "populated" board (also reused, blurred, as the backdrop for the Hint sheet) |
| **c. Invalid word / shake** | Same board as (b) but current row is entirely `typing` (no reveal), animated shake; white toast pill "Soʻz lugʻatda yoʻq" ("word not in dictionary") floats above the board | Toast is the only element that changes vs. (b); tiles never take absent/present/correct color during a shake |
| **d. Solved + countdown** | Board replaced by a compact recap layout: sparkles icon, "Ajoyib!" headline, attempt-count subtitle, mini solved-board recap (30px tiles), countdown-to-next-word box, giant Telegram-blue share CTA, "+40 tanga ishlandi" coin-earned line | Header drops the hint button (no longer needed) and bumps streak to 13, coins to 1 280 |
| **e. Failed + answer** | Compact 6-row board (42px tiles, all rows filled/revealed), answer card (label "Topilmadi — bugungi javob", the answer word, a one-line dictionary definition), countdown box + smaller share button side-by-side | Header shows streak reset to 0 (flame dimmed to `#4A5B80`), hint button removed |

---

## 2. Result / Share (`Natija`) — proposed route `/daily/share`

Presented as a full-screen modal pushed from state 1d/1e's share button (has its own `X`
close button in a centered nav bar, not a back-chevron — treat as a modal route, not a
stack push, in GoRouter terms).

Consumes: `--surface` card, emoji-grid glyphs (not app-rendered tiles — literal
🟩🟨⬛ characters), `--telegram` CTA, coin-breakdown list, dashed cross-promo placeholder.

| State | Notes |
|---|---|
| **a. Share screen** (only state designed) | Telegram-style emoji-grid preview card ("Soʻz Jangi #142 · 4/6 · 🔥12" + emoji rows + "soz-jangi.uz" footer), primary Telegram CTA, secondary "Stories" / "Nusxa" (copy) buttons, coin-breakdown card (base + speed-bonus + streak-bonus = total), optional "Mashq qilish" outline CTA, and an explicitly-labeled `CROSS-PROMO SLOT` dashed placeholder (content undefined — flag) |

---

## 3. Practice Hub (`Mashq`) — proposed route `/practice`

Consumes: `--surface` tier buttons with per-tier accent color/icon, session-stat tiles,
info callout (rgba-tinted `--gem`).

| State | Notes |
|---|---|
| **a. Practice hub** (only state designed) | 3 difficulty tier buttons (Oson/+10, Oʻrta/+20, Qiyin/+35 — each with its own accent color and Lucide icon), "Bugungi sessiya" stat row (solved / accuracy% / coins), and an info callout annotating that free-tier users see a full-screen interstitial ad every 3rd solve |

**Missing:** the actual practice gameplay screen (board + keyboard for a practice puzzle)
and any practice-solved/practice-failed result state are **not designed** — only the tier
picker exists. See Open Questions §2.

---

## 4. Hint bottom sheet (`Yordam`) — modal, not a route

Presented as a `showModalBottomSheet`-style overlay from the Daily Board's hint button,
over a blurred/dimmed (`opacity:.28; filter:blur(1px)`, `rgba(5,8,14,.55)` scrim) board
backdrop.

Consumes: `sheet` radius (28px top corners), drag handle, 3 hint-action cards, coin-price
buttons, ad-price buttons, `--danger`-tinted subtitle for the insufficient variant.

| State | What's different |
|---|---|
| **a. Default (enough coins)** | All 3 hint cards active: "Harf ochish" (150 coins / watch-ad), "Harflarni tozalash" (100 coins / watch-ad), "Lugʻat" (75 coins only, no ad option) |
| **b. Insufficient coins** | Coin chip turns danger-tinted (40 coins shown, red border), subtitle switches to danger copy, the coin-price button on each card becomes disabled (`#131C2C`/`#22304C`/`#5E6D8C`, `cursor:not-allowed`) while the watch-ad button becomes the emphasized green primary action (`flex:1.4` vs `1`), and the coinless-only "Lugʻat" card becomes fully locked (`lock` icon, 60% opacity, no ad fallback since it has none) |

**Open question:** does this same sheet apply to a Practice puzzle, or is it Daily-only?
Not stated — practice gameplay isn't designed at all (see §3).

---

## 5. Stats (`Statistika`) — proposed route `/stats`

Consumes: 4-up stat grid, histogram bars (current-attempt row highlighted in `--correct`,
others in `--absent`), footer brand lockup.

| State | Notes |
|---|---|
| **a. Stats screen** (only state designed) | Played/Win%/Current-streak/Best-streak 2×2 grid, "Topish taqsimoti" (guess distribution) 6-row histogram with the day's actual attempt row (row 4 in the sample data) highlighted, a green success callout ("Bugun 4-urinishda topdingiz — eng koʻp uchraydigan natija!"), footer brand mark. Designed to fit one screen without scrolling ("shareable, fits one screen" per section subtitle) |

---

## 6. Shop (`Doʻkon`) — proposed route `/shop`

Two design frames (6a, 6b) share one header pattern (back-chevron / "Doʻkon" / gem chip)
and read as continuous content — **proposed as a single scrollable route**, not two
routes or a tab switcher, since nothing in the design shows a tab control between them.
Flagged as an assumption in Open Questions §3.

Consumes: hero-card gradient treatment, 2×2 gems grid, hint-bundle card, starter-pack
banner, tile-skin preview cards, restore-purchases link.

| Frame | Content |
|---|---|
| **a. Hero · gems · hints** | "ENG YAXSHI TAKLIF" (best offer) badged hero card for the ad-free + daily-hint bundle ($2.99), 4-SKU gems ladder (100/$0.99, 550/$4.99 +50 bonus, 1200/$9.99 +150 bonus, 2500/$19.99 "Eng foydali"/best), 10× hint-pack bundle ($1.99) |
| **b. Tile skins · starter pack** | Time-limited Starter Pack banner (500 gems + 20 hints, was $9.99 now $3.99, countdown timer), 4-item tile-skin gallery (Standart/active, Milliy naqsh/240💎, Neon/180💎, Oltin/320💎), "Xaridlarni tiklash" (restore purchases) link |

---

## 7. Streak & Freeze (`Streak & Muzlatgich`) — proposed route `/streak`

| State | Notes |
|---|---|
| **a. Streak detail (healthy)** | Big flame + streak-count hero card ("13 · shaxsiy rekord 57"), 30-day heat-map grid (played/missed/frozen-day icon states), 2-slot freeze inventory (1 ready, 1 empty/purchasable), "Muzlatgich olish" (get a freeze) CTA card with coin-price and free/watch-ad options |
| **b. Streak broken · repair offer** | Modal dialog over a dimmed/blurred giant flame icon: "Streak uzildi" (streak broken) headline, "57 kunlik streakingiz xavf ostida" body copy, a repair offer card (48-hour countdown, 50-gem price), primary "Streakni tiklash" (repair) CTA, tertiary "Yoʻq, rahmat" (no thanks) dismiss |

**Missing:** no "streak auto-saved by freeze" confirmation state is designed — only the
inventory view and the fully-broken repair-offer view exist. See Open Questions §4.

---

## 8. Onboarding — proposed route `/onboarding` (internal step state, not per-step routes)

3-step flow, skip button on steps 1–2, dot-progress indicator (3 dots, active dot widens
to 22px per the design).

| Step | Content |
|---|---|
| **a. Welcome** | App icon, "Soʻz Jangi" title, "Har kuni yangi oʻzbekcha soʻz. 5 harf, 6 urinish." tagline, "Boshlash" (start) CTA |
| **b. Color rules** | 3-row legend explaining tile colors (correct/present/absent) using real 56px tile swatches with sample letters A/L/K, "Davom etish" (continue) CTA |
| **c. Try it (coach-mark)** | "Endi oʻzingiz urinib koʻring" heading, live board with a partial demo game already in progress, a green coach-mark tooltip ("Harfni tanlang" / "pick a letter") pointing at the keyboard | No explicit CTA shown — presumably advances on first keyboard tap |

---

## 9. Ad & dialog states — modals, not routes

| State | Notes |
|---|---|
| **a. Rewarded-ad offer** | Modal dialog: coin icon badge, "Bepul 150 tanga" (free 150 coins) headline, body copy, green "Reklama koʻring va oling" (watch ad and get it) CTA, note that the close button only activates after a 2-second delay (anti-accidental-dismiss pattern — must be implemented, not just visual) |
| **b. Reward granted** | Modal dialog: animated coin badge with sparkle accents, "+150" amount, "Ajoyib!" confirmation, "Tangalar hisobingizga qoʻshildi" body, single dismiss CTA |
| **c. Daily chest — closed** | Card: gift icon, "Kunlik sandiq" (daily chest) title, "Bugun tayyor!" (ready today) subtitle, "Ochish" (open) CTA |
| **c. Daily chest — opened** | Card: gift icon (green tint) + sparkle, "+80 tanga" title, "Ochildi" (opened) subtitle, "Oldim" (claimed) button — reads as a post-claim confirmation state of the same card |
| **c. Daily chest — ×2 offer** | Card: gradient "green hero" treatment, "×2" badge, "Ikki barobar" (double it) title, "160 tanga oling" subtitle, green "×2" watch-ad CTA |

**Open question:** all three chest states are shown as isolated card mockups, never
embedded within an actual screen layout (Daily Board, a popup-on-launch, a dedicated tab
— none specified). Where and when this card actually appears in the app is undefined. See
Open Questions §5.

---

## Component-reference frame (not a screen)

**"Uzbek keyboard · 29 keys"** — a standalone component-spec frame showing the live
keyboard with all 4 key states legend-labeled, plus written row/flex/radius annotations.
This is documentation, not a user-facing screen; fully covered in `component_spec.md`.

---

## OPEN QUESTIONS

1. **No navigation shell is designed anywhere** (see §0 above) — Shop, Stats,
   Streak-detail, and Practice have no discoverable entry point from the Daily Board. This
   blocks route-graph / bottom-nav implementation until resolved with design.
2. **Practice gameplay is entirely undesigned.** The Practice Hub only shows a tier
   picker; there is no practice board+keyboard screen, no practice-solved state, and no
   practice-failed state. The hub's own info-callout references a full-screen interstitial
   ad flow that also has no visual design.
3. **Shop's two frames (6a/6b) are assumed to be one scrollable screen**, not two routes
   or a tab pair — nothing in the source confirms this; there's no tab control shown
   between "hero/gems/hints" and "skins/starter pack."
4. **No "streak saved by freeze" confirmation exists** — only the freeze-inventory view
   and the streak-already-broken repair-offer view are designed. What the user sees at the
   moment a freeze auto-consumes is unspecified.
5. **Daily chest placement is undefined** — three card states are designed in isolation,
   with no parent screen, modal trigger, or navigation context shown.
6. No settings screen exists despite a settings button appearing in every Daily Board
   header state.
7. No splash/loading screen, no offline/error states, and no push-notification permission
   prompt are designed — all plausible for a daily word game with server-fetched puzzles
   and streak reminders, but out of scope of this design as delivered.
8. Onboarding step 3's coach-mark has no visible "next" affordance — advance trigger
   (tap-anywhere vs. tap-the-highlighted-key vs. timer) is not specified.
