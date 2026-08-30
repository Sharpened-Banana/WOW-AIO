---
name: specsage-refresh
description: Refresh SpecSage's (the WoW addon in this repo) game-version metadata, Mythic+ talent loadouts, and rotation guidance for a new WoW patch. Use this whenever the user asks to update, refresh, or sync SpecSage's data for a new patch/season, mentions the addon being "out of date," asks to pull new SimC data, or invokes /specsage-refresh directly. Runs a multi-agent pipeline: detect the current patch, pull fresh talent strings and rotation logic from SimulationCraft's public repo, handle specs SimC doesn't cover without ever touching Wowhead/Method/Archon, review, fix, and ship.
---

# SpecSage patch-day refresh

SpecSage ships two kinds of game-content data: hand-authored guide prose
(never sourced from any specific site) and, for most DPS/tank specs, a
`mplusLoadout` talent string plus rotation cross-check pulled from
SimulationCraft's public GitHub repo. Both go stale every patch. This skill
repeats the refresh pipeline that produced the addon's first Midnight-era
update, so it doesn't need to be re-derived from scratch each time.

Read `/home/user/WOW-AIO/DESIGN.md` before starting — specifically the
"Shipped Mythic+ talent loadout (v1.2)" section, which is the schema and the
reasoning for why SimC (not a guide website) is the source.

## The one rule that can't bend: no Wowhead, Method, Archon, or any other
guide site — ever, for anything

This was a deliberate call, not an oversight. Their rotation priorities and
stat-weight orderings are curated analytical work product — courts treat
that kind of compilation as protectable even when you paraphrase it, and
these sites' own terms of use prohibit scraping and republishing. SimC's
data is different: it's GPLv3, published by the project specifically for
tools to build on, and a talent string is thin enough (a configuration
choice from a fixed rule set, not prose) to carry a much lower risk. If SimC
doesn't cover something, the fallback is Blizzard's own official patch
notes (a primary source, fine to read and summarize) plus careful
hand-authoring — never a guide site, no matter how convenient.

## The other rule that can't bend: never fetch an exact/opaque string with
WebFetch

This bit the first refresh pass and is worth explaining so it isn't
repeated. `WebFetch` doesn't return raw page bytes — it converts the page to
markdown and runs a smaller model over it to answer your prompt, then
returns that model's answer. That's fine for prose ("what does this guide
say about X") but it is *lossy* for a ~150-character opaque base64-like
token like a talent export string: the summarizing model can silently swap
or drop characters, and running the fetch twice can even return the same
wrong answer twice if it's deterministic, which is not proof of
correctness. Talent strings decode against a specific bit format
(`ClassTalentImportExportMixin` in the client); a single wrong character
produces a plausible-looking but garbage loadout the client's empty-hash
check won't even flag.

**So: for the `talents=` line (or any other value you need byte-exact),
fetch the raw file with the Bash tool, not WebFetch:**

```
curl -s https://raw.githubusercontent.com/simulationcraft/simc/<branch>/profiles/<tier>/<file>.simc | grep '^talents='
```

This returns literal bytes with no model in the loop. Use WebFetch freely
for everything else in this pipeline (reading patch notes, understanding an
APL's priority *logic* in prose form, browsing directory listings) — the
lossiness only matters for a token you're copying verbatim.

## Step 1 — Determine the current patch

Accept an optional argument naming the patch (e.g. this skill invoked as
"specsage-refresh 12.2"). If none is given, research it: WebSearch for the
current WoW expansion/patch and its release date, then derive the interface
number from the pattern `major.minor.patch` with periods removed (e.g.
12.1.0 → 120100) — don't guess a number without confirming the pattern
against a recent search result, the numbering has been consistent but it's
cheap to verify.

Compare the result against `SpecSage/SpecSage.toc`'s current
`## Interface:` line. If it's unchanged, the addon is already current —
skip straight to Step 4 (SimC may still have published new profiles for the
same patch, e.g. a new raid tier) rather than ending the skill early.

## Step 2 — Update version metadata if the patch changed

`grep -rn` the repo for the old interface number and the old expansion/patch
name (don't assume a fixed file list — the first pass touched
`SpecSage/SpecSage.toc`, `README.md`, and `DESIGN.md`, but a later session
may have added more references). Update every hit: the toc's Interface
line, and prose mentions of the expansion/patch in the docs.

## Step 3 — Discover SimC's current data layout fresh

Don't hardcode folder names — the tier-naming convention (`MID1`, `MID2`
this expansion) can change next season or next expansion. Use WebFetch (safe
here, you're reading a directory listing, not extracting an opaque token)
on `https://github.com/simulationcraft/simc/tree/<branch>/profiles` to find
the current tier folder, then on that folder to list what per-spec `.simc`
files actually exist. Also list the immediately-prior tier as a fallback
source for specs the current tier hasn't caught up on yet. Confirm the
branch name too (it tracks the expansion, e.g. `midnight`) rather than
assuming last time's branch is still right.

## Step 4 — Enumerate SpecSage's specs

Read `SpecSage/Data/API.lua`'s `GetClasses`/`GetClassSpecs` and the 13
`SpecSage/Data/Guides_*.lua` files to get the live list of registered
class/spec pairs — don't hardcode a spec list in this skill, it will drift
as SpecSage's own coverage changes (e.g. a new spec gets added later).

## Step 5 — Dispatch data agents for SimC-covered specs

For every spec with a current-tier (or prior-tier fallback) SimC profile,
dispatch Sonnet agents in parallel, grouped by class — split the 13 classes
across two or three agents for reasonable parallelism, similar to a ~7+6
split. Each agent's job per spec:

1. `curl` the raw `.simc` file (see the rule above — never WebFetch for
   this step) and `grep '^talents='` for the exact string.
2. WebFetch (or read the same curl output) for the `actions.*` priority
   lines, including any hero-talent-conditional branches
   (`run_action_list,name=X,if=talent.Y`).
3. Update the guide's `mplusLoadout` table: `string` (the curled value,
   verbatim, never retyped), `source` (credit line per DESIGN.md's
   example), `patch` (short — "12.1", or "12.0 (MID1, previous tier)" for
   a fallback-tier pull; put any longer explanation in a comment, not the
   UI-rendered `patch` string itself, since it renders in a fixed-width
   Codex row).
4. Sanity-check `rotation` and `statPriority` prose against the fetched
   APL. Fix only where you're actually confident there's drift — translate
   to plain English, never paste `actions.*` syntax into guide prose, never
   invent an ability name you didn't see in the fetch.
5. Skip a spec entirely (leave existing prose untouched, no `mplusLoadout`
   field) if it has no coverage in either tier — no fabrication.
6. Update the file's header comment honestly, at the file level, since a
   file holds multiple specs and not all of them may have gotten a pass
   this round: name which specs (by having an `mplusLoadout` field) were
   SimC-cross-checked this patch, and that the rest weren't re-verified.

## Step 6 — Handle specs SimC doesn't cover

Typically healers, and any spec new to the patch. Do NOT fall back to a
guide website (see the rule at the top). Instead, dispatch an agent to read
Blizzard's own official patch notes (news.blizzard.com, or the current PTR/
live patch notes page) for that class/spec — a primary source describing
mechanical changes, which is fine to read and factually summarize — and
revise the existing hand-authored prose using that context plus general
spec-design knowledge, at the same confidence standard as the original
authoring pass (no claims of sim-verified precision it doesn't have). Flag
the affected spec's guide clearly (a note near the top of its entry or in
the file header) as "revised against official patch notes, not
SimC-cross-checked" so a reader can tell the confidence level apart from a
SimC-verified spec.

