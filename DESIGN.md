# SpecSage — Design Document

SpecSage is an all-in-one World of Warcraft addon for Retail (Midnight,
Interface 120100). It combines:

1. **The Codex** — a browsable guide window for every class and spec: overview,
   stat priority, rotation priorities, cooldowns, consumables/enchants, tips.
2. **Talent Loadout Vault** — save, label, import and export talent loadout
   strings per spec, organised by content type (Raid / Mythic+ / Delves / PvP).
3. **Personal Notes** — free-text notes per spec, saved between sessions.
4. **Stat Overlay** — a movable live overlay with character stats, combat
   metrics (DPS/HPS/damage taken), and proc/cooldown tracking (ported from the
   StatOverlay addon by the same author).

What makes it different from guide-scraper addons (e.g. Class Codex):

- **No scraped data.** Guide content ships as plain, human-editable Lua data
  files with a registration API, so anyone can write or amend a guide pack —
  including in a separate addon that registers into SpecSage.
- **Live stats inline.** The stat-priority page shows *your* current value next
  to each stat in the priority, so the guide and your character sheet are one
  screen.
- **It's also a tracker.** The overlay (stats, DPS/HPS, procs) is part of the
  same addon and the same options panel.

## Repository layout

```
WOW-AIO/
  README.md
  DESIGN.md
  .luacheckrc
  SpecSage/                 <- the addon folder users install
    SpecSage.toc
    Bindings.xml
    Core/Init.lua           namespace, module registry, event bus, helpers
    Core/Config.lua         saved-variable defaults + accessors
    Core/Options.lua        Settings API panel
    Core/Commands.lua       /sage slash commands
    UI/Overlay.lua          overlay frame + row layout engine
    UI/Tooltips.lua         hover + pinnable tooltips for overlay rows
    UI/Codex.lua            the codex window (class/spec browser + tabs)
    Modules/Stats.lua       character stats -> overlay rows + live stat lookup
    Modules/Combat.lua      combat log metrics
    Modules/Procs.lua       proc/cooldown tracking
    Modules/Loadouts.lua    talent loadout vault (save/import/export)
    Modules/Notes.lua       per-spec personal notes
    Data/API.lua            guide-pack registration API (ns.GuideStore)
    Data/Guides_Warrior.lua ... one file per class (13 files)
  tests/
    wow_mock.lua            strict WoW API mock (Lua 5.1)
    run.lua                 test driver: loads the addon in toc order, asserts
```

## Conventions (ALL agents must follow these)

- Addon name / folder / toc: `SpecSage`. SavedVariables: `SpecSageDB`
  (account-wide), `SpecSageCharDB` (per character).
- Namespace: `local ADDON, ns = ...` at the top of every addon file. No
  globals except the two saved variables and the slash handlers.
