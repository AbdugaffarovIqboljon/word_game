# Design Decisions — So'z Jangi

This document **resolves every open question** raised in `design_tokens.md`,
`component_spec.md`, and `screen_inventory.md`. Where it conflicts with those
specs, **this document wins**. It is the single implementation authority for
tokens, navigation, and disputed values.

---

## 1. Typography

- **Font-weight `800` → `700` everywhere.** Space Grotesk's Google Fonts cut
  tops out at 700; every "800" in the specs renders as 700. All display/title/
  heading/numeral roles use `FontWeight.w700`. (Resolves tokens §2.2 / OQ1.)
- **TextTheme collapsed to 10 roles** (resolves tokens §2.3 / OQ2). Space Grotesk
  unless noted:

  | Role | Size / Weight | Font |
  |---|---|---|
  | `display` | 44 / 700 | Space Grotesk |
  | `headline` | 32 / 700 | Space Grotesk |
  | `title` | 26 / 700 | Space Grotesk |
  | `sectionTitle` | 20 / 700 | Space Grotesk |
  | `navTitle` | 17 / 700 | Space Grotesk |
  | `bodyStrong` | 15 / 700 | Space Grotesk |
  | `body` | 15 / 500 | **Manrope** |
  | `caption` | 13 / 500 | **Manrope** |
  | `micro` | 11 / 600 | Space Grotesk (uppercase, +0.14em tracking) |
  | `tile` | 28 / 700 | Space Grotesk |

  Every one-off size in the specs snaps to the nearest role. Context-specific
  tile sizes (56/52/42/30) are handled by the Tile widget's size parameter, not
  extra text roles — the `tile` role defines weight/family; size is passed in.

## 2. Navigation (resolves screen_inventory §0 / OQ1)

- **NO bottom navigation bar, NO drawer, NO tab bar.** The Daily Board header
  chips ARE the navigation:
  - **Streak / flame chip** → `/streak`
  - **Coin chip** and **Gem chip** → `/shop`
  - **`bar-chart-3` header icon** (added to the Daily header) → `/stats`
  - **Compact "Mashq" pill** rendered below the board → `/practice`
- Settings icon → `/settings`. Hint icon → opens the hint bottom sheet.
- Gift icon-button (daily chest) lives in the Daily header with a notification
  dot when the chest is unclaimed.

## 3. Radius (resolves tokens §4.2 + component_spec OQ5)

- **Keyboard key radius = 7px** (live component value, not the 8px legend).
- **ALL card radii = 16px.** The 14px/16px "card" split is collapsed to 16 for
  every card-like surface (stat tiles, breakdown, hint-bundle, skin cards,
  freeze slots, etc.).
- `radiusDialog = 22px` (new named token). Sheet top corners stay 28px.
- Tile 6, chip 12, CTA button 14, icon-button 10, counter pill 20.

## 4. New color tokens (resolves tokens §1.4 + component_spec OQ2)

| Token | Hex | Replaces / formalizes |
|---|---|---|
| `surfaceModal` | `#0E1420` | dialog + bottom-sheet + share-card surface |
| `textSub` | `#8493B0` | the most-reused untokenized subtitle color |
| `successBright` | `#5FBE73` | lighter green for outline-button text, checkmarks |
| `muted` | `#4A5B80` | ENTER/DEL key fill, disabled chevron, dimmed flame |
| `onGold` | `#3A2A00` | text/icon on gold surfaces |

- **`#0A0C10` (canvas background) must NEVER appear in app code.** It framed the
  spec document only. Scaffold background is `bg = #0B1220`. (Resolves tokens §1.5.)

## 5. Shadows (resolves tokens §5.2 / OQ7)

- **`keyBevel`** — named constant: `0 2px 0 rgba(0,0,0,.35)` on every key.
- **`ctaGlow(brand)`** — named constant (function of brand color): the raised
  colored-glow recipe under every primary CTA. Flutter has no `inset` shadow;
  the inset top-highlight is approximated with a subtle top gradient overlay,
  the colored glow + dark drop are real `BoxShadow`s.

## 6. Motion (resolves tokens §8.1 / component_spec)

- **Shake = 500ms, single-shot**, ±8px, keyframe curve from the source
  (`10/90→-2, 20/80→4, 30/50/70→-8, 40/60→8`). The 600ms/infinite CSS is a
  preview artifact and is NOT ported.
- Tile flip = 150ms/tile, 100ms stagger, color swap at the 50% keyframe.
- **Fire-pulse animation STOPS when streak == 0** (resolves component_spec OQ3).
  The flame also dims to `muted` at zero.

## 7. Keyboard key-state priority (resolves component_spec OQ1)

- Aggregated best-known state wins: **`correct` > `present` > `absent`**. A key
  never downgrades once it reaches `correct`.

## 8. Screen-scope rulings (resolves screen_inventory OQs 2–8)

- **Shop is ONE scrollable route** (`/shop`), frames 6a+6b concatenated. (OQ3.)
- **Practice gameplay (Track A):** reuse the Daily Board layout for the practice
  board+keyboard. Practice header = back-chevron · tier badge · coin chip · hint
  button. Solved/failed states render as an overlay card above the board with
  "again / next tier / back" actions and the tier's coin reward. (OQ2.)
- **Streak freeze auto-save (OQ4):** on launch, if a freeze was consumed to save
  the streak across a missed day, show a "freeze consumed" dialog. Inventory =
  2 slots.
- **Daily chest (OQ5):** lives in the Daily header (gift icon-button + unclaimed
  dot). Tapping opens the chest card states.
- **Settings screen (OQ6 / Track A):** language rows (uz-Latn active; ru & uz-Cyrl
  present but disabled-for-v1), sound / haptics / notifications toggles wired to
  real services, remove-ads row → `/shop`, restore row, version footer.
- Onboarding step 3 advances on the **first keyboard key tap** (OQ8). Onboarding
  is shown once (persisted flag).

## 9. Config & gateways

- Every economy/game constant lives in `core/config/game_config.dart` with
  keyed getters, structured for a future RemoteConfig override (plain defaults now).
- `RewardGateway` (rewarded ads) and `PurchaseGateway` (IAP) are abstract
  interfaces; v1 ships debug fakes that always succeed. Dictionary is an
  interface with an in-memory fake seeded with a small word list.

## 10. Compound-key accent border removed (supersedes component_spec §a)

- The amber accent border on `default`-state compound keys (Oʻ/Gʻ/Sh/Ch/Ng) is
  **removed**. Amber (`#C2952B`) is reserved **exclusively** for the `present`
  game state; using it as decoration made untouched keys read as "letter is in
  the word".
- Compound keys render identically to regular letter keys in every state
  (`default` = `#3A4A6B` fill, no border). They are distinguished by their
  two-character labels alone.
