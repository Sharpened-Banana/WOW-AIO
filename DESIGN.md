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
    Data/StatPriority.lua   generated: Wowhead stat priority per hero tree
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
    -- the player's live value beside it (only for the player's own class).
    -- Kept in step with the spec's first Data/StatPriority.lua list; the
    -- per-hero-tree orders live there, not here (see "Stat priority")
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
Wowhead, Method, Archon, or anywhere else in game — and a shipped
item-level BiS list goes stale every patch regardless of where it's
sourced from, becoming actively misleading until someone updates it.
SpecSage therefore splits gear into two halves:

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
Trinket lines). Since v1.5 an entry may also carry a numeric `itemID`; the
Codex then appends the item as a clickable, quality-coloured link after the
guidance text (see the v1.5 addendum below). No shipped guide sets one yet.

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

### v1.5 addendum: clickable item links

Every concrete item the BiS tab shows is now an item link, not just text:
a trinket tier-list row (below), a gear guidance entry that carries the
optional `itemID` (see the schema section), and a personal checklist entry
with an itemID. Hover shows the item tooltip (`GameTooltip:SetItemByID`, as
before); a click runs the same path a chat link does — `HandleModifiedItemClick`
first (shift-click inserts into chat, ctrl-click opens the dressing room),
then `SetItemRef` for a plain click, which opens the standard `ItemRefTooltip`
the player can move and close. Both are pcall-wrapped (`ClickItemLink` in
UI/Codex.lua). The link itself is `C_Item.GetItemInfo`'s when the item is
cached and a bare `item:<id>` otherwise, which `SetItemRef` still resolves.

## Trinket tier lists (v1.5)

