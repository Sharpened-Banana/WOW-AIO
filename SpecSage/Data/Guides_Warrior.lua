local ADDON, ns = ...

-- SpecSage guide data: Warrior (Arms 71, Fury 72, Protection 73)
-- Content targets Midnight (patch 12.1). Specs below with an `mplusLoadout`
-- and/or `raidLoadout` field have that talent string (only) cross-checked
-- against SimulationCraft's public profiles (github.com/simulationcraft/simc,
-- GPLv3, `midnight` branch) as of patch 12.1; specs without one have no such
-- reference.
-- Rotation/overview/tips/gear prose throughout this file is hand-authored
-- and was reviewed for Midnight ability changes, not derived from or
-- checked against SimC's APLs, and was not re-verified against current
-- tuning this pass — EXCEPT Arms, refreshed this pass, and all three specs,
-- which each also gained an `mplusMetaLoadout` this pass:
--   * `mplusLoadout.string` re-pulled from profiles/MID1/MID1_Warrior_Arms.simc's
--     `talents=` line (superseding an earlier, now-stale pull of the same
--     file - SimC's `midnight` branch updates its default profiles via
--     automation), fetched twice to confirm an exact match before use.
--   * The Slayer hero-talent `condition` lines on the Execute rotation step
--     and the Bladestorm cooldown were translated (not pasted) from
--     actions.slayer_execute/actions.slayer_st lines in that same file,
--     same double-fetch confirmation.
--   * NOT added: `raidLoadout`. As of this pass, SimC's `midnight` branch
--     ships exactly one profile per spec here (this same file, referenced
--     by the profiles/MID1_Raid.simc aggregator) - no genuinely separate
--     Mythic+/dungeon-context build to source a second field from. Adding
--     `raidLoadout` anyway, pointed at the same profile under a UI label
--     that implies real raid-vs-M+ differentiation, would misrepresent the
--     data to a player who only sees "Suggested Raid" vs "Suggested
--     Mythic+" in the Codex with no way to see this comment. See
--     DESIGN.md's v1.3 section.
--   * `mplusMetaLoadout` (DESIGN.md's v1.4 section) added for Arms (71),
--     Fury (72), and Protection (73): pulled live from Blizzard's own
--     Battle.net Game Data API (client-credentials OAuth, US region) rather
--     than SimC, on 2026-08-30. Methodology: every current-season Mythic+
--     leaderboard (8-dungeon pool, period 1078) across all 83 US connected
--     realms was scanned (top 20 groups per realm/dungeon) for each spec's
--     group members; the 50 distinct characters per spec with the highest
--     observed keystone level had their live `specializations` looked up
--     for their active loadout's `talent_loadout_code`. See each field's
--     own `source` comment for the resulting distribution.
-- A later pass (2026-09-01) enriched all three specs' overview/rotation/
-- cooldowns/tips with opener sequences, single-target-vs-AoE priority
-- nuances, cooldown-syncing notes, and hero-talent-caused differences,
-- drawing on guide sites (Wowhead/Icy Veins/Maxroll/Method/Boostmatch),
-- now a permitted source per repo policy (see
-- .claude/skills/specsage-refresh/SKILL.md). All prose was rewritten in
-- SpecSage's own words rather than copied from any source, and every
-- spellID added was verified against Wowhead rather than guessed (Thunder
-- Blast was deliberately left without a spellID - even addon developers
-- have shipped the wrong one for it, per a public Hekili bug report).
-- raidLoadout follow-up (2026-09-02): checked SimC's `midnight` branch
-- fresh - still exactly one profile per spec, no genuinely separate raid
-- build to source a distinct field from (same reasoning as the Arms note
-- above). Enriched Fury's Slayer/Mountain Thane note instead with the
-- source material's raid-vs-M+ framing (informational text, no opaque
-- talent string needed or risked).
-- This is community-maintained conventional guidance (stat priorities and
-- rotations that match the spec's long-standing design) — not a claim of
-- bleeding-edge sim-perfect optimization.
-- To edit: change the strings/tables below and reload. To add a spec pack,
-- call ns.GuideStore:RegisterSpec(classToken, specID, guideTable) from any
-- addon that loads after SpecSage; see Data/API.lua for validation rules.

-- Consumables/gear pass (2026-09-01, same session as the rotation-guide
-- enrichment above): every spec's Flask/Food/Potion/Augment Rune entries
-- were refreshed to the current Season 2 consumable system (stat-matched
-- "Flask of Tempered <X>" flasks rather than the old generic "Flask of
-- Alchemical Chaos" placeholder used everywhere; current food/potion/
-- augment-rune names), and specs with concrete Season 2 tier-set 2pc/4pc
-- effects (per the same guide-site sources) had that detail appended to
-- their Head gear entry - specs the sources gave no specific tier numbers
-- for were left with their existing generic tier-set mention rather than
-- inventing specifics. statPriority was deliberately NOT touched in this
-- pass either: stat-priority orderings are exactly the kind of contested
-- judgment call (not a mechanically-determined fact) this repo's policy
-- says to flag rather than silently adopt, and neither source gave a
-- confident order clearly better than what already shipped.
if not ns.GuideStore then return end

ns.GuideStore:RegisterSpec("WARRIOR", 71, {
  specName = "Arms",
  role = "DAMAGER",
  overview = {
    "Arms Warrior is a two-handed weapon melee spec built around Mortal Strike as its core rhythm and Colossus Smash (or Sudden Death procs) as its burst windows. It plays as a methodical, cooldown-driven spec: you build and spend rage on a tight priority list, keep Rend and Overpower windows active, and time your offensive cooldowns to land inside Colossus Smash's armor-reduction debuff.",
    "The spec's core resource is Rage, generated from auto-attacks and abilities like Overpower, and spent on Mortal Strike, Cleave, and execute-range finishers. Its defining mechanic is the Colossus Smash / Warbreaker debuff window — damage done to the target is increased for a short duration, so cooldowns and high-value spenders are stacked inside it for burst.",
    "Arms brings strong single-target cleave, self-sufficient defensives (Die by the Sword, Rallying Cry), and solid execute-phase damage, making it a reliable pick for raid progression and Mythic+ alike when you want consistent melee pressure without pet or DoT management.",
  },
  statPriority = {
    { stat = "primary", note = "Strength, passive" },
    { stat = "crit" },
    { stat = "mastery" },
    { stat = "haste", note = "to a comfortable breakpoint for rage flow" },
    { stat = "versatility" },
  },
  rotation = {
    { title = "Opener", steps = {
        { spellID = 100, text = "Charge to open and generate your first Rage" },
        { spellID = 260708, text = "Sweeping Strikes pre-cast if multiple targets are already up" },
        { spellID = 167105, text = "Colossus Smash / Warbreaker to open your burst window" },
        { spellID = 12294, text = "Mortal Strike inside the Colossus Smash window" },
        { text = "Trinkets, potions, and your other offensive cooldowns alongside this first Colossus Smash" },
    }},
    { title = "Single Target", steps = {
        { spellID = 167105, text = "Colossus Smash — open burst windows and align cooldowns with it" },
        { spellID = 12294, text = "Mortal Strike on cooldown — top rage priority; also fire it early if Rend has less than 3 seconds left, or if you're holding a Fierce Followthrough buff" },
        { spellID = 772, text = "Rend — keep the bleed active on the target" },
        { spellID = 7384, text = "Overpower when charges are available" },
        { spellID = 845, text = "Cleave / Slam (or Heroic Strike procs under Slayer) to spend excess rage between cooldowns" },
        { spellID = 163201, text = "Execute once the target drops below 35% health, or on a Sudden Death proc even outside execute range",
          condition = "Slayer hero talent: use with Rage above 40, or on a Sudden Death proc" },
        { spellID = 376079, text = "Champion's Spear on cooldown for extra burst inside your Colossus Smash window" },
    }},
    { title = "AoE", steps = {
        { spellID = 260708, text = "Sweeping Strikes whenever multiple targets are up" },
        { spellID = 227847, text = "Bladestorm to open on 3+ targets" },
        { spellID = 167105, text = "Colossus Smash / Warbreaker before committing cooldowns" },
        { spellID = 845, text = "Cleave as your rage dump against multiple targets" },
        { spellID = 772, text = "Rend on targets that will live long enough for the bleed to pay off" },
        { spellID = 7384, text = "Overpower to keep charges from capping" },
        { text = "Fill remaining rage with Mortal Strike on the highest-priority target" },
    }},
    { title = "Opener Notes", steps = {
        { text = "Pool rage before pulling, then open with Colossus Smash into Mortal Strike to front-load burst" },
        { text = "Line up trinkets and offensive cooldowns with the first Colossus Smash window" },
        { text = "Your hero talent choice reshapes the burst window: Colossus leans on Demolish spenders stacked on Colossal Might inside Colossus Smash, while Slayer ties Bladestorm itself to the Colossus Smash/Avatar debuff instead of using it as a separate cleave cooldown" },
    }},
  },
  cooldowns = {
    { spellID = 107574, text = "Avatar — pair with Colossus Smash for maximum burst" },
    { spellID = 167105, text = "Colossus Smash — core damage-amp window, use on cooldown" },
    { spellID = 227847, text = "Bladestorm — strong AoE/cleave cooldown, also usable defensively; under the Slayer hero talent it's pulled into the Colossus Smash burst window instead",
      condition = "Slayer hero talent: use while your Colossus Smash debuff is active" },
    { spellID = 436358, text = "Demolish — Colossus hero talent spender, use on cooldown stacked on Colossal Might inside your Colossus Smash window",
      condition = "Colossus hero talent only" },
    { spellID = 118038, text = "Die by the Sword — major defensive, use under heavy melee pressure" },
    { spellID = 97462, text = "Rallying Cry — raid-wide defensive cooldown for group survival checks" },
  },
  consumables = {
    { slot = "Flask", text = "Flask of Tempered Aggression — matches this spec's top secondary; Flask of Alchemical Chaos is the flex pick if your stat weights are close" },
    { slot = "Food", text = "Loa's Gathering or Feast of Knowledge for raid (Stamina + your highest secondary); Hearty Venom-Spiced Cutlets or Puffer Plate for Mythic+/personal (prefer the Hearty version for death persistence)" },
    { slot = "Potion", text = "Tempered Potion, used inside your Colossus Smash burst window. Liquid Luster (builds Versatility over 30s) is a strong ramp/M+ alternative, Potion of Unwavering Focus if you want a pure single-target pick instead; always carry Concentrated Silvermoon Health Potions for the emergency heal." },
    { slot = "Weapon", text = "Ironclaw Whetstone or the current-tier weapon oil" },
    { slot = "Enchants", text = "Weapon enchant for Strength/Crit; ring enchants for secondary stats" },
    { slot = "Gems", text = "Strength or Strength/secondary hybrid gems in available sockets" },
    { slot = "Augment Rune", text = "Crystallized Augment Rune (1-hour primary stat) for progression pulls and high keys; the reusable Ethereal Augment Rune the rest of the time" },
  },
  gear = {
    { slot = "Head", text = "Tier set piece — the set bonus usually reshapes your Colossus Smash burst more than a small item-level gap does. Season 2's set bonus boosts Mortal Strike/Execute and gives Slam a small cleave, with the four-piece boosting Overpower and having it buff your next Slam, stacking." },
    { slot = "Neck", text = "Favor Crit and Mastery over Haste and Versatility to match Arms' stat priority" },
    { slot = "Back", text = "Treat it like any other armor slot — secondary stat weighting matters more than the base stat total" },
    { slot = "Legs", text = "Another tier slot when available; otherwise the highest item level piece with Crit and Mastery" },
    { slot = "Ring", text = "Crit- or Mastery-heavy rings outweigh ones leaning Haste or Versatility" },
    { slot = "Trinket", text = "One on-use Strength or damage-proc trinket timed to pop alongside Colossus Smash and Avatar" },
    { slot = "Trinket", text = "A second, passive stat-stick trinket for consistent damage between cooldown windows" },
    { slot = "Weapon", text = "The highest item level two-hander available — weapon damage drives a large share of Arms' output" },
  },
  -- Refreshed this pass (see file header): superseded string from an
  -- earlier, now-stale pull of the same file.
  mplusLoadout = {
    string = "CcEAAAAAAAAAAAAAAAAAAAAAAAzMzsMzMzMDAAAghphxYmxyMzMzgxMDAAAAgZWmZAZMWWGYBMgZYCZGsBMjNz2YwMGgZGAmxwA",
    source = "SimulationCraft default profile (credit, not endorsement of 'best')",
    patch = "12.1",
  },
  -- Live top-players pull (DESIGN.md's v1.4 section), NOT SimC - see this
  -- file's header for the full methodology. The plurality build among the
  -- sample: 8/50 (16%) ran this exact code, since flex-point choices vary - but
  -- the bigger signal is that 50/50 (100%) ran Slayer overall. Reported
  -- honestly rather than dressed up as more decisive than it is.
  mplusMetaLoadout = {
    string = "CcEASWsDSHNyPDXnbxuIhH3ZdjZmZmFzYmZGAAAghphxYmZzMzMzYmxMDAAAAgxyMDMhxy2ALgBMDTIzgNwMDDDmlZ2GgZGAMDDA",
    source = "Blizzard Battle.net API, US region, 2026-08-30: top 50 current-season Mythic+ Arms Warriors by best keystone level, sampled across all 83 US connected realms' leaderboards. This exact build was the plurality pick (8/50, 16%); 50/50 (100%) ran Slayer overall.",
    patch = "12.1",
    sampleSize = 50,
  },
  tips = {
    "Never let Rend fall off a target you'll be hitting for more than a few seconds.",
    "Save Overpower charges to spend rather than letting them cap and go to waste.",
    "Line up Colossus Smash, trinkets, and Avatar together whenever possible for maximum burst windows.",
    "Watch your rage bar during downtime — starving Mortal Strike of rage is a common DPS loss; Rage mostly comes from auto-attacks, so avoid melee downtime.",
    "Pre-cast Sweeping Strikes before a pull with multiple targets so it's active the instant you engage.",
  },
})

ns.GuideStore:RegisterSpec("WARRIOR", 72, {
  specName = "Fury",
  role = "DAMAGER",
  overview = {
    "Fury Warrior is a dual-wield melee spec that plays as a fast, rage-flooded brawler. Its core loop is built around Bloodthirst for rage generation and healing, and Raging Blow for spending the Enrage charges it grants, all while Whirlwind and Rampage fill in the gaps of a high-tempo priority rotation.",
    "The core resource is Rage, generated heavily from Bloodthirst and auto-attacks, and spent in large chunks on Rampage — which is both your main Rage sink and your main source of Enrage. The defining mechanic is the Enrage state — several abilities trigger or require it, so keeping yourself enraged as close to permanently as possible is the throughput backbone of the spec.",
    "Fury is a strong pick when you want simple positioning requirements, good sustained AoE from Whirlwind cleave, and consistent single-target damage without needing precise debuff-window timing — a good fit for both raid and Mythic+ content.",
  },
  statPriority = {
    { stat = "primary", note = "Strength, passive" },
    { stat = "haste", note = "smooths global cooldown and Enrage uptime" },
    { stat = "mastery" },
    { stat = "crit" },
    { stat = "versatility" },
  },
  rotation = {
    { title = "Opener", steps = {
        { spellID = 100, text = "Charge to open and generate your first Rage" },
        { spellID = 1719, text = "Recklessness early, so its burst window covers as much of the fight as possible" },
        { spellID = 107574, text = "Avatar alongside Recklessness for your first burst window" },
        { spellID = 23881, text = "Bloodthirst to establish Enrage immediately" },
    }},
    { title = "Single Target", steps = {
        { spellID = 1719, text = "Recklessness and Avatar on cooldown" },
        { spellID = 184367, text = "Rampage whenever you can afford it — refreshing Enrage is the top priority" },
        { spellID = 163201, text = "Execute whenever it's available" },
        { spellID = 85288, text = "Raging Blow to spend Enrage charges before they're wasted (Slayer's main filler)" },
        { spellID = 205545, text = "Odyn's Fury on cooldown" },
        { spellID = 23881, text = "Bloodthirst on cooldown — core Rage and Enrage generator" },
        { spellID = 1680, text = "Whirlwind if nothing else is available" },
        { text = "Keep Enrage as close to 100% uptime as possible — it underpins most of Fury's damage" },
    }},
    { title = "AoE", steps = {
        { spellID = 1680, text = "Whirlwind whenever the Improved Whirlwind buff isn't already active" },
        { spellID = 23881, text = "Bloodthirst still on cooldown for rage, healing, and cleave damage" },
        { spellID = 85288, text = "Raging Blow to dump Enrage charges — cleaves naturally" },
        { spellID = 163201, text = "Execute cleaves too — use it whenever available" },
        { spellID = 184367, text = "Rampage to maintain Enrage uptime while cleaving" },
        { spellID = 6343, text = "Thunder Clap for extra AoE threat and damage" },
        { spellID = 46968, text = "Shockwave to stun and cluster adds when available" },
    }},
    { title = "Opener Notes", steps = {
        { text = "Open with Bloodthirst to establish Enrage immediately, then weave Rampage as rage allows" },
        { text = "Save Recklessness for a moment you can chain several Enrage-consuming abilities back to back" },
        { text = "Your hero talent choice matters for burst sequencing: Slayer strings Recklessness into Rampage, Bladestorm, and Execute together, while Mountain Thane instead weaves Bloodthirst and Raging Blow through its own lightning-infused cooldown windows and leans on Thunder Blast for extra AoE. As a starting point, Slayer suits single-target raid bosses better and Mountain Thane suits Mythic+/add-heavy fights better — but check which one your loadout uses before assuming a fixed order, and re-sim if you're unsure" },
    }},
  },
  cooldowns = {
    { spellID = 1719, text = "Recklessness — pop for a burst window, ideally with trinkets" },
    { spellID = 107574, text = "Avatar — pair with Recklessness for the same burst window" },
    { spellID = 227847, text = "Bladestorm — strong cleave/AoE cooldown, also a brief defensive tool; under Slayer it's folded into the main Recklessness burst sequence" },
    { spellID = 205545, text = "Odyn's Fury — hard-hitting burst cooldown, weave into the same window as Recklessness" },
    { spellID = 184364, text = "Enraged Regeneration — self-healing cooldown for sustain checks" },
    { spellID = 23920, text = "Spell Reflection — reflects the next incoming spell, use against dangerous casts" },
    { spellID = 97462, text = "Rallying Cry — raid-wide defensive utility cooldown" },
  },
  consumables = {
    { slot = "Flask", text = "Flask of Tempered Swiftness — matches this spec's top secondary; Flask of Alchemical Chaos is the flex pick if your stat weights are close" },
    { slot = "Food", text = "Loa's Gathering or Feast of Knowledge for raid (Stamina + your highest secondary); Hearty Venom-Spiced Cutlets or Puffer Plate for Mythic+/personal (prefer the Hearty version for death persistence)" },
    { slot = "Potion", text = "Tempered Potion, used with Recklessness for burst. Liquid Luster (builds Versatility over 30s) is a strong ramp/M+ alternative, Potion of Unwavering Focus if you want a pure single-target pick instead; always carry Concentrated Silvermoon Health Potions for the emergency heal." },
    { slot = "Weapon", text = "Ironclaw Whetstone or the current-tier weapon oil on both weapons" },
    { slot = "Enchants", text = "Weapon enchant for Strength/Crit; ring enchants for secondary stats" },
    { slot = "Gems", text = "Strength or Strength/secondary hybrid gems in available sockets" },
    { slot = "Augment Rune", text = "Crystallized Augment Rune (1-hour primary stat) for progression pulls and high keys; the reusable Ethereal Augment Rune the rest of the time" },
  },
  gear = {
    { slot = "Head", text = "Tier set piece — the set bonus is usually worth more than a small item-level upgrade. Season 2's set bonus boosts Raging Blow and lets it extend Recklessness, with the four-piece boosting Bloodthirst and its crit bonus during Recklessness — check your tooltip for the exact current numbers, they vary by source." },
    { slot = "Neck", text = "Favor Haste to keep the global cooldown fast and Enrage uptime near-permanent" },
    { slot = "Back", text = "Pick up secondary stats matching Haste and Mastery over a raw item-level chase" },
    { slot = "Legs", text = "Another tier slot when possible; otherwise the highest item level piece with Haste and Mastery" },
    { slot = "Ring", text = "Haste-leaning rings support Enrage uptime and faster ability weaving" },
    { slot = "Trinket", text = "One on-use Strength or damage trinket lined up with Recklessness" },
    { slot = "Trinket", text = "A passive stat-stick trinket for sustained damage between cooldowns" },
    { slot = "Weapon", text = "Two matched, high item level one-handers — both weapons contribute equally to Fury's damage" },
  },
  mplusLoadout = {
    string = "CgEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAgGDzMmZ2MzMzMDjZmZGzMzsMzMmZmZzYmBAAixy2ALgJYGmAzwGwMDjNAAYmhxYYMYM",
    source = "SimulationCraft default profile (credit, not endorsement of 'best')",
    patch = "12.1",
  },
  -- Live top-players pull (DESIGN.md's v1.4 section), NOT SimC - see this
  -- file's header for the full methodology. The plurality build among the
  -- sample: 6/50 (12%) ran this exact code, since flex-point choices vary - but
  -- the bigger signal is that 46/50 (92%) ran Slayer overall. Reported honestly
  -- rather than dressed up as more decisive than it is.
  mplusMetaLoadout = {
    string = "CgEASWsDSHNyPDXnbxuIhH3ZdDAAAAAAAjhxYmZzMzMzMzMmZmZmZm5BWmxYmxsZmZGAAAjltBWADYGGgZYDYmhBAAYmhxsMMGMG",
    source = "Blizzard Battle.net API, US region, 2026-08-30: top 50 current-season Mythic+ Fury Warriors by best keystone level, sampled across all 83 US connected realms' leaderboards. This exact build was the plurality pick (6/50, 12%); 46/50 (92%) ran Slayer overall.",
    patch = "12.1",
    sampleSize = 50,
  },
  tips = {
    "Try to stay Enraged as close to 100% of the time as possible — it underpins most of Fury's damage.",
    "Don't let Raging Blow charges cap; spend them before they overflow.",
    "Whirlwind's passive buff is worth maintaining even on single target if it's about to fall off.",
    "Save Recklessness for windows where you can string several abilities together rather than opening cold.",
    "Rampage is both your best Rage sink and your main Enrage source — spend big chunks of Rage on it rather than trickling Rage away elsewhere.",
    "Open every pull with Charge into an early Recklessness/Avatar so the burst window covers as much of the fight as possible.",
  },
})

ns.GuideStore:RegisterSpec("WARRIOR", 73, {
  specName = "Protection",
  role = "TANK",
  overview = {
    "Protection Warrior is a shield-and-board tank that plays around Shield Block for physical mitigation and Ignore Pain as a damage-smoothing absorb shield. Its offense and defense are tightly linked: Revenge and Shield Slam generate rage that is spent both on threat abilities and on Ignore Pain to soak incoming hits.",
    "The core resource is Rage, generated from taking damage and auto-attacking, and the defining mechanic is the interplay between Shield Block (mitigation window) and Ignore Pain (absorb shield) — both compete for the same rage pool, so pacing rage spend between offense, block uptime, and pain absorption is the spec's central skill.",
    "Protection brings strong sustained mitigation, good AoE threat via Thunder Clap and Revenge, and reliable cooldowns for both magic and physical damage spikes, making it a dependable tank for both raid bosses and Mythic+ trash-heavy pulls.",
  },
  statPriority = {
    { stat = "stamina", note = "for survivability buffer" },
    { stat = "primary", note = "Strength, passive" },
    { stat = "mastery", note = "block value and chance" },
    { stat = "haste" },
    { stat = "versatility" },
    { stat = "crit" },
    { stat = "avoidance" },
  },
  rotation = {
    { title = "Opener", steps = {
        { spellID = 100, text = "Charge to open and establish threat" },
        { spellID = 23922, text = "Shield Slam as your first Rage-generating attack" },
        { spellID = 6343, text = "Thunder Clap to apply its debuff" },
        { spellID = 6572, text = "Revenge if it's free or already available" },
        { spellID = 2565, text = "Shield Block established as soon as you have the Rage for it" },
    }},
    { title = "Single Target", steps = {
        { spellID = 23922, text = "Shield Slam on cooldown — top rage priority, strong threat, and one of your two main Rage generators" },
        { spellID = 6343, text = "Thunder Clap to keep its debuff active on the target — your other main Rage generator" },
        { spellID = 6572, text = "Revenge when free or off cooldown for rage-efficient damage" },
        { spellID = 163201, text = "Execute in range to spend Rage efficiently" },
        { spellID = 190456, text = "Ignore Pain to smooth incoming damage, spending excess rage" },
        { spellID = 1160, text = "Demoralizing Shout for extra mitigation as needed" },
        { spellID = 20243, text = "Devastate as a rage-neutral filler when nothing else is ready" },
    }},
    { title = "AoE", steps = {
        { spellID = 6343, text = "Thunder Clap as the primary AoE threat generator (Thunder Blast under Mountain Thane)" },
        { spellID = 6572, text = "Revenge cleaves nearby targets — use liberally when free" },
        { spellID = 23922, text = "Shield Slam still on cooldown for single-target priority damage" },
        { spellID = 46968, text = "Shockwave to stun and control add clusters" },
        { spellID = 190456, text = "Ignore Pain to absorb burst damage from multiple attackers" },
        { text = "Rotate cooldowns proactively when pulling large packs" },
    }},
    { title = "Mitigation", steps = {
        { spellID = 2565, text = "Shield Block before predictable physical damage windows — your primary active mitigation" },
        { spellID = 190456, text = "Ignore Pain to convert spare rage into an absorb shield" },
        { spellID = 436358, text = "Demolish on cooldown, stacked on Colossal Might",
          condition = "Colossus hero talent only" },
        { spellID = 12975, text = "Last Stand for a big health buffer during dangerous phases" },
        { spellID = 871, text = "Shield Wall as the strongest cooldown for the heaviest damage spikes" },
        { text = "Rotate Shield Wall, Demoralizing Shout, Spell Reflection, and Last Stand across a fight's danger points rather than stacking them all on one pull" },
        { text = "Alternate Shield Block and Ignore Pain uptime so rage isn't wasted overcapping either" },
    }},
    { title = "Opener Notes", steps = {
        { text = "Your hero talent choice changes the opener: Mountain Thane leads with Thunder Blast ahead of Shield Slam to seed its own buffs, while Colossus keeps Shield Slam first and folds Thunder Clap in as a phalanx-refresh rather than a pure filler" },
    }},
  },
  cooldowns = {
    { spellID = 871, text = "Shield Wall — biggest defensive cooldown, save for the most dangerous hits" },
    { spellID = 12975, text = "Last Stand — extra effective health, pair with predictable burst damage" },
    { spellID = 2565, text = "Shield Block — core physical mitigation, keep uptime high" },
    { spellID = 1160, text = "Demoralizing Shout — raid-wide damage reduction utility" },
    { spellID = 23920, text = "Spell Reflection — reflects the next incoming spell, use against dangerous casts" },
    { spellID = 97462, text = "Rallying Cry — group-wide defensive cooldown for raid damage checks" },
  },
  consumables = {
    { slot = "Flask", text = "Flask of Tempered Mastery — matches this spec's top secondary; Flask of Alchemical Chaos is the flex pick if your stat weights are close" },
    { slot = "Food", text = "Loa's Gathering or Feast of Knowledge for raid (Stamina + your highest secondary); Hearty Venom-Spiced Cutlets or Puffer Plate for Mythic+/personal (prefer the Hearty version for death persistence)" },
    { slot = "Potion", text = "A Stamina or defensive potion for dangerous pulls/phases. Liquid Luster (builds Versatility over 30s) is a strong ramp/M+ alternative, Potion of Unwavering Focus if you want a pure single-target pick instead; always carry Concentrated Silvermoon Health Potions for the emergency heal." },
    { slot = "Weapon", text = "Ironclaw Whetstone or the current-tier weapon oil" },
    { slot = "Enchants", text = "Weapon enchant for Stamina/mitigation; ring enchants for secondary stats" },
    { slot = "Gems", text = "Stamina or Stamina/secondary hybrid gems in available sockets" },
    { slot = "Augment Rune", text = "Crystallized Augment Rune (1-hour primary stat) for progression pulls and high keys; the reusable Ethereal Augment Rune the rest of the time" },
  },
  gear = {
    { slot = "Head", text = "Tier set piece — mitigation- and threat-relevant set bonuses often outweigh raw item level for a tank. Season 2's set bonus boosts free Revenge procs and buffs your next Shield Slam, with the four-piece adding a bleed to Ravager and free Revenges and cutting Ravager's cooldown." },
    { slot = "Neck", text = "Balance Stamina for a survivability buffer against Mastery for block value" },
    { slot = "Back", text = "Prioritize Stamina and secondary stats over a pure item-level trade" },
    { slot = "Legs", text = "Another tier slot when possible; otherwise the highest item level piece with Stamina and Mastery" },
    { slot = "Ring", text = "Mastery or Haste rings depending on whether you need more block chance or faster Ignore Pain cycling" },
    { slot = "Trinket", text = "One defensive on-use trinket saved for the fight's heaviest predicted damage window" },
    { slot = "Trinket", text = "One passive Stamina or avoidance trinket for a steady survivability floor" },
    { slot = "Weapon", text = "A solid one-hander — Protection's damage comes mostly from abilities, so mitigation stats outweigh weapon dps" },
    { slot = "Off-hand", text = "The highest-armor shield you can equip, since shield block value scales your core mitigation ability" },
  },
  mplusLoadout = {
    string = "CkEAAAAAAAAAAAAAAAAAAAAAA02AAAzMDzMzMzMzmxsMjxYmGGDLzMzMDGzMAAAAYZAYGDAsYGDbwAzwCNmZBmxMDmNAAzMAgZgxA",
    source = "SimulationCraft default profile (credit, not endorsement of 'best')",
    patch = "12.1",
  },
  -- Live top-players pull (DESIGN.md's v1.4 section), NOT SimC - see this
  -- file's header for the full methodology. The plurality build among the
  -- sample: 2/50 (4%) ran this exact code, since flex-point choices vary - but
  -- the bigger signal is that 43/50 (86%) ran Mountain Thane overall. Reported
  -- honestly rather than dressed up as more decisive than it is.
  mplusMetaLoadout = {
    string = "CkEASWsDSHNyPDXnbxuIhH3ZdnBAAGzYmZmZmxsZmZZGjxoxMGWMzMzYGmZAAAAwyMDwMGgB2glFjGzAYWiZ2AmZGGbAwMDAAzAjB",
    source = "Blizzard Battle.net API, US region, 2026-08-30: top 50 current-season Mythic+ Protection Warriors by best keystone level, sampled across all 83 US connected realms' leaderboards. This exact build was the plurality pick (2/50, 4%); 43/50 (86%) ran Mountain Thane overall.",
    patch = "12.1",
    sampleSize = 50,
  },
  tips = {
    "Keep Shield Block active before big physical hits rather than reacting after the fact.",
    "Don't dump all your rage into Ignore Pain at once — spread it to smooth damage over time.",
    "Thunder Clap's debuff is worth refreshing even on single target for the extra mitigation, since it doubles as one of your two Rage generators alongside Shield Slam.",
    "Save your strongest defensive cooldown for known burst phases rather than reacting late.",
    "Rotate your secondary defensives (Shield Wall, Demoralizing Shout, Spell Reflection, Last Stand) across a fight's danger points instead of stacking them all on one pull.",
  },
})
