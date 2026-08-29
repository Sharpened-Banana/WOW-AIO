# SpecSage — Review #2: BiS / Gear (v1.1)

Scope: `Modules/BiS.lua` (new), `UI/Codex.lua` BiS tab + shared changes,
`Data/API.lua` gear validation, all 13 `Data/Guides_*.lua` gear blocks,
`Core/Config.lua` `bis` default/reset, `tests/wow_mock.lua` additions, and
cross-cutting interaction with Loadouts/Notes.

Verified by running: `lua5.1 tests/run.lua` → **773 passed, 0 failed**;
`luac5.1 -p` on all 27 addon files → clean.

**No Critical findings.** Unlike the previous round, every new Button uses
`UIPanelButtonTemplate`, every new EditBox uses `InputBoxTemplate`, and the
`INVSLOT_*` numbers in `SLOT_INVENTORY_IDS` are all correct against Blizzard's
real inventory slot IDs. The findings below are one High correctness bug, a
handful of Medium live-client-only defects the mock structurally cannot catch,
and Low polish/doc drift.

---

## High

### 1. `Weapon` maps to main-hand only, so dual-wield BiS entries always report "missing"
**`SpecSage/Modules/BiS.lua:41`**

```lua
Ring = { 11, 12 }, Trinket = { 13, 14 }, Weapon = { 16 }, ["Off-hand"] = { 17 },
```

`Ring` and `Trinket` correctly fan out to both of their inventory slots, but
`Weapon` only checks `INVSLOT_MAINHAND` (16). The shipped gear guidance itself
tells dual-wield specs to use two weapons under the single `Weapon` slot — e.g.
`Guides_Warrior.lua:142` ("Two matched, high item level one-handers"), and the
same pattern for Frost DK, Enhancement, Windwalker, Havoc, and every Rogue spec.

In the real client a player who adds both of their weapons to the checklist
under `Weapon` gets one row correctly showing green "equipped" and the other
permanently showing grey "missing" while it is visibly equipped in their
off-hand. That is a wrong answer from the feature's headline function, not a
degradation.

The tests never exercise `Weapon` at all (`tests/run.lua:1264-1299` covers only
Head→1, Ring→12, Off-hand→17), so nothing catches it.

**Fix:** `Weapon = { 16, 17 }`. Off-hand stays `{ 17 }` (a shield/held-in-off-hand
entry filed under `Off-hand` is still correct, and an item in 17 legitimately
satisfies either). Add a test that equips a one-hander in slot 17 and asserts a
`Weapon` entry reports `"equipped"`, plus a test for each remaining slot number
(2,3,5,6,7,8,9,10,15) so the whole table is covered rather than three entries of it.

---

## Medium

### 2. `GetItemInfo`'s real asynchrony is never actually handled — only claimed
**`SpecSage/Modules/BiS.lua:55-63, 82-89, 170-182`; `tests/wow_mock.lua:715-728, 339-352`**

The "store the ID, lazily re-resolve on render" pattern is implemented exactly
as `ResolveDisplay` describes, and it is safe (no error, no wrong data). But it
is *incomplete* for the live client in a way the mock hides:

- `ParseItemText` (line 82-89) stores `"Item 12345"` as the name when the client
  has not cached the item.
- `OnBiSAddClicked` (`UI/Codex.lua:597`) re-renders **immediately**. In the real
  client, the `GetItemInfo` call inside `ParseItemText` has only just *queued*
  the server request; the re-render's `ResolveDisplay` call still returns nil.
  So the row the player sees right after adding says `[Neck] Item 12345` in
  neutral grey, with no quality colour — and stays that way until the player
  happens to switch tab or spec again some time later.
- Nothing registers `GET_ITEM_INFO_RECEIVED`, and nothing calls
  `C_Item.RequestLoadItemDataByID`, so there is no event that would trigger the
  "lazy" re-resolve.

