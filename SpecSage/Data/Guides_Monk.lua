local ADDON, ns = ...

-- SpecSage guide data: Monk
-- Content targets Midnight (patch 12.1). Specs below with an `mplusLoadout`
-- field have that talent string (only) cross-checked against
-- SimulationCraft's public profiles (github.com/simulationcraft/simc,
-- GPLv3) as of patch 12.1; specs without one have no such reference.
-- Rotation/overview/tips/gear prose throughout this file is hand-authored
-- and was reviewed for Midnight ability changes, not derived from or
-- checked against SimC's APLs, and was not re-verified against current
-- tuning this pass.
-- This is community-maintained, conventional guidance (keep-it-simple stat
-- priorities, long-standing rotation patterns) and is NOT a claim of
-- sim-perfect or bleeding-edge optimal play.
-- To edit: find the RegisterSpec(...) block for the spec you want to change
-- and edit the table in place. To add a new tip/step, insert a new entry in
-- the relevant array. Keep this file data-only — no logic beyond the calls
-- below. See DESIGN.md "Guide data schema" for the full table shape.

if not ns.GuideStore then return end

-- Brewmaster -----------------------------------------------------------
ns.GuideStore:RegisterSpec("MONK", 268, {
  specName = "Brewmaster",
  role = "TANK",
  overview = {
    "Brewmaster Monk tanks by staggering a portion of incoming physical damage into a damage-over-time effect, then clearing that staggered damage with Purifying Brew. Active mitigation is a constant rhythm rather than a single defensive-cooldown press.",
    "The core mechanic is Stagger: a percentage of hits you take is converted into a rolling damage-over-time tick instead of hitting you all at once. Purifying Brew removes a portion of the staggered pool, and Brew charges are also consumed indirectly by abilities that reduce Brew cooldown, so brew management is central to survival.",
    "Bring Brewmaster when you want a tank that smooths out burst damage into manageable ticks, has strong self-healing through Expel Harm and Celestial Brew, and provides solid AoE threat through Breath of Fire and Keg Smash.",
  },
  statPriority = {
    { stat = "stamina" },
    { stat = "primary" },
    { stat = "versatility" },
    { stat = "mastery" },
    { stat = "crit" },
    { stat = "haste" },
  },
  rotation = {
    { title = "Single Target", steps = {
        { spellID = 121253, text = "Keg Smash on cooldown to build threat and reduce other cooldowns" },
        { spellID = 100780, text = "Tiger Palm to spend Chi and build Blackout Combo synergy" },
        { spellID = 115181, text = "Breath of Fire to apply the Dizzying Haze debuff and refresh Stagger benefits" },
        { text = "Blackout Kick / Rising Sun Kick per talent build for extra damage" },
        { text = "Expel Harm when Chi is capped or self-healing is needed" },
        { text = "Opener Notes: Brewmaster splits along the Master of Harmony and Shado-Pan hero trees — both keep Keg Smash/Breath of Fire as the core loop, they mainly change how your mitigation and cooldown windows are shaped" },
    }},
    { title = "AoE", steps = {
        { spellID = 121253, text = "Keg Smash on cooldown, it's your main AoE threat generator" },
        { spellID = 115181, text = "Breath of Fire to damage and weaken nearby enemies" },
        { text = "Spinning Crane Kick to hit all nearby targets" },
        { text = "Weave Rushing Jade Wind / Charred Passions (talent-dependent) for sustained cleave" },
        { text = "Keep Keg Smash on cooldown above all else when tanking a pack" },
    }},
    { title = "Mitigation", steps = {
        { spellID = 119582, text = "Purifying Brew to clear staggered damage when the pool is getting high" },
        { spellID = 322507, text = "Celestial Brew to shield against an upcoming damage spike" },
        { text = "Fortifying Brew for sustained periods of heavy damage" },
        { text = "Diffuse Magic / Zen Meditation for magic-heavy or unavoidable burst mechanics" },
        { text = "Don't purify a near-empty stagger pool — save charges for when the pool is meaningfully full" },
    }},
  },
  cooldowns = {
    { spellID = 322507, text = "Celestial Brew — proactive shield, use before a known damage spike" },
    { text = "Fortifying Brew — major defensive, use for sustained heavy-damage phases" },
    { spellID = 119582, text = "Purifying Brew — core mitigation tool, use to prevent stagger overflow" },
    { text = "Zen Meditation / Diffuse Magic — situational defensives for magic damage" },
    { text = "Invoke Niuzao (talent) — major cooldown for extended high-threat or high-damage windows" },
  },
  consumables = {
    { slot = "Flask", text = "Flask of Alchemical Chaos (Agility, tank stat variant)" },
    { slot = "Food", text = "A feast or personal Stamina/Agility food for the encounter" },
    { slot = "Potion", text = "Tempered Potion or a Stamina/defensive potion for survival cooldowns" },
    { slot = "Weapon", text = "Ironclaw Whetstone or the current-tier weapon enchant" },
    { slot = "Enchants", text = "Max-rank Stamina/Agility enchants on cloak and rings" },
    { slot = "Gems", text = "Stamina/Agility gems in available sockets" },
  },
  gear = {
    { slot = "Head", text = "One of your tier-set slots — the four-piece bonus strengthens your Stagger/Purifying Brew loop, worth prioritizing over a raw item-level gap" },
    { slot = "Chest", text = "A large stat budget and often your other tier piece — balance Stamina for your health pool against Versatility for flat damage reduction" },
    { slot = "Neck", text = "Usually carries a socket — lean Versatility first for survivability, with Mastery next for Stagger scaling" },
    { slot = "Ring", text = "No set bonus attached — use rings to fill in Versatility and Mastery wherever your gear is light" },
    { slot = "Trinket", text = "One trinket built around avoidance, armor, or a defensive proc rather than pure Agility, to smooth out incoming damage spikes" },
    { slot = "Trinket", text = "A second trinket that adds Stamina or a passive mitigation effect so you're not trading all your survivability for threat" },
    { slot = "Weapon", text = "Monks can dual-wield one-handers or wield a single two-hander — form and Stagger math don't care which, so take the highest weapon damage option" },
    { slot = "Waist", text = "An easy slot to slot in an extra gem for whichever secondary — Versatility or Mastery — your build is currently short on" },
  },
  mplusLoadout = {
    string = "CwQAAAAAAAAAAAAAAAAAAAAAAAAAAgZbzYGzMWmxGmZMAAAAAAALLYmwMwMM2MDmZmZY2GzMmZBLb22GzYWAAglZZaZ2mZZAAgAMDbgZGw0YADAYA",
    source = "SimulationCraft default profile (credit, not endorsement of 'best')",
    patch = "12.1",
  },
  tips = {
    "Purify when the stagger pool is meaningfully full, not reflexively on cooldown — timing it right smooths damage better.",
    "Keep Keg Smash on cooldown as much as possible; it's both your best threat tool and part of your mitigation kit.",
    "Use Celestial Brew proactively before a telegraphed damage spike rather than reactively after taking the hit.",
    "Watch your Brew charge count so you're never sitting capped and wasting potential mitigation.",
  },
})