- Lua 5.1 only (WoW's dialect). No `goto`, no `//` operator, no `#!`.
- Retail API namespaces via fallback, e.g.
  `local GetSpellInfo = (C_Spell and C_Spell.GetSpellInfo) or GetSpellInfo`.
- Modules are plain tables from `ns:NewModule(name)`; lifecycle hooks
  `OnInit` (after saved vars), `OnEnable` (PLAYER_LOGIN),
  `OnConfigChanged` (settings changed). Modules never create frames for the
  overlay — they hand rows to `ns.UI:SetSection(id, rows, tooltipProvider)`.
- Print prefix colour `|cff33ff99SpecSage|r: ` via `ns.Print(...)`.
- Every file must compile with `luac5.1 -p` and the test suite must pass:
  `lua5.1 tests/run.lua` from the repo root.
- Comments: explain constraints and non-obvious WoW API behaviour, not
  what the next line does.

## Slash commands

`/sage` and `/specsage` (register both).

| Command | Action |
| --- | --- |
| `/sage` | Toggle the Codex window |
| `/sage overlay` | Toggle the stat overlay |
| `/sage guide <class> [spec]` | Open the Codex at a class/spec (fuzzy match) |
| `/sage lock` / `unlock` | Lock/unlock overlay dragging |
| `/sage config` | Open options |
| `/sage scale <0.5-2>` / `width <120-320>` / `font <8-20>` | Overlay sizing |
| `/sage stat [name]` | List / toggle overlay stat rows (per character) |
| `/sage tooltips` | Toggle overlay hover tooltips |
| `/sage pin` / `unpin` / `pins` | Pinnable tooltips (as StatOverlay) |
| `/sage dps` / `reset dps` | Combat summary / reset |
| `/sage watch <spellID>` / `unwatch` / `watch list` / `scan` | Proc watcher |
| `/sage reset pos` / `reset all` | Position / full reset |

## Guide data schema (Data/API.lua)

`Data/API.lua` creates `ns.GuideStore` with:

```lua
ns.GuideStore:RegisterSpec(classToken, specID, guide)
ns.GuideStore:GetGuide(specID)          -- -> guide table or nil
ns.GuideStore:GetClassSpecs(classToken) -- -> ordered array of specIDs
ns.GuideStore:GetClasses()              -- -> ordered array of class entries
```

A guide table:

```lua
{
  specName = "Fury",            -- display name
  role = "DAMAGER",             -- DAMAGER | TANK | HEALER
  overview = { "paragraph 1", "paragraph 2" },   -- plain strings
  statPriority = {
    -- ordered; statKey matches Modules/Stats keys so the Codex can show
    -- the player's live value beside it (only for the player's own class)
    { stat = "haste",   note = "to ~20%" },
    { stat = "mastery" },
    { stat = "crit" },
    { stat = "versatility" },
  },
  rotation = {
    { title = "Single Target", steps = {
        { spellID = 23881, text = "Bloodthirst on cooldown" },
        { spellID = 85288, text = "Raging Blow to spend charges" },
        { text = "Free-text step without a spell icon is allowed" },
    }},
    { title = "AoE", steps = { ... } },
  },
  cooldowns = {
    { spellID = 1719, text = "Recklessness — with damage buffs up" },
  },
  consumables = {
    { slot = "Flask",   text = "Flask of Alchemical Chaos" },
    { slot = "Food",    text = "The Sushi Special" },
    { slot = "Potion",  text = "Tempered Potion" },
    { slot = "Weapon",  text = "Ironclaw Whetstone" },
    { slot = "Enchants", text = "..." },
    { slot = "Gems",    text = "..." },
  },
  tips = { "short tip", ... },
}
```

Valid `stat` keys: `primary`, `crit`, `haste`, `mastery`, `versatility`,
`leech`, `avoidance`, `speed`, `armor`, `stamina`.

Spec IDs are Blizzard's numeric specialization IDs (e.g. 72 = Fury). Class
tokens are the uppercase English tokens (`WARRIOR`, `PALADIN`, ...).

The registration API must validate its input (wrong types → `ns.Print`
warning, guide skipped) so a third-party guide pack cannot take the addon
down. Guide data files contain **data only** — no logic beyond the
`RegisterSpec` calls.

Data files carry a header comment noting content targets The War Within and
is community-maintained; each entry is a sensible, conventional guideline
(stat priorities and rotations that match the spec's long-standing design),
not a claim of being bleeding-edge optimal.

## BiS / Gear (v1.1)

WoW addons have no network access at runtime, so nothing can be pulled from
Wowhead, Method, Archon, or anywhere else in game — and item-level BiS lists
belong to the sites that maintain them and go stale every patch. SpecSage
therefore splits gear into two halves:

**1. Shipped gear guidance** — the guide schema gains an optional `gear`
array of slot guidance (what to look for, in our own words — stats, tier
bonuses, trinket styles — never a scraped item list):

```lua
gear = {
  { slot = "Head",    text = "Tier set piece — the 4-piece bonus outweighs raw item level" },
  { slot = "Trinket", text = "One on-use Strength burst trinket to pair with cooldowns, one passive stat stick" },
  { slot = "Weapon",  text = "Highest item level two-hander; weapon damage dominates" },
}
```

Valid `slot` values: `Head, Neck, Shoulder, Back, Chest, Wrist, Hands,
Waist, Legs, Feet, Ring, Trinket, Weapon, Off-hand` (validated by
`Data/API.lua` like statPriority keys; a guide may repeat a slot, e.g. two
Trinket lines).

**2. Personal BiS checklist** (`Modules/BiS.lua`, module name "BiS") — the
user builds their own list from whatever source they trust, and the addon
tracks progress live:

- Storage: `SpecSageDB.bis[specID]` = array of
  `{ slot = <valid slot>, itemID = <number or nil>, name = <string>, note = <string or nil> }`.
- API (frame-free, testable): `BiS:GetForSpec(specID)`,
  `BiS:Add(specID, slot, itemText, note)` — `itemText` may be a pasted item
  link (`|Hitem:12345:...|h[Name]|h`; parse the itemID and name out of it),
  a bare numeric itemID (resolve the name via `C_Item.GetItemInfo` fallback
  chain, which may be async — store the ID and re-resolve lazily on render),
  or a plain name (no ID; still listed, just can't be auto-checked);
  `BiS:Delete(specID, index)`; `BiS:GetStatus(entry)` returning `"equipped"`,
  `"owned"` (in bags, via `C_Container.GetContainerNumSlots`/`GetContainerItemID`
  fallback chain), or `"missing"` — only meaningful when the entry has an
  itemID and the viewed spec is the player's; pcall-wrap container/item APIs.
- Codex **BiS** tab: shipped gear guidance rows on top (slot label +
  text), then a divider, then the personal checklist — each row shows slot,
  item name (item-quality colour when known), status tag
  (green "equipped" / yellow "in bags" / grey "missing", only for own spec
  with itemID), a Delete button, and item `GameTooltip:SetItemByID` on
  hover (pcall). Below: an Add row — slot dropdown/cycler + editbox
  accepting link, itemID, or name.

The Codex grows to 8 tabs: Overview | Stats | Rotation | Cooldowns |
Consumables | BiS | Loadouts | Notes. To fit, `FRAME_WIDTH` widens to 984
and `CONTENT_WIDTH` grows by the same 84px; tab width/stride stay as they
are. (The tab strip is a separate geometry chain from `CONTENT_WIDTH` -
frame width minus both rails, their gaps, and its own 8px side margins - and
8 tabs at the existing 84/86 width/stride need 686px; +60 alone left that
16px short, clipping the last tab past the frame's right edge. +84 covers
it with a small margin.)

A later pass (options-in-Codex work, not otherwise documented in this file)
added a 9th tab, **Options**, and widened the frame again to 984 -> 1070
with the same `FRAME_WIDTH - 310` invariant carrying `CONTENT_WIDTH` along
with it (760). `tests/run.lua`'s tab-strip width assertion derives its
"needed" width from the live tab count rather than a hardcoded number, so
adding a further tab fails that test instead of silently clipping in the
client.

`/sage reset all` leaves `SpecSageDB.bis` alone (curated data, like
loadouts and notes).

## Shipped Mythic+ talent loadout (v1.2)

A talent build string is thin: it is Blizzard's own export-format encoding of
a specific set of choices from a fixed, enumerable rule set (the talent
tree), closer to a configuration than to creative prose. That makes it a
meaningfully lower-risk thing to ship a default for than guide prose or an
Action Priority List's conditional logic would be — so unlike the guide text
(hand-authored, never sourced from a specific site) and unlike BiS (no
shipped items at all), SpecSage ships ONE reference value here, sourced from
SimulationCraft's public GitHub repository (github.com/simulationcraft/simc,
GPLv3, credited) rather than from any guide website:

```lua
mplusLoadout = {
  string = "C0EAy0kSampleExportStringFromSimC...",  -- Blizzard talent export format
  source = "SimulationCraft default profile (credit, not endorsement of 'best')",
  patch = "12.1",                                    -- the game patch it was pulled for
}
```

Validated by `Data/API.lua` like `gear`: optional; when present, `string` and
`patch` must be non-empty strings (bad shape -> warn + skip the whole guide,
consistent with every other validation in this file).

This is a *reference starting point*, not a claim of "the" Mythic+ build —
SimC's bundled profiles are commonly patchwerk/raid-simmed rather than
M+-labeled, and talent trees get retuned every patch. Guide files note this
per spec where the SimC profile's fight style is not clearly M+-oriented,
rather than presenting it as more authoritative than it is.

The Codex **Loadouts** tab, when `guide.mplusLoadout` is present, shows one
extra row above the user's own saved loadouts: "Suggested Mythic+ (via
SimulationCraft, patch 12.1)" with a **Copy** button (same read-only
highlighted-editbox pattern as a saved loadout) and an **Add to my vault**
button that calls `Loadouts:Add(specID, "Suggested M+ (SimC)", "Mythic+",
guide.mplusLoadout.string)` — it never writes into `SpecSageDB.loadouts`
until the user clicks Add, keeping the existing "shipped guide data is
read-only reference, `SpecSageDB` is the user's own roster" separation
intact. Absent for a spec with no `mplusLoadout` — no placeholder text; it
simply doesn't add the extra row.