The mock cannot surface this: `tests/wow_mock.lua:721` is a pure synchronous
lookup that either always knows an item or never does. The test at
`tests/run.lua:1200-1218` simulates the async transition by *manually* inserting
into `mock.items` between two calls — it proves `ResolveDisplay` re-reads, but
not that anything in the addon ever calls it again on its own.

**Fix:** in `Modules/BiS.lua`, call `C_Item.RequestLoadItemDataByID(itemID)`
(pcall-wrapped, with a `C_Item and C_Item.RequestLoadItemDataByID` guard) for
any entry whose name is still unresolved, and have the Codex re-render the BiS
tab on `GET_ITEM_INFO_RECEIVED` when the received itemID is in the viewed spec's
list. This requires adding `"GET_ITEM_INFO_RECEIVED"` to
`tests/wow_mock.lua`'s `KNOWN_EVENTS` (line 339-352) — the strict mock currently
*blocks* the fix, since `ns:RegisterEvent` would assert on the unknown name.

### 3. The mock cannot catch a wrong inventory slot number — the exact "permissive mock hides a live bug" pattern from round 1
**`tests/wow_mock.lua:741-748`; `tests/run.lua:1264-1299`**

```lua
mock.equipped = {}
function GetInventoryItemID(unit, invSlot)
    if unit ~= "player" then return nil end
    return mock.equipped[invSlot]
end
```

The mock has no independent notion of Blizzard's slot numbering — it is a bare
number→itemID map, and the tests populate it with the *same literals*
`Modules/BiS.lua` uses. If `SLOT_INVENTORY_IDS` said `Back = { 16 }` or
`Waist = { 7 }`, the suite would still pass as long as the test set the matching
key. This is structurally the same weakness that let untemplated widgets pass in
the previous round: the mock accepts whatever the code asserts.

(I hand-verified the table against the real constants: Head 1, Neck 2, Shoulder 3,
Chest 5, Waist 6, Legs 7, Feet 8, Wrist 9, Hands 10, Finger1/2 11/12,
Trinket1/2 13/14, Back 15, MainHand 16, OffHand 17 — all correct. But nothing in
the repo protects that.)

**Fix:** define the real `INVSLOT_HEAD … INVSLOT_OFFHAND` globals in the mock
(they exist in the live client), have `Modules/BiS.lua` build
`SLOT_INVENTORY_IDS` from those named constants with a numeric fallback, and
have `tests/run.lua` index `mock.equipped` by the constant name rather than a
literal. Then a wrong number becomes a naming mismatch instead of a
self-consistent tautology. Add `INVSLOT_*` to `.luacheckrc`'s `read_globals`.

### 4. BiS row item text is unbounded and will draw over the status tag and Delete button
**`SpecSage/UI/Codex.lua:510-521`**

```lua
row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
row.text:SetJustifyH("LEFT")
row.text:SetPoint("LEFT", row, "LEFT", 0, 0)
```

`row.text` is anchored only on its left with no `SetWidth`, no
`SetWordWrap(false)`, and no truncation, inside a row that also carries
`row.status` at `RIGHT -58` and a 50px Delete button at `RIGHT 0`. Real item
names are short enough to be safe, but a **plain-name entry is arbitrary user
text** — and `self.bisItemBox` (line 552) has no `SetMaxLetters`, so a player can
type a 300-character sentence. FontStrings do not clip to their parent frame, so
that text renders straight through the status tag and the Delete button.
`AcquireLoadoutRow` (line 735-737) has the same shape, so this is a shared
pattern worth fixing once.

The mock does no layout at all, so no test can see this.

**Fix:** `row.text:SetWidth(width - 120)` when the row is sized in `RenderBiS`
(line 673), plus `pcall(row.text.SetWordWrap, row.text, false)` at creation so
overlong text ellipsises on one line. Optionally `itemBox:SetMaxLetters(255)`.