-- Mistweaver -------------------------------------------------------------
ns.GuideStore:RegisterSpec("MONK", 270, {
  specName = "Mistweaver",
  role = "HEALER",
  overview = {
    "Mistweaver Monk heals through a mix of direct healing spells, the Renewing Mist heal-over-time that bounces between injured allies, and periodic burst-healing windows via Revival and Thunder Focus Tea. Many builds can flex between a melee 'Fistweaving' playstyle and a pure caster playstyle.",
    "The core mechanic is Soothing Mist and Renewing Mist uptime: keeping Renewing Mist spread across the raid provides steady passive healing, while Enveloping Mist and Vivify handle spot healing, and Thunder Focus Tea empowers your next cast for extra value.",
    "Bring Mistweaver when you want a mobile healer with strong raid-wide throughput via Revival and Mana Tea-style efficiency tools, plus meaningful damage contribution when played in a Fistweaving style.",
  },
  statPriority = {
    { stat = "primary" },
    { stat = "haste", note = "smooths cast times and HoT ticks" },
    { stat = "mastery" },
    { stat = "crit" },
    { stat = "versatility" },
  },
  rotation = {
    { title = "Priorities", steps = {
        { spellID = 115151, text = "Renewing Mist to keep it rolling on injured or about-to-be-injured allies" },
        { spellID = 191837, text = "Essence Font on cooldown for group-wide healing and buffs" },
        { spellID = 191840, text = "Enveloping Mist for strong single-target/spot healing on focus-fire targets" },
        { spellID = 116670, text = "Vivify as an efficient direct heal and Renewing Mist refresher" },
        { text = "Weave Rising Sun Kick / Blackout Kick (Fistweaving builds) to contribute damage between heals" },
    }},
    { title = "Cooldown usage", steps = {
        { spellID = 115310, text = "Revival for raid-wide healing and cooldown-window damage phases" },
        { spellID = 116680, text = "Thunder Focus Tea to empower your next Enveloping Mist or Essence Font" },
        { text = "Life Cocoon on the target about to take heavy predictable damage" },
        { text = "Chi-Ji / Yu'lon (talent-dependent major cooldown) for extended raid-healing windows" },
        { text = "Pool Thunder Focus Tea charges for high-value moments rather than using them immediately" },
    }},
  },
  cooldowns = {
    { spellID = 115310, text = "Revival — raid-wide heal + cleanse, use for a big incoming damage wave" },
    { text = "Life Cocoon — single-target damage absorb, save for a tank swap or known burst target" },
    { spellID = 116680, text = "Thunder Focus Tea — empowers the next cast, use on Enveloping Mist or Essence Font for max value" },
    { text = "Invoke Yu'lon / Chi-Ji (talent) — major raid-cooldown, line up with heavy damage phases" },
    { spellID = 122783, text = "Diffuse Magic — personal defensive against magic damage" },
  },
  consumables = {
    { slot = "Flask", text = "Flask of Alchemical Chaos (Intellect)" },
    { slot = "Food", text = "A feast or personal Intellect food for the encounter" },
    { slot = "Potion", text = "Tempered Potion or a healing-oriented potion for a big damage phase" },
    { slot = "Weapon", text = "Not applicable" },
    { slot = "Enchants", text = "Max-rank Intellect enchants on cloak and rings" },
    { slot = "Gems", text = "Intellect/secondary stat gems in available sockets" },
  },
  gear = {
    { slot = "Head", text = "One of your tier-set slots — the four-piece bonus adds real throughput to your Renewing Mist/Vivify loop, worth prioritizing" },
    { slot = "Chest", text = "A large stat budget and often your other tier piece — lean Haste first to smooth cast times and Renewing Mist ticks" },
    { slot = "Neck", text = "Usually carries a socket — favor Haste, then Mastery" },
    { slot = "Ring", text = "No set bonus attached — use rings to round out Haste and Mastery" },
    { slot = "Trinket", text = "One mana-efficiency or passive-throughput trinket to stretch your healing across a long fight" },
    { slot = "Trinket", text = "A second trinket built around a burst-healing proc or on-use effect you can align with Revival/Thunder Focus Tea" },
    { slot = "Weapon", text = "Monks can dual-wield one-handers or wield a two-hander — take the highest weapon damage option since it feeds both Fistweaving damage and healing" },
    { slot = "Off-hand", text = "If dual-wielding, an off-hand that leans Haste keeps your cast-heavy healing loop smooth" },
  },
  tips = {
    "Keep Renewing Mist bouncing across as many raid members as reasonable — it's efficient passive throughput.",
    "Save Thunder Focus Tea for your highest-value cast rather than spending it on cooldown by default.",
    "If Fistweaving, don't neglect direct healing when damage spikes — melee damage is a bonus, not a replacement for healing.",
    "Pre-position Life Cocoon or Revival ahead of known scripted damage rather than reacting after the fact.",
  },
})

