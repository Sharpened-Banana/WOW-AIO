# SpecSage — adversarial review

Reviewed against `DESIGN.md`. Verified with `lua5.1 tests/run.lua` (456 passed,
0 failed) and `luac5.1 -p` on all 26 Lua files (all clean). Every claim below
that could be checked outside the client was checked with a throwaway driver
script against `tests/wow_mock.lua`; findings that can only be confirmed in the
real client are marked as such.

Severity: **Critical** = breaks in game · **High** = user-visible bug ·
**Medium** = robustness or data error · **Low** = polish.

---

## Critical

### 1. `UI/Codex.lua` (no default for `self.activeTab`; used at :756, set only at :905) — the Codex opens completely blank

`Codex.activeTab` is never initialised. The Codex module has no `OnInit`/`OnEnable`,
`BuildFrame` does not set it, and `Open`/`Toggle` do not set it. The first
`/sage` therefore runs `RenderActiveTab()` with `self.activeTab == nil`:
`HideOtherTabWidgets(nil)` hides every pool, and none of the
`if tab == "Overview" … elseif …` branches fire, so nothing is drawn.

Verified: after `Codex:Toggle()` on a fresh session, `activeTab = nil` and
**0** content rows are visible. The user sees a class rail, a spec rail, a
(currently invisible — see #2) tab strip and an empty content area until they
click a tab. This is the addon's headline feature and its first impression.

Why it matters in game: `/sage` is the primary entry point per DESIGN.md. It
opens to nothing on every fresh login.

Fix: initialise the tab. Either add

```lua
function Codex:OnInit()
    self.activeTab = "Overview"
end
```

or, more defensively, at the top of `RenderActiveTab`:
`local tab = self.activeTab or "Overview"; self.activeTab = tab`.

Also add a test that asserts a content row is visible immediately after the
first `Codex:Toggle()` (see #22).

### 2. `UI/Codex.lua:420, 425, 440, 445, 588, 603, 609, 970` — every Codex button is created with no template, so it is invisible in the real client

All of these are `CreateFrame("Button", nil, parent)` followed by `:SetText(...)`:
the seven tab-strip buttons, `Save current`, `Add from string`, the category
cycler, the Add dialog's `Save`/`Cancel`, and each loadout row's `Copy`/`Delete`.

A bare `Button` has no normal/pushed/highlight texture and — critically — no
font string. `Button:SetText` applies to the button's font string, which only
exists when a template (or an explicit `SetFontString`) provides one, so in the
real client these render as *nothing at all*: no border, no label, no hover
state. They are still clickable, but the user cannot see or find them.

The mock hides this completely: `tests/wow_mock.lua:177` gives **every** frame a
`SetText`, regardless of `frameType` or template, so `tabButtons.Overview.text`
reads back `"Overview"` in tests and looks correct.

Fix: use `"UIPanelButtonTemplate"` for the action buttons
(`CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")`) and either
`"UIPanelButtonTemplate"` or `"PanelTabButtonTemplate"` for the tab strip. Note
`UIPanelButtonTemplate` at 64px will clip "Consumables" — widen the tab buttons
to ~86px and bump the `x = x + 66` stride to match, or shorten the label.

### 3. `UI/Codex.lua:583, 597, 665, 702` — every EditBox is created with no template and no font object

`nameBox`, `importBox`, the Copy dialog's `box` and the Notes `box` are all bare
`CreateFrame("EditBox", nil, parent)`. A FontInstance widget with no font set
cannot render text; in retail this yields invisible text and can raise a
"font not set" error on `SetText`. There is also no backdrop or inset, so there
is no visual indication of where to click or type.

Consequence in game: the "Add from string" dialog is an empty grey rectangle,
the Copy dialog shows no string to copy, and the Notes tab is a blank area that
silently swallows typing. Again invisible to the tests, because the mock's
`SetText`/`GetText` (`wow_mock.lua:177-178`) work on any frame.

Fix: give the single-line name box `"InputBoxTemplate"`, and for the multi-line
boxes set an explicit font plus insets, e.g.

```lua
local box = CreateFrame("EditBox", nil, parent)
box:SetFontObject(ChatFontNormal)      -- or GameFontHighlightSmall
box:SetTextInsets(4, 4, 2, 2)
```

and back the multi-line boxes with a `BackdropTemplate` frame (or
`InputScrollFrameTemplate`) so the edit area is visible. Add `ChatFontNormal` to
`.luacheckrc`'s `read_globals` and to the mock.

---

## High

### 4. `UI/Codex.lua:680-686` — the Copy dialog focuses and highlights the edit box *before* showing it, so Ctrl+C does not work

```lua
self.copyBox:SetText(exportString or "")
self.copyBox:SetFocus()
self.copyBox:HighlightText()
self.copyDialog:Show()
```

`EditBox:SetFocus()` on a hidden widget is a no-op in the real client (focus
requires a visible frame), and `HighlightText()` on an unfocused box leaves
nothing selected. The dialog's own label promises "Ctrl+C to copy", so the user
follows the instruction and copies nothing.

Fix: show first, then focus/highlight:

```lua
self.copyDialog:Show()
self.copyBox:SetText(exportString or "")
self.copyBox:SetFocus()
self.copyBox:HighlightText()
```

The test at `tests/run.lua:1134-1136` only checks `GetText()`, so it passes
either way.

### 5. `UI/Codex.lua:711-725` (`RenderNotes`) + `:891-896` (`SelectSpec`) — switching spec while the Notes tab is open silently discards the note you were typing

Notes are only saved on `OnEditFocusLost` and on the frame's `OnHide`. Clicking a
spec-rail button does **not** clear an EditBox's focus in WoW, and `SelectSpec`
goes straight to `RenderActiveTab()` → `RenderNotes(newSpecID)` →
`box:SetText(other spec's note)`, overwriting the buffer without saving.

Verified: typed text for spec 252, called `SelectSpec(251)`, and
`Notes:Get(252)` came back empty.

(Tab switching happens to be safe because `HideOtherTabWidgets` hides the box,
which does clear focus — but only by luck, and only for that path.)

Fix: save before re-rendering. In `SelectSpec` and `SelectTab`, call
`self:SaveNotes()` first, and/or in `RenderNotes` save the previous
`box.specID`'s text before calling `SetText`:

```lua
function Codex:SelectSpec(specID)
    self:SaveNotes()          -- flush the open note against its own specID
    self.selectedSpecID = specID
    ...
```

Also add `box:SetScript("OnEscapePressed", function(b) b:ClearFocus() end)` —
without it, ESC inside a focused EditBox is ambiguous with the
`UISpecialFrames` ESC-to-close on the Codex.

### 6. Guide data — six abilities attributed to the wrong specialization

The Codex renders a spell icon and the *game's own tooltip* for any step with a
`spellID`, so a wrong-spec ID shows the player an ability they do not have,
right next to advice telling them to press it.

| File:line | Listed as | Reality (TWW / 11.x) |
| --- | --- | --- |
| `Data/Guides_Warrior.lua:51` | Recklessness (1719) as an **Arms** cooldown | Fury-only. Arms' burst is Avatar (107574) / Warbreaker–Colossus Smash windows. |
| `Data/Guides_Warrior.lua:113` | Die by the Sword (118038) as a **Fury** cooldown | Arms-only. Fury's equivalent (Enraged Regeneration 184364) is already listed on line 112. |
| `Data/Guides_Warrior.lua:38, 53` | Bladestorm **46924** for Arms | 46924 is the Fury version; Arms' Bladestorm is **227847**. (Fury's use on `:111` is correct.) *Verify against the current build before changing.* |
| `Data/Guides_Rogue.lua:52` | Shadow Blades (121471) as an **Assassination** cooldown | Subtlety-only (correctly listed at `:171`). |
| `Data/Guides_Priest.lua:50` | Dispersion (47585) as a **Discipline** cooldown | Shadow-only (correctly listed at `:162`). |
| `Data/Guides_Priest.lua:40, 48` | Guardian Spirit (47788) as a **Discipline** cooldown | Holy-only (correctly listed at `:95, :102`). Discipline's save is Pain Suppression (33206), already on `:49`. |
| `Data/Guides_DeathKnight.lua:33` | Scourge Strike (55090) in the **Blood** single-target priority | Unholy-only. Blood's spender is Heart Strike (**206930**). |

Fix: replace each with the correct spec's ability (and correct the accompanying
text), or drop the `spellID` and leave free text.