## Step 7 — Flag, don't author, a wholly new spec

If patch notes reveal a spec that isn't in `Data/API.lua`'s registered list
at all (this happened once already — a "Devourer" Demon Hunter spec turned
up in SimC's directory listing with no SpecSage guide), don't try to author
a full guide for it inline here. A brand-new spec needs its own dedicated
research pass and its own review, not a rushed entry riding along on a
patch-metadata refresh. Report it prominently as a follow-up instead.

## Step 8 — Review

Dispatch an Opus-model agent, review-only (no file writes except its
findings, no git commands), to check adversarially: no leaked APL syntax
anywhere in the 13 guide files' prose fields; no fabricated `mplusLoadout`
for an uncovered spec; every `mplusLoadout.string` actually decodes
sensibly (don't just trust that it "looks like" a plausible string — this
is exactly the class of bug that slipped through the first pass); interface
version references fully consistent repo-wide; SimC/patch-notes attribution
present and honest; spot-check several of the data agents' reported
"material fixes" for spec-appropriateness. Have it write findings to a
REVIEW file rather than printing them inline, so the next step can act on a
concrete artifact.

## Step 9 — Fix and verify

Dispatch a Sonnet agent to address the review's findings. Iterate until
`lua5.1 tests/run.lua` passes with zero failures and
`find SpecSage -name '*.lua' -exec luac5.1 -p {} +` is clean. Delete the
review file from the tree afterward (git history keeps it; a stray
`REVIEW*.md` shouldn't ship in the repo).

## Step 10 — Commit and push

Commit with a descriptive message (mention the patch number and what
changed — version bump, N specs refreshed, any specs skipped and why) and
push to the current branch. Don't create a pull request unless asked. Don't
force-push. Don't touch main/master directly — work on whatever branch the
session is already on.

## When something looks wrong mid-run

If a fetched profile file 404s, has no `talents=` line, or a decoded string
looks implausible, don't paper over it — drop that spec's `mplusLoadout`
rather than ship something uncertain, and say so in the final report. The
addon's whole pitch is that its data is either genuinely sourced or clearly
marked as not — a silently-wrong entry undermines that more than a missing
one does.
