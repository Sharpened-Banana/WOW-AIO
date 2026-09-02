# SpecSage

An all-in-one World of Warcraft addon for **Retail (Midnight, patch 12.1)** that puts
class guides, talent loadouts, and live character tracking in one place:

- **The Codex** — a browsable guide window for every class and spec: overview,
  stat priority, rotation priorities, cooldowns, consumables & enchants, and
  practical tips. Opens on your own spec, but you can read up on any class —
  teammates, enemies, or the alt you are levelling.
- **BiS & Gear** — per-spec gear guidance (what to look for in each slot),
  a sim-based **trinket tier list** per spec (S/A/B/C, single-target and
  3/5-target, every row a clickable item link), plus a personal best-in-slot
  checklist: paste item links from whatever guide site you trust and SpecSage
  tracks live which pieces you have equipped, in your bags, or still missing.
- **Tier and stat ranks on item tooltips** — a trinket's tooltip shows its
  tier in your current spec's trinket lists (Single Target S, Icy Veins A,
  …), and every item tooltip gets each secondary stat's rank written next to
  the stat itself ("+512 Haste  #1") against your spec's stat priority, so
  you can tell at a glance whether a drop in your bags is for you.
- **Talent Loadout Vault** — save, label, import, and export talent loadout
  strings per spec, organised by content type (Raid, Mythic+, Delves, PvP).
- **Personal Notes** — free-text notes per spec, kept between sessions.
- **Feedback button** — in the Codex title bar (and `/sage feedback`): shows
  the addon's CurseForge link ready to Ctrl+C for bug reports and feature
  requests. WoW gives addons no network access, so no addon can open your
  browser or send a report itself; copying a link is the honest version.
- **Stat Overlay** — a small movable overlay with your character stats, live
  combat numbers (DPS / HPS / damage taken), and proc & cooldown tracking.

The pieces talk to each other: the Codex's stat-priority page shows *your
live values* next to each stat in the priority, so the guide and your
character sheet are one screen.

No external libraries — only the Blizzard API.

## How it differs from guide-scraper addons

SpecSage does not scrape or bundle website data. Guide content ships as plain,
human-editable Lua files (`SpecSage/Data/`) registered through a small API, so
anyone can amend a guide or publish their own guide pack as a separate addon
that registers into SpecSage. What ships in the box is conventional, stable
guidance for each spec — the priorities and habits that survive patch churn —
not week-by-week sim results.

## Where BiS data comes from

WoW addons have no network access, so nothing updates itself in game; what
ships is a snapshot, refreshed with each release. Three things live on the
BiS tab:

- **Slot-by-slot guidance** in SpecSage's own words (which slots carry your
  tier set, what stats to look for on rings, what trinket styles suit the
  spec).
- **A trinket tier list per spec**, from two sources side by side
  (`tools/fetch_trinkets.py` regenerates `Data/Trinkets.lua`): bloodmallet.com's
  public SimulationCraft trinket sims — each row shows the simulated DPS gain
  over no trinket and an S/A/B/C tier relative to the best one, for
  single-target, 3-target and 5-target fights — and Icy Veins' editorial
  trinket ranking as its own list, with Icy Veins' tier also shown beside
  every sim row. Healers and the few specs SimC has no current-patch profile
  for yet get the Icy Veins list only, and the tab says why. Neither is a
  verdict for your fight, and the tab says that too.
- **A personal checklist** you fill from whichever source you trust: pick a
  slot, shift-click an item link (or paste an item ID or name) from chat, a
  guide, or the dungeon journal, and SpecSage marks each entry equipped /
  in bags / missing as you gear up.

Every item on the tab is a real item link: hover for the tooltip, click to
open it, shift-click to put it in chat.

## Install