The one slot where "what to look for" is not enough: trinkets are discrete,
wildly uneven, and the only defensible ranking is a sim. `Data/Trinkets.lua`
ships one per spec, **generated** by `tools/fetch_trinkets.py` from
bloodmallet.com's public chart JSON (`/chart/get/trinkets/<fight style>/
<class>/<spec>`) — bloodmallet runs SimulationCraft's trinket sims for every
spec SimC has a current-tier profile for, and the JSON carries each trinket's
simulated DPS per item level, its itemID, source (Raid/Dungeon/Profession/
PvP) and whether it is on-use. This is the same "credit SimC's public data,
not a guide site's editorial" sourcing `mplusLoadout` uses, so it needed no
policy change; the guide-site rule was lifted anyway (see the skill file).

Registration, separate from the guide table so the generated file never
touches the hand-written guides and a third-party pack can ship its own:

```lua
ns.GuideStore:RegisterTrinkets(specID, {
  source = "bloodmallet.com trinket sims, SimulationCraft build f869791 (MID2 tier), ...",
  patch = "12.1",
  lists = {
    { title = "Single Target", fightStyle = "castingpatchwerk", list = {
        { itemID = 270173, name = "Zul'jin's Guillotine Technique", ilvl = 344,
          gain = 10.16, tier = "S", source = "Raid", onUse = false },
        ...
    }},
    { title = "3 Targets", ... }, { title = "5 Targets", ... },
  },
})
-- or, for a spec with nothing to rank:
ns.GuideStore:RegisterTrinkets(specID, { unavailable = "<why>" })
ns.GuideStore:GetTrinkets(specID)   -- -> either table, or nil
```

`Data/API.lua` validates: `unavailable` is a non-empty string, or `lists` is
a non-empty array of `{ title, list }` whose rows each have a numeric
`itemID`, non-empty `name`, `tier` in S/A/B/C and numeric `gain`; anything
else prints one warning and is skipped, like a bad guide.

What the numbers mean (and the Codex says so under the list): `gain` is the
trinket's simulated DPS over the spec's no-trinket baseline, at the highest
item level bloodmallet simulated it at (raid trinkets sim at 344, dungeon at
334, profession at 331 — a deliberate "each at its own best" comparison, the
same default view bloodmallet shows). The tier is that gain as a share of the
best trinket's gain in the same list: S ≥ 90%, A ≥ 78%, B ≥ 62%, C below.
Top 15 per list. It is a Patchwerk-style sim ranking, not a verdict for any
particular fight, and the row text says so.

Coverage, as of 2026-09-02: 27 of 40 specs have sim lists. The 13 without
are the 6 healers (SimC has no healing model, so nobody sims them) and the 7
specs SimC has not published a current-tier (MID2) profile for yet —
Retribution, all four Druid specs, all three Evoker specs. Re-running the
script picks those up the day they appear. The script needs a browser-like
User-Agent (bloodmallet 403s Python's default); it sets one.

### Icy Veins cross-check (2026-09-02)

The owner asked for the sim lists to be checked against Wowhead's and Icy
Veins' trinket tier lists. Icy Veins' per-spec gear guide carries a "Trinket
Rankings" table — an editorial S..D tier list with a wowhead item ID on
every entry — for all 40 specs, and is parseable from its plain HTML;
`tools/fetch_trinkets.py` now fetches it alongside bloodmallet. **Wowhead
could not be read**: its guide pages render client-side (WebFetch gets only
the page chrome), refuse plain HTTP clients (403), and the Chrome extension
was not connected in that session. So the cross-check is Icy Veins only,
and the data says so.

How it is folded in, rather than picking a winner:

- Every spec gets an extra **"Icy Veins"** list (the site's own tiers, in
  its order, `tier` = its letter, no `gain`) as the last entry in the toggle.
  For the 13 specs without sims it is the only list, and a `note` says why
  there is no sim list; the old `unavailable` shape is still accepted by the
  API but no shipped spec uses it now.
- Every sim row carries `siteTier`, Icy Veins' tier for the same item, and
  the Codex renders it in the row's detail ("Icy Veins A", or "not on Icy
  Veins' list") so the two views are compared on the row, not by flipping.
- Where Icy Veins rates a trinket S that is absent from the sim top 15, the
  script writes a `note` naming it. As of this run there are none: after
  filtering out non-trinket items the site mentions inside a trinket's
  description (Havoc's S-tier entry names the weapon it pairs with, and the
  first parser version swept those up), every Icy Veins S-tier trinket sits
  inside the sim top 15 for all 27 simmed specs, and in the top 5 for nearly
  all of them. The two sources agree far more than they differ; where the
  tier letters differ it is mostly the sim's stricter, gain-relative
  bucketing versus the site's coarser editorial one.

Schema additions (validated in `Data/API.lua`): `gain` is now optional
(present on sim rows only), `siteTier` is an optional S..D letter, `D` is
accepted as a tier (editorial lists use it; sim buckets stop at C), and a
top-level `note` is an optional non-empty string the Codex draws under the
list.

Codex BiS tab layout, top to bottom: shipped gear guidance rows (as before),
then a **Trinket Tier List** header with a fight-style toggle button beside
it (cycles Single Target / 3 Targets / 5 Targets; hidden when only one list
exists), one row per trinket — tier tag (S orange, A purple, B blue, C
green) | quality-coloured item name with `ilvl · source · on-use` detail |
`+x.x%` gain — and a muted attribution line, then the Personal Checklist as
before. Rows are clickable item links (addendum above). An uncached item shows
the sim's own name, queues `C_Item.RequestLoadItemDataByID`, and re-renders
on `GET_ITEM_INFO_RECEIVED` the same way checklist entries do.

## Linked BiS lists (v1.5, Data/BiS.lua)

The owner asked for the BiS tab's items to be real links, not prose. Icy
Veins' gear guide for every spec carries a "Best in Slot" block with one tab
per context (Overall, Mythic+, Raid) and, per slot, the item's wowhead ID,
name and drop source, parseable from plain HTML. `tools/fetch_bis.py`
generates `Data/BiS.lua`: one `RegisterBiS(specID, { source, patch, lists
= { { title, list = { { slot, itemID, name, from } } } } })` per spec, slots
mapped onto the 14-slot vocabulary `Data/API.lua` validates. Wowhead could
not be read (client-rendered, 403 to plain clients), so this is one site's
editorial list and the tab's attribution line says so — and says it goes
stale every patch, which is the whole reason the shipped prose guidance and
the personal checklist still exist alongside it.

Codex BiS tab order is now: prose gear guidance, **Best in Slot (Icy
Veins)** with a context toggle and one clickable row per slot (slot |
quality-coloured item + drop source | **Add**, which files the item on the
personal checklist under that slot via `BiS:Add`), the trinket tier list,
then the personal checklist. As of 2026-09-02 all 40 specs have all three
contexts. One guide (Discipline) repeats its block; the parser keeps the
first list per title.

### Bonus IDs (v1.6) — why the rows showed the wrong item

The first version shipped only the item ID, and a bare item ID resolves to
the item's **base** form. On current-season gear that is a different item
from the one on the guide page: Protection Paladin's Mythic+ neck, item
273781, renders in the client as a level-48 rare with +8 Stamina, where Icy
Veins means the item level 334 epic. The addon looked wrong in exactly the
way a stale list would, while the data was current.

What separates them is the item's **bonus-ID list**, which puts it on its
upgrade track. Icy Veins links every BiS entry as
`item=<id>&bonus=<a>:<b>`, and `tools/fetch_bis.py` now carries that through
as a row's `bonus` (validated optional, `"a:b:c"`). Details worth keeping:

- Icy Veins appends `&original-item=<id>` to catalysed pieces — the token's
  pre-catalyst source, not part of the bonus list. Dropped.
- It writes a **leading empty element** on the returning older-expansion
  dungeon pieces (`bonus=:12854`: no upgrade-track bonus, only a rank).
  Wowhead tolerates that; a client item string does not, so the list is
  normalised to bare numbers.
- Wowhead's own guide markup carries bare `[item=<id>]` with no bonus list —
  the site applies a default context when it renders. Rather than invent
  one, a Wowhead row reuses the bonus list Icy Veins publishes for the
  **same item ID**, which means `fetch_bis.py` reads every Icy Veins guide
  before writing any row. 652 of 668 Wowhead rows get one that way; the 16
  that no Icy Veins guide names stay bare.
- The map is written to `tools/item_bonus.json` so `tools/fetch_trinkets.py`
  can share it. Trinket coverage is much thinner (25 of 102 items) because
  neither trinket source publishes bonus lists and only some trinkets appear
  in a BiS guide; those rows stay bare until a better source turns up.

On the addon side `UI/Codex.lua`'s `ItemString(itemID, bonus)` builds
`item:<id>:0:0:0:0:0:0:0:0:0:0:0:<numBonusIDs>:<bonus...>` — the eleven
fields between the ID and the bonus count zeroed — or returns the plain
numeric ID when there is no bonus list, which is what every path took
before. A row keeps its numeric `itemID` (that is what
`GET_ITEM_INFO_RECEIVED` and the checklist match on) and gains an
`itemLink` holding the string; hover, click and name/quality lookup all
prefer `itemLink or itemID`. `GameTooltip:SetItemByID` takes a numeric ID
only, so the hover path switches to `SetHyperlink` for a string — the mock
now asserts that distinction rather than accepting either.

The **Add** button still files the bare item ID on the personal checklist.
That list answers "do I have this piece", which is matched by item ID
against your bags and equipped slots; folding a guide's upgrade track into
it would misreport what you actually own.

## Stat priority (v1.6, Data/StatPriority.lua)

A guide's own `statPriority` is one flat, ordered list per spec. That was
always a simplification: since hero talents shipped, most specs have two
meaningfully different stat orders, one per hero tree, and the shipped lists
had drifted from what the sites actually recommend (Arcane, for one, shipped
Crit/Mastery first while Wowhead has had Haste first all season).

Wowhead publishes exactly the missing thing — a stat priority per hero
talent tree on each spec's `stat-priority-pve-<role>` page. Roughly two
thirds of those pages state it as a plain ordered list of stat names, which
`tools/wowhead_harvest.js`'s `__harvestStats` reads straight off the page.
The rest write it as free text inside the list items ("Mastery to 1200
rating", "Haste (~700 Haste)", "Crit = Mastery") or as prose, and no parser
should be trusted to turn that into a ranking on its own. So the committed
source of truth is `tools/wowhead_stats.json` — the reviewed transcription
of all 40 pages, with each record's page URL and Wowhead's own updated date
— and `tools/fetch_stats.py` only turns that into Lua. `__harvestStats` is
how you find which pages moved since; re-read those by hand.

`Data/StatPriority.lua` registers one
`RegisterStatPriority(specID, { source, url, patch, heroSplit, lists = { {
title, note, list = { { stat } } } } })` per spec. Rules the data follows:

- **One list per hero talent tree**, titled with the tree's name. Where
  Wowhead splits on something else instead — a tank's survivability vs DPS
  goal, a healer's raid vs Mythic+ content — the title names *both* hero
  trees (`"Lightsmith / Templar - Survivability"`), so every hero spec is
  covered explicitly rather than silently dropped. `heroSplit` records which
  of the two shapes a record is.
- **Anything Wowhead ranks that is not a character stat** — item level,
  weapon damage — goes in the list's `note`, never invented into the order.
  Ties ("Haste = Crit"), rating caps and content caveats live there too.
- **Stat keys are the same vocabulary** `Data/API.lua` validates the guides'
  flat `statPriority` against, and `RegisterStatPriority` runs each list
  through the same `ValidateStatPriority`, so the two can never drift into
  different vocabularies.

The guides' own flat `statPriority` was rewritten this pass to match each
spec's *first* Wowhead list, and a test asserts the two stay in agreement.
That flat list is still what `Modules/ItemRanks.lua` ranks items against —
tooltips rank a single item for a single character, and picking which hero
tree the player is in is not something the addon reads today. It skips
primary/stamina/armor entirely, so a spec whose Wowhead order puts Intellect
last (Elemental) ranks its secondaries the same as any other.

Codex Stats tab order: the flat priority as before (numbered, with the
player's live value beside each row for their own spec), then a **By Hero
Talent Tree** section — one wrapping row per list, `Title: A > B > C > D`,
each note indented under it in the condition colour — then the Wowhead
attribution line. The section draws into its own `Codex.statLinePool` rather
than `pools.stats`: those are label/value stat rows that do not wrap, and a
note like "Haste only to roughly 800 rating" has to.

## Guide-site talent builds (v1.5, Data/SiteLoadouts.lua)

Icy Veins' "Spec Builds & Talents" page for each spec publishes its
recommended builds as export-string blocks (title + exact Blizzard export
string). `tools/fetch_talents.py` reads them from the raw HTML — never
through a summarising fetch, since talent strings are opaque — and
**decodes every string's header** (first 8 bits: serialization version;
next 16: specID) to confirm it encodes the spec it is filed under; a string
for the wrong spec is dropped with a warning. That check is what makes
shipping a site's strings safe where WebFetch never was. Output:
`RegisterSiteLoadouts(specID, { source, patch, builds = { { label, string
} } })`. As of 2026-09-02: 136 builds across all 40 specs (2–15 per spec;
Shadow Priest's page ships per-boss variants).

The Codex Loadouts tab renders them as "Icy Veins: <label> (patch 12.1)"
rows under the SimC/Blizzard suggested rows, with the same Copy and Add to
my vault buttons; the vault category is inferred from the site's own label
words (`SiteBuildCategory`: Mythic+/keys/dungeon/AoE → Mythic+, delve →
Delves, raid/single/cleave → Raid, else Other). They sit alongside, not in
place of, the guide's own `mplusLoadout`/`raidLoadout`/`mplusMetaLoadout`.

## Wowhead as a second source (2026-09-02)

Wowhead's guide pages are rendered client-side and return 403 to any
non-browser client, so the Python generators cannot read them. What does
work: a page on wowhead.com can `fetch()` its sibling guide pages
same-origin, and the response carries the guide body as Wowhead's own
`[markup]` (item tables as `[table]…[item=ID]`, the trinket list as
`[tier-list]…[tier-label]S[/tier-label]…[icon-badge=ID display-options=raid]`,
talent builds as `[copy="Raid"]CODE[/copy]`). `tools/wowhead_harvest.js`,
run in the browser (devtools console, or Claude's Chrome tool) on any
lightweight wowhead.com page — a heavy guide page freezes the renderer —
fetches and parses all 80 pages for the 40 specs into `window.__ss`, which
is dumped as `tools/wowhead_dump.json`. Item names and equip slots the
tables omit come from Wowhead's public tooltip endpoint
(`nether.wowhead.com/tooltip/item/<id>`, which plain HTTP *can* reach),
cached in `tools/wowhead_items.json` by `tools/wowhead_items.py`;
`tools/wowhead.py` turns the dump into the shapes the three generators
consume. Regenerating from a fresh dump is: harvest in browser → save dump
→ run the three scripts.

What it adds, alongside Icy Veins on every spec (never replacing it):

- **BiS**: a `Wowhead` list per spec (or one per hero tree, `Wowhead
  (Deathbringer)` / `Wowhead (San'layn)`, where the guide splits them);
  the Icy Veins lists are now titled `Icy Veins Overall/Mythic+/Raid` so
  the toggle names its source. Wowhead's own slot labels vary ("Helm",
  "Cape", "Trinket (Raid)", "2h Weapon", "Ring 1") and a few tables have
  no slot column at all; both are normalised through the tooltip slot.
