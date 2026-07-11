# UX Audit — So'z Jangi (pre-submission polish)

**Method:** walked every screen and flow as a first-time Uzbek user who has never
seen Wordle. Each finding is rated:

- **P0** — confusing or broken-feeling; a new user cannot proceed or misreads the state.
- **P1** — flat / unpolished; works but reads as unfinished.
- **P2** — nice-to-have refinement.

**Scope note:** game logic, the token/economy system, and navigation IA are out of
scope — this is presentation, feedback, and comprehension only. Findings that the
owner already mandated (Phase B of the work order) are tagged **[MANDATED]** and are
not re-counted in the discretionary totals.

**Baseline that is already good** (so the audit isn't misread as "nothing works"):
tile flip reveal, invalid-word shake + toast, streak-flame pulse (stops at 0),
keyboard key press-scale + haptic, and a 600 ms coin count-up on the balance chip are
already implemented to spec. The gaps below are what remains.

---

## Totals

| Severity | Count (incl. mandated) | Discretionary only |
|---|---|---|
| **P0** | 8 | 3 |
| **P1** | 17 | 11 |
| **P2** | 9 | 8 |

Mandated items map to: DB-1, DB-2, DB-3, DB-4, DB-5, DB-6, DB-7, DB-8, DB-9, DB-10,
PG-1 (see per-screen sections).

---

## 1. Onboarding (`/onboarding`)

| ID | Finding | Cat | Sev |
|---|---|---|---|
| OB-1 | Step 3 ("try it") gives **no hint that any keypress ends onboarding** — the coach-mark says only "Harfni tanlang" ("pick a letter"). A first-timer taps a letter expecting to type into the demo board, but instead is thrown straight to the live daily board mid-thought. Advance trigger is undiscoverable and feels like a misfire. | Comprehension | **P1** |
| OB-2 | Steps snap between each other with an instant `setState` swap — no slide/fade transition. The dot indicator animates (good) but the content it describes teleports. | Motion | P1 |
| OB-3 | If the user taps **Skip** on step 1/2 they never see the color legend at all, then land on a board whose colors are unexplained. (Root cause for DB-3's auto-open rule.) | Comprehension | **P0** |
| OB-4 | The demo board on step 3 is a **static** pre-filled guess — it never animates a flip, so the one moment we could teach "letters flip to reveal a color" is wasted. | Missing motion | P2 |
| OB-5 | Welcome step vertically centers content in `Expanded` but the skip-bar reserves a fixed 44 px even on step 3 where there's no skip button, leaving a small dead band at the top on the interactive step. | Dead layout | P2 |

---

## 2. Daily Board — all 5 states (`/daily`)

### 2a. Fresh (empty board)

| ID | Finding | Cat | Sev |
|---|---|---|---|
| DB-1 | **ENTER key label wraps to two lines** at ≤360 px, breaking the keyboard's bottom row visually. **[MANDATED]** → replace with ↵ icon. | Dead layout | **P0** |
| DB-9 | Empty board gives a first-timer **no prompt to start typing** — six empty rows and a keyboard, no "type a 5-letter word" affordance. The only text ("Kunlik soʻzni toping") sits above the board as a thin caption and reads as a page subtitle, not an instruction. **[MANDATED]** → ghost placeholder. | Comprehension | **P0** |
| DB-2 | **Large dead vertical band**: the board is `Center`ed in an `Expanded`, so on a tall phone it floats with big gaps above (below the lone caption) and below (above the Mashq pill). Nothing anchors it; the screen reads as unfinished. Also there is **no puzzle context** (which puzzle #, what date). **[MANDATED]** → context header + rebalance. | Dead layout | **P0** |
| DB-3 | **No way to re-read the rules.** Once onboarding is dismissed (or skipped) the color meaning is gone forever. **[MANDATED]** → circle-help button + Qoidalar sheet + auto-open when onboarding skipped. | Comprehension | **P0** |
| DB-10 | Header packs 3 chips + 3–4 icon buttons in one row; the chips are in a horizontal scroller so at 360 px they can **silently clip/scroll** rather than fitting, and the hint lightbulb crowds the settings gear. **[MANDATED]** → density pass + verify 360 px. | Dead layout | **P1** |
| DB-11 | The Mashq pill is the **only** entry to Practice and looks like a decorative label, not a button — no chevron, no elevation, easy to miss. | Comprehension | P1 |
| DB-12 | Compound keys (Oʻ Gʻ Sh Ch Ng) carry an amber accent border but there is **no legend** anywhere telling a new user these are single keys / "the extra Uzbek letters." A first-timer may hunt for C/W (correctly absent) and not realize Sh/Ch/Ng are one tap. | Comprehension | P1 |

### 2b. Mid-game (typing / rows filled)

| ID | Finding | Cat | Sev |
|---|---|---|---|
| DB-4 | **No active-row / active-cell feedback.** Every empty tile looks identical; a new user cannot tell which row is live or where the next letter will land. **[MANDATED]** → active-row highlight + pulsing next-empty tile. | Missing feedback | **P0** |
| DB-5 | **Typed letters snap in with zero animation** — a tile goes from empty to filled instantly. No "pop", no scale, no confirmation the tap registered beyond the letter appearing. Backspace likewise snaps. **[MANDATED]** → type pop + backspace fade + per-key haptic tick. | Missing motion/feedback | **P1** |
| DB-13 | Submitting a too-short word only shakes the row (shared with the invalid-word path) but shows **no toast** — the user gets the same shake for "not enough letters" and "not a word" with no disambiguation. | Missing feedback | P1 |

### 2c. Invalid word / shake

| ID | Finding | Cat | Sev |
|---|---|---|---|
| DB-14 | Toast is well done, but it appears at a **fixed `topOffset: 150`** regardless of where the board actually sits — after the DB-2 rebalance this can overlap the header or the top board row. Should anchor relative to the board. | Dead layout | P1 |
| DB-15 | Invalid submit fires a shake but **no haptic** (a light error buzz is the genre norm and reinforces "rejected"). | Missing feedback | P2 |

### 2d. Solved + countdown

| ID | Finding | Cat | Sev |
|---|---|---|---|
| DB-6 | On a win the last row flips and then the layout **hard-cuts** to the recap card — no celebratory beat. Design spec calls for a per-tile bounce + confetti Lottie; **the Lottie was never added** (no `lottie` dep, no asset). No win haptic. **[MANDATED]** → bounce + confetti + medium haptic (loss = soft double-tick). | Missing motion | **P1** |
| DB-8 | The countdown ticks but the changing digit **snaps** with no life; and critically at **00:00:00 the board does not roll over** — the user must kill & relaunch the app to get the new day's puzzle. **[MANDATED]** → digit opacity pulse + auto-refresh at rollover. | Missing feedback / broken | **P1** |
| DB-7 | The "+40 tanga ishlandi" line is static text; the coins were credited to the header chip but on this recap screen the credit isn't visually tied to the balance (chip is scrolled away / behind). Any silent credit path reads as "did I actually get coins?" **[MANDATED]** → count-up + chip glow on every credit. | Missing feedback | P1 |
| DB-16 | Recap is `SingleChildScrollView`-centered but on a short phone the giant share CTA can push the coins-earned line below the fold with no scroll cue. | Dead layout | P2 |

### 2e. Failed + answer

| ID | Finding | Cat | Sev |
|---|---|---|---|
| DB-17 | The failed state reveals the answer with no transition — the compact 42 px board and answer card just appear. A gentle fade-in on the answer card would soften the "you lost" moment. | Missing motion | P1 |
| DB-18 | Loss has **no haptic** and no distinct sound cue. **[MANDATED via DB-6]** → soft double-tick. | Missing feedback | P2 |

---

## 3. Practice Hub (`/practice`)

| ID | Finding | Cat | Sev |
|---|---|---|---|
| PH-1 | Tier cards are tappable `AppCard`s but give **no press feedback beyond the default ink** and no chevron — they read like stat rows, not "tap to play." | Missing feedback | P1 |
| PH-2 | "Bugungi sessiya" stats show 0/0%/0 on first visit with no empty-state copy — reads as broken rather than "play a round to fill this." | Comprehension | P2 |

## 3b. Practice gameplay (`/practice/play`)

| ID | Finding | Cat | Sev |
|---|---|---|---|
| PG-1 | Header shows only a tier badge + coin chip — **no round context** (which attempt of the session, no "keep the board anchored"), and the board floats in the same `Expanded`-`Center` dead-space pattern as the daily board. **[MANDATED]** → tier badge + round-counter context block + same vertical rebalance. | Dead layout | **P1** |
| PG-2 | Inherits DB-4 (no active-row feedback) and DB-5 (no type pop) since it reuses the same board/keyboard. Fixed transitively by those. | Missing feedback | P1 |
| PG-3 | Solved/failed overlay slaps a full-screen scrim + card over the board with **no fade/scale-in** — it pops instantly. | Missing motion | P1 |
| PG-4 | On win, the practice reward credits coins but the overlay's "+N" is static text with no count-up and the coin chip is covered by the scrim — same silent-credit smell as DB-7. | Missing feedback | P2 |

---

## 4. Hint bottom sheet

| ID | Finding | Cat | Sev |
|---|---|---|---|
| HS-1 | Sheet is functionally complete and states are correct. Minor: the "Lugʻat" reveal replaces the card description in place with **no transition** — the definition just appears where the tagline was. | Missing motion | P2 |
| HS-2 | When a coin purchase succeeds the sheet closes but there's **no coin-spend feedback** on the way out (balance just drops). A brief debit flash on the chip would close the loop. | Missing feedback | P2 |

---

## 5. Result / Share (`/daily/share`)

| ID | Finding | Cat | Sev |
|---|---|---|---|
| SH-1 | "Nusxa" (copy) confirms via a default Material `SnackBar` — visually off-theme (light, bottom, squared) versus the app's custom dark toast used elsewhere. | Missing feedback | P1 |
| SH-2 | The `CROSS-PROMO SLOT` dashed placeholder ships visible to end users — **must be hidden or filled before submission**; a store reviewer will see literal "CROSS-PROMO SLOT" text. | Comprehension | **P1** |
| SH-3 | Coin-breakdown card appears with no reveal; a quick staggered row fade would make the "how you earned it" moment land. | Missing motion | P2 |

---

## 6. Stats (`/stats`)

| ID | Finding | Cat | Sev |
|---|---|---|---|
| ST-1 | Histogram bars render at their final width instantly — **no grow-in animation**, so the "distribution" reads as a static table rather than data. | Missing motion | P1 |
| ST-2 | On a brand-new profile every stat is 0 and the histogram is six min-width stubs with "0" — no empty state; looks broken to a first-timer who opens stats before playing. | Comprehension | P1 |

---

## 7. Streak & Freeze (`/streak`)

| ID | Finding | Cat | Sev |
|---|---|---|---|
| SK-1 | 30-day heat row is an unlabeled `Wrap` of colored squares with **no legend** (what does green vs blue vs red mean?) and no day/date tooltips. A new user cannot decode it. | Comprehension | P1 |
| SK-2 | Repair offer dialog auto-opens on entry via `addPostFrameCallback` with no transition and can feel like an ambush; also fine functionally. | Missing motion | P2 |

---

## 8. Shop (`/shop`)

| ID | Finding | Cat | Sev |
|---|---|---|---|
| SP-1 | Buying a skin / gems gives feedback only through the balance number changing + a `setState` — no purchase confirmation animation, and skin **apply** doesn't preview-flash the board. | Missing feedback | P1 |
| SP-2 | Starter-pack "was/now" price is rendered as two prices separated by spaces (`$9.99   $3.99`) with **no strikethrough** on the old price — the discount is not visually legible. | Comprehension | P1 |
| SP-3 | Off-theme Material `SnackBar` again for restore feedback (see SH-1). | Missing feedback | P2 |

---

## 9. Settings (`/settings`)

| ID | Finding | Cat | Sev |
|---|---|---|---|
| SE-1 | Disabled language rows say "Tez orada" (coming soon) which is clear (good). No findings above P2. Minor: toggles use stock Material `Switch` sizing that sits slightly oversized against the dense rows. | Dead layout | P2 |

---

## 10. Dialogs (rewarded offer, reward granted, chest, freeze-consumed, streak repair, attribution)

| ID | Finding | Cat | Sev |
|---|---|---|---|
| DG-1 | Reward-granted / chest-opened dialogs show a coin badge with a static glow — the amount just appears; **no count-up or coin-fly to the header**, so the reward doesn't feel "received." (Ties into DB-7 credit feedback.) | Missing motion | P1 |
| DG-2 | All dialogs use Flutter's default `showDialog` scale/fade (fine) but the **chest closed→opened transition is an instant `setState` swap** within the same card — the gift "opening" is the one place a small motion beat is expected and it's absent. | Missing motion | P1 |
| DG-3 | Rewarded-ad offer's 2-second close-lock is implemented (good) but gives **no countdown affordance** — the X is just greyed; a user may think it's broken. A subtle progress/tick would explain the wait. | Comprehension | P2 |

---

## Prioritized discretionary work (what Phase C will and won't do)

**P0 discretionary (all will be fixed):**
- OB-3 — colors unexplained after skip → resolved by DB-3's auto-open-on-skip rule.
- SH-2 — cross-promo placeholder visible to users → hide it (store-blocking).
- DB-13/PG active-row applies transitively.

**P1 discretionary — fix where local & low-risk:**
- SH-1 / SP-3 — replace off-theme `SnackBar` copy-confirm with the app's dark toast.
- SP-2 — strikethrough the starter-pack old price.
- DB-13 — distinct toast for "too short" vs "not a word".
- PH-1 — add chevron affordance to tier cards / Mashq pill (DB-11).

**Deliberately deferred (documented, not fixed — out of scope or non-local):**
- OB-1, OB-2, OB-4, OB-5 (onboarding flow redesign — touches the flow, higher risk).
- ST-1, ST-2 (stats empty state + bar animation — new empty-state design).
- SK-1 (heat-map legend — new component).
- SP-1, HS-1, HS-2, DG-1, DG-2, DG-3, PG-3, PG-4, SH-3 (polish motions on secondary
  surfaces; nice-to-have, not submission-blocking).
- DB-16, DB-12 (compound-key legend is partially served by the new Qoidalar sheet).