## Shipped raid loadout & structured rotation conditions (v1.3)

Two extensions that go further with the same SimulationCraft source
`mplusLoadout` (v1.2) already established, rather than opening a new one:

**1. `raidLoadout`** — a second talent-string suggestion, same shape and
same trust bar as `mplusLoadout`, for a spec where SimC publishes a
genuinely different build for raid content than for Mythic+/dungeon content:

```lua
raidLoadout = {
  string = "C0EAy0kSampleExportStringFromSimC",  -- Blizzard talent export format
  source = "SimulationCraft default profile (credit, not endorsement of 'best')",
  patch = "12.1",
}
```

**Only add it when that distinct source genuinely exists.** As of patch
12.1, SimC's `midnight` branch ships exactly ONE profile per spec
(`profiles/<tier>/<tier>_<Class>_<Spec>.simc`) — the `profiles/<tier>_Raid.simc`
file at the top level is an aggregator that `#include`s each spec's single
file, not a separately-talented raid build sitting alongside a
separately-talented dungeon one. Pointing `raidLoadout` at that same file
under a `mplusLoadout` field that also (from an earlier or later fetch)
points at it would show a player two different-looking Codex rows —
"Suggested Mythic+" and "Suggested Raid" — that carry no real
differentiation the label promises, with no way for the player to know that
from the UI alone. Confirm SimC's directory structure for the current
tier actually branches by content type before populating both fields for a
spec; if it does not, refresh `mplusLoadout` alone and leave `raidLoadout`
unset, the same as any spec without SimC coverage for a field. (This
schema and its rendering are validated with synthetic fixture data — see
`tests/run.lua`'s "Suggested Mythic+ and Raid loadout rows" section — deliberately,
so the mechanism is proven independently of whether real source data
supporting it exists yet for any particular spec.)