### 7. Guide data — six `spellID`s that do not match the ability named in the text

These will draw the wrong icon and pop the wrong tooltip on hover.

| File:line | Text says | ID given | ID actually is | Correct ID |
| --- | --- | --- | --- | --- |
| `Data/Guides_Mage.lua:98` | Fireball | 2120 | **Flamestrike** | 133 |
| `Data/Guides_DemonHunter.lua:110, 116` | Metamorphosis (tank) | 203720 | **Demon Spikes** | 187827 |
| `Data/Guides_Shaman.lua:152` | Healing Rain | 5394 | **Healing Stream Totem** | 73920 |
| `Data/Guides_Monk.lua:35, 41` | Breath of Fire | 121283 | not Breath of Fire | 115181 |
| `Data/Guides_Shaman.lua:154` | Riptide (re-application) | 61301 | not Riptide | 61295 — and this is a duplicate of `:150`; the line should probably be dropped |
| `Data/Guides_Druid.lua:32` | "Wrath / Starfire" | 194153 | Starfire only | Wrath is 190984; pick one, or drop the ID |

Note `Guides_Mage.lua:105` uses 2120 correctly for Flamestrike, which makes
`:98` an obvious copy/paste slip.

Fix: correct the IDs as above. A cheap guard against the whole class of bug:
add a build-time (or in-game `/sage` debug) check that
`C_Spell.GetSpellInfo(id).name` is a substring of the step's text.

---

## Medium

### 8. Guide data — three abilities that no longer exist in modern retail

