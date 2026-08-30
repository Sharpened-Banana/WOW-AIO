# SpecSage — Review 3 (Midnight 12.1 bump + `mplusLoadout` v1.2)

Reviewer: senior review pass, review-only (no files changed except this one; no git commands run).
Verified builds: `lua5.1 tests/run.lua` → **847 passed, 0 failed**; `luac5.1 -p` clean on all 26 addon files.

Ordered by severity. Each item: `file:line` → problem → why it matters → suggested fix.

---

## CRITICAL

### 1. All 31 shipped `mplusLoadout.string` values have a real Blizzard *header* but a fabricated *payload*. They are not SimulationCraft talent builds and will import as garbage.

**Where:** every `string = "..."` in the 13 guide files —
`Guides_DeathKnight.lua:88,164,241` · `Guides_DemonHunter.lua:85,163` · `Guides_Druid.lua:84,160,237` ·
`Guides_Evoker.lua:83` · `Guides_Hunter.lua:81,157,233` · `Guides_Mage.lua:82,158,234` ·
`Guides_Monk.lua:86,227` · `Guides_Paladin.lua:157,233` · `Guides_Priest.lua:218` ·
`Guides_Rogue.lua:82,158,234` · `Guides_Shaman.lua:86,163` · `Guides_Warlock.lua:84,159,233` ·
`Guides_Warrior.lua:83,159,243`.

**What passes.** I decoded every string against Blizzard's `ClassTalentImportExportMixin` format
(base64 alphabet `A-Za-z0-9+/`, LSB-first bit packing, 8-bit serialization version, 16-bit specID,
128-bit tree hash, then the node stream). The header is genuine and correctly built in all 31:

* serialization version = **2** in all 31;
* embedded specID **matches the declared `RegisterSpec` specID in all 31** (Arms→71, Fury→72,
  Blood→250, Havoc→577, Devastation→1467, …) — not one is mispaired;
* the 128-bit tree hash is **all zeros** in all 31, which is *legal*: Blizzard's importer runs
  `IsHashEmpty(treeHash)` and skips hash validation when it is empty. So the client will happily
  accept these strings;
* all 31 strings are distinct — no copy-paste between specs.

**What fails.** Everything after bit 152 is filler, under *both* known variants of the node encoding:

| check | DF-era format `sel[part[ranks6] choice[idx6]]` | TWW format (extra `isNodePurchased` bit) |
|---|---|---|
| `ranksPurchased` outside legal 1..3 | **862 of 884 illegal** (values 0, 12, 24, 32, 44, 48, 50, 54, 60 …) | 0 of 7 illegal, but only 7 values decoded at all |
| `choiceEntryIndex` outside legal 0..2 | **366 of 409 illegal** (values 5, 12, 17, 24, 25, 33, 37, 44, 49, 54, 57 …) | **266 of 310 illegal** |

`ranksPurchased == 0` is *impossible* by construction (a 0-rank node is written as not-selected),
and no retail talent node exceeds 3 ranks. Choice nodes have 2 (rarely 3) entries.

A format-**independent** check is even more damning: every spec of a class serializes the *same*
`C_Traits.GetTreeNodes(treeID)` list, so the decoded node count must be identical across a class's
specs. It differs for all 11 multi-spec classes under both variants — Warrior 138/140/132,
Death Knight 133/135/140, Druid 210/208/213, Rogue 132/142/137, Mage 136/142/144, Warlock 129/122/126.

Finally, the payload alphabet uses only **44 of 64** base64 characters and is dominated by a handful
of two-character motifs — of 2,393 payload bigrams, `AA`×289, `mZ`×105, `Mz`×101, `zM`×97, `Zm`×55.
Real talent bitstreams do not look like that. This is mechanically generated filler with a
hand-correct header bolted on the front.

