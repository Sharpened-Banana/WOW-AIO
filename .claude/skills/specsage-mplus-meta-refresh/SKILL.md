---
name: specsage-mplus-meta-refresh
description: Refresh SpecSage's (the WoW addon in this repo) mplusMetaLoadout fields — what current top Mythic+ players are actually running, per spec, pulled live from Blizzard's own Battle.net Game Data API. Use this when the user asks to update/refresh the "top players" or "live meta" build data, mentions mplusMetaLoadout being stale, or invokes /specsage-mplus-meta-refresh directly. Companion to /specsage-refresh (which handles SimC-sourced mplusLoadout/raidLoadout and rotation prose) — this skill is Blizzard-API-sourced and spec-by-spec, not a full-repo patch-day pass.
---

# SpecSage Mythic+ live-meta refresh

DESIGN.md's "Live Mythic+ meta loadout (v1.4)" section is the schema and the
full reasoning for why this field exists and how it differs from
`mplusLoadout`/`raidLoadout` (SimC-theorycrafted) — read it before starting.
This skill is the pipeline that populates `mplusMetaLoadout`: what current
top Mythic+ players are actually choosing, sourced from Blizzard's own API,
not SimC.

The pipeline was built and validated end-to-end for Protection Paladin
(specID 66) on 2026-08-30 — see that spec's entry in
`SpecSage/Data/Guides_Paladin.lua` and its file header for the exact
worked example this skill generalizes from.

## Prerequisite: Battle.net API credentials

The user needs a free Battle.net API client (`client_id` + `client_secret`)
from `develop.battle.net` → **API Access** → create a client. **Never commit
these anywhere in the repo.** Ask the user how they want to share them —
writing straight to a local, untracked scratch file is preferable to pasting
a secret into chat, but pasting is an acceptable tradeoff if the user
prefers it (these are free-tier, rate-limited, easily-rotated credentials,
not a high-stakes secret). Either way, write them immediately to a file
outside the repo (this session's scratchpad directory, `chmod 600`) and
never echo the secret back in any message or command output.

## The one rule that can't bend: no fabricated or guessed data

Every `mplusMetaLoadout` this pipeline ships must trace to an actual,
successful API response for an actual character, the same integrity bar
`/specsage-refresh` holds SimC data to. If a spec's sample comes back too
small or too noisy to trust (see Step 6), skip that spec and say so — don't
lower the bar to fill in a field.

## Step 1 — Get an access token

```
curl -s -u "${client_id}:${client_secret}" -d grant_type=client_credentials \
  https://oauth.battle.net/token
```

Returns a bearer token valid ~24 hours (`expires_in` in the response). Every
subsequent call needs `Authorization: Bearer <token>`.

## Step 2 — Discover the current season, period, and dungeon pool fresh

Don't hardcode a season/period number — like SimC's tier folders, these
change every season. In order:

1. `GET /data/wow/mythic-keystone/season/index?namespace=dynamic-{region}` →
   `current_season.id`.
2. `GET /data/wow/mythic-keystone/period/index?namespace=dynamic-{region}` →
   `current_period.id`.
3. Pick any connected realm (see Step 3) and
   `GET /data/wow/connected-realm/{id}/mythic-leaderboard/index?namespace=dynamic-{region}`
   → `current_leaderboards[].id` is the current season's dungeon pool
   (confirmed 8 dungeons for season 18/period 1078, US, at the time this
   skill was built). This is season-wide, not realm-specific — fetch it
   once, reuse the dungeon ID list for every realm in Step 4.

## Step 3 — Enumerate connected realms

`GET /data/wow/connected-realm/index?namespace=dynamic-{region}` → parse
each entry's `href` for the connected-realm ID. US region had 83 at the time
this skill was built; re-fetch fresh each run rather than trusting a cached
count, since realm mergers change this over time.

## Step 4 — Scan leaderboards for the target spec(s)

For every (connected realm × dungeon) pair:

```
GET /data/wow/connected-realm/{realmId}/mythic-leaderboard/{dungeonId}/period/{periodId}?namespace=dynamic-{region}
```

Each response's `leading_groups[]` is pre-sorted best-first (up to 500
entries) and each group's `members[]` already carries
`specialization.id` directly — **no extra lookup is needed just to filter by
spec.** Take only the top N groups per leaderboard (20 was used for the
worked example — "top players," not the full 500-deep list) and, for each
member whose `specialization.id` matches the target spec, record
`(character name, realm slug)` and the group's `keystone_level`, keeping
each character's *best* observed level across all leaderboards scanned.

This is the expensive phase call-count-wise (realms × dungeons — 664 for
one spec at 83×8). Self-throttle gently (the worked example used a small
per-call sleep; Blizzard's default tier allows ~100 req/s, so this is a
large safety margin, not a requirement) and **cache the accumulated
per-character results to a local file as you go, or at minimum right after
this phase completes** — a bug or crash in the next phase should never mean
redoing this scan. This bit the worked example once already: a Unicode
URL-encoding bug in Step 5 crashed the run, and without a cache the entire
664-call scan would have had to be repeated to fix a one-line bug in a later
step.

To cover **every spec of a class in one pass** (cheaper than one full scan
per spec), track all specializations of interest simultaneously while
scanning rather than re-scanning per spec — the leaderboard data for a given
realm/dungeon/period does not change between specs.