### 5. The BiS Add box is not cleared or unfocused on spec/tab switch — entries can land on the wrong spec
**`SpecSage/UI/Codex.lua:1225-1241` (`SelectSpec`), `1243-1257` (`SelectTab`), `1061-1068` (`HideOtherTabWidgets`)**

`SelectSpec` was deliberately hardened for exactly this class of bug — it flushes
the Notes buffer and closes the Add/Copy dialogs so nothing writes against the
wrong spec. The BiS Add row was not given the same treatment:

- Typed-but-not-yet-added text in `self.bisItemBox` survives a spec switch. Type
  an item while viewing Fury, click Arms in the spec rail, click **Add** → the
  entry silently lands on Arms. There is no visible cue that the box's contents
  belong to the previous spec, whereas `ShowAddDialog` (line 939-946) resets its
  boxes on every open.
- `HideOtherTabWidgets` calls `self.bisItemBox:Hide()` without `ClearFocus()`.
  A focused EditBox that is hidden without releasing keyboard focus is a
  long-standing source of "my keybinds stopped working" reports; it costs one
  line to be certain. (`self.notesBox` at line 1080 has the same omission — it
  is flushed via `SaveNotes` but never unfocused.)

**Fix:** in `SelectSpec` and `SelectTab`, alongside the existing
`SaveNotes`/`HideAddDialog` calls, add
`if self.bisItemBox then self.bisItemBox:ClearFocus(); self.bisItemBox:SetText("") end`.
In `HideOtherTabWidgets`, call `ClearFocus()` before `Hide()` on both
`self.bisItemBox` and `self.notesBox`.

### 6. `GetStatus` rescans all five bags per row, per render
**`SpecSage/Modules/BiS.lua:209-224`; called from `SpecSage/UI/Codex.lua:682`**

Each `GetStatus` call walks bags 0-4 and every slot in them. A full 14-slot
checklist on the player's own spec is up to ~14 × 5 × 36 ≈ 2,500
`C_Container.GetContainerItemID` calls on every BiS render — and a render happens
on every tab switch, spec switch, add, and delete. It is not per-frame so it will
not visibly stutter, but it is wasteful for no reason, and it is invisible in
tests because `mock.bags` is empty by default (`tests/wow_mock.lua:754`), making
`GetContainerNumSlots` return 0 and the whole loop a no-op.

**Fix:** build a `{ [itemID] = true }` bag set once at the top of `RenderBiS` and
pass it into `GetStatus`, or add a `BiS:ScanBags()` helper the Codex calls once
per render. Keep the existing per-entry path as the fallback signature so the
module stays independently testable.

---

## Low

### 7. `ValidateGear` accepts whitespace-only text where the rest of the addon trims
**`SpecSage/Data/API.lua:110-112`**

```lua
if type(entry.text) ~= "string" or entry.text == "" then
```

`{ slot = "Head", text = "   " }` passes validation and renders as
`"Head:    "` in the BiS tab. `Modules/BiS.lua:120` and `Modules/Loadouts.lua`
both use `Trim(x) == ""` for the equivalent check. `Data/API.lua` has no `Trim`
helper yet, which is presumably why.

Everything else about the gear validation is right and matches the file's
established pattern: bad slot rejected, missing text rejected, `gear == nil`
accepted, and — importantly — **one bad gear entry rejects the whole guide**
(`ValidateGuide` line 144-147 returns false → `RegisterSpec` line 159-165 prints
and returns without touching storage), identical to `statPriority`. Tests at
`tests/run.lua:306-334` confirm the guide is not stored.

**Fix:** add a local `Trim` and use `Trim(entry.text) == ""`.

### 8. DESIGN.md's stated frame sizing no longer matches the code
**`DESIGN.md:206-209` vs `SpecSage/UI/Codex.lua:54, 61`**