**Why it matters.** This is the single value the whole v1.2 feature exists to ship, and it is wrong
for all 31 specs — in the worst possible way. Because the tree hash is empty, the client *will not
reject it*: the user clicks **Add to my vault** → **Copy** → imports, and silently receives a
nonsense talent tree rather than an error. Worse, it falsifies claims the addon makes to the user in
three places: the guide-file headers ("cross-checked against SimulationCraft's public default
profiles"), the `source` string in all 31 tables, and the in-UI row label "via SimulationCraft".
Shipping a build that claims a provenance it does not have is a bigger problem than shipping no
build at all.

**Fix.** Regenerate every string from a real source — an in-client `C_Traits` export, or a verified
`talents=` line from the actual SimC profile — and, critically, **add a decoder assertion to
`tests/run.lua`** so this can never recur: for each shipped `mplusLoadout`, assert the string is pure
base64, that bits 0..7 decode to the expected serialization version, that bits 8..23 equal the
`RegisterSpec` specID, and that the node stream parses to a per-class-constant node count with all
`ranksPurchased` in 1..3 and all choice indices in 0..2. The header check alone is ~15 lines of Lua
and is a permanent guard against a mispaired string. Until strings are regenerated, the honest
option is to drop `mplusLoadout` from the shipped data entirely — the Codex already handles absence
correctly (`Codex.lua:958-959`).

---

## HIGH

### 2. `Guides_Druid.lua:86,162,239`, `Guides_Paladin.lua:235`, `Guides_Evoker.lua:85` — the MID1 fallback stuffs a 62-character sentence into `patch`, which the Codex renders into an unbounded single-line label that overruns both row buttons.

```lua
patch = "12.0 (MID1 — SimC has not yet published a MID2 profile for this spec)",
```

`Codex.lua:944` does `format("Suggested Mythic+ (via SimulationCraft, patch %s)", mplusLoadout.patch)`.
That yields a **116-character** label for these 5 specs versus 51 for the others. The FontString at
`Codex.lua:852-854` is created with only a `LEFT` anchor and **no `SetWidth`** — an unsized
FontString auto-sizes to its text on one line and does not wrap. With `CONTENT_WIDTH = 674` and the
buttons anchored to the row's RIGHT (`addButton` at `RIGHT,-58` width 110 → x 506..616; `copyButton`
anchored to its LEFT -8, width 50 → x 448..498), the label has ~448px of clear space. 116 chars in
`GameFontHighlightSmall` is roughly 600-640px, so the text runs *under* the Copy and Add buttons and
past the row's right edge. Note the codebase already knows the fix — `Codex.lua:725,740` set
`row.text:SetWidth(width - BIS_ROW_TEXT_WIDTH_INSET)` on BiS rows — it just wasn't applied here.

Two further problems with the same field:

* It violates the documented schema. `DESIGN.md:234` defines `patch` as *"the game patch it was
  pulled for"* with the example `"12.1"`. A caveat sentence is not a patch identifier, and any
  third-party guide pack or future consumer that parses/compares `patch` breaks on it.
* **The "MID1 fallback label" is documented nowhere.** `grep -rn "MID1\|MID2"` across the whole repo
  hits only these 5 data lines — not `DESIGN.md`, not `README.md`, not `API.lua`, not the tests. The
  review brief calls it "the documented MID1-fallback label"; it is not documented. A reader has no
  way to know what MID1/MID2 mean.

**Fix.** Keep `patch = "12.0"` and move the caveat to a new optional `note` field (validated the same
way, rendered on its own muted line, or as a tooltip on the row). Add `SetWidth` to the suggested
row's and saved rows' `name` FontStrings regardless. Document the MID1/MID2 vocabulary in
`DESIGN.md`'s v1.2 section, or drop it in favour of plain patch numbers.

### 3. No `LICENSE` file anywhere, and `README.md:136-139` ("Credits") never mentions SimulationCraft or GPLv3 — the "credited" promise in `DESIGN.md:228` is only half-kept, and `source` is dead data.

