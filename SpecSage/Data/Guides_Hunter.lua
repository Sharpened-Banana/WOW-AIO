local ADDON, ns = ...

-- SpecSage guide data: Hunter (Beast Mastery 253, Marksmanship 254, Survival 255)
-- Content targets Midnight (patch 12.1). Specs below with an `mplusLoadout`
-- field have that talent string (only) cross-checked against
-- SimulationCraft's public profiles (github.com/simulationcraft/simc,
-- GPLv3) as of patch 12.1; specs without one have no such reference.
-- Rotation/overview/tips/gear prose throughout this file is hand-authored
-- and was reviewed for Midnight ability changes, not derived from or
-- checked against SimC's APLs, and was not re-verified against current
-- tuning this pass — EXCEPT Beast Mastery (253), Marksmanship (254), and Survival (255),
-- which each gained an `mplusMetaLoadout` (DESIGN.md's v1.4 section) this
-- pass: pulled live from Blizzard's own Battle.net Game Data API
-- (client-credentials OAuth, US region) rather than SimC, on 2026-08-30.
-- Methodology: every current-season Mythic+ leaderboard (8-dungeon pool,
-- period 1078) across all 83 US connected realms was scanned (top 20 groups
-- per realm/dungeon) for each spec's group members; the top-observed-keystone
-- characters (up to 50 per spec) had their live `specializations` looked up
-- for their active loadout's `talent_loadout_code`. See each field's own
-- `source` comment for the resulting distribution.
-- Survival's overview/rotation/tips were also corrected this pass: they
-- described the old Mongoose Bite/Mongoose Fury stacking mechanic and a
-- separate Coordinated Assault cooldown, both gone. SimC's current
-- `midnight` branch profile has zero references to either (mongoose_bite,
-- coordinated_assault) and is instead built entirely around Tip of the
-- Spear stacks spent on a new Takedown finisher; a Blizzard developer post
-- on the official forums states Takedown "combines aspects of both
-- Coordinated Assault and Flanking Strike."
-- This is community-maintained conventional guidance (stat priorities and
-- rotations that match the spec's long-standing design) — not a claim of
-- bleeding-edge sim-perfect optimization.
-- To edit: change the strings/tables below and reload. To add a spec pack,
-- call ns.GuideStore:RegisterSpec(classToken, specID, guideTable) from any
-- addon that loads after SpecSage; see Data/API.lua for validation rules.

if not ns.GuideStore then return end

ns.GuideStore:RegisterSpec("HUNTER", 253, {
  specName = "Beast Mastery",
  role = "DAMAGER",
  overview = {
    "Beast Mastery Hunter is a pet-focused ranged spec where a large share of the damage comes from your permanent pet, buffed heavily by Bestial Wrath and Kill Command. It plays as a mobile, simple-to-execute spec that stays fully effective while moving, since most casts are instant.",
    "The core resource is Focus, generated passively and from Cobra Shot, and spent on Kill Command and Barbed Shot. The defining mechanic is Barbed Shot's Frenzy stacks on your pet, which increase pet attack speed and must be refreshed regularly to keep pet damage — the spec's main damage source — at its peak.",
    "Beast Mastery is a strong pick for fights requiring constant movement, cleave-light single target, and simple resource management, making it a common choice for Mythic+ and progression pulls with heavy mechanics.",
  },
  statPriority = {
    { stat = "primary", note = "Agility, passive" },
    { stat = "crit" },
    { stat = "mastery", note = "boosts pet damage directly" },
    { stat = "haste" },
    { stat = "versatility" },
  },
  rotation = {
    { title = "Single Target", steps = {
        { spellID = 217200, text = "Barbed Shot to keep Frenzy stacks on your pet active" },
        { spellID = 34026, text = "Kill Command on cooldown — top Focus spender" },
        { spellID = 19574, text = "Bestial Wrath on cooldown for a burst window" },
        { spellID = 193455, text = "Cobra Shot to spend excess Focus and keep Barbed Shot's cooldown rolling" },
        { text = "Never let Barbed Shot's Frenzy buff fall off your pet" },
    }},
    { title = "AoE", steps = {
        { text = "Barrage or Multi-Shot to cleave Focus spenders across targets" },
        { spellID = 1264359, text = "Wild Thrash from your pet as a core AoE tool once 2+ targets are up" },
        { spellID = 217200, text = "Barbed Shot still prioritized to maintain Frenzy" },
        { spellID = 34026, text = "Kill Command on cooldown, hits cleave through pet talents" },
        { spellID = 19574, text = "Bestial Wrath for burst during add waves" },
        { spellID = 193455, text = "Cobra Shot as Focus dump when other cooldowns are down" },
        { text = "Keep pet uptime on the highest-priority target while cleaving" },
    }},
    { title = "Opener Notes", steps = {
        { text = "Send your pet in first and open with Barbed Shot to establish Frenzy before Bestial Wrath" },
        { text = "Use Bestial Wrath as close to pull as possible so its window overlaps your other cooldowns" },
    }},
  },
  cooldowns = {
    { spellID = 19574, text = "Bestial Wrath — core offensive cooldown, use on cooldown" },
    { text = "Aspect of the Wild — stack with Bestial Wrath for burst" },
    { spellID = 186265, text = "Aspect of the Turtle — major defensive, absorbs most damage briefly" },
    { spellID = 109304, text = "Exhilaration — self-healing cooldown for sustain checks" },
    { spellID = 5384, text = "Feign Death — drop threat/aggro or avoid certain mechanics" },
  },
  consumables = {
    { slot = "Flask", text = "Flask of Alchemical Chaos (Agility)" },
    { slot = "Food", text = "An Agility-focused feast or food buff" },
    { slot = "Potion", text = "Tempered Potion, used inside Bestial Wrath" },
    { slot = "Weapon", text = "Not typically enchanted — check current-tier weapon oil availability" },
    { slot = "Enchants", text = "Weapon enchant for Agility/Crit; ring enchants for secondary stats" },
    { slot = "Gems", text = "Agility or Agility/secondary hybrid gems in available sockets" },
  },
  gear = {
    { slot = "Head", text = "Tier set piece — the set bonus usually matters more than a small item-level gap" },
    { slot = "Neck", text = "Favor Crit and Mastery, since Mastery boosts pet damage directly for Beast Mastery" },
    { slot = "Back", text = "Secondary stats matching Crit and Mastery outweigh a pure item-level trade" },
    { slot = "Legs", text = "Another tier slot when possible; otherwise the highest item level piece leaning Crit and Mastery" },
    { slot = "Ring", text = "Crit or Mastery rings depending on your current stat weights" },
    { slot = "Trinket", text = "One on-use Agility or damage trinket lined up with Bestial Wrath" },
    { slot = "Trinket", text = "A passive stat-stick trinket for consistent pet and Focus-spender damage" },
    { slot = "Weapon", text = "Mostly a stat stick for Hunters — take the highest item level option since it doesn't gate ability damage directly" },
  },
  mplusLoadout = {
    string = "C0PAAAAAAAAAAAAAAAAAAAAAAAMmxwCsAzwwMsBAgZYMzyMDzYmxMMzYMzwMjZMziZmxMmBjpZAAAAAzAAAwYmZAmZjxGMLgtBgBA",
    source = "SimulationCraft default profile (credit, not endorsement of 'best')",
    patch = "12.1",
  },
  -- Live top-players pull (DESIGN.md's v1.4 section), NOT SimC - see this
  -- file's header for the full methodology. The plurality build among the
  -- sample: 6/50 (12%) ran this exact code, since flex-point choices vary - but
  -- the bigger signal is that 50/50 (100%) ran Pack Leader overall. Reported
  -- honestly rather than dressed up as more decisive than it is.
  mplusMetaLoadout = {
    string = "C0PAD57yiELKEty14ekTDtZEqAMmxwCsAzwQDbAAYGzMzsYGzMzMjZGMzYmhZGzMzYbmZMjZYZMNDAAAAAAAA8AjxAmZjAmFw2AwA",
    source = "Blizzard Battle.net API, US region, 2026-08-30: top 50 current-season Mythic+ Beast Mastery Hunters by best keystone level, sampled across all 83 US connected realms' leaderboards. This exact build was the plurality pick (6/50, 12%); 50/50 (100%) ran Pack Leader overall.",
    patch = "12.1",
    sampleSize = 50,
  },
  tips = {
    "Keep Barbed Shot's Frenzy buff active on your pet at essentially all times — this is the spec's core damage driver.",
    "Line up Bestial Wrath with Aspect of the Wild and trinkets for maximum burst.",
    "Feign Death is useful defensively as well as for threat — it can dodge some mechanics entirely.",
    "Avoid capping Focus; Cobra Shot exists specifically to prevent Focus overflow.",
  },
})

ns.GuideStore:RegisterSpec("HUNTER", 254, {
  specName = "Marksmanship",
  role = "DAMAGER",
  overview = {
    "Marksmanship Hunter is a precision ranged spec built around hard-hitting cast-time shots, most notably Aimed Shot, amplified by Trueshot and Precise Shots procs. It plays with more positioning and casting discipline than the other Hunter specs, rewarding careful use of instant-cast windows while moving.",
    "The core resource is Focus, generated from Steady Shot and passive regeneration, and spent primarily on Aimed Shot and Rapid Fire. The defining mechanic is the Precise Shots buff, generated by Trick Shots/Aimed Shot interactions, which makes your next Arcane Shot or Multi-Shot free and empowered — sequencing around this buff is central to the rotation.",
    "Marksmanship brings strong burst windows under Trueshot, good execute-phase damage, and solid ranged utility (traps, Concussive Shot), making it a good pick for fights that reward burst windows and have some downtime to cast in.",
  },
  statPriority = {
    { stat = "primary", note = "Agility, passive" },
    { stat = "crit" },
    { stat = "mastery" },
    { stat = "haste", note = "smooths cast time on Aimed Shot" },
    { stat = "versatility" },
  },
  rotation = {
    { title = "Single Target", steps = {
        { spellID = 19434, text = "Aimed Shot as the primary Focus spender and damage source" },
        { spellID = 257044, text = "Rapid Fire on cooldown for burst Focus and damage" },
        { spellID = 185358, text = "Arcane Shot to spend Precise Shots procs" },
        { spellID = 56641, text = "Steady Shot to generate Focus between spenders" },
        { spellID = 288613, text = "Trueshot on cooldown, ideally lined up with other burst" },
        { text = "Never let a Precise Shots proc go unused before it expires" },
    }},
    { title = "AoE", steps = {
        { spellID = 257620, text = "Multi-Shot to apply Trick Shots and cleave Aimed Shot across targets" },
        { spellID = 19434, text = "Aimed Shot cleaves while Trick Shots is active" },
        { spellID = 257044, text = "Rapid Fire on cooldown, hits multiple targets" },
        { spellID = 185358, text = "Arcane Shot/Multi-Shot to spend Precise Shots procs" },
        { spellID = 56641, text = "Steady Shot as Focus filler between cooldowns" },
        { text = "Keep Trick Shots active whenever 2+ targets are engaged" },
    }},
    { title = "Opener Notes", steps = {
        { text = "Pre-pot and open with Trueshot lined up against your first Aimed Shot for a strong burst window" },
        { text = "Use Rapid Fire early to build Focus for a follow-up Aimed Shot volley" },
        { text = "The Dark Ranger hero talent weaves in Black Arrow and Wailing Arrow around the same Aimed Shot/Precise Shots priority — it adds to the core rotation rather than replacing it" },
    }},
  },
  cooldowns = {
    { spellID = 288613, text = "Trueshot — core offensive cooldown, align with trinkets and burst windows" },
    { spellID = 257044, text = "Rapid Fire — Focus and damage cooldown, use on cooldown" },
    { spellID = 186265, text = "Aspect of the Turtle — major defensive, absorbs most damage briefly" },
    { spellID = 109304, text = "Exhilaration — self-healing cooldown for sustain checks" },
    { spellID = 5384, text = "Feign Death — drop threat/aggro or avoid certain mechanics" },
  },
  consumables = {
    { slot = "Flask", text = "Flask of Alchemical Chaos (Agility)" },
    { slot = "Food", text = "An Agility-focused feast or food buff" },
    { slot = "Potion", text = "Tempered Potion, used inside Trueshot" },
    { slot = "Weapon", text = "Not typically enchanted — check current-tier weapon oil availability" },
    { slot = "Enchants", text = "Weapon enchant for Agility/Crit; ring enchants for secondary stats" },
    { slot = "Gems", text = "Agility or Agility/secondary hybrid gems in available sockets" },
  },
  gear = {
    { slot = "Head", text = "Tier set piece — the set bonus usually outweighs a small item-level gap" },
    { slot = "Neck", text = "Favor Crit and Mastery to match Marksmanship's stat priority" },
    { slot = "Back", text = "Secondary stats matching Crit and Mastery outweigh a pure item-level chase" },
    { slot = "Legs", text = "Another tier slot when possible; otherwise the highest item level piece leaning Crit and Mastery" },
    { slot = "Ring", text = "Crit or Haste rings depending on whether burst or cast-time smoothing is your current bottleneck" },
    { slot = "Trinket", text = "One on-use Agility or damage trinket lined up with Trueshot" },
    { slot = "Trinket", text = "A passive stat-stick trinket for consistent Aimed Shot damage" },
    { slot = "Weapon", text = "Mostly a stat stick — take the highest item level option available" },
  },
  mplusLoadout = {
    string = "C4PAAAAAAAAAAAAAAAAAAAAAAwCMwMGzYZAjZwGAAAAAAAAYGzYmFzYmZMDGTzYwYbZmZmZmZmZWYmlBzAAAGzMjBwM22gBYjZ2mxAA",
    source = "SimulationCraft default profile (credit, not endorsement of 'best')",
    patch = "12.1",
  },
  -- Live top-players pull (DESIGN.md's v1.4 section), NOT SimC - see this
  -- file's header for the full methodology. The plurality build among the
  -- sample: 5/50 (10%) ran this exact code, since flex-point choices vary - but
  -- the bigger signal is that 50/50 (100%) ran Sentinel overall. Reported
  -- honestly rather than dressed up as more decisive than it is.
  mplusMetaLoadout = {
    string = "C4PAD57yiELKEty14ekTDtZEqwGMwMGNWGQmBbAAAAAAAAgZMzMjtZMzMmhlx0MGMLbLzMzMzMzMzCzsMMDAAgHYMGAmxGYA2YmtZMA",
    source = "Blizzard Battle.net API, US region, 2026-08-30: top 50 current-season Mythic+ Marksmanship Hunters by best keystone level, sampled across all 83 US connected realms' leaderboards. This exact build was the plurality pick (5/50, 10%); 50/50 (100%) ran Sentinel overall.",
    patch = "12.1",
    sampleSize = 50,
  },
  tips = {
    "Don't let Precise Shots procs sit unused — they're a meaningful chunk of your damage.",
    "Line up Trueshot with Rapid Fire and trinkets for the biggest burst windows.",
    "Keep Trick Shots active any time you're facing two or more targets.",
    "Position for uninterrupted casting whenever possible — Aimed Shot is a real cast time, not instant.",
  },
})

ns.GuideStore:RegisterSpec("HUNTER", 255, {
  specName = "Survival",
  role = "DAMAGER",
  overview = {
    "Survival Hunter is a melee spec (uniquely among Hunter specs) that combines direct weapon attacks with pet support and DoT-style bleeds. It plays as an aggressive, mobility-heavy melee spec that still keeps a pet as a secondary damage source, blending Kill Command with Raptor Strike and a Takedown-based finisher.",
    "The core resource is Focus, generated from auto-attacks and abilities like Raptor Strike, and spent on Kill Command and Wildfire Bomb. The defining mechanic is building Tip of the Spear stacks from Kill Command and Wildfire Bomb, then spending them on Takedown — the hard-hitting finisher that replaced Mongoose Bite/Mongoose Fury (and folded in what used to be the separate Coordinated Assault cooldown) in Midnight.",
    "Survival brings strong sustained single-target damage, useful AoE via Wildfire Bomb, and melee utility (Muzzle interrupt, traps), making it a solid pick for fights where melee positioning is viable and you want pet-assisted burst.",
  },
  statPriority = {
    { stat = "primary", note = "Agility, passive" },
    { stat = "haste" },
    { stat = "crit" },
    { stat = "mastery" },
    { stat = "versatility" },
  },
  rotation = {
    { title = "Single Target", steps = {
        { spellID = 259495, text = "Wildfire Bomb on cooldown — strong Focus-free damage and DoT" },
        { spellID = 34026, text = "Kill Command on cooldown for pet-assisted burst" },
        { text = "Takedown once Tip of the Spear stacks are up — your main single-target finisher" },
        { spellID = 186270, text = "Raptor Strike as a Focus-efficient filler and builder" },
        { spellID = 190925, text = "Harpoon to close distance and enable extra melee uptime" },
        { text = "Keep bleeds/DoTs active on the target between cooldown usage" },
    }},
    { title = "AoE", steps = {
        { spellID = 259495, text = "Wildfire Bomb as the primary AoE cooldown, hits and DoTs multiple targets" },
        { spellID = 212436, text = "Butchery to cleave nearby targets with melee swings" },
        { spellID = 34026, text = "Kill Command on cooldown across the pull" },
        { spellID = 186270, text = "Raptor Strike as filler when other cooldowns are down" },
        { text = "Prioritize Butchery over single-target fillers while 2+ targets are in melee range" },
        { text = "Keep Wildfire Bomb's DoT rolling across as many targets as possible" },
    }},
    { title = "Opener Notes", steps = {
        { text = "Open with Wildfire Bomb and Kill Command to establish damage and build Tip of the Spear stacks" },
        { text = "Line up Takedown with your other burst cooldowns once Tip of the Spear stacks are up" },
        { text = "Your hero talent choice splits the rotation in two: Pack Leader leans on its pet-summon procs alongside the core builders, while Sentinel runs its own separate priority list — check which one your loadout uses" },
    }},
  },
  cooldowns = {
    { text = "Takedown — core offensive cooldown (replaced Mongoose Bite and folded in the old Coordinated Assault), use once Tip of the Spear stacks are up" },
    { spellID = 259495, text = "Wildfire Bomb — frequent damage cooldown, weave in on cooldown" },
    { spellID = 186265, text = "Aspect of the Turtle — major defensive, absorbs most damage briefly" },
    { spellID = 109304, text = "Exhilaration — self-healing cooldown for sustain checks" },
    { spellID = 5384, text = "Feign Death — drop threat/aggro or avoid certain mechanics" },
  },
  consumables = {
    { slot = "Flask", text = "Flask of Alchemical Chaos (Agility)" },
    { slot = "Food", text = "An Agility-focused feast or food buff" },
    { slot = "Potion", text = "Tempered Potion, used inside a Takedown window" },
    { slot = "Weapon", text = "Ironclaw Whetstone or the current-tier weapon oil" },
    { slot = "Enchants", text = "Weapon enchant for Agility/Crit; ring enchants for secondary stats" },
    { slot = "Gems", text = "Agility or Agility/secondary hybrid gems in available sockets" },
  },
  gear = {
    { slot = "Head", text = "Tier set piece — the set bonus usually matters more than a small item-level gap" },
    { slot = "Neck", text = "Favor Haste to speed up Focus generation and Tip of the Spear stacking" },
    { slot = "Back", text = "Secondary stats matching Haste and Crit outweigh a pure item-level chase" },
    { slot = "Legs", text = "Another tier slot when possible; otherwise the highest item level piece leaning Haste and Crit" },
    { slot = "Ring", text = "Haste or Crit rings depending on your current stat weights" },
    { slot = "Trinket", text = "One on-use Agility or damage trinket lined up with a Takedown window" },
    { slot = "Trinket", text = "A passive stat-stick trinket for consistent melee and Kill Command damage" },
    { slot = "Weapon", text = "A melee weapon this time, since Survival fights in melee — take the highest item level option with useful secondary stats" },
  },
  mplusLoadout = {
    string = "C8PAAAAAAAAAAAAAAAAAAAAAAMWgBmxoxyAYmgtZMzMGzyAAAAAAwMmxMLmxYGzgx0MAAAADAmxyyMzsYMzMjZmBAzYZDGDjNDAA",
    source = "SimulationCraft default profile (credit, not endorsement of 'best')",
    patch = "12.1",
  },
  -- Live top-players pull (DESIGN.md's v1.4 section), NOT SimC - see this
  -- file's header for the full methodology. The plurality build among the
  -- sample: 5/50 (10%) ran this exact code, since flex-point choices vary - but
  -- the bigger signal is that 30/50 (60%) ran Sentinel overall. Reported
  -- honestly rather than dressed up as more decisive than it is.
  mplusMetaLoadout = {
    string = "C8PAD57yiELKEty14ekTDtZEqMWgBmxoxyAYmgtZmZmZGz28AAAAAAAmxMzM2mxYGzwyYaGAAAgBAGLLzMWwMz4BGjBgZsBGjZmNDA",
    source = "Blizzard Battle.net API, US region, 2026-08-30: top 50 current-season Mythic+ Survival Hunters by best keystone level, sampled across all 83 US connected realms' leaderboards. This exact build was the plurality pick (5/50, 10%); 30/50 (60%) ran Sentinel overall.",
    patch = "12.1",
    sampleSize = 50,
  },
  tips = {
    "Build Tip of the Spear stacks before spending them on Takedown rather than using it early.",
    "Wildfire Bomb has a short cooldown — don't let it sit unused, especially in AoE.",
    "Butchery is worth prioritizing over single-target fillers as soon as a second target is in melee range.",
    "Muzzle is a strong interrupt — use it proactively on scripted casts rather than saving it indefinitely.",
  },
})