## Step 5 — Resolve each top character's actual build

Rank the distinct characters found in Step 4 by best keystone level, take
the top ~50 (the worked example's sample size — large enough to see a real
distribution, small enough to keep this phase's call count trivial), and for
each:

```
GET /profile/wow/character/{realmSlug}/{characterName}/specializations?namespace=profile-{region}
```

**`character name must be URL-percent-encoded`** (`urllib.parse.quote` or
equivalent) — non-ASCII letters in real character names (accents, etc.) will
otherwise fail at the HTTP layer before any response exists, not with a
clean 4xx. Realm slugs are already URL-safe.

In the response, find the `specializations[]` entry whose
`specialization.id` matches the target spec, then within that entry's own
`loadouts[]`, find the one with `is_active: true` (a spec can have multiple
saved loadouts; `is_active` marks which one the character currently has
equipped for that spec — this is independent of the top-level
`active_specialization`, which names which of the character's specs is
currently active overall. A character found via a Protection-spec M+ run
might not currently be sitting in Protection, so read the target spec's own
`is_active` loadout, not the character's globally active one).

**`loadouts[].talent_loadout_code` is already Blizzard's export-string
format** — confirmed by direct comparison against a live character's actual
in-game build (character/realm on file in this skill's commit history) and
against the shape of strings already shipped in `mplusLoadout`/`raidLoadout`
(same character set, same ~100-110 char length, same
class-token-letter-plus-"EAA..." prefix pattern). Use it directly as
`mplusMetaLoadout.string` — **no re-encoding, no custom serializer needed.**
This was the open question the schema shipped with; it is resolved.

`selected_hero_talent_tree.name` on the same loadout object is worth
capturing too (see Step 6) — it's a much stronger "meta" signal than the
literal exported string tends to be.

A character lookup can fail (renamed, transferred, privacy settings,
transient error) — skip it and keep going, don't let one failure abort the
whole resolve phase. Report how many resolved vs. failed.

## Step 6 — Aggregate honestly, including when the answer is "no strong consensus"

Count occurrences of the exact `talent_loadout_code` string among resolved
characters. The plurality winner becomes `mplusMetaLoadout.string`. **Do not
inflate what this means**: in the worked example, the winning code was
shared by only 4/50 (8%) — real top players vary in flex-point talent
choices even when they broadly agree on strategy, so a thin plurality on the
literal byte string is the normal, honest outcome, not evidence the pull
went wrong.

Separately tally `selected_hero_talent_tree.name` (or any other structured
field worth summarizing) — this is often a much clearer consensus signal
(94% Lightsmith vs. only 8% on the exact code, in the worked example) and
belongs in the shipped `source` string so a reader gets the fuller picture,
not just a lone percentage that undersells real agreement elsewhere in the
build.

If the resolved sample is too small to mean anything (very low participation
for an off-meta spec, most lookups failing, etc.), don't ship a field built
from it — skip that spec for this pass and say so in the report, the same
"skip rather than fabricate" rule `/specsage-refresh` follows for SimC
coverage gaps.

## Step 7 — Write the guide field, with an honest `source`

```lua
mplusMetaLoadout = {
  string = "<talent_loadout_code, verbatim>",
  source = "Blizzard Battle.net API, <region> region, <date>: top <N> current-season "
    .. "Mythic+ <Spec> <Class>s by best keystone level, sampled across all <realm count> "
    .. "<region> connected realms' leaderboards. This exact build was the plurality pick "
    .. "(<count>/<N>, <pct>%); <hero-talent %> ran <hero talent> overall.",
  patch = "<game patch, e.g. 12.1>",
  sampleSize = <N>,
}
```

Validated by the same `ValidateLoadoutSuggestion` in `Data/API.lua` that
backs `mplusLoadout`/`raidLoadout` (`string`/`patch` required non-empty;
`sampleSize`, if present, must be a positive number). Update the guide
file's header comment too, the same way `/specsage-refresh` requires for any
data-provenance change: name which spec(s) got a fresh `mplusMetaLoadout`
this pass, the date, and a one-line methodology summary — the full
methodology belongs in the field's own comment (see
`Guides_Paladin.lua`'s Protection entry for the established pattern), the
header just needs to point a reader there.

## Step 8 — Verify and clean up

`lua5.1 tests/run.lua` must still pass with zero failures and
`find SpecSage -name '*.lua' -exec luac5.1 -p {} +` must be clean, same as
every other change to this repo. Confirm the new field actually renders in
the Codex (open the spec's Loadouts tab, the live-meta row should show with
the right label/sample size) before calling this done — a schema that
validates but never reaches the UI is not actually shipped. Delete any
scratch files holding the API credentials or raw pull data once you're done
(they live outside the repo already, in the session scratchpad — but clean
housekeeping matters for a credential file regardless).

## When something looks wrong mid-run

If the leaderboard scan finds suspiciously few characters for a spec that
should be common, or every character lookup in Step 5 fails, don't paper
over it — that's more likely a bug (wrong spec ID, wrong period, an
unhandled API error being silently swallowed) than a genuinely tiny playerbase.
Stop and investigate before shipping a `sampleSize` that doesn't mean what
it claims to.