- `Data/Guides_Rogue.lua:34, 41, 51` — **Vendetta (79140)** was replaced by
  Deathmark (**360194**) for Assassination in 10.0. It is also referenced in the
  Assassination `consumables` "Potion" text. `C_Spell.GetSpellTexture(79140)`
  will return nothing usable and the tooltip will be empty or a legacy stub.
- `Data/Guides_Mage.lua:33, 54` — **Arcane Power (12042)** was removed in 10.0
  and replaced by Arcane Surge (365350). The guide lists *both*, telling Arcane
  mages to press a button that does not exist and to "pair" it with the one that
  replaced it.
- `Data/Guides_Priest.lua:149` — **Mind Sear (48045)** was removed for Shadow in
  10.0.

Fix: delete/replace these entries. Given the addon's own README promises
"conventional, stable guidance … that survives patch churn", shipping removed
abilities is exactly the failure mode it advertises against.

### 9. `Data/Guides_*.lua` (all 39 specs) — "Flask of Alchemical Chaos (Strength/Agility/Intellect/Stamina)" is not a real item variant

Flask of Alchemical Chaos rotates *secondary* stats; there is no primary-stat
variant of it. 39 of 39 specs carry a parenthetical that does not correspond to
anything a player can buy.

Fix: drop the parenthetical (`"Flask of Alchemical Chaos"`), or name the correct
primary-stat flask for the tier and keep the parenthetical accurate.

### 10. `Data/Guides_Shaman.lua` (Bloodlust 2825) — faction-specific spell ID

2825 is Bloodlust (Horde). Alliance shamans have Heroism (32182). The three
Shaman guides all show the Horde icon and tooltip.

Fix: drop the `spellID` and leave the text `"Bloodlust / Heroism"`, or resolve it
at render time from `UnitFactionGroup("player")`.

### 11. `Data/Guides_Evoker.lua`, `Guides_DemonHunter.lua`, `Guides_Druid.lua`, `Guides_Warlock.lua`, `Guides_Monk.lua`, `Guides_Mage.lua` — spell-icon coverage is wildly uneven across classes

Steps carrying a `spellID` (icon + real tooltip) per file:
Warrior 49/77, Rogue 44/75, Shaman 43/72, Hunter 42/74, Priest 40/68 …
Druid **29/95**, Warlock 27/71, Monk 26/71, DemonHunter **9/49**,
Evoker **4/65**.

Two guides (Warlock Demonology, Evoker Augmentation) have essentially no icons
at all, so those tabs are walls of grey text next to classes that look
illustrated. It reads as unfinished rather than as a stylistic choice.

Fix: backfill `spellID` on at least the named, non-talent-conditional abilities
in the low-coverage files. Roughly: Evoker (Living Flame 361469, Fire Breath
357208, Eternity Surge 359073, Pyre 357211, Dragonrage 375087, Ebon Might 395152,
Prescience 409311, Echo 364343, Dream Breath 355936, Spiritbloom 367226,
Reversion 366155, Rewind 363534, Emerald Communion 370960, Time Dilation 357170),
Demon Hunter (Demon's Bite 162243, Fel Rush 195072, Blade Dance 188499,
Metamorphosis 191427, Immolation Aura 258920, Fracture 263642, Spirit Bomb 247454,
Fel Devastation 212084, Sigil of Flame 204596, Fiery Brand 204021, Demon Spikes
203720), Guardian Druid (Mangle 33917, Thrash 77758, Ironfur 192081, Frenzied
Regeneration 22842, Swipe 213771). Verify each ID against the live build before
committing.

### 12. `Core/Options.lua` — DESIGN.md's "options panel gains Codex settings" was never implemented, and `UI/Codex.lua:49` points users at it anyway

The panel has Display / Stats / Combat / Procs sections only — nothing about the
Codex. Meanwhile every empty guide section renders
`"no guide data yet - /sage config explains how to contribute"`
(`UI/Codex.lua:49`), and `/sage config` opens a panel that says nothing about
contributing.

Fix: either add a Codex section to `BuildPanel` (at minimum a static
`CreateSettingsListSectionHeaderInitializer("Codex")` plus a text/button
initializer explaining `ns.GuideStore:RegisterSpec` and the
`SpecSage/Data/Guides_<Class>.lua` files), or change `NO_DATA_TEXT` to name the
real location, e.g. `"no guide data yet - see SpecSage/Data/Guides_<Class>.lua
to add some"`.

### 13. `Core/Config.lua:116-131` (`MigrateStatVisibility`) — dead migration that cannot ever fire for the users it claims to protect

The comment says "Stat visibility used to live in the shared DB. Move an existing
account-wide choice onto this character the first time it is seen, so upgrading
does not silently reset anyone's layout." But it reads `SpecSageDB.stats.show`,
and `SpecSageDB` is a *brand-new* saved variable created by this addon —
`DEFAULTS.stats` only ever contains `enabled`. A user upgrading from the
predecessor addon has `StatOverlayDB`, which nothing here reads. So the branch is
unreachable in production; the only thing that exercises it is
`tests/run.lua:520`, which writes `SpecSageDB.stats.show` by hand.