- **Trinkets**: a `Wowhead` list per spec (its single S–F ranking, with
  each item's source from the site's raid/dungeon/delves/crafting filter
  tags), `whTier` on every sim row the site lists, rendered as "Icy Veins
  A · Wowhead S" in the row detail, and the same "site rates X S-tier but
  the sims don't have it" note logic for Wowhead. `F` joined the valid
  tier letters.
- **Talent builds**: Wowhead's import codes with the hero tree folded into
  the label ("Fel-Scarred: Raid (Best)"), decoded and spec-checked exactly
  like Icy Veins'. Each build now carries `site`, and the Loadouts row and
  vault name use it.

## Item stat ranks and trinket tiers on tooltips (v1.5, Modules/ItemRanks.lua)

Two annotations share one tooltip hook. **Trinket tier**: an item that
appears in the player's current spec's trinket lists (Data/Trinkets.lua)
gets a line naming every list that ranks it with its tier and, for sim
lists, its gain — `Single Target S (+10.2%)  5 Targets A (+8.9%)  Icy Veins
S` — so a trinket in your bags carries its tier on hover. A trinket
(`INVTYPE_TRINKET`) that no list ranks says "not in this spec's trinket
lists", since silence would read as "no opinion" when the addon does have
lists for the spec; a non-trinket gets no tier line at all.
`ItemRanks:DescribeTrinket(itemID, specID)` is the tooltip-free half.

