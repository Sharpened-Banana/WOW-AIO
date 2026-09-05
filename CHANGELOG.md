# Changelog

## 1.3.1 (2026-09-05)

**New**
- **Talent window button.** A SpecSage button on the Talents tab lists every build for your spec (SimC Mythic+ and Raid, live top-players', guide sites, your vault) and lays the one you pick onto the tree, unsaved.
- **Minimap button.** The wax seal on the minimap ring: left-click the Codex, right-click the stat overlay, drag to move.
- **Consumables tab rebuilt on Midnight data.** The old entries were War Within items. Every spec now gets eleven kinds (flask, food, potion, weapon oil, each enchant slot, gems, augment rune), stat-matched to its priority and role, every item a hoverable, clickable chip. Item IDs checked against Wowhead. Also on the character sheet panel.
- **Overlay themes.** Minimal, Bordered, and Class-coloured, from the Options tab or Settings panel.
- **Buffs section** on the overlay: missing raid buffs and, optionally, a missing flask or food. Silent when nothing is missing.
- **Show stat overlay** option, plus **Toggle stat overlay** and **Toggle the Codex** key bindings.
- **Stagger** stat row (off by default).

**Improved**
- Buttons read as buttons: ink plates with a shadow and lit edge, wax red on hover, they sink when pressed, and they size to their labels.
- Armor tooltip shows reduction against your current target and falls back to a self-checking estimate when the live figure is unavailable.
- Mastery tooltip quotes your spec's own mastery text and shows mastery points.
- Combat report shows "?" for one protected number instead of blanking the whole line.
- Colour-blind-safe status colours across combat, proc, and buff rows.
- Feedback link now points at github.com/Sharpened-Banana/SpecSage, in a dialog that fits its text.

**Fixed**
- "Save current" and "Add from string" no longer overflow their buttons.
- One watched proc failing to build no longer hides the others.