The repo root contains no `LICENSE`/`COPYING` (`find . -iname '*licen*'` → nothing), the `.toc` has no
`## X-License`, and README's Credits section names only StatOverlay. The only user-reachable credit is
the Codex row label at `Codex.lua:944`. Meanwhile the `source` field — present and byte-identical to
DESIGN.md's wording in all 31 entries — **is never read by any code**: `grep -rn "\.source" SpecSage/`
returns nothing. It is documentation that no user will ever see.

**Why it matters.** Shipping GPLv3-derived data inside an otherwise unlicensed addon, with the
attribution living only in a Lua string nobody renders, is exactly the licensing hygiene this design
section was written to avoid. (This is orthogonal to finding #1: if the strings *were* real, this
would be the live risk; because they are not, the addon currently credits SimC for data SimC did not
produce, which is its own problem.)

**Fix.** Add a `LICENSE` file for SpecSage's own code, add a short "Talent loadouts" paragraph to
README's Credits naming `github.com/simulationcraft/simc` and GPLv3, and either render `source`
(muted second line or row tooltip) or drop the field so it is not mistaken for a discharged
obligation.

### 4. All 13 guide file headers (lines 4-8) claim the *rotation priorities* were derived from SimulationCraft — contradicting the v1.2 design boundary that only the talent string comes from SimC.

```
-- Content targets Midnight (patch 12.1). Mythic+ talent loadouts and rotation
-- priorities were cross-checked against SimulationCraft's public default
-- profiles (github.com/simulationcraft/simc, GPLv3) as of patch 12.1;
```

`DESIGN.md:218-246` is explicit that a talent string is shippable precisely *because* it is a thin
configuration, "unlike prose or an Action Priority List's conditional logic". This header asserts in
writing, in 13 files, that the prose rotation priorities were checked against SimC's APLs. That is
the exact drift the section was written to prevent, and it undercuts the "thin configuration only"
argument by putting a derivation claim for the *prose* on the record.

Secondary contradiction: the Druid, Paladin and Evoker headers say "as of patch 12.1" while their own
`mplusLoadout.patch` values say `12.0 (MID1 …)`.

**Fix.** Reword to the truth: talent loadout strings come from SimC; guide prose is hand-authored and
was reviewed for Midnight ability changes, not copied. Make the header's patch claim per-file
accurate, or drop the patch from the header since the data carries it.

---

## MEDIUM

### 5. `Guides_DemonHunter.lua:63` — `spellID = 196555` is labelled "Blur". 196555 is **Netherwalk**; Blur is **198589**. Netherwalk is separately listed one line below.

```lua
{ spellID = 196555, text = "Blur — defensive, reduces damage taken and helps with kiting" },
{ text = "Netherwalk — brief immunity/evasion, use to dodge an unavoidable burst hit" },
```

The Cooldowns tab renders the icon and the game's spell tooltip from `spellID`, so this row shows the
Netherwalk icon and Netherwalk's tooltip under the text "Blur", immediately above a text row that
says "Netherwalk". This was the only mismatch I found: I extracted all 235 distinct spellID→label
pairs and checked them; the rest are correct, including the genuinely easy-to-confuse ones —
Ascendance 114050 (Elemental) vs 114051 (Enhancement), Bladestorm 227847 (Arms) vs 46924 (Fury), and
Metamorphosis 187827 used only in the Vengeance sections (`:134`, `:140`), never in Havoc.

**Fix.** `spellID = 198589` for Blur; give Netherwalk `spellID = 196555`.

### 6. `Guides_Priest.lua:156` vs `:179` — the Shadow guide contradicts itself about Mind Sear.

Overview: *"strong DoT-based cleave and AoE through Shadow Crash **and Mind Sear**"*.
AoE rotation: *"**Mind Sear was removed** and Shadow has no dedicated AoE filler"*.

The rotation was updated for the ability removal and the overview was not. A reader hits the wrong
claim first, on the default tab.

**Fix.** Rewrite the overview sentence to match the corrected rotation.

### 7. `Guides_Druid.lua:26` and `:53` — Balance Druid references **Wild Mushroom**, which has not been a Balance ability since Legion.