**Stat ranks**: every item tooltip in the game gets each secondary stat's
rank written onto that stat's own line, in the line's right-aligned column
so the ranks form one column down the tooltip's edge (`+512 Haste ...... #1`,
`+380 Versatility .. #4`) rather than trailing each stat's text at a
different offset — against the player's *current spec's* Codex
`statPriority`. Tooltip lines are FontString pairs `<tooltipName>TextLeft<i>`
/ `TextRight<i>`; `ItemRanks:AnnotateInline` walks them, takes only lines
whose left text starts with `+` (so an effect description mentioning Haste
is untouched), matches the client's own localized `STAT_*` names, and writes
the rank into `TextRight<i>` (showing it) when that is empty, appending to
the left text only when another addon already used the right half. A line
whose right column already carries a `#` is skipped, so a second post-call
pass cannot stack ranks. Whatever it cannot place
(an unnamed tooltip, or a stat with no `+` line) falls back to the summary
line described next, so a
Haste/Versatility piece reads, for an Unholy DK, as `Haste #1 of 4 ·
Versatility #4 of 4`. Ranks count only rankable stats (crit, haste,
mastery, versatility, leech, avoidance, speed) — primary stat, stamina and
armor are on every piece for its slot and rank nothing — so a guide listing
primary first still ranks its best secondary as #1. A stat on the item that
the guide's priority does not mention shows as "unranked" rather than being
silently dropped. Colours run green → yellow → orange from #1 down.

