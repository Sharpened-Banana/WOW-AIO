# SpecSage — Design Document

SpecSage is an all-in-one World of Warcraft addon for Retail (The War Within,
Interface 110200). It combines:

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

## Codex window (UI/Codex.lua)

- One movable, resizable-feeling frame (fixed size is fine: ~740x520),
  `UIPanelDialogTemplate`-style but custom-built (dark backdrop, class-colour
  accents). ESC closes it (`tinsert(UISpecialFrames, ...)`).
- Left rail: 13 class buttons (class icon + class-coloured name), then the
  selected class's specs beneath/next to it (spec icon + name). Defaults to
  the player's own class and current spec on open.
- Main pane: tab strip — **Overview | Stats | Rotation | Cooldowns |
  Consumables | Loadouts | Notes** — and a scrollable content area.
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