Fix: pick one. Either (a) delete the function and the test, and note in the
README that overlay settings do not carry over from StatOverlay; or (b) make it a
real port seam — read `StatOverlayDB` / `StatOverlayCharDB` once on first run and
import `scale`, `width`, `fontSize`, `position`, `pinnedTooltips` and the stat
show-list, guarded by a `migratedFromStatOverlay` flag. (b) is the behaviour the
comment promises.

### 14. `Core/Options.lua:86-204` — Settings variable names use a short, collision-prone `SAGE_` prefix

`Settings.RegisterProxySetting` registers into a client-global setting registry
keyed by the variable string. `SAGE_locked`, `SAGE_scale`, `SAGE_stats`,
`SAGE_combat_enabled` … are short and generic enough that another addon could
plausibly claim them; a collision means one addon's panel silently drives the
other's setting (or the registration is rejected outright).

Fix: rename every variable to a `SpecSage_` prefix (`SpecSage_locked`, …).
There are no saved-variable implications — these are proxy settings backed by
`ns.db`, not stored by the Settings API.

### 15. `UI/Codex.lua:981` — anonymous `ScrollFrame` created from `UIPanelScrollFrameTemplate`

`UIPanelScrollFrameTemplate` historically names its scrollbar `$parentScrollBar`
and `ScrollFrame_OnLoad` resolves it via `_G[self:GetName().."ScrollBar"]` when
`self.ScrollBar` is not set by a `parentKey`. With `name = nil` that is a
`concat` on nil. Modern retail sets the `parentKey`, so this most likely works —
but it is a gratuitous risk on a template Blizzard has reworked twice, and it
cannot be exercised by the mock (`wow_mock.lua:100` ignores `template` entirely).

Fix: give it a name — `CreateFrame("ScrollFrame", "SpecSageCodexScrollFrame",
self.frame, "UIPanelScrollFrameTemplate")` — and add it to `.luacheckrc`
globals. Cheap insurance; must be confirmed in the live client.

### 16. `Modules/Loadouts.lua:120-128` — `C_Traits.GenerateInspectImportString` is called with a `configID`, but it takes a unit token

```lua
for _, fnName in ipairs({ "GenerateImportString", "GenerateInspectImportString" }) do
    local fn = C_Traits[fnName]
    if fn then
        local callOk, result = pcall(fn, configID)
```

`C_Traits.GenerateImportString(configID)` is correct. `GenerateInspectImportString`
takes a *unit* (`"player"`), so the fallback passes a number where a string is
expected: it returns nil or errors, and either way the `pcall` swallows it. The
"fallback chain" is therefore one link long in practice.

The test at `tests/run.lua:998` passes for the wrong reason — the mock's
`GenerateInspectImportString` (`wow_mock.lua:476`) ignores its arguments — and in
any case the first function already succeeds, so the fallback is never taken.

Fix: call it with the right argument, or drop it:

```lua
local ok1, s = pcall(C_Traits.GenerateImportString, configID)
if ok1 and type(s) == "string" and s ~= "" then return s end
if C_Traits.GenerateInspectImportString then
    local ok2, s2 = pcall(C_Traits.GenerateInspectImportString, "player")
    if ok2 and type(s2) == "string" and s2 ~= "" then return s2 end
end
```

### 17. `Modules/Procs.lua:14, 273-277` — a 0.1 s ticker forces a full overlay relayout ~10×/second, forever

`Procs:Update()` runs every 100 ms whenever the procs section is enabled (the
default). It always calls `ns.UI:SetSection("procs", rows, …)`, which sets
`layoutDirty = true` unconditionally, so `UI:Relayout()` runs on the very next
frame — every frame-pair, in and out of combat, whether or not anything changed.
`LayoutSection` then calls `ApplyFont` (a `GameFontNormal:GetFont()` plus
`SetFont`) on two font strings per row, for every row in every section, plus the
`Combat` ticker at 0.25 s doing the same.

That is a few hundred `SetFont` calls a second on an idle character. Not fatal,
but it is the kind of thing that shows up in an addon-CPU profile and gets an
addon a reputation.

