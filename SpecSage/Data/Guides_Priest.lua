local ADDON, ns = ...

-- SpecSage guide data: Priest (Discipline 256, Holy 257, Shadow 258)
-- Content targets Midnight (patch 12.1). Specs below with an `mplusLoadout`
-- field have that talent string (only) cross-checked against
-- SimulationCraft's public profiles (github.com/simulationcraft/simc,
-- GPLv3) as of patch 12.1; specs without one have no such reference.
-- Rotation/overview/tips/gear prose throughout this file is hand-authored
-- and was reviewed for Midnight ability changes, not derived from or
-- checked against SimC's APLs, and was not re-verified against current
-- tuning this pass — EXCEPT Discipline (256), Holy (257), and Shadow (258),
-- which each gained an `mplusMetaLoadout` (DESIGN.md's v1.4 section) this
-- pass: pulled live from Blizzard's own Battle.net Game Data API
-- (client-credentials OAuth, US region) rather than SimC, on 2026-08-30.
-- Methodology: every current-season Mythic+ leaderboard (8-dungeon pool,
-- period 1078) across all 83 US connected realms was scanned (top 20 groups
-- per realm/dungeon) for each spec's group members; the top-observed-keystone
-- characters (up to 50 per spec) had their live `specializations` looked up
-- for their active loadout's `talent_loadout_code`. See each field's own
-- `source` comment for the resulting distribution.
-- Shadow's overview/rotation/tips were also corrected this pass, confirmed
-- against SimC's current `midnight` branch profile: Shadow Crash has zero
-- references (replaced by Tentacle Slam, confirmed via a Blizzard forum
-- thread titled "Replacing One of the Worst Spells Ever Designed (Shadow
-- Crash) With Something Worse (Tentacle Slam)"), and Void Bolt/Void
-- Eruption both have zero references (Voidform is now a directly-cast
-- burst-window cooldown, with Void Volley as the limited-use Insanity
-- spender inside it, per Blizzard's Curse of Ula'tek Content Update Notes).
-- This is community-maintained conventional guidance (stat priorities and
-- rotations that match the spec's long-standing design) — not a claim of
-- bleeding-edge sim-perfect optimization.
-- To edit: change the strings/tables below and reload. To add a spec pack,
-- call ns.GuideStore:RegisterSpec(classToken, specID, guideTable) from any
-- addon that loads after SpecSage; see Data/API.lua for validation rules.

if not ns.GuideStore then return end

-- Discipline (256): revised for 12.1 from Blizzard patch-note content reached
-- via search summaries, not from a directly-fetched patch-notes page, and not
-- SimC-cross-checked (no SimC profile exists for this spec — SimC does not
-- publish healer profiles). The specific numbers/mechanics below are
-- UNVERIFIED against a primary source and should be treated as provisional
-- pending direct confirmation. No mplusLoadout is shipped for this spec for
-- the same reason; see the file header and DESIGN.md's "BiS / Gear" section.
ns.GuideStore:RegisterSpec("PRIEST", 256, {
  specName = "Discipline",
  role = "HEALER",
  overview = {
    "Discipline Priest is a hybrid healer that converts damage into healing through Atonement — a buff applied to allies that turns your damage spells into heals on them. It plays less like a traditional reactive healer and more like a proactive damage-dealer whose output is redirected into the raid's health bars.",
    "The core resource is Mana, spent on both direct heals and the damage spells that trigger Atonement healing, most notably Penance and Smite. The defining mechanic is Atonement uptime — keeping the buff active on as many allies as possible before damage happens, so your damage output translates directly into pre-emptive healing. Patch 12.1 rebalanced this conversion: Discipline's damage output was brought down while the Atonement conversion rate itself was raised, so the spec still turns damage into meaningful healing, just via a smaller amount of harder-hitting damage rather than raw damage volume.",
    "Oracle's Penance changes (extra charge, overheal protection) and Voidweaver's Entropic Rift / Void Blast are the two hero talent paths. Entropic Rift's damage was buffed in 12.1; Void Blast is channeled, so it requires standing still. Discipline brings strong damage-mitigation-as-healing through Power Word: Shield and Pain Suppression, solid raid cooldowns, and a unique playstyle that rewards good raid-damage prediction.",
  },
  statPriority = {
    { stat = "primary", note = "Intellect, passive" },
    { stat = "crit" },
    { stat = "haste" },
    { stat = "mastery", note = "increases Atonement healing" },
    { stat = "versatility" },
  },
  rotation = {
    { title = "Priorities", steps = {
        { spellID = 194509, text = "Power Word: Radiance to spread Atonement to the group before damage lands" },
        { spellID = 47540, text = "Penance as a strong Atonement trigger and direct heal/damage" },
        { spellID = 585, text = "Smite to maintain Atonement healing with efficient mana use" },
        { spellID = 17, text = "Power Word: Shield on the target about to take a hit" },
        { spellID = 214621, text = "Schism or a similar damage cooldown to spike Atonement healing" },
        { text = "Keep Atonement active on as many raid members as possible before damage phases" },
    }},
    { title = "Cooldown Usage", steps = {
        { spellID = 33206, text = "Pain Suppression on the tank or target about to take a lethal-range hit" },
        { spellID = 62618, text = "Power Word: Barrier for a raid-wide damage reduction and healing zone" },
        { spellID = 373481, text = "Power Word: Life as an emergency instant heal on a critically low-health target" },
        { text = "Pre-shield the raid and refresh Atonement right before a known burst damage phase" },
        { text = "Save your strongest cooldown for the highest predicted damage spike rather than reacting late" },
    }},
  },
  cooldowns = {
    { spellID = 62618, text = "Power Word: Barrier — raid-wide cooldown, use for known heavy damage windows" },
    { spellID = 33206, text = "Pain Suppression — strong single-target defensive/healing cooldown" },
    { spellID = 373481, text = "Power Word: Life — emergency instant heal, prevents a lethal hit on a low-health target" },
    { spellID = 10060, text = "Power Infusion — offensive/support cooldown, use on yourself or a strong DPS ally" },
    { spellID = 47536, text = "Rapture — boosts Power Word: Shield strength and grants Atonement to everyone you shield" },
  },
  consumables = {
    { slot = "Flask", text = "Flask of Alchemical Chaos (Intellect)" },
    { slot = "Food", text = "An Intellect-focused feast or food buff" },
    { slot = "Potion", text = "A mana or Intellect potion for extended healing-heavy fights" },
    { slot = "Weapon", text = "Shadowcore Oil or the current-tier weapon oil" },
    { slot = "Enchants", text = "Weapon enchant for Intellect/haste; ring enchants for secondary stats" },
    { slot = "Gems", text = "Intellect or Intellect/secondary hybrid gems in available sockets" },
  },
  gear = {
    { slot = "Head", text = "Tier set piece — the set bonus usually matters more than a small item-level gap" },
    { slot = "Neck", text = "Favor Crit and Haste to strengthen Penance and Smite's Atonement healing" },
    { slot = "Back", text = "Pick up Intellect and secondary stats over a pure item-level upgrade" },
    { slot = "Legs", text = "Another tier slot when possible; otherwise the highest item level piece leaning Crit and Mastery" },
    { slot = "Ring", text = "Crit or Mastery rings depending on whether burst healing or Atonement scaling needs more support" },
    { slot = "Trinket", text = "One mana-efficiency trinket for extended fights" },
    { slot = "Trinket", text = "One throughput trinket timed with Power Word: Barrier or Rapture windows" },
    { slot = "Weapon", text = "A one-hander with strong Intellect and secondary stats rather than a pure item-level chase" },
    { slot = "Off-hand", text = "An off-hand caster stat stick for extra Intellect and secondary stats" },
  },
  -- Live top-players pull (DESIGN.md's v1.4 section), NOT SimC - see this
  -- file's header for the full methodology. The plurality build among the
  -- sample: 2/50 (4%) ran this exact code, since flex-point choices vary - but
  -- the bigger signal is that 38/50 (76%) ran Oracle overall. Reported honestly
  -- rather than dressed up as more decisive than it is.
  mplusMetaLoadout = {
    string = "CAQAR03Gt7xPmcDNOjs2Zlb3yCDsMDWmZMmBmZbmtZmZmxMDAAAAAAAAAgZYZGMzMzwYmBbmmJGgZWwQYMLDwYwCAAMmZmxgZAmZGBzA",
    source = "Blizzard Battle.net API, US region, 2026-08-30: top 50 current-season Mythic+ Discipline Priests by best keystone level, sampled across all 83 US connected realms' leaderboards. This exact build was the plurality pick (2/50, 4%); 38/50 (76%) ran Oracle overall.",
    patch = "12.1",
    sampleSize = 50,
  },
  tips = {
    "Keep Atonement spread across the raid before damage happens, not after.",
    "Power Word: Shield is both mitigation and an Atonement application tool — use it proactively.",
    "Save Power Word: Barrier and Pain Suppression for the fight's known heaviest damage windows.",
    "Smite is mana-efficient Atonement healing — don't neglect it just because it looks like a 'DPS' spell.",
    "Since patch 12.1 raised the Atonement conversion rate while trimming Discipline's raw damage, don't chase damage numbers for their own sake — a smaller amount of well-timed damage on Atonement'd targets still converts into strong healing.",
  },
})

-- Holy (257): revised for 12.1 from Blizzard patch-note content reached via
-- search summaries, not from a directly-fetched patch-notes page, and not
-- SimC-cross-checked (no SimC profile exists for this spec — SimC does not
-- publish healer profiles). The specific numbers/mechanics below are
-- UNVERIFIED against a primary source and should be treated as provisional
-- pending direct confirmation. No mplusLoadout is shipped for this spec for
-- the same reason; see the file header and DESIGN.md's "BiS / Gear" section.
ns.GuideStore:RegisterSpec("PRIEST", 257, {
  specName = "Holy",
  role = "HEALER",
  overview = {
    "Holy Priest is a versatile healer that blends strong AoE healing tools (Circle of Healing, Prayer of Healing, Holy Word: Sanctify) with solid single-target throughput from Flash Heal and Heal, all built around the Holy Word cooldown-reduction system.",
    "The core resource is Mana, spent across a wide toolkit of direct and AoE heals. The defining mechanic is the Holy Word system — casting Serenity/Sanctify/Chastise reduces the cooldown of your other Holy Words based on healing/damage done, rewarding a rotation that keeps weaving these together rather than spamming a single spell. Patch 12.1 leaned into this: the Words of the Wise talent now gives a much larger healing bonus to Holy Word: Serenity and Holy Word: Sanctify than before, so keeping both on cooldown is more valuable than ever, and Enlightenment now returns mana noticeably faster, easing the spec's traditional mana pressure over a long fight.",
    "Oracle and Archon are the two hero talent paths. Oracle's healing was tuned up in 12.1. Archon builds around empowering Halo. Holy Priest brings excellent raid-wide AoE healing, strong cooldowns (Apotheosis, Divine Hymn), and useful utility (Mass Dispel, Leap of Faith).",
  },
  statPriority = {
    { stat = "primary", note = "Intellect, passive" },
    { stat = "crit" },
    { stat = "haste" },
    { stat = "mastery", note = "boosts Echo of Light-style residual healing" },
    { stat = "versatility" },
  },
  rotation = {
    { title = "Priorities", steps = {
        { spellID = 2050, text = "Holy Word: Serenity on cooldown for strong single-target healing — Words of the Wise makes this hit noticeably harder as of 12.1, so don't let it sit unused" },
        { spellID = 34861, text = "Holy Word: Sanctify on cooldown for AoE healing coverage — also boosted by Words of the Wise" },
        { spellID = 596, text = "Prayer of Healing for grouped-up raid healing" },
        { spellID = 2061, text = "Flash Heal for fast reactive single-target healing" },
        { spellID = 139, text = "Renew to keep a low-cost HoT rolling on the tank or a spiking target" },
        { text = "Weave damage spells (Smite/Holy Fire) when healing demand is low to reduce Holy Word cooldowns" },
    }},
    { title = "Cooldown Usage", steps = {
        { spellID = 64843, text = "Divine Hymn during a sustained heavy raid-damage phase" },
        { spellID = 200183, text = "Apotheosis to empower your next Holy Word casts, use with a burst window" },
        { spellID = 47788, text = "Guardian Spirit as an emergency save on a critical target" },
        { text = "Pre-cast Renew or shields before a known damage spike where possible" },
        { text = "Stack Apotheosis with Holy Word: Serenity/Sanctify for the strongest healing windows" },
    }},
  },
  cooldowns = {
    { spellID = 64843, text = "Divine Hymn — sustained raid-wide healing cooldown" },
    { spellID = 47788, text = "Guardian Spirit — emergency save, prevents a lethal hit" },
    { spellID = 200183, text = "Apotheosis — empowers Holy Word casts, use inside a burst window" },
    { spellID = 33076, text = "Prayer of Mending — bounces between allies, refresh it before it runs out of jumps" },
    { spellID = 73325, text = "Leap of Faith — utility cooldown to pull an ally out of danger" },
  },
  consumables = {
    { slot = "Flask", text = "Flask of Alchemical Chaos (Intellect)" },
    { slot = "Food", text = "An Intellect-focused feast or food buff" },
    { slot = "Potion", text = "A mana or Intellect potion for extended healing-heavy fights" },
    { slot = "Weapon", text = "Shadowcore Oil or the current-tier weapon oil" },
    { slot = "Enchants", text = "Weapon enchant for Intellect/haste; ring enchants for secondary stats" },
    { slot = "Gems", text = "Intellect or Intellect/secondary hybrid gems in available sockets" },
  },
  gear = {
    { slot = "Head", text = "Tier set piece — the set bonus usually matters more than a small item-level gap" },
    { slot = "Neck", text = "Favor Crit and Haste to speed up Holy Word cooldown reduction" },
    { slot = "Back", text = "Pick up Intellect and secondary stats over a pure item-level upgrade" },
    { slot = "Legs", text = "Another tier slot when possible; otherwise the highest item level piece leaning Crit and Mastery" },
    { slot = "Ring", text = "Crit or Mastery rings depending on whether burst or sustained healing needs more support" },
    { slot = "Trinket", text = "One mana-efficiency trinket for long fights" },
    { slot = "Trinket", text = "One throughput trinket timed with Apotheosis or Divine Hymn windows" },
    { slot = "Weapon", text = "A one-hander with strong Intellect and secondary stats rather than a pure item-level chase" },
    { slot = "Off-hand", text = "An off-hand caster stat stick for extra Intellect and secondary stats" },
  },
  -- Live top-players pull (DESIGN.md's v1.4 section), NOT SimC - see this
  -- file's header for the full methodology. The plurality build among the
  -- sample: 3/50 (6%) ran this exact code, since flex-point choices vary - but
  -- the bigger signal is that 50/50 (100%) ran Oracle overall. Reported
  -- honestly rather than dressed up as more decisive than it is.
  mplusMetaLoadout = {
    string = "CEQAR03Gt7xPmcDNOjs2Zlb3yyYAAAAAAAMzMmlxMjZGDzALzMzMAAAAGzsMDmZmx2MmZAMTBwMLYIMmtBYMwiZmBgmxMjxgZAmZGwA",
    source = "Blizzard Battle.net API, US region, 2026-08-30: top 50 current-season Mythic+ Holy Priests by best keystone level, sampled across all 83 US connected realms' leaderboards. This exact build was the plurality pick (3/50, 6%); 50/50 (100%) ran Oracle overall.",
    patch = "12.1",
    sampleSize = 50,
  },
  tips = {
    "Weave in a damage spell when nobody needs healing — it reduces your Holy Word cooldowns.",
    "Use Holy Word: Sanctify and Serenity on cooldown rather than saving them, since usage reduces their own cooldowns — and since 12.1 buffed Words of the Wise, these two casts are worth even more than before.",
    "Save Divine Hymn for sustained damage phases rather than single burst spikes.",
    "Renew is cheap — keep it rolling on the tank between bigger heals.",
    "Enlightenment's mana regen was buffed substantially in 12.1 — you should feel noticeably less mana-starved on longer fights than in prior tiers.",
  },
})

ns.GuideStore:RegisterSpec("PRIEST", 258, {
  specName = "Shadow",
  role = "DAMAGER",
  overview = {
    "Shadow Priest is a DoT-focused caster spec built around maintaining Shadow Word: Pain and Vampiric Touch on the target while spending Insanity on Mind Blast, entering Voidform (a directly-cast burst-window cooldown) to unlock a handful of Void Volley casts. It plays as a sustained-pressure spec with an escape-into-Voidform rhythm that rewards good DoT and Insanity management.",
    "The core resource is Insanity, generated from Mind Blast, Mind Flay, and DoT ticks, and spent on Void Volley once you're in Voidform. The defining mechanic is DoT uptime combined with the Insanity-fueled Voidform burst window, where damage output is meaningfully higher and must be timed with cooldowns and add windows.",
    "Shadow Priest brings strong DoT-based cleave and AoE through Tentacle Slam, useful raid utility (Mass Dispel, Fade), and solid execute-independent scaling, making it a good pick for fights with multiple DoT-friendly targets or sustained add phases.",
  },
  statPriority = {
    { stat = "primary", note = "Intellect, passive" },
    { stat = "haste", note = "faster DoT ticks and Insanity generation" },
    { stat = "mastery" },
    { stat = "crit" },
    { stat = "versatility" },
  },
  rotation = {
    { title = "Single Target", steps = {
        { spellID = 589, text = "Shadow Word: Pain kept active on the target" },
        { spellID = 34914, text = "Vampiric Touch kept active on the target" },
        { spellID = 8092, text = "Mind Blast on cooldown — strong Insanity generator" },
        { spellID = 15407, text = "Mind Flay as your primary Insanity-neutral filler" },
        { text = "Once in Voidform, spend your limited Void Volley casts before it ends" },
        { text = "Void Torrent during your burst window — a channeled Insanity-fueled cooldown, keep your DoTs freshly refreshed before using it" },
        { spellID = 32379, text = "Shadow Word: Death as an execute-range filler (also usable off-cooldown for its Insanity refund on a kill)" },
        { spellID = 335467, text = "Shadow Word: Madness, a hard-hitting DoT/burst tool, has joined the kit alongside Shadow Word: Pain and Vampiric Touch — weave it into your DoT upkeep rather than treating it as optional" },
        { text = "Refresh DoTs before they fall off rather than letting them lapse" },
    }},
    { title = "AoE", steps = {
        { text = "Tentacle Slam to spread DoTs to multiple targets instantly, with no travel time (replaced Shadow Crash)" },
        { text = "Multi-dot with Mind Blast and let Shadow Word: Pain/Vampiric Touch carry the AoE damage — Mind Sear was removed and Shadow has no dedicated AoE filler" },
        { spellID = 589, text = "Shadow Word: Pain maintained on priority targets" },
        { spellID = 8092, text = "Mind Blast on cooldown, still strong even while cleaving" },
        { text = "Spend Void Volley casts during Voidform for burst during add waves" },
        { text = "Keep DoTs rolling on as many targets as your Insanity budget allows" },
    }},
    { title = "Opener Notes", steps = {
        { text = "Apply Shadow Word: Pain and Vampiric Touch immediately, then build toward your burst window" },
        { text = "Line up your Insanity-spending burst cooldown with trinkets and other offensive cooldowns" },
        { text = "The Voidweaver hero talent path leans on Void Torrent and your Void-empowered casts inside the burst window; the Archon path instead ramps a stacking buff into Voidform — check which one your loadout uses before assuming a fixed cooldown cadence" },
    }},
  },
  cooldowns = {
    { text = "Voidform — your burst-window cooldown, use on cooldown" },
    { text = "Void Torrent — channeled Insanity dump, line up with your DoTs freshly applied" },
    { spellID = 47585, text = "Dispersion — damage reduction and mana/Insanity recovery cooldown" },
    { spellID = 586, text = "Fade to drop threat or avoid certain mechanics" },
    { spellID = 15487, text = "Silence — interrupt/utility cooldown, use on dangerous casts" },
  },
  consumables = {
    { slot = "Flask", text = "Flask of Alchemical Chaos (Intellect)" },
    { slot = "Food", text = "An Intellect-focused feast or food buff" },
    { slot = "Potion", text = "Tempered Potion, used inside your burst window" },
    { slot = "Weapon", text = "Shadowcore Oil or the current-tier weapon oil" },
    { slot = "Enchants", text = "Weapon enchant for Intellect/haste; ring enchants for secondary stats" },
    { slot = "Gems", text = "Intellect or Intellect/secondary hybrid gems in available sockets" },
  },
  gear = {
    { slot = "Head", text = "Tier set piece — the set bonus usually matters more than a small item-level gap" },
    { slot = "Neck", text = "Favor Haste to speed up DoT ticks and Insanity generation" },
    { slot = "Back", text = "Secondary stats matching Haste and Mastery outweigh a pure item-level chase" },
    { slot = "Legs", text = "Another tier slot when possible; otherwise the highest item level piece leaning Haste and Mastery" },
    { slot = "Ring", text = "Haste or Mastery rings depending on your current stat weights" },
    { slot = "Trinket", text = "One on-use Intellect or damage trinket lined up with your Insanity burst window" },
    { slot = "Trinket", text = "A passive stat-stick trinket for consistent DoT damage" },
    { slot = "Weapon", text = "A one-hander or staff with strong Intellect and secondary stats" },
    { slot = "Off-hand", text = "An off-hand caster stat stick for extra Intellect and secondary stats" },
  },
  mplusLoadout = {
    string = "CIQAAAAAAAAAAAAAAAAAAAAAAMMjZGAAAAAAAAAAAAMLmxMbzMMz2MzYG2mZGzMzYDZGLmpBYmZGAIAz2stEMbMAwgxMzMmtxMYmBzgB",
    source = "SimulationCraft default profile (credit, not endorsement of 'best')",
    patch = "12.1",
  },
  -- Live top-players pull (DESIGN.md's v1.4 section), NOT SimC - see this
  -- file's header for the full methodology. The plurality build among the
  -- sample: 2/49 (4%) ran this exact code, since flex-point choices vary - but
  -- the bigger signal is that 29/49 (59%) ran Archon overall. Reported honestly
  -- rather than dressed up as more decisive than it is.
  mplusMetaLoadout = {
    string = "CIQAR03Gt7xPmcDNOjs2Zlb3yOjZMAAAAAAAAAAAAYMLzMGbzMmZ2mZGzw2MzYmZGbIzYxMNAzMzAABY2mtlgZjBAGMmZmxsNmBzMYGMA",
    source = "Blizzard Battle.net API, US region, 2026-08-30: top 49 current-season Mythic+ Shadow Priests by best keystone level, sampled across all 83 US connected realms' leaderboards. This exact build was the plurality pick (2/49, 4%); 29/49 (59%) ran Archon overall.",
    patch = "12.1",
    sampleSize = 49,
  },
  tips = {
    "Never let Shadow Word: Pain or Vampiric Touch fall off a target you'll keep attacking.",
    "Tentacle Slam is a strong opener tool for seeding DoTs across a whole pull, with no travel time to wait out.",
    "Don't dump Insanity haphazardly — plan your burst window around your strongest cooldowns.",
    "Fade is useful for both threat management and dodging certain mechanics — don't save it purely for emergencies.",
  },
})