-- Windwalker ---------------------------------------------------------------
ns.GuideStore:RegisterSpec("MONK", 269, {
  specName = "Windwalker",
  role = "DAMAGER",
  overview = {
    "Windwalker Monk is a fast-paced melee spec built around generating and spending Chi to fuel a combo-point-like system through Rising Sun Kick, Fists of Fury, and the burst window granted by Storm, Earth, and Fire and Serenity/Invoke Xuen (build-dependent).",
    "The core resource loop is Energy generating Chi via Tiger Palm/Expel Harm-style builders, spent on Chi abilities like Rising Sun Kick and Fists of Fury, with Mark of the Crane stacks and combo strikes (never repeating the same ability twice) increasing damage and enabling free casts.",
    "Bring Windwalker when you want a highly mobile, cooldown-driven melee spec with strong burst windows and good cleave through Storm, Earth, and Fire or Whirling Dragon Punch-style AoE tools.",
  },
  statPriority = {
    { stat = "primary" },
    { stat = "crit" },
    { stat = "mastery" },
    { stat = "versatility" },
    { stat = "haste" },
  },
  rotation = {
    { title = "Opener", steps = {
        { text = "Invoke Xuen the White Tiger (or Serenity, per build) to open with a strong window" },
        { spellID = 107428, text = "Rising Sun Kick to open with a big hit and debuff" },
        { spellID = 113656, text = "Fists of Fury once Chi is available for a strong channel" },
        { text = "Opener Notes: if talented, Zenith and Celestial Conduit's channel jump ahead of your normal single-target flow — fit them into the opener/burst window rather than treating them as regular fillers" },
    }},
    { title = "Single Target", steps = {
        { spellID = 100780, text = "Tiger Palm to build Chi and maintain the Mark of the Crane debuff" },
        { spellID = 107428, text = "Rising Sun Kick on cooldown for strong direct damage" },
        { spellID = 113656, text = "Fists of Fury on cooldown, ideally while stationary" },
        { text = "Spinning Crane Kick as a Chi spender when talented for single-target value" },
        { text = "Maintain 'combo strikes' by never repeating the same ability back-to-back" },
    }},
    { title = "AoE", steps = {
        { text = "Spinning Crane Kick to hit all nearby targets and spread Mark of the Crane" },
        { spellID = 107428, text = "Rising Sun Kick to apply its debuff across engaged targets (per talents)" },
        { text = "Whirling Dragon Punch (talent) when both Rising Sun Kick and Fists of Fury are ready" },
        { text = "Storm, Earth, and Fire (talent) to split damage across multiple targets" },
        { text = "Keep combo strikes going while prioritizing AoE-focused abilities" },
    }},
  },
  cooldowns = {
    { text = "Invoke Xuen the White Tiger / Invoke Yu'lon (build-dependent) — major burst cooldown, use with your opener or a planned window" },
    { text = "Serenity (talent, mutually exclusive with Xuen build) — short, high-value burst window" },
    { text = "Storm, Earth, and Fire — splits your damage to extra targets, use for cleave/multi-target windows" },
    { spellID = 122470, text = "Touch of Karma — defensive that reflects damage back as healing/damage" },
    { spellID = 122783, text = "Diffuse Magic — personal defensive against magic damage" },
  },
  consumables = {
    { slot = "Flask", text = "Flask of Alchemical Chaos (Agility)" },
    { slot = "Food", text = "A feast or personal Agility food for the encounter" },
    { slot = "Potion", text = "Tempered Potion, used inside your cooldown window" },
    { slot = "Weapon", text = "Ironclaw Whetstone or the current-tier weapon enchant" },
    { slot = "Enchants", text = "Max-rank Agility enchants on cloak and rings" },
    { slot = "Gems", text = "Agility/secondary stat gems in available sockets" },
  },
  gear = {
    { slot = "Head", text = "One of your tier-set slots — the four-piece bonus is built around your Chi/combo-strike burst windows, worth prioritizing over raw item level" },
    { slot = "Chest", text = "A large stat budget and often your other tier piece — push Critical Strike first for your Rising Sun Kick/Fists of Fury payoff" },
    { slot = "Neck", text = "Usually carries a socket — favor Critical Strike, then Mastery" },
    { slot = "Ring", text = "No set bonus attached — use rings to fill out Critical Strike and Mastery" },
    { slot = "Trinket", text = "One on-use trinket timed to pop with Invoke Xuen/Serenity for a stacked burst window" },
    { slot = "Trinket", text = "A passive Agility or Critical Strike stat-stick trinket to keep pressure up between cooldowns" },
    { slot = "Weapon", text = "Fast one-handers (fist weapons or similar) are the natural fit for Windwalker's attack-speed-driven combo strikes" },
    { slot = "Off-hand", text = "Match your off-hand's secondary stats to your main-hand's Critical Strike lean rather than treating it as filler" },
  },
  mplusLoadout = {
    string = "C0QAAAAAAAAAAAAAAAAAAAAAAMzYw2MmhlZGbzAAAAAAAAAAAAsMMaGzAGwMGmZmZY2GmhZZmAAWMz2MDzMzMAA2AQzys0MzMLAYgZGAGLDgB8B",
    source = "SimulationCraft default profile (credit, not endorsement of 'best')",
    patch = "12.1",
  },
  tips = {
    "Never repeat the same ability twice in a row when possible — combo strikes are core to Windwalker's damage and mastery.",
    "Line up Invoke Xuen/Serenity with your other cooldowns and, where possible, boss burst phases.",
    "Try to channel Fists of Fury while stationary or use its mobility talent — movement during the channel loses ticks.",
    "Use Touch of Karma both as a defensive cooldown and as extra damage when you can afford the self-damage.",
  },
})