Fix, cheapest first:
1. In `UI:SetSection`, only dirty the layout when the row set actually changed
   (compare `#rows` and each row's `label`/`value`/`icon`), or
2. cache the font in `ApplyFont` and skip `SetFont` when size is unchanged, and
3. skip the Procs ticker entirely when there are no watched spells and no
   active auto-procs, restarting it from `UNIT_AURA`.

### 18. `UI/Codex.lua:736-754` (`HideOtherTabWidgets`) — the Add/Copy dialogs are not hidden when the tab or spec changes

`ShowAddDialog` leaves the dialog up; clicking another tab, another spec, or
another class does not close it. `OnAddDialogSave` then writes to
`self.selectedSpecID`, which is whatever the user has since navigated to — so a
loadout typed for Fury can land on Protection.

Fix: call `self:HideAddDialog()` and hide `self.copyDialog` from
`HideOtherTabWidgets` (or from `SelectSpec`/`SelectClass`), or capture
`self.selectedSpecID` into the dialog at `ShowAddDialog` time and use that
captured value in `OnAddDialogSave`.

### 19. `Core/Commands.lua:27` — the help text contains a raw `|a`, which the client's text parser eats

```lua
"  |cffffff00/sage unpin [stat|all]|r - close pinned tooltips",
```

`|a` is the closing token for WoW's atlas markup (`|A:…|a`). An unmatched `|a`
in a chat string is consumed by the parser, so this line renders as something
like `/sage unpin [statll]`.

Fix: escape the pipe (`[stat||all]`) or reword (`[stat or all]`). The README
already dodges this with a markdown escape, so the two are out of sync.

### 20. `UI/Codex.lua:583-618, 665-669` — no `OnEscapePressed` / `OnEnterPressed` on any EditBox

The Codex is in `UISpecialFrames`, so ESC closes the whole window. With a focused
EditBox in the way, ESC's behaviour is ambiguous: at best it closes the Codex out
from under a half-typed loadout, at worst the user is stuck with focus captured
and no way to release it without clicking a button they cannot see (#2).

Fix: on every EditBox,
`box:SetScript("OnEscapePressed", function(b) b:ClearFocus() end)`; on the
single-line name box, `OnEnterPressed` → `self:OnAddDialogSave()`.

### 21. `Modules/Combat.lua:87-112` — `CombatLogGetCurrentEventInfo()` is called two or three times per combat-log event

```lua
local _, subevent, ... = CombatLogGetCurrentEventInfo()
...
local amount = select(damageIndex, CombatLogGetCurrentEventInfo()) or 0
```

Each call returns ~20 values. In a raid, `COMBAT_LOG_EVENT_UNFILTERED` fires
thousands of times a second; doing this twice per damage event (three times for a
damage event the player both dealt and took) is pure waste.

Fix: capture once into locals and `select` from a single call, e.g.

```lua
local function OnCombatLogEvent()
    local _, subevent, _, sourceGUID, _, sourceFlags, _, destGUID,
          _, _, _, p12, p13, p14, p15, p16 = CombatLogGetCurrentEventInfo()
```

then index `p12/p13/p15/p16` by subevent. The existing payload-index table maps
cleanly onto that.

The parsing itself is correct — I verified every index against the real payload
layouts (see "Checked, OK").

### 22. `tests/` — several tests pass for the wrong reason, and the mock hides whole classes of real-client failure

Each of these let a real bug through in this review:

1. **`run.lua:1056-1082`** — the Codex smoke test never asserts that anything is
   *rendered* after the first open; it calls `SelectTab` explicitly before
   checking anything. That is how finding #1 (blank window on open) survived.
   *Fix:* after the first `Toggle()`, assert `#visible rows in Codex.pools.overview > 0`.
2. **`wow_mock.lua:100-206`** — `CreateFrame` ignores `frameType` and `template`
   entirely and grants every frame `SetText`, `SetFontObject`, the whole EditBox
   surface and the whole ScrollFrame surface. Findings #2, #3 and #15 are
   invisible as a result. *Fix:* key the method set off `frameType`, and keep a
   whitelist of known templates so an unknown/misspelled template fails the run
   (the same "strict" philosophy the event table already uses).
3. **`run.lua:64-72`** — addon `print` output during load is captured into
   `addonOutput` and then **never inspected**. A guide file whose entry
   `GuideStore` rejects would print a warning and vanish silently, and the suite
   would still be green. *Fix:* `check(#addonOutput == 0, "no addon warnings at load", addonOutput[1])`.
4. **`run.lua:333-354`** — the shipped-guide loop only walks specs that *are*
   registered, so a data file that drops a spec cannot fail it. *Fix:* assert the
   exact spec count per class (3 each except Druid 4 and Demon Hunter 2, 39
   total) and assert each `statPriority` entry resolves through
   `Stats:GetStatValue`.
5. **`run.lua:211`** — `check(#GuideStore:GetClassSpecs("MONK") >= 0, …)` is a
   tautology (`#t >= 0` is always true), and its comment ("a class nobody has
   registered a guide for") is wrong — Monk has three guides. *Fix:* assert
   `GetClassSpecs("NOTACLASS")` returns an empty table instead.
6. **`wow_mock.lua:349`** — `GetCombatRatingBonus()` ignores its index and always
   returns 4.5, so the melee-vs-spell crit/haste rating index selection in
   `Stats.lua:261-268` is never actually verified. *Fix:* return a function of
   the index.
7. **`wow_mock.lua:448-452`** — `GetSpecializationInfoByID` returns a 7-value
   tuple with `classID` at position 6; the real API returns 6 values with
   `primaryStat` at position 6. Harmless today (the Codex only reads 2 and 4) but
   a trap for the next change. *Fix:* match the real return shape.
8. **`wow_mock.lua:522-528`** — `AuraUtil.ForEachAura` ignores both the `filter`
   and `usePackedAura` arguments, so `HELPFUL` filtering is untested.

---

## Low

23. **`Core/Commands.lua:5-8, 52-55`** — leftover author-internal comments:
    "Codex.lua is owned by a later work package", "UI/Codex.lua is a placeholder
    until a later work package implements it". Codex.lua exists and is complete.
    Embarrassing in a public release. *Fix:* rewrite as "the Codex is optional at
    runtime — a guide pack can be installed without it", or just delete.

24. **`SpecSage.toc:37`** — `Bindings.xml` is listed in the TOC. The client loads
    `Bindings.xml` automatically from the addon folder; listing it as well is at
    best redundant. *Fix:* verify in game that the SpecSage binding appears
    exactly once under Key Bindings; if it appears twice, drop the TOC line.

25. **`.luacheckrc`** — `GetSpellTexture` (used at `UI/Codex.lua:115-116`) is
    missing from `read_globals`, as are `ChatFontNormal`/`UIPanelButtonTemplate`
    globals you will need for #2/#3, and the frame globals
    `SpecSageHoverTooltip`/`SpecSagePinnedTooltip*`. Also note luacheck is not
    installed in this environment, so the config is currently unverified.

26. **`tests/run.lua:67`** — `table.concat({ mock and "" or "" }, "")` is dead
    nonsense that concatenates the empty string onto the front of every captured
    line. *Fix:* delete it.

27. **`Data/Guides_Paladin.lua`** (Retribution cooldowns) and
    **`Data/Guides_Mage.lua`** (Arcane cooldowns) contain entries with no
    `spellID` and vague text — "A talent-granted burst cooldown (varies by build)
    — use alongside your main cooldown window", "Touch of the Magi (talent)".
    Naming the actual talent (Crusade 231895 / Divine Toll; Touch of the Magi
    321507) is strictly more useful and matches the standard set elsewhere.

28. **`UI/Codex.lua:914-949`** — DESIGN.md specifies the class rail as "class
    icon **+ class-coloured name**"; the implementation is icon-only, with the
    class name relegated to a hover tooltip. With `CLASS_RAIL_WIDTH = 40` there is
    no room for the name. Either widen the rail and add the coloured label, or
    update DESIGN.md.

29. **`UI/Tooltips.lua:316-322` / `Core/Commands.lua:299-301`** — `/sage pins`
    prints raw internal pin ids (`stats:armor`, `procs:190319`). Show the row
    label and, for procs, the spell name.

30. **`UI/Codex.lua:995-1041`** — the Codex frame is movable but its position is
    never saved; it recentres every reload. `SpecSageDB` already carries a
    `position` table pattern for the overlay; a `codexPosition` alongside it would
    be four lines.

31. **`UI/Codex.lua:34, 980-993`** — `CONTENT_WIDTH = 480` is hardcoded while the
    scroll frame is anchor-derived at roughly 510px, leaving ~30px of dead space
    on the right of every content tab. *Fix:* set the scroll child's width from
    `scrollFrame:GetWidth()` in an `OnSizeChanged`, or align the constant with the
    real geometry.

32. **`Modules/Loadouts.lua:10` / `Modules/Notes.lua:9`** — `ns.Loadouts` and
    `ns.Notes` are assigned but nothing reads them (`UI/Codex.lua` uses
    `ns:GetModule(...)` everywhere). Harmless, but two ways to reach the same
    module invites drift. Pick one.

33. **`Core/Init.lua:9`** — `ns.version` is computed and never used. Either show it
    (`/sage help` header, or the Codex title) or drop it.

34. **`README.md:120-122`** — the credit links to
    `github.com/Sharpened-Banana/stat-overlay` while `SpecSage.toc:4` gives the
    author as `lonezebra`. Verify the link resolves and the owner is right before
    publishing; a dead credit link is the first thing a reviewer clicks.

35. **`Modules/Combat.lua`** — absorbed damage (`SPELL_ABSORBED`) and absorbed
    healing are not counted, and `SWING_DAMAGE_LANDED` is (correctly) not used.
    Worth a one-line comment saying the omission is deliberate, so the next reader
    does not "fix" it.

---

## Checked, OK

Things that looked suspicious and turned out to be correct — please do not
re-litigate these:

- **`Bindings.xml` exists** and is wired correctly end to end:
  `<Binding name="SPECSAGE_PIN_TOOLTIP" header="SPECSAGE">` matches
  `BINDING_HEADER_SPECSAGE` and `BINDING_NAME_SPECSAGE_PIN_TOOLTIP`
  (`UI/Tooltips.lua:369-370`) and calls the global
  `SpecSage_PinHoveredTooltip()` (`:372`), which is defined before the bindings
  are read. (See #24 for the only nit.)
- **TOC ↔ disk**: all 26 `.lua` files listed in `SpecSage.toc` exist, no file on
  disk is missing from the TOC, and `tests/run.lua`'s `FILES` list matches the
  TOC order exactly.
- **No StatOverlay / `/so` remnants** anywhere under `SpecSage/`. The only
  "StatOverlay" strings are the deliberate credit in `README.md` and the port
  notes in `DESIGN.md`. Saved variables, frame names, slash commands, binding
  names and print prefix are all `SpecSage`.
- **Globals hygiene**: the only globals created are `SpecSageDB`,
  `SpecSageCharDB`, `SLASH_SPECSAGE1/2`, `SlashCmdList.SPECSAGE`,
  `SpecSage_PinHoveredTooltip`, `BINDING_HEADER_SPECSAGE`,
  `BINDING_NAME_SPECSAGE_PIN_TOOLTIP`, and the frame names
  `SpecSageOverlayFrame`, `SpecSageCodexFrame`, `SpecSageHoverTooltip`,
  `SpecSagePinnedTooltipN`. All prefixed or required by the binding/slash system.
- **All 39 retail specs are registered**, with correct class-token pairings and
  correct spec IDs: Warrior 71/72/73, Paladin 65/66/70, Hunter 253/254/255,
  Rogue 259/260/261, Priest 256/257/258, DK 250/251/252, Shaman 262/263/264,
  Mage 62/63/64, Warlock 265/266/267, Monk 268/270/269, Druid 102/103/104/105,
  Demon Hunter 577/581, Evoker 1467/1468/1473. Roles are all correct. Monk's
  registration order (Brewmaster → Mistweaver → Windwalker) and Evoker's
  (Devastation → Preservation → Augmentation) match Blizzard's in-game ordering.
- **Stat key vocabulary is consistent across all three packages.** I ran
  `Stats:GetStatValue` over every key DESIGN.md declares valid — `primary`,
  `crit`, `haste`, `mastery`, `versatility`, `leech`, `avoidance`, `speed`,
  `armor`, `stamina` — and all ten resolve to a formatted value. The
  `versatility`→`vers` / `avoidance`→`avoid` aliasing in
  `Modules/Stats.lua:57-60` covers exactly the two keys that differ from
  `ns.STAT_LIST`, `Data/API.lua:44-47`'s `VALID_STAT_KEYS` matches DESIGN.md
  exactly, and `UI/Codex.lua:54-58`'s `STAT_LABELS` covers the same ten. The
  shipped guides use seven of the ten (`primary`, `crit`, `haste`, `mastery`,
  `versatility` ×39, `stamina` ×6, `avoidance` ×1) and every one resolves.
- **`readers.primary` uses the *player's* primary stat**, which is correct
  because `Codex:RenderStats` only requests live values when
  `IsPlayersSpec(specID)` is true (`UI/Codex.lua:332`).
- **Combat-log parsing is correct.** Verified index by index:
  `CombatLogGetCurrentEventInfo()` positions 2/4/6/8 (subevent, sourceGUID,
  sourceFlags, destGUID) are right, `SWING_DAMAGE` amount at 12,
  `ENVIRONMENTAL_DAMAGE` at 13, `SPELL_*`/`RANGE_DAMAGE`/`DAMAGE_SHIELD`/
  `DAMAGE_SPLIT`/`SPELL_BUILDING_DAMAGE` at 15, `SPELL_HEAL` amount+overhealing
  at 15/16. Pet detection via `AFFILIATION_MINE` AND (`TYPE_PET` OR
  `TYPE_GUARDIAN`) is right, and `TYPE_PET + TYPE_GUARDIAN` is equivalent to
  `bit.bor` here because the bits are disjoint.
- **`AuraUtil.ForEachAura("player", "HELPFUL", nil, cb, true)`** matches the real
  `(unit, filter, maxCount, func, usePackedAura)` signature, and the packed-aura
  field names used (`spellId`, `name`, `icon`, `duration`, `expirationTime`,
  `applications`) are the real ones.
- **API namespace fallbacks are all guarded correctly** and none of them will
  hard-error if the namespaced form is absent: `C_AddOns.GetAddOnMetadata`,
  `C_Spell.GetSpellInfo/GetSpellTexture/GetSpellCooldown`,
  `C_UnitAuras.GetPlayerAuraBySpellID`, `C_SpecializationInfo.GetSpecialization/
  GetSpecializationInfo/GetSpecializationInfoByID`, `C_ClassTalents`, `C_Traits`.
  `C_Spell.GetSpellCooldown`'s table return (`startTime`/`duration`) is handled
  correctly, including the 1.5 s GCD suppression.
- **`GetSpecializationInfoByID` return positions** — `UI/Codex.lua:90` takes
  index 2 (name) and `:101` takes index 4 (icon) out of `pcall`, which is right
  for the real `id, name, description, icon, role, primaryStat`. The `pcall`
  offset (`local ok, _, name = pcall(...)`) is handled correctly in both.
- **Nil-safety on the APIs that legitimately return nil**: `GetSpecialization()`
  returning nil on a fresh/low-level character is handled
  (`Modules/Stats.lua:68-82` falls back to the largest of STR/AGI/INT;
  `Modules/Loadouts.lua:97-104` returns nil);
  `GetSpecializationInfoByID` for an unknown id is `pcall`ed with a `specName`
  fallback; `C_ClassTalents.GetActiveConfigID()` returning nil is handled
  (`Loadouts.lua:115-116`), as is `C_ClassTalents`/`C_Traits` being absent
  entirely.
- **`ns:RegisterEvent`'s `pcall` around `RegisterEvent`** (`Core/Init.lua:52`) is
  the right call: registering an event that does not exist in the running client
  throws, and swallowing that is correct here (it is not hiding a logic error).
  Every event the addon registers exists in retail 11.x: `UNIT_STATS`,
  `UNIT_AURA`, `UNIT_MAXHEALTH`, `UNIT_ATTACK_POWER`, `COMBAT_RATING_UPDATE`,
  `MASTERY_UPDATE`, `SPEED_UPDATE`, `LIFESTEAL_UPDATE`, `AVOIDANCE_UPDATE`,
  `PLAYER_EQUIPMENT_CHANGED`, `PLAYER_AVG_ITEM_LEVEL_UPDATE`,
  `PLAYER_SPECIALIZATION_CHANGED`, `PLAYER_TALENT_UPDATE`,
  `PLAYER_REGEN_ENABLED/DISABLED`, `COMBAT_LOG_EVENT_UNFILTERED`,
  `ADDON_LOADED`, `PLAYER_LOGIN`. The unit-scoped ones are filtered to `"player"`
  by the handlers.
- **`BackdropTemplate` is passed everywhere `SetBackdrop` is called**
  (`UI/Overlay.lua:28`, `UI/Codex.lua:571, 651, 996`). No missing-mixin errors.
- **Load order is sound.** Nothing dereferences another file's symbols at load
  time: `Data/Guides_*.lua` guard on `if not ns.GuideStore then return end`,
  `Core/Commands.lua` reaches `ns.UI` / `ns.Tooltips` / `ns.OpenOptions` /
  `ns.GuideStore` only inside handlers, and `UI/Codex.lua` (loaded before
  `Modules/Loadouts.lua` and `Modules/Stats.lua`) only calls `ns:GetModule` at
  runtime.
- **`ResetConfig` behaviour matches the README**: display settings and this
  character's `statsShow` reset; `loadouts`, `notes` and `chardb.watch` are
  preserved; pins are closed against the old table first
  (`Core/Config.lua:152-156`) so no orphaned frames are left on screen.
- **`Loadouts`/`Notes` storage matches DESIGN.md** —
  `SpecSageDB.loadouts[specID] = { {name, category, export}, … }` and
  `SpecSageDB.notes[specID]`, both account-wide, with numeric spec-ID keys that
  round-trip through WoW's saved-variable serializer. `GetForSpec` returning the
  live table (so index-based `Delete` stays in sync) is deliberate and correct,
  and reading an unsaved spec does not create a DB entry.
- **`Commands.lua` routing matches the real method names** on `Codex`
  (`Toggle`, `Open`), `Combat` (`GetReport`, `ResetSession`), `Procs`
  (`Watch`, `Unwatch`, `ListWatched`, `ScanAuras`), `Tooltips`
  (`Pin`, `PinHovered`, `Unpin`, `UnpinAll`, `ListPinned`) and `UI`
  (`Toggle`, `ResetPosition`). The fuzzy matcher's ambiguity handling
  (`war` → Warrior/Warlock) is correct, and the `Codex not loaded` degradation
  paths work.
- **`Data/Guides_*.lua` are genuinely data-only** — the only statement in any of
  them beyond `RegisterSpec` calls is the `if not ns.GuideStore then return end`
  guard.
- **`GuideStore` validation** rejects non-table guides, unknown class tokens,
  missing/empty `specName`, bad roles and invalid `statPriority` stat keys,
  without erroring, and re-registering a specID updates in place without
  duplicating the ordering slot. Third-party packs cannot take the addon down
  through this entry point.
- **`SpecSage.toc` metadata** is well-formed for 11.x: `## Interface: 110200`
  (TWW 11.2), `## SavedVariables` / `## SavedVariablesPerCharacter` match the
  code, `## IconTexture` points at a real icon, `## Category-enUS` is a valid
  field.
- `luac5.1 -p` passes on all 26 addon files plus both test files;
  `lua5.1 tests/run.lua` reports 456 passed, 0 failed.

---

## Verdict

**Not shippable as it stands, but close — and the blockers are shallow.** The
architecture is genuinely good: the module lifecycle, event bus, section/provider
split between modules and the overlay, and the `GuideStore` validation boundary
are all clean, well-commented and correctly nil-safe against the WoW APIs that
really do return nil. The port is complete — I found no StatOverlay leftovers,
no TOC/disk mismatch, no load-order faults, and the combat-log parsing and stat
key vocabulary are correct across all three packages. What lets it down is that
the Codex — the addon's headline feature and the only genuinely new UI — has
never actually been looked at in the game: it opens blank (#1), and every button
and edit box in it is created without a template or font, so the tab strip, the
loadout controls and the notes area are invisible (#2, #3). The mock's
frame-type-agnostic widget surface made all three unfindable from the test suite,
which is the review's real lesson. Fix findings #1–#5, spend one session with the
addon loaded in a live client to confirm the widget work and the anonymous
ScrollFrame (#15), correct the thirteen wrong or removed spell IDs in #6–#8
(these are the ones that will get the addon publicly called out, since the Codex
shows the game's own tooltip right next to the wrong advice), and clean up the
"later work package" comments (#23). Everything else on the list is worth doing
but can follow a 1.0.1. With those in hand this is a solid, publishable addon.