Hook: `TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, ...)`
on modern clients (one call covers GameTooltip, ItemRefTooltip and the
compare tooltips); `OnTooltipSetItem` HookScript on GameTooltip/ItemRefTooltip
as the fallback. The link comes from the post-call's `data.hyperlink` first
and `tooltip:GetItem()` second. Stats come from `C_Item.GetItemStats(link)`
(`GetItemStats` fallback), keyed `ITEM_MOD_<STAT>_RATING_SHORT` /
`ITEM_MOD_VERSATILITY`. Everything that touches the tooltip is pcall-wrapped:
an error inside a tooltip post-call breaks *every* item tooltip in the
client, not just ours. `ItemRanks:Describe(link, specID)` is the pure,
tooltip-free half tests drive directly.

Setting: `SpecSageDB.itemStatRanks` (default on) governs both annotations,
exposed as "Tier and stat ranks on item tooltips" under a new **Codex**
group in `ns.OPTION_GROUPS`, so both the Codex Options tab and the Settings
panel carry it.

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

**Visual style ("Blizzard Modern", 2026-09-01):** soft dark blue-gray panels
with a faked vertical gradient (`Texture:SetGradient`, no bundled art) and a
1px top-edge highlight seam (`ApplyPanelChrome` in `UI/Codex.lua`), a warm
bronze accent (`ACCENT_COLOR`) that shifts to the selected class's own color
for the active-tab underline, and flat bordered buttons (`SkinButton`)
replacing the stock gray 3D-bevel `UIPanelButtonTemplate` look. Section
headers (`PlaceLine(..., { isHeader = true })`) get a hairline divider
instead of a bare colored line.