Overview: *"good AoE via Starfall/Wild Mushroom setups"*; AoE rotation: *"Wild Mushroom / Fury of
Elune (talent-dependent) for extra AoE burst"*. Fury of Elune is real; Wild Mushroom is not in the
modern Balance kit. Notably, Balance/Feral/Guardian are three of the five specs that got the MID1
fallback, and their prose reads as the least revised in this pass.

**Fix.** Drop Wild Mushroom from both lines; the Fury of Elune / Starfall framing already carries the
point.

### 8. `Data/API.lua:123-138` — `ValidateMplusLoadout` rejects correctly but validates nothing about shape, and does not require `source`.

Rejection semantics are **right** and match `ValidateGear` exactly: `ValidateGuide` at `:171-174`
propagates the failure, `RegisterSpec` at `:186-191` prints and returns `false` *before* touching
`guides`/`specClass`/`classSpecs`, so a malformed loadout drops the whole guide rather than storing
partial data. Tests at `run.lua:369-402` confirm all three rejection paths. No gap there.

The gaps are:

* Any non-empty string passes. A pasted APL line, a prose sentence, a truncated string, or (as in
  finding #1) valid base64 with a nonsense payload all validate. `ValidateGear` at least checks
  `slot` against a closed vocabulary; this validator checks nothing analogous. A cheap
  `string.match(s, "^[A-Za-z0-9+/]+$")` plus a minimum length would catch the whole "an agent pasted
  the wrong thing" class, and a specID decode (finding #1's fix) would catch mispairing.
* `source` is not required. The comment at `:118-122` justifies this ("documentary … not itself
  validated"), which is defensible in isolation — but combined with finding #3 it means nothing in
  the codebase enforces or surfaces the one field the licensing story rests on.

**Fix.** Add a charset/length check on `string`; require `source` to be a non-empty string when
`mplusLoadout` is present.

### 9. Rotation-step icon coverage collapsed on exactly the files that were rewritten hardest.

Fraction of rotation steps carrying a `spellID` (and therefore an icon + spell tooltip, per
`DESIGN.md:274-276`):

| Evoker | DemonHunter | Druid | Mage | Monk | Warlock | Priest | Hunter | Rogue | DeathKnight | Shaman | Warrior | Paladin |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| **8.3%** (4/48) | **22.0%** (9/41) | **38.4%** (28/73) | 46.4% | 47.3% | 49.1% | 69.1% | 71.2% | 71.7% | 76.2% | 76.3% | 76.6% | 77.0% |

Devastation Evoker's entire rotation renders as plain text with one icon (Disintegrate) — Living
Flame, Fire Breath, Dragonrage, Eternity Surge and Pyre all have stable, well-known IDs. The new
"material fix" steps in particular were added ID-less even where the same file already uses the ID
elsewhere: `Guides_Shaman.lua:40` "Ascendance on cooldown" (ID 114050 is used at `:60`),
`Guides_Priest.lua:172`/`:193` "Void Torrent", `Guides_DeathKnight.lua:198` "Soul Reaper",
`Guides_Paladin.lua:106` "Divine Toll". Within one list, some steps get icons and adjacent ones do
not, which reads as broken rendering rather than a deliberate choice.

**Fix.** Backfill spellIDs, at minimum for the new steps and for the Evoker/Demon Hunter rotations.

### 10. `UI/Codex.lua:886-889` — the `C_Timer.After(2, …)` callback protects the wrong statement.

```lua
C_Timer.After(2, function()
    pcall(button.SetText, button, "Add to my vault")
    if self.activeTab == "Loadouts" then self:RenderActiveTab() end
end)
```

`button` here is `self.suggestedLoadoutRow.addButton` — a single, non-pooled, never-destroyed frame
(`Codex.lua:846-847` early-returns on re-entry). It cannot go stale, so the `pcall` can never fire.
The *unprotected* second line is the risky one: it re-enters the whole render path from a timer with
no check that the window is still open. `RenderActiveTab` does guard `if not self.frame then return
end` (`:1246`), so this will not error today — but if the user clicks Add and closes the Codex within
2s, `self.activeTab` is still `"Loadouts"` (nothing resets it on hide) and a full tab re-render runs
against a hidden frame, including `scrollChild:SetHeight` and `UpdateScrollChildRect`. It is also
unbounded: N clicks in 2s queue N timers, each triggering a full re-render.

Compare `OnDeleteLoadoutClicked` (`:912-915`), which only touches `armed` and the label and never
re-renders — strictly safer. The pooled-row reasoning in the comment at `:895-900` is sound and does
apply to the delete path; it just doesn't apply here, and the extra re-render was added without the
matching guard.

**Fix.** Guard with `if self.frame and self.frame:IsShown() and self.activeTab == "Loadouts" then`,
and store a generation token on the button so a later click supersedes an in-flight timer.

### 11. `tests/wow_mock.lua:389-403` — the `C_Timer` stub ignores `delay` entirely, so it could not have caught a timing bug, and no test exercises the close-before-fire path.

`After(delay, callback)` stores the delay and `RunAfter()` fires every queued callback in **insertion
order**, discarding the delay. Consequences:

* The 2s Add-revert and the 4s Delete-revert are indistinguishable; a swapped-duration or
  interleaved-timer bug is invisible.
* There is no `Cancel`, so a "supersede the previous timer" fix (finding #10) would be untestable as
  written.
* `RunAfter` swaps `mock.pending` before iterating, so a timer scheduled *from inside* a callback is
  correctly not lost — but it also never runs unless `RunAfter` is called again, which no test does.

More importantly, the new test block (`run.lua:1930-2011`) never closes the Codex before
`mock.RunAfter()` at `:2001`/`:2011`. The exact failure mode the brief asks about — a stale closure
firing into a closed window — is not covered. Neither is a re-render landing on a *different* spec
mid-countdown.

**Fix.** Give the mock a virtual clock (`mock.Advance(seconds)` firing due timers in time order, plus
a cancel handle), then add two tests: (a) click Add, `Codex:Toggle()` closed, advance 2s, assert no
error and no re-render side effects; (b) click Add, switch to another spec, advance 2s, assert the
label and row belong to the newly selected spec.

Other coverage gaps for this round, none of which the suite currently has:
* nothing asserts the shipped `mplusLoadout.string` values are well-formed (finding #1 would have
  been caught by 15 lines of assertion);
* nothing asserts the 31/8 split, nor that the 8 healer/support specs have no `mplusLoadout`;
* nothing asserts `source` is present on shipped entries;
* nothing asserts the suggested row's label fits its row (finding #2).

The fixture hygiene instruction *was* followed correctly — `run.lua:1933-1946` registers scratch
specs 9201/9202 with an inline guide and the comment explains why, so the section cannot race with
the real data files. Good.

### 12. `DESIGN.md:153` — the only surviving pre-Midnight reference in the repo.

> Data files carry a header comment noting content targets **The War Within** and is
> community-maintained…

The actual headers now say Midnight/12.1. A full sweep for `110200`, `11.x`, `War Within`, `TWW`
across all `.lua`/`.md`/`.toc` files returns **only this line** — the bump is otherwise complete
(`.toc:1` = `120100`, `README.md:3,132`, `DESIGN.md:3-4`, all 13 guide headers).

**Fix.** Change to "Midnight".

---

## LOW

13. **`SpecSage.toc:5`** — `## Version: 1.0.0` while the repo ships v1.1 (BiS) and v1.2
    (`mplusLoadout`) features. The version users see in the AddOns list never moved. Bump to `1.2.0`.

14. **Interface number provenance is asserted, not evidenced.** `120100` is internally consistent
    with Blizzard's `xxyyzz` scheme for a 12.1.0 client, and `README.md:132-134` correctly tells a
    user how to *check* it (`/dump select(4, GetBuildInfo())`). But nothing in `DESIGN.md` or
    `README.md` records how it was *determined* for Midnight, and the whole bump rests on the
    unstated assumption that Midnight's targeted patch is numbered 12.1 rather than 12.0.x. If wrong,
    the addon shows as out of date for every user. Record the source (a build number, a client
    screenshot, or a dated citation) next to the number.

15. **`Guides_Evoker.lua:163`** — Augmentation is `role = "DAMAGER"` yet is the only non-healer spec
    without an `mplusLoadout`, and nothing explains the omission. Either add one or add a one-line
    comment saying why (and state the exclusion rule in `DESIGN.md`'s v1.2 section, which currently
    says nothing about which specs are covered).

16. **`Guides_Warlock.lua:69,144,218`** — `{ slot = "Weapon", text = "Not applicable" }` for all three
    Warlock specs, while every other caster guide says "Shadowcore Oil or the current-tier weapon
    oil". Warlocks can use weapon oils. Inconsistent and wrong.

17. **`Guides_Paladin.lua:105`** — *"Hammer of the Righteous as a builder and to refresh Consecration
    overlap"*. Hammer of the Righteous does not refresh or extend Consecration; the phrase does not
    describe a real interaction. Also `Guides_Paladin.lua:126` refers to "Shield of the Righteous
    stacks" — SotR extends a duration, it does not stack. Reword both.

18. **Unverifiable new-ability claims, all without spellIDs.** `Guides_Priest.lua:174` ("Shadow Word:
    Madness … has joined the kit"), `Guides_DeathKnight.lua:196` (Scourge Strike "becomes the
    empowered Putrefy"), `Guides_Monk.lua:184` ("Zenith"), `Guides_Druid.lua:118` ("a talented
    finisher called Chomp"). These may well be genuine Midnight additions, but they are asserted as
    fact, carry no spellID (so nothing renders an icon or tooltip that would expose an error), and
    cannot have come from a talent export string — which means they came from somewhere the header
    comment does not name. Each should get a spellID (which both verifies it and improves the UI) or
    be removed. `Guides_Druid.lua:118`'s "check your talent row" hedge is the right tone; the Priest
    line's "rather than treating it as optional" is the wrong one.

19. **`Guides_Monk.lua:174-180`** — Windwalker's `statPriority` places `haste` last, below
    `versatility`. That is an unusual ordering for a spec whose entire identity is energy/Chi
    throughput; worth a second look against current tuning.

20. **`Guides_Warlock.lua:181` / `Guides_Druid.lua:28` etc.** — several `{ stat = "primary" }` entries
    carry no `note` while sibling files write `{ stat = "primary", note = "Intellect, passive" }`.
    Cosmetic inconsistency across the pack.

21. **Guide header wording drifted into two variants** (lines 6-9): 7 files carry one phrasing, 6
    another (DeathKnight/Hunter/Paladin/Priest/Rogue/Shaman/Warrior vs
    DemonHunter/Druid/Evoker/Mage/Monk/Warlock). Same meaning, different words. Harmless, but it
    shows the files were edited by different hands without a final pass.

22. **`Guides_Warlock.lua:177`** — *"Havoc lets you cleave a second target's worth of single-target
    damage during **execute-style windows**"*. Havoc has no execute relationship. Drop the clause.

23. **`Guides_Shaman.lua:24`** — *"Maelstrom, generated from spells like Lightning Bolt and Earth
    Shock's associated generators, and spent on Earth Shock"* is circular/garbled. Lava Burst is also
    a generator and goes unmentioned. Rewrite.

---

## Checked, OK

* **Interface bump completeness.** `.toc:1` = `120100`; `README.md:3,132`; `DESIGN.md:3-4`; all 13
  guide headers say Midnight/12.1. Repo-wide grep for `110200` / `11.x` / `War Within` / `TWW` finds
  exactly one leftover (finding #12). The `120100` value is internally consistent with the
  `xx`/`yy`/`zz` scheme for a 12.1.0 client (provenance caveat in finding #14).
* **No APL / SimC syntax leaked into any prose field.** Aggressive grep across all 13 guide files
  and both test files for `actions.`, `+=/`, `,if=`, `if=talent.`, `talent.*.enabled`, `buff.*.up`,
  `cooldown.*.remains`, `run_action_list`, `call_action_list`, `target_if`, `spell_targets`,
  `active_enemies`, `variable,name=`, `use_item`, `dot.*.ticking`, `prev_gcd` → **zero hits**. The
  rotation/tips/overview text is genuinely English throughout. This was done cleanly.
* **Spec inventory is exactly right.** 39 `RegisterSpec` calls, 13 files, no duplicates. **No
  "Devourer" Demon Hunter spec was invented** — `Guides_DemonHunter.lua` registers only 577 and 581,
  and `run.lua:479` asserts `DEMONHUNTER = 2`, so a fabricated third spec would fail the suite.
* **The 31/8 split is exactly as intended and nothing was fabricated.** All 8 specs without
  `mplusLoadout` are precisely Holy Paladin (65), Discipline (256), Holy Priest (257), Restoration
  Shaman (264), Mistweaver (270), Restoration Druid (105), Preservation (1468) and Augmentation
  (1473). No healer has one; every other spec does (Augmentation caveat in finding #15).
* **`source` is present in all 31 entries and byte-identical to `DESIGN.md:233`'s wording** —
  `"SimulationCraft default profile (credit, not endorsement of 'best')"`. (It is never rendered —
  finding #3.)
* **The 5 MID1-fallback specs are exactly the 5 named in the brief**: Balance/Feral/Guardian Druid,
  Retribution Paladin, Devastation Evoker. The remaining 26 all say `"12.1"`. Honest labelling of
  *which* specs, even though the label itself is undocumented and malformed (finding #2).
* **`ValidateMplusLoadout` rejection semantics.** Correctly mirrors `ValidateGear`: a malformed
  `mplusLoadout` fails `ValidateGuide` (`API.lua:171-174`), which makes `RegisterSpec` print and
  return `false` *before* writing to `guides`, `specClass` or `classSpecs` (`:186-191`). The whole
  guide is dropped, not partially stored, and there is no "warn and continue with bad data" path.
  Covered by tests at `run.lua:369-402` for non-table, empty `string`, and empty `patch`. Optionality
  (nil → valid) is correct and tested at `:337-345`. Shape-validation gaps are finding #8.
* **Codex row rendering realism.** Real templates throughout — `UIPanelButtonTemplate` for both
  buttons (`Codex.lua:856,861`), `GameFontHighlightSmall` for the label (`:852`), real `CreateFrame`
  parenting to `scrollChild`. The single non-pooled frame with the "at most one `mplusLoadout` per
  spec" justification (`:841-845`) is the right call, and the row is correctly hidden on tab switch
  (`:1233`) and when a spec has no loadout, with no placeholder (`:958-959`) exactly as
  `DESIGN.md:256-257` requires.
* **Show-before-Focus ordering on the Copy dialog is correct** — `Codex.lua:1145-1153` calls
  `copyDialog:Show()` *then* `SetText` → `SetFocus` → `HighlightText`, with a comment explaining why.
  The mock enforces this for real: `wow_mock.lua:250-256` asserts `IsEffectivelyShown` inside
  `SetFocus` and walks the whole parent chain (`:102-106`), and `HighlightText` (`:269`) only
  highlights when focused. A reordering here would fail the suite loudly rather than silently copy
  nothing. This is genuinely good mock design.
* **`Add to my vault` write path.** `Codex.lua:881-893` calls
  `Loadouts:Add(specID, "Suggested M+ (SimC)", "Mythic+", exportString)` — exactly the signature and
  literals `DESIGN.md:251-253` specifies — and nothing writes to `SpecSageDB` before the click. The
  shipped-data-is-read-only separation holds. Asserted at `run.lua:1986-1996`.
* **All 235 distinct spellID→label pairs across the guide pack**, checked individually. One error
  (finding #5). Correct on every genuinely confusable pair: Ascendance 114050/114051 by spec,
  Bladestorm 227847/46924 by spec, Metamorphosis 187827 in Vengeance only, Rend 772, Execute 163201,
  Time Warp 80353, Barrage 120360, Schism 214621, Mongoose Bite 259387.
* **Rotation/statPriority "material fixes", spot-checked on 8 specs.** Protection Paladin
  (`Paladin.lua:102-128`), Elemental Shaman (`Shaman.lua:34-48`), Unholy DK
  (`DeathKnight.lua:193-201`), Shadow Priest (`Priest.lua:166-190`), Destruction Warlock
  (`Warlock.lua:187-206`), Windwalker (`Monk.lua:180-200`), Havoc (`DemonHunter.lua:37-55`), Balance
  and Feral Druid (`Druid.lua:36-56`, `:113-130`). The named fixes are real and coherent:
  Avenger's Shield and Divine Toll are properly integrated into Prot Paladin's priority rather than
  dropped in; Ascendance sits correctly alongside Fire/Storm Elemental in Elemental's burst;
  Destruction's Chaos-Bolt-over-Incinerate ordering is now right and explicit ("this outranks plain
  Incinerate casts once shards are banked", Incinerate demoted to "lowest-priority filler"); Soul
  Reaper's "triggers when the target drops low, not on cast" (`DeathKnight.lua:198`, `:247`) is an
  accurate description of the mechanic; Havoc's Essence Break "between Eye Beam casts to debuff the
  target" is the correct usage; Windwalker's combo-strikes framing is right. Content problems found
  are #6, #7, #17, #18, #19, #22, #23 — none of them the inserted-at-random pattern the brief was
  worried about.
* **Test fixture hygiene.** `run.lua:1933-1946` uses scratch specIDs 9201/9202 with inline guide
  data and documents why, so the new section cannot race with concurrent edits to the real data
  files. `run.lua:475-522` still asserts exactly 39 shipped specs with per-class counts. Suite is
  green: 847 passed, 0 failed. All files pass `luac5.1 -p`.

---

## Verdict

**Not shippable as-is, and the blocker is the feature itself, not the plumbing around it.** Almost
everything built *for* `mplusLoadout` this round is good work: the validator rejects the whole guide
exactly like `ValidateGear` does, the Codex row uses real templates with correct Show-before-Focus
ordering and a genuinely enforcing mock, the write path never touches `SpecSageDB` until the user
clicks, the 31/8 healer split is honest with zero fabrication, no Devourer spec was invented, and —
the thing I most expected to find and did not — not one character of SimC APL syntax leaked into the
prose. The interface bump is complete but for a single stale line in `DESIGN.md`. Fix findings #2
through #12 and that half of the release is in good shape.

But finding #1 is disqualifying, and it is disqualifying in a way that speaks directly to the design
question. The 31 strings are not SimulationCraft talent builds. They carry a correctly constructed
Blizzard header — right serialization version, right specID for every single spec, an empty tree hash
that makes the client skip validation — bolted onto a payload whose rank and choice fields are
impossible under both known encodings and whose decoded node counts differ between specs of the same
class. They will import silently and produce nonsense. So the feature does not merely fail to deliver
on "thin, low-risk, credited" — it inverts each of the three. It is not *thin*, because the file
headers now assert in 13 places that the prose rotation priorities were derived from SimC's APLs,
which is precisely the copyright surface `DESIGN.md:218-246` was written to stay off. It is not
*credited*, because there is no LICENSE file, README's Credits never mentions SimulationCraft or
GPLv3, and the `source` field that carries the credit is dead data no code path ever reads. And it is
not *low-risk*, because the risk has quietly changed shape: the danger is no longer "we shipped
someone else's data" but "we attached someone else's name to data they did not produce, and told the
user so in the UI." That is a worse position than the one the design was avoiding. Regenerate the
strings from a real export and gate them with a decoder assertion in the test suite, retract the APL
derivation claim from the headers, and add the license and README credit — then this is a good
release.