Validated identically to `mplusLoadout` (`Data/API.lua`'s
`ValidateLoadoutSuggestion` backs both — optional; when present, `string`
and `patch` must be non-empty strings). A guide may carry either, both, or
neither; the two do not interact.

The Codex **Loadouts** tab gains a second suggested-loadout row, "Suggested
Raid (via SimulationCraft, patch 12.1)", with the same Copy/Add to my vault
behaviour as the Mythic+ row (`Loadouts:Add(specID, "Suggested Raid (SimC)",
"Raid", guide.raidLoadout.string)`). `UI/Codex.lua`'s
`SUGGESTED_LOADOUT_KINDS` table drives both rows from one shared renderer,
Mythic+ above Raid, each independently shown or hidden depending on which
loadout kinds that spec's guide actually ships — a spec with only one still
shows just the one row, not a placeholder for the other.

**2. Structured `condition` on a rotation step or cooldown entry** — a rotation
group's step (`rotation[].steps[]`) and a `cooldowns[]` entry both gain an
optional `condition` field, alongside the existing `spellID`/`text`:

```lua
{ spellID = 163201, text = "Execute once the target drops below execute-range health",
  condition = "Slayer hero talent: use with Rage above 40, or on a Sudden Death proc" },
```

This is an Action Priority List's `if=` logic, translated to plain English -
never raw `actions.*` syntax - and kept structurally separate from
hand-authored `text` rather than folded into one sentence, so a future
refresh pass can update the condition from a newer APL without touching
prose a person wrote, and so the two read as clearly different things in the
Codex rather than one run-on line. Not validated by `Data/API.lua` (same
laissez-faire treatment `rotation`/`cooldowns` steps already get - a bad
shape renders oddly rather than being rejected, since these are free-text
fields already, not an enumerable vocabulary like `stat` or `slot`).