**Readability pass (2026-09-02):** the 2026-09-01 pass bundled PT Sans (SIL
OFL) at 11/12pt for body text; the owner found it harder to read than the
game's own face, too small, and the rows too cramped. Body text is now the
client's standard font (`STANDARD_TEXT_FONT`, Friz Quadrata — the same face
every default tooltip and panel uses) at 13pt for rows and 14pt for
paragraphs, and the layout opened to match: list rows 18→22px on a 20→26px
step (`ROW_HEIGHT`/`ROW_STEP`), stat rows 16→20 on 18→24, option rows
22→26, line/paragraph/group gaps 3/6/10→5/10/16, wrapped-text height
estimate 14→17px per line, tabs 24→28px, rail buttons 26/28→30/32px, and
the frame 520→600px tall to keep the same amount on screen. Friz has no
bold cut in the client, so "bold" headers use the same face and lean on
their colour and divider. The PT Sans files and their license were removed
from `SpecSage/Fonts/` since nothing references them now.

**Rounded corners and a glow texture (2026-09-02 follow-up):** the main
Codex frame's corners are now genuinely rounded, and buttons get a soft
accent glow on hover. Both use bundled PNG assets in `SpecSage/Textures/`
(generated with PIL for exact, pixel-precise alpha channels — an AI image
generator can't produce a mathematically exact rounded-rect mask or radial
gradient the way a script can). The rounding specifically required more
than a corner-mask overlay: `BackdropTemplate`'s own bg/border fill paints
the *entire* rectangle including the corners, so a transparent "cut" pixel
drawn on top of that fill just reveals the same opaque color sitting
underneath, not the real background behind the frame — the first version
of this fix looked correct in isolation but would not actually have
rounded anything in-game. `ApplyRoundedCorners` in `UI/Codex.lua` instead
replaces the backdrop's fill entirely with a manual "cross" of 6 plain
rects (3 border-colored, 3 fill-colored, each shaped to avoid the 4 corner
squares) plus the 4 corner PNGs dropped into exactly those unpainted
squares, so nothing else paints there and the tiles' transparent zone
correctly reveals whatever's really behind. Only the main frame got this
treatment (dialogs and the notes editbox keep the simpler flat corners);
the 4 corner tiles are a fixed color rather than tinted per selected class
like the rest of the border, a deliberate scope cut. **This has not been
verified rendering correctly in an actual game client** — `luac`/the test
suite can check the Lua is valid, not that the visual result looks right;
if the corners look wrong in-game, `ApplyRoundedCorners` is isolated and
safe to revert independently of everything else in this file.

## Overlay port

Ported from `stat-overlay` (same author, code may be reused verbatim where it
fits) with these changes: namespace/saved-variable/branding renames, slash
commands folded into `/sage`, options panel gains Codex settings, and
`Modules/Stats.lua` additionally exposes
`Stats:GetStatValue(statKey) -> displayString` for the Codex's live stat
integration.