DESIGN.md still says `FRAME_WIDTH` widens to **960** and `CONTENT_WIDTH` grows by
**60px**. The code uses **984 / +84** and carries an eight-line comment
(`Codex.lua:45-53`) explaining that DESIGN.md's +60 was arithmetically wrong —
the tab strip is a separate geometry chain and 8 tabs at 84/86 need 686px, which
+60 left 16px short.

The code and its test (`tests/run.lua:1429-1441`) are correct; I re-derived it:
strip spans x=282 (120 rail + 4 gap + 150 rail + 8 gap) to x=976 (984 − 8) =
694px available vs 686 needed. `CONTENT_WIDTH` 674 likewise matches the scroll
frame's real geometry (984 − 282 − 28). The problem is that the *spec* is now
wrong and will mislead the next agent.

**Fix:** update DESIGN.md's "BiS / Gear (v1.1)" paragraph to 984 / +84 with the
tab-strip reasoning, so the code comment's correction is not the only record.

### 9. DESIGN.md's Codex section still lists the 7-tab strip
**`DESIGN.md:222-223`** — "tab strip — **Overview | Stats | Rotation | Cooldowns |
Consumables | Loadouts | Notes**" contradicts line 206-207's 8-tab list in the
same document. Add `BiS`. (Line 216's "~740x520" is also stale, pre-existing.)

### 10. The `note` field is storable but unreachable from the UI
**`SpecSage/Modules/BiS.lua:113, 138-141`; `SpecSage/UI/Codex.lua:677`**

`BiS:Add` accepts and stores a `note`, and the DESIGN storage schema includes it,
but the Add row has no note input and `RenderBiS` never renders `entry.note`. The
field is dead in practice — a player can only get one there by hand-editing
SavedVariables. Either surface it (append `|cff888888 — note|r` to the row text)
or drop the parameter; leaving it half-wired invites a future agent to assume it
works.

### 11. Clicking **Add** with an empty box prints an error to chat
**`SpecSage/UI/Codex.lua:588-601`** — an empty/whitespace box makes `BiS:Add`
return `false, "itemText must be a non-empty string"` and `OnBiSAddClicked` pipes
that straight to `ns.Print`. Guard with an early return on empty input so a stray
click is a no-op rather than chat spam.

### 12. `RenderBiS` calls `FinishPool` mid-render
**`SpecSage/UI/Codex.lua:644`** — `FinishPool` sets `scrollChild:SetHeight()` from
a `y` cursor that is only partway down the tab, and line 722-723 immediately
overwrites it with the correct value. Harmless today, but it reads as if the
render is finished when it is not. Split out a `HidePoolTail(pool, n)` for the
mid-render case and keep `FinishPool` for the actual end.

### 13. Item-link regex requires a colon immediately after the itemID
**`SpecSage/Modules/BiS.lua:72`** — `"Hitem:(%d+):.-|h%[(.-)%]"`. Every real
`|Hitem:` link has trailing fields, so this is fine in practice, but a
hand-typed or truncated `|Hitem:12345|h[Name]|h` falls through to the plain-name
branch and stores the whole escape sequence as the display name, which then
renders as raw markup. Cheap hardening: `"Hitem:(%d+)[:|]"` for the ID and a
separate `"|h%[(.-)%]"` for the name.

### 14. No test asserts that shipped guides *have* a gear block
**`tests/run.lua:401-453`** asserts every shipped guide has a `specName` and a
non-empty `rotation`, and that all 39 register (which does prove all 39 gear
blocks validate). But nothing asserts `guide.gear` is present and non-empty, so a
future edit could silently drop one and every BiS tab for that spec would fall
back to the NO_DATA line with a green suite. Add
`check(guide.gear and #guide.gear > 0, ...)` to that loop.

### 15. `## Version: 1.0.0` unchanged in the TOC
**`SpecSage/SpecSage.toc:5`** — DESIGN.md calls this feature v1.1 and README
documents it as shipped. Bump to 1.1.0; the Codex title reads
`ns.version` (`Codex.lua:1394`) so the window will show a stale version.
`## Notes:` (line 3) also does not mention BiS/gear.

### 16. `CycleBiSSlot` / `OnBiSAddClicked` assume `EnsureBiSWidgets` has run
**`SpecSage/UI/Codex.lua:572-586, 588-601`** — both dereference `self.bisButtons` /
`self.bisItemBox` unguarded. Unreachable today (they are only wired to widgets
that do not exist until after the first `RenderBiS`), but they are public methods
on the module. `OnDeleteBiSClicked` (line 605-620) likewise calls
`BiSModule:Delete` without a nil guard — matching `OnDeleteLoadoutClicked`, so
consistent, but consistently unguarded.

### 17. BiS status does not refresh on equipment change
**`SpecSage/UI/Codex.lua:681-688`** — equip a listed item with the Codex open on
the BiS tab and the tag stays "in bags"/"missing" until the player switches tab or
spec. `PLAYER_EQUIPMENT_CHANGED` is already a known event (the Stats module uses
it and it is in the mock's `KNOWN_EVENTS`), so a one-line re-render hook when the
BiS tab is active would close it. Not required by DESIGN.md.

---

## Checked, OK — do not redo

**Modules/BiS.lua**
- `SLOT_INVENTORY_IDS` numbers (line 38-42) verified against Blizzard's real
  `INVSLOT_*` values for all 14 slots. Ring 11/12 and Trinket 13/14 correctly fan
  out to both slots; Off-hand 17 correct. Only `Weapon` is wrong (finding #1).
- `C_Item.GetItemInfo` return-position unpacking (line 60): `local ok, name, _, quality = pcall(...)`
  correctly takes `itemName` at 1 and `itemQuality` at 3 of the real multi-return.
  The mock (`wow_mock.lua:724-726`) models 11 positions in the right order, so a
  wrong index *would* be caught.
- `C_Container.GetContainerNumSlots(bag)` / `GetContainerItemID(bag, slot)`
  signatures are correct, and the 1-based slot iteration (line 215) matches the
  real API. Bags 0-4 is the right range (reagent bag 5 cannot hold gear).
- Every real-client API call is pcall-wrapped: `ResolveItemInfo` (60), the
  equipped scan (198), the bag scan (210). Failure degrades to `"missing"`, never
  an error, and it is documented.
- `Trim` (line 51-53) is correctly parenthesised for Lua 5.1's multi-return
  truncation; both `gsub` results are discarded.
- Validate-and-return-false contract on `Add`/`Delete` matches Loadouts and
  Data/API.lua. `GetForSpec` returns the live table when one exists and a fresh
  empty table otherwise, so reading an untouched spec creates no DB clutter
  (asserted at `tests/run.lua:1160-1161`).
- No new globals. `BiS.SLOT_ORDER` / `BiS.VALID_SLOTS` are module-table fields;
  everything else is file-local. No `ns.BiS` alias, matching Loadouts/Notes.
- Module is registered in the TOC (`SpecSage.toc`, after Loadouts) and loads after
  `UI/Codex.lua`, which is safe because Codex resolves it via `ns:GetModule("BiS")`
  at call time, never at load time.

**UI/Codex.lua**
- Every new Button uses `UIPanelButtonTemplate` (delete 518, slot cycler 548, add
  558). Every new EditBox uses `InputBoxTemplate` (552). Every new FontString uses
  a real font object (`GameFontHighlightSmall` / `GameFontNormalSmall`). The mock's
  `KNOWN_TEMPLATES` / `BUTTON_TEXT_TEMPLATES` gates (`wow_mock.lua:115-130`,
  `280-311`) would have caught an untemplated one — this is the round-1 bug class
  and it did not recur.
- The BiS tab adds no dialog, so there is no Show-before-Focus hazard. The one
  existing focus path (`ShowCopyDialog`, line 995-1004) still shows first, and the
  mock still asserts it (`SetFocus` on a hidden widget throws, `wow_mock.lua:250-257`).
- Frame/content geometry: FRAME_WIDTH 984 gives the tab strip 694px for 686px of
  tabs; CONTENT_WIDTH 674 exactly equals the scroll frame's real width. Verified
  by hand and by `tests/run.lua:1424-1441`. Vertically the 13-class rail ends at
  −392 inside a 520px frame; the strip and scroll area do not collide.
- The BiS tab is **not** two-column — it is a single vertical stack (guidance →
  divider → checklist → Add row) sharing one `y` cursor, which is what DESIGN.md
  actually specifies ("rows on top … then a divider, then the personal
  checklist"). I traced the cursor through all four sections: no overlap, and the
  Add row's 90 + 8 + 300 + 8 + 60 = 466px fits in 674px.
- No widget leak or duplication across tab/spec switch: `POOL_BY_TAB` includes
  `bis` (line 1052), and `HideOtherTabWidgets` (1054-1082) hides the BiS pool, the
  BiS row pool, and all three Add-row widgets whenever the active tab is not BiS.
  The empty-checklist branch (655-667) and the populated branch (669-701) both
  hide the pool tail, and the empty branch's `deleteButton:Hide()` is correctly
  re-`Show()`n by the populated branch.
- Per-row delete: two-click confirm with a 4s `C_Timer.After` reset, identical to
  the loadout path, and the closure is rebound every render so a shifted index
  after a delete cannot go stale.
- Per-row tooltip uses the real `GameTooltip:SetItemByID`, pcall-wrapped, with an
  early return when the entry has no itemID — same shared-GameTooltip approach as
  rotation/cooldown rows, which DESIGN.md permits (the Codex has no pinning).
- `ItemQualityColor` (line 180-184) guards a nil quality and a missing
  `ITEM_QUALITY_COLORS` and falls back to neutral grey.
- Shift-clicking an item into the Add box: FrameXML's `ChatEdit_InsertLink` falls
  back to `GetCurrentKeyBoardFocus()`, so a focused custom EditBox does receive
  the link — the README's documented flow works. Untested, and it does require the
  player to click into the box first (`SetAutoFocus(false)`); no change needed.

**Data/API.lua**
- `VALID_GEAR_SLOTS` (56-60) is exactly the 14-slot vocabulary from DESIGN.md and
  matches `BiS.SLOT_ORDER` element for element, including the hyphenated
  `["Off-hand"]` key.
- A bad slot, a missing/empty `text`, or a non-table entry rejects the **entire
  guide**, matching the `statPriority` precedent. `gear == nil` is accepted so
  pre-v1.1 guides still register. Repeated slots (two Trinket lines) are allowed,
  as specified. All covered by tests at `run.lua:278-334`.

**Data/Guides_*.lua** — I parsed every `gear = { … }` block across all 13 files:
- **39 gear blocks / 320 entries — one for every shipped spec**, all 39 registering
  successfully (`run.lua:453` asserts exactly 39 shipped specs).
- **Every slot value is valid**: Head 39, Neck 39, Ring 39, Weapon 39, Trinket 78
  (two per spec), Off-hand 22, Legs 21, Back 21, Chest 18, Waist 3, Feet 1. No
  invalid or typo'd slot anywhere.
- **No leaked item data.** I extracted every capitalised proper noun across all 320
  entries and classified them: every one is a stat name (Mastery, Critical Strike,
  Haste, Versatility, Stamina, Intellect, Agility, Strength), a resource
  (Holy Power, Runic Power, Astral Power, Maelstrom, Chi, Insanity, Essence,
  Fury, Pain, Stagger), or a **spell/ability** name (Colossus Smash, Pillar of
  Frost, Wake of Ashes, Breath of Eons, Thunder Focus Tea, Shield of the
  Righteous, Fingers of Frost, Army of the Dead, …). Zero item names, zero
  itemIDs, zero item links, zero dungeon/raid/boss references, zero
  patch-specific gear. The "guidance only, never real items" instruction held
  across all 13 files.
- Grepped the whole tree for `wowhead|archon|method|icy-?veins|bloodmallet|raidbots|subcreation|scrape`
  — only prose in README.md/DESIGN.md explaining that SpecSage deliberately does
  *not* use them.

**Core/Config.lua**
- `bis = {}` default present (line 74-76) and reached by `CopyDefaults`, so an
  existing v1.0 SavedVariables file gains the key on first load.
- `ResetConfig` (line 137-155) stashes `bis` alongside `loadouts` and `notes`
  before the rebuild and restores it after — the same three-way check the
  previous review used. `ns.db` is reassigned to the new table and `BiS` reads
  `ns.db.bis` at call time, so no stale reference survives.
- Asserted end-to-end at `tests/run.lua:1029-1034`.

**tests/wow_mock.lua**
- `C_Item.GetItemInfo` return shape is faithful for the positions the addon reads
  (finding #2 is about behaviour, not shape).
- `ITEM_QUALITY_COLORS` 0-5 with `r/g/b` matches the real global's shape; the
  addon nil-guards indices 6-8 that the mock omits.
- `C_Container.*` signatures are correct and 1-based.
- `GameTooltip:SetItemByID` records the itemID so the hover test is real.
- The strict `KNOWN_TEMPLATES` / `BUTTON_TEXT_TEMPLATES` / font-required-for-SetText
  gates from round 1 are intact and still doing their job for the new widgets.

**Cross-cutting**
- No global-namespace collision: `Modules/BiS.lua` declares nothing global, and
  the Codex adds no new named frames (`SpecSageCodexFrame` /
  `SpecSageCodexScrollFrame` are unchanged and both are already in `.luacheckrc`).
  `.luacheckrc` correctly gained `C_Item`, `C_Container`, `GetItemInfo`,
  `GetInventoryItemID`, `GetContainerNumSlots`, `GetContainerItemID`,
  `ITEM_QUALITY_COLORS`.
- BiS does not disturb the Loadouts/Notes save-on-switch pattern; `SaveNotes` and
  the dialog teardown in `SelectSpec`/`SelectTab` still run first. The one gap is
  that BiS did not get the same treatment (finding #5).
- `/sage reset all` → `ns.ResetConfig` preserves `bis` (see above).

---

## Verdict

**Yes — shippable after the listed fixes, and the originality claim holds up
cleanly.** There is no Critical defect this round: the frame-template and
font-object discipline that the previous review established was carried into the
BiS tab without exception, the inventory-slot table is 13/14 correct, every
game-API call is pcall-wrapped, and `bis` genuinely survives `ResetConfig`. The
one substantive correctness bug is #1 — `Weapon` checking only the main-hand
slot, which makes the feature give a visibly wrong answer to every dual-wield
spec, including specs whose own shipped guidance tells them to list two weapons —
and it is a one-token fix plus a test. Everything else is either a live-client-only
degradation the current mock cannot express (#2, #3, #6) or polish. The pattern
worth internalising is that the mock is now strict about *widget surface* but
still permissive about *game semantics*: it will catch a button with no font
string, but not a wrong inventory slot number or a synchronous assumption about
an async API, so those need either real constants in the mock or explicit
adversarial fixtures. On originality: I parsed all 320 gear entries across all 13
data files and found zero item names, itemIDs, links, or dungeon/raid references
— every proper noun is a stat, a resource, or a class ability. The shipped half is
genuinely durable "what to look for in this slot" guidance in the addon's own
words, and the volatile half is a checklist the player fills from whatever source
they trust, which is exactly the split DESIGN.md argues for and a defensible
alternative to re-shipping scraped BiS tables every patch.