Rendered as its own line directly under the step it belongs to, in a
dedicated colour (`UI/Codex.lua`'s `CONDITION_COLOR`, distinct from a
section header's colour and from plain step text) and indented
(`CONDITION_INDENT`) so it reads as a detail on the step above rather than a
new item. Present only when the step actually carries a `condition` - a step
without one costs no extra row.

Applied so far to Arms Warrior's Execute step and Bladestorm cooldown (both
Slayer-hero-talent-specific), translated from
`actions.slayer_execute+=/execute,if=rage>40|buff.sudden_death.up` and
`actions.slayer_st+=/bladestorm,if=debuff.colossus_smash.up` in
`profiles/MID1/MID1_Warrior_Arms.simc`, each independently re-fetched to
confirm an exact match before use - the same double-check bar as a shipped
talent string, since a mistranscribed `if=` clause would be silently wrong
rather than merely malformed. Arms's `mplusLoadout.string` was refreshed
from the same file in the same pass (see `Data/Guides_Warrior.lua`'s header
comment - the previous string was a stale snapshot from an earlier refresh).
Every other spec in the repo predates this field and has none yet;
`raidLoadout` has not been applied to any real spec's guide file yet (see
above) - only exercised by `tests/run.lua`'s fixtures.

## Codex window (UI/Codex.lua)

- One movable, resizable-feeling frame (fixed size is fine: ~740x520),
  `UIPanelDialogTemplate`-style but custom-built (dark backdrop, class-colour
  accents). ESC closes it (`tinsert(UISpecialFrames, ...)`).
- Left rail: 13 class buttons (class icon + class-coloured name), then the
  selected class's specs beneath/next to it (spec icon + name). Defaults to
  the player's own class and current spec on open.
- Main pane: tab strip — **Overview | Stats | Rotation | Cooldowns |
  Consumables | BiS | Loadouts | Notes** — and a scrollable content area.
- Section renderers read from `ns.GuideStore`; missing sections render an
  italic "no data yet — /sage config explains how to contribute" line.
- Stats tab: for the *player's own spec*, each priority row also shows the
  live value from `ns:GetModule("Stats")` (e.g. "Haste — 14.77%"); for other
  classes/specs just the priority.
- Rotation steps with a `spellID` show the spell icon (via
  `C_Spell.GetSpellTexture` fallback chain) and the game's spell tooltip on
  hover (shared `GameTooltip` is fine here — the Codex has no pinning).
- Loadouts tab: list of saved loadouts for the viewed spec with name +
  category; buttons: **Save current** (only for own spec, reads
  `C_Traits`/`C_ClassTalents` export string when available), **Add from
  string** (editbox dialog), **Copy** (read-only editbox with the string
  selected for Ctrl+C), **Delete**. Stored in
  `SpecSageDB.loadouts[specID] = { {name=..., category=..., export=...}, ... }`.
  Categories: Raid, Mythic+, Delves, PvP, Other.
- Notes tab: multi-line editbox saved to `SpecSageDB.notes[specID]` on
  focus-lost / window close.

## Overlay port

Ported from `stat-overlay` (same author, code may be reused verbatim where it
fits) with these changes: namespace/saved-variable/branding renames, slash
commands folded into `/sage`, options panel gains Codex settings, and
`Modules/Stats.lua` additionally exposes
`Stats:GetStatValue(statKey) -> displayString` for the Codex's live stat
integration.

## Live Mythic+ meta loadout (v1.4) — schema and UI shipped, data pipeline blocked