## Live Mythic+ meta loadout (v1.4) — schema, UI, and pipeline all shipped

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

**Resolved by a real authenticated test call** (2026-08-30, against a known
character — see below): `GET /profile/wow/character/{realm}/{name}/specializations`
returns each spec as `{ specialization, loadouts: [...] }`, and each entry in
`loadouts` carries a `talent_loadout_code` field alongside the structured
`selected_class_talents`/`selected_spec_talents`/`selected_hero_talents`
node data. `talent_loadout_code` **is already the Blizzard export string** —
same character set, same length range (~100-110 chars), same
class-token-letter-plus-"EAA..." prefix shape as the SimC strings already
shipped in `mplusLoadout`/`raidLoadout`. Verified against a live character
(Holeehands-Emerald Dream, US) whose returned `talent_loadout_code` for its
active loadout matched its actual in-game Protection Paladin / Lightsmith
build, cross-checked against the response's own `character`/
`active_specialization`/`active_hero_talent_tree` fields.

This means the earlier concern in this section — that the API might only
expose structured node data, requiring the pipeline to build its own
serializer to re-encode Blizzard's internal bit-packed export format — does
**not** apply. Populating `mplusMetaLoadout.string` for a given player is a
direct field read (`loadouts[].talent_loadout_code` for the entry where
`is_active` is true), the same "just pull the string" scope
`mplusLoadout`/`raidLoadout` already had.

**The pipeline is built and has now shipped for all 39 specs in the addon**
(a 40th, Devourer Demon Hunter, was added 2026-09-02 after this rollout and
does not have one yet — no API credentials were available in that pass; see
Guides_DemonHunter.lua's header).
Protection Paladin (specID 66) ran first, end-to-end, on 2026-08-30:
`GET /data/wow/connected-realm/{id}/mythic-leaderboard/{dungeonId}/period/{period}`
(the confirmed live path — note `mythic-leaderboard`, not
`mythic-keystone-leaderboard`) scanned across all 83 US connected realms ×
the current season's 8-dungeon pool (no single global leaderboard exists,
so this genuinely means enumerating every realm — 664 calls, mechanically
simple and fast, not structurally hard), filtering
`leading_groups[].members[].specialization.id` for Protection Paladin
directly from the leaderboard response (no extra lookup needed just to
identify a member's spec). The top 50 distinct characters by best observed
keystone level had their `specializations` looked up for their active
Protection loadout's `talent_loadout_code`; the plurality exact build (4/50,
8%) shipped as `mplusMetaLoadout.string`, with the far stronger 94%
Lightsmith-hero-talent consensus called out in `source` for the fuller
picture a single percentage on the literal string would undersell.

The remaining 38 specs followed the same day in a second pass, generalized
to cover every class/spec pair in one scan: rather than re-running the
664-call leaderboard scan per spec, a single pass bucketed every
`leading_groups[].members[]` entry across all 83 realms × 8 dungeons by
`specialization.id` for all 38 target specs simultaneously (the leaderboard
data doesn't change between specs, so this is strictly cheaper than 38
separate scans), then resolved each spec's own top ~50 characters
independently. All 38 resolved with a usable sample (22-50 characters each —
a few off-meta specs, like Evoker's Augmentation and Mage's Fire, simply had
fewer distinct top-keystone characters to draw from; none fell below the
15-character honesty floor that would have required skipping a spec rather
than shipping a thin sample). See each `Guides_*.lua` file's Loadouts
section (and file header) for exactly what shipped per spec, and
`.claude/skills/specsage-mplus-meta-refresh/SKILL.md` for the generalized,
repeatable pipeline (run separately from `/specsage-refresh`'s full-repo
SimC pass) - the query path, the `is_active`-within-a-spec's-own-loadouts
nuance, the URL-encoding pitfall hit once already (non-ASCII character
names), the "scan once for every spec, not once per spec" efficiency this
second pass added, and the "report thin consensus honestly, don't inflate
it" rule every shipped `source` string follows.

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