1. Copy the **`SpecSage`** folder (not the repository root) into:
   - Windows: `World of Warcraft\_retail_\Interface\AddOns\`
   - macOS: `World of Warcraft/_retail_/Interface/AddOns/`
2. Restart the game, or run `/reload` if it is already running.
3. Make sure **SpecSage** is ticked in the AddOns list.

The folder name must stay `SpecSage` so it matches `SpecSage.toc`.

## Usage

`/sage` opens the Codex. `/sage overlay` toggles the overlay; drag it to move
it, then `/sage lock` to fix it in place (locking lets clicks pass through).

### Commands

| Command | What it does |
| --- | --- |
| `/sage` | Toggle the Codex window |
| `/sage overlay` | Show or hide the stat overlay |
| `/sage guide <class> [spec]` | Open the Codex at a class/spec, e.g. `/sage guide druid resto` |
| `/sage lock` / `/sage unlock` | Lock or unlock overlay dragging |
| `/sage config` | Open the options panel |
| `/sage scale <0.5-2>` | Set the overlay scale |
| `/sage width <120-320>` | Set the overlay width |
| `/sage font <8-20>` | Set the overlay font size |
| `/sage stat` | List overlay stat rows and whether each is shown |
| `/sage stat <name>` | Toggle a stat row for this character |
| `/sage tooltips` | Toggle overlay hover tooltips |
| `/sage feedback` | Show the CurseForge link (ready to copy) for bug reports and feature requests |
| `/sage pin [stat]` | Keep a tooltip on screen (the hovered one if no stat given) |
| `/sage unpin [stat\|all]` | Close pinned tooltips |
| `/sage pins` | List what is pinned |
| `/sage dps` | Print a summary of the last fight |
| `/sage watch <spellID>` | Track a spell's proc and cooldown |
| `/sage unwatch <spellID>` | Stop tracking a spell |
| `/sage watch list` | Show tracked spells |
| `/sage scan` | List your current buffs with their spell IDs |
| `/sage reset dps` | Clear combat totals |
| `/sage reset pos` | Move the overlay back to the centre |
| `/sage reset all` | Restore every setting to default |

`/specsage` works everywhere `/sage` does. Everything is also available under
**Options → AddOns → SpecSage**.

## Configuration storage

- `SpecSageDB` — display settings, saved talent loadouts, BiS checklists,
  and per-spec notes, shared across all characters.
- `SpecSageCharDB` — which overlay stats are shown and the proc watch list,
  per character, since both are class- and role-specific.

`/sage reset all` restores display settings and this character's stat rows. It
leaves loadouts, notes, BiS checklists, and the watch list alone: that is
curated data, not a setting.

## Editing guide content

Each class's guide lives in `SpecSage/Data/Guides_<Class>.lua` as a plain Lua
table — open it in any editor, change the text, `/reload`. The schema is
documented in [DESIGN.md](DESIGN.md). A separate addon can also call
`ns.GuideStore:RegisterSpec(classToken, specID, guide)` after SpecSage loads
to override or extend what ships here.

## Development

Plain Lua 5.1 (WoW's dialect), no build step. Layout, module lifecycle, and
the guide data schema are documented in [DESIGN.md](DESIGN.md).

Run the test suite (a strict mock of the WoW API drives the whole addon
outside the game):

```sh
lua5.1 tests/run.lua
```

Syntax-check everything:

```sh
find SpecSage -name '*.lua' -exec luac5.1 -p {} +
```

## Game version

`## Interface: 120100` in the `.toc` targets Midnight patch 12.1. When a patch
bumps the interface number, update that line or the addon shows as out of
date. The current value is shown by `/dump select(4, GetBuildInfo())` in game.

## Credits

The overlay half of SpecSage grew out of the author's earlier StatOverlay
addon, folded in here so the guides and the live tracking ship as one addon.

The shipped Mythic+ talent loadout strings (`mplusLoadout` in the guide data)
are sourced from SimulationCraft's public default profiles
(github.com/simulationcraft/simc, GPLv3) — credit, not an endorsement of
"best". They are a reference starting point, not a scraped or generated
recommendation.