A third suggested-loadout kind, `mplusMetaLoadout`, alongside `mplusLoadout`
(v1.2, SimC's theorycrafted default) and `raidLoadout` (v1.3): what current
top Mythic+ players are actually running, sourced from Blizzard's own
Battle.net Game Data API rather than SimC. This is not the same
"is this genuinely distinct" question `raidLoadout` ran into — an empirical
aggregate of real players' choices is categorically different data from a
simulated recommendation, by construction, regardless of source freshness.

```lua
mplusMetaLoadout = {
  string = "C0EAy0kSampleLiveMetaExportString",  -- Blizzard talent export format
  source = "Blizzard Battle.net API, aggregated from top current-season Mythic+ players",
  patch = "12.1",
  sampleSize = 50,  -- optional: how many players this was aggregated from
}
```

Validated by the same `Data/API.lua` `ValidateLoadoutSuggestion` that backs
`mplusLoadout`/`raidLoadout`, extended with an optional `sampleSize` (must be
a positive number when present — the only field of the three loadout kinds
that isn't just `string`/`source`/`patch`, since an empirical aggregate has a
sample size and a single curated profile does not).

`UI/Codex.lua`'s `SUGGESTED_LOADOUT_KINDS` gained a third entry and an
`attribution` field per kind ("via SimulationCraft" for the first two, "via
Blizzard's API" for this one) — the row label is no longer a hardcoded "via
SimulationCraft" phrase reused across every kind, which would have
mislabeled this one. When `loadout.sampleSize` is present it's folded into
the label too: "Top Players' Mythic+ Build (via Blizzard's API, top 50,
patch 12.1)". Same Copy / Add to my vault behaviour as the other two rows
(`Loadouts:Add(specID, "Top M+ Build (Live)", "Mythic+", ...)` — category
`"Mythic+"`, the same category the SimC mplus row uses, since it is also a
Mythic+ build; only the source and name differ).

**What is shipped and tested:** the schema, validation, and full Codex
rendering (three independently shown/hidden/ordered rows, correct
per-kind attribution, Copy, Add to my vault) — proven with `tests/run.lua`
fixtures, same as `raidLoadout` before any real spec carried one.

**What is NOT yet shipped: a working pipeline that actually populates this
field**, and the reason is a specific, unresolved technical question, not
just "not built yet." Populating `mplusMetaLoadout.string` requires
Blizzard's own Battle.net API to hand back a talent build in the same
export-string format `mplusLoadout`/`raidLoadout` already use (the format
`C_Traits.GenerateImportString` produces and the in-game import UI accepts)
— but that format is generated client-side by
`C_ClassTalents.GetLoadoutExportString()`, which Blizzard's own
documentation describes as an internal/undocumented encoder, and the
REST API's other resources (equipment, achievements) consistently expose
structured IDs rather than an opaque client-format blob. Research strongly
suggests (but could not directly confirm without an authenticated test call,
which needs real Battle.net API credentials nobody had yet at research time)
that the character-specializations endpoint's `loadouts` field is structured
talent-node data, not a ready-to-use export string.

If that's correct, shipping this field for real means the refresh pipeline
must itself re-implement Blizzard's talent-loadout serializer — encoding
structured node selections back into the client's bit-packed export format
— which is a real, separate reverse-engineering project, not something to
fold into "just pull the string" scope the way `mplusLoadout`/`raidLoadout`
could. **Before writing that pipeline, make one real authenticated API call
against a character with a known talent build and inspect the actual
`loadouts` field shape** — cheap and decisive, and settles whether this is a
one-field mapping or a serializer to build. See
`.claude/skills/specsage-refresh/SKILL.md` (or a dedicated Mythic+-meta
refresh skill, if one exists by the time you're reading this) for the rest
of the pipeline: enumerate current-season connected-realm Mythic+
leaderboards (`GET /data/wow/connected-realm/{id}/mythic-keystone-leaderboard/{dungeonId}/period/{period}`
- no single global leaderboard exists, this genuinely requires enumerating
many realms) to identify top characters per spec, then look up each one's
specializations (and equipment, via the separate, unaffected
`GET /profile/wow/character/{realm}/{name}/equipment`) to build the
aggregate.

## Tests

Port the strict mock and driver from stat-overlay; extend the mock with the
extra APIs the Codex needs (`C_ClassTalents`, `C_Traits`,
`GetSpecializationInfoByID`, `GetNumClasses`/`GetClassInfo`,
`UISpecialFrames`, editbox/scrollframe widget methods, etc. — keep the mock
strict: unknown registered events fail the run).

New test areas: GuideStore validation (bad guides rejected, good guides
retrievable, ordering), every shipped data file registers all of its class's
specs with valid stat keys and non-empty rotation, loadout add/delete/export
round-trip, notes persistence, codex open/select-spec/tab-switch smoke tests,
slash command routing.
