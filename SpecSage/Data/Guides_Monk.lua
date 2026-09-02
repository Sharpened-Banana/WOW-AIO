local ADDON, ns = ...

-- SpecSage guide data: Monk
-- Content targets Midnight (patch 12.1). Specs below with an `mplusLoadout`
-- field have that talent string (only) cross-checked against
-- SimulationCraft's public profiles (github.com/simulationcraft/simc,
-- GPLv3) as of patch 12.1; specs without one have no such reference.
-- Rotation/overview/tips/gear prose throughout this file is hand-authored
-- and was reviewed for Midnight ability changes, not derived from or
-- checked against SimC's APLs, and was not re-verified against current
-- tuning this pass — EXCEPT Brewmaster (268), Mistweaver (270), and Windwalker (269),
-- which each gained an `mplusMetaLoadout` (DESIGN.md's v1.4 section) this
-- pass: pulled live from Blizzard's own Battle.net Game Data API
-- (client-credentials OAuth, US region) rather than SimC, on 2026-08-30.
-- Methodology: every current-season Mythic+ leaderboard (8-dungeon pool,
-- period 1078) across all 83 US connected realms was scanned (top 20 groups
-- per realm/dungeon) for each spec's group members; the top-observed-keystone
-- characters (up to 50 per spec) had their live `specializations` looked up
-- for their active loadout's `talent_loadout_code`. See each field's own
-- `source` comment for the resulting distribution.
-- This pass also added an "Opener Notes" rotation entry naming each spec's
-- two hero talent trees, for the two specs that didn't already have one
-- inline (Mistweaver, Windwalker - Brewmaster already carried a hero-tree
-- note and was left as-is). Unlike the hand-authored prose above, these new
-- notes ARE cross-checked against SimC's current `midnight` branch profiles
-- (github.com/simulationcraft/simc) where a real action-list branch exists
-- per hero tree; where SimC's profile set has no branch (an identical
-- actions= list either way, or no profile for the spec at all), the note
-- says so honestly instead of inventing a rotation change.
-- Windwalker's overview/rotation were also corrected this pass, confirmed
-- against SimC's current `midnight` branch profile: Storm, Earth, and Fire
-- has zero references (replaced by Zenith, a baseline burst-window
-- cooldown called unconditionally in the action list, not gated behind a
-- hero talent) and Mark of the Crane has zero references either (the
-- combo-strike/Combo Breaker mastery loop the guide already described
-- separately is what actually drives the "don't repeat an ability" reward
-- now).
-- This is community-maintained, conventional guidance (keep-it-simple stat
-- priorities, long-standing rotation patterns) and is NOT a claim of
-- sim-perfect or bleeding-edge optimal play.
-- To edit: find the RegisterSpec(...) block for the spec you want to change
-- and edit the table in place. To add a new tip/step, insert a new entry in
-- the relevant array. Keep this file data-only — no logic beyond the calls
-- below. See DESIGN.md "Guide data schema" for the full table shape.

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

-- Brewmaster -----------------------------------------------------------
ns.GuideStore:RegisterSpec("MONK", 268, {
  specName = "Brewmaster",
  role = "TANK",
  overview = {
    "Brewmaster Monk tanks by staggering a portion of incoming physical damage into a damage-over-time effect, then clearing that staggered damage with Purifying Brew. Active mitigation is a constant rhythm rather than a single defensive-cooldown press.",
    "The core mechanic is Stagger: a percentage of hits you take is converted into a rolling damage-over-time tick instead of hitting you all at once. Purifying Brew removes a portion of the staggered pool, and Brew charges are also consumed indirectly by abilities that reduce Brew cooldown, so brew management is central to survival. Black Ox Brew instantly refunds Energy, a Purifying Brew charge, and a charge of your Celestial/Fortifying tool — press it when that refund will actually get used, not just because it's off the global cooldown.",
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
    { title = "Opener", steps = {
        { text = "Get Shuffle rolling immediately — it's the mitigation buff Keg Smash (and your other builders) grant, so establishing it comes before anything else" },
        { spellID = 121253, text = "Keg Smash to start the Shuffle/threat loop" },
        { spellID = 100784, text = "Blackout Kick" },
        { spellID = 115181, text = "Breath of Fire" },
        { spellID = 214326, text = "Exploding Keg" },
        { text = "Chi Burst or Rushing Jade Wind (talent-dependent) to round things out" },
        { spellID = 132578, text = "Invoke Niuzao only if the pull is expected to last 25 seconds or more — it's not worth the cooldown on a short fight" },
    }},
    { title = "Single Target", steps = {
        { spellID = 115399, text = "Black Ox Brew off-GCD whenever its Energy/Purifying Brew refund won't go to waste — check your resources rather than pressing it on reflex" },
        { text = "Touch of Death whenever it's up and safe to use" },
        { spellID = 121253, text = "Keg Smash on cooldown to build threat, refresh Shuffle, and reduce other cooldowns" },
        { spellID = 100784, text = "Blackout Kick whenever it's available — don't hold it" },
        { spellID = 115181, text = "Breath of Fire on targets you've already Keg Smashed, to apply Dizzying Haze and refresh Stagger benefits" },
        { spellID = 214326, text = "Exploding Keg on cooldown" },
        { spellID = 116847, text = "Rushing Jade Wind kept up for its passive cleave" },
        { spellID = 100780, text = "Tiger Palm to fill Energy and Chi whenever nothing else is ready" },
        { spellID = 322101, text = "Expel Harm when Chi is capped or self-healing is needed" },
        { text = "Opener Notes: Brewmaster splits along the Master of Harmony and Shado-Pan hero trees — Shado-Pan leans on Invoke Niuzao for burst windows, while Master of Harmony smooths out consistent single-target mitigation and Purifying/Celestial Brew value; both keep this same Keg Smash/Breath of Fire loop as their core, so the two are largely interchangeable rather than one clearly outperforming the other" },
    }},
    { title = "AoE", steps = {
        { spellID = 121253, text = "Keg Smash on cooldown, it's your main AoE threat generator" },
        { spellID = 115181, text = "Breath of Fire to damage and weaken nearby enemies — its value goes up with every extra target" },
        { text = "Dragonfire Brew (if talented) for extra AoE burst on top of Breath of Fire" },
        { text = "Spinning Crane Kick to hit all nearby targets" },
        { spellID = 116847, text = "Rushing Jade Wind / Charred Passions (talent-dependent) for sustained cleave" },
        { text = "The single-target priority otherwise carries over largely unchanged — keep Keg Smash on cooldown above all else when tanking a pack" },
    }},
    { title = "Mitigation", steps = {
        { text = "Shuffle uptime is your #1 defensive stat — everything below is secondary to keeping it rolling" },
        { spellID = 119582, text = "Purifying Brew to clear staggered damage when the pool is getting high — hold a charge back if you know a spike is coming rather than dumping both at once" },
        { spellID = 322507, text = "Celestial Brew (or Celestial Infusion, hero-talent dependent) to shield against an upcoming damage spike" },
        { spellID = 115203, text = "Fortifying Brew ahead of a sustained heavy-damage phase, not after you're already deep into it" },
        { text = "Diffuse Magic / Zen Meditation for magic-heavy or unavoidable burst mechanics" },
        { text = "Don't purify a near-empty stagger pool — save charges for when the pool is meaningfully full" },
    }},
  },
  cooldowns = {
    { spellID = 322507, text = "Celestial Brew — proactive shield, use before a known damage spike" },
    { spellID = 115203, text = "Fortifying Brew — major defensive, use preemptively for sustained heavy-damage phases" },
    { spellID = 119582, text = "Purifying Brew — core mitigation tool, use to prevent stagger overflow; bank a charge for an expected spike rather than spending both on cooldown" },
    { spellID = 115399, text = "Black Ox Brew — off-GCD reset for Energy, a Purifying Brew charge, and a Celestial/Fortifying charge; press it when the refund would actually be used, not purely on cooldown" },
    { text = "Zen Meditation / Diffuse Magic — situational defensives for magic damage" },
    { spellID = 132578, text = "Invoke Niuzao (talent) — major cooldown for extended (25s+) high-threat or high-damage windows" },
  },
  consumables = {
    { slot = "Flask", text = "Flask of Tempered Versatility — matches this spec's top secondary; Flask of Alchemical Chaos is the flex pick if your stat weights are close" },
    { slot = "Food", text = "Loa's Gathering or Feast of Knowledge for raid (Stamina + your highest secondary); Hearty Venom-Spiced Cutlets or Puffer Plate for Mythic+/personal (prefer the Hearty version for death persistence)" },
    { slot = "Potion", text = "Tempered Potion or a Stamina/defensive potion for survival cooldowns. Liquid Luster (builds Versatility over 30s) is a strong ramp/M+ alternative, Potion of Unwavering Focus if you want a pure single-target pick instead; always carry Concentrated Silvermoon Health Potions for the emergency heal." },
    { slot = "Weapon", text = "Ironclaw Whetstone or the current-tier weapon enchant" },
    { slot = "Enchants", text = "Max-rank Stamina/Agility enchants on cloak and rings" },
    { slot = "Gems", text = "Stamina/Agility gems in available sockets" },
    { slot = "Augment Rune", text = "Crystallized Augment Rune (1-hour primary stat) for progression pulls and high keys; the reusable Ethereal Augment Rune the rest of the time" },
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
  -- Live top-players pull (DESIGN.md's v1.4 section), NOT SimC - see this
  -- file's header for the full methodology. The plurality build among the
  -- sample: 2/50 (4%) ran this exact code, since flex-point choices vary - but
  -- the bigger signal is that 50/50 (100%) ran Master of Harmony overall.
  -- Reported honestly rather than dressed up as more decisive than it is.
  mplusMetaLoadout = {
    string = "CwQAQnG51S19isUJoJoTeJ/IKDAAAgZbzYGGzyMzGzMjBAAAAAAYZBzEzMwMM2gxMzMDz2YmxYZYZ7B22mNMLAAwysMtMbzsMAAQAMsBmZATjBAAMA",
    source = "Blizzard Battle.net API, US region, 2026-08-30: top 50 current-season Mythic+ Brewmaster Monks by best keystone level, sampled across all 83 US connected realms' leaderboards. This exact build was the plurality pick (2/50, 4%); 50/50 (100%) ran Master of Harmony overall.",
    patch = "12.1",
    sampleSize = 50,
  },
  tips = {
    "Purify when the stagger pool is meaningfully full, not reflexively on cooldown — timing it right smooths damage better.",
    "Keep Keg Smash on cooldown as much as possible; it's both your best threat tool and part of your mitigation kit.",
    "Use Celestial Brew proactively before a telegraphed damage spike rather than reactively after taking the hit.",
    "Watch your Brew charge count so you're never sitting capped and wasting potential mitigation.",
    "Save Black Ox Brew for a moment when its Energy/Brew refund actually gets used, not as a reflexive off-GCD press.",
    "Invoke Niuzao is only worth casting on pulls expected to run 25 seconds or longer.",
  },
})

-- Mistweaver -------------------------------------------------------------
-- Revised for 12.1 (Curse of Ula'tek) from Blizzard patch-note content
-- reached via search summaries; the official article could not be fetched
-- directly from this environment, so the specific numbers below are
-- UNVERIFIED against the source page and should be treated as provisional
-- pending direct confirmation. No SimC profile exists for this spec, so it
-- is NOT SimC-cross-checked — see the mplusLoadout note in the header above.
-- 12.1 shifts throughput out of Spinning Crane Kick (-7%) and into Mastery:
-- Gust of Mist (+50%) and the Ancient Teachings/Way of the Crane transfer,
-- explicitly to make Mastery a more viable secondary stat; it also adds a
-- new Vital Expenditure talent (Soothing Mist healing +300%, mana cost
-- +200%, a choice node against Dancing Mists). NOTE: the statPriority order
-- below has deliberately been left as Haste-before-Mastery rather than
-- reordered to match the buff — a stat-priority reorder is a derived
-- analytical conclusion (it requires modelling the spec's full scaling),
-- not a fact relayed from a patch note, and the buff alone does not
-- establish the new ranking. See the Mastery stat note below for the bare
-- fact instead.
ns.GuideStore:RegisterSpec("MONK", 270, {
  specName = "Mistweaver",
  role = "HEALER",
  overview = {
    "Mistweaver Monk heals through a mix of direct healing spells, the Renewing Mist heal-over-time that bounces between injured allies, and periodic burst-healing windows via Revival and Thunder Focus Tea. Many builds can flex between a melee 'Fistweaving' playstyle and a pure caster playstyle. Like most healers, Mistweaver doesn't run a fixed cast order — it's a reactive throughput loop where you keep your triggers (Renewing Mist uptime, Rising Sun Kick availability) rolling and press whichever spell is ready for whoever needs it most.",
    "The core mechanic is Soothing Mist and Renewing Mist uptime: keeping Renewing Mist spread across the raid provides steady passive healing, while Enveloping Mist and Vivify handle spot healing, and Thunder Focus Tea empowers your next cast for extra value.",
    "Patch 12.1 leans the spec harder into Mastery: Gust of Mist (buffed 50%) and the Ancient Teachings/Way of the Crane damage-to-healing transfer, while trimming Spinning Crane Kick's own damage — a deliberate push to make Mastery a real secondary stat instead of an afterthought. A new Vital Expenditure talent offers a channel-heavy alternative to Dancing Mists: hugely amplified Soothing Mist healing at triple the mana cost.",
    "Bring Mistweaver when you want a mobile healer with strong raid-wide throughput via Revival and Thunder Focus Tea, plus meaningful damage contribution when played in a Fistweaving style.",
  },
  statPriority = {
    { stat = "primary" },
    { stat = "haste", note = "smooths cast times and HoT ticks" },
    { stat = "mastery", note = "Gust of Mist healing was increased in 12.1" },
    { stat = "crit" },
    { stat = "versatility" },
  },
  rotation = {
    { title = "Priorities", steps = {
        { text = "This is a reactive throughput loop rather than a strict cast order — keep the triggers below up and press whichever's ready for the ally who needs it" },
        { spellID = 115151, text = "Renewing Mist to keep it rolling on injured or about-to-be-injured allies — don't let charges cap, but don't dump them on full-health targets either" },
        { spellID = 107428, text = "Rising Sun Kick (or its Conduit of the Celestials upgrade) as often as it comes off cooldown — it's core throughput, not just a Fistweaving bonus" },
        { spellID = 353937, text = "Essence Font on cooldown for group-wide healing and buffs" },
        { spellID = 116670, text = "Vivify as an efficient direct heal — hits harder the more of your current Renewing Mist targets are among the people you're healing" },
        { spellID = 124682, text = "Enveloping Mist for strong single-target/spot healing on focus-fire targets" },
        { spellID = 388193, text = "Jadefire Stomp woven in whenever it's up" },
    }},
    { title = "AoE", steps = {
        { text = "Spinning Crane Kick becomes real group-healing throughput via the Way of the Crane transfer — lean on it during Mythic+ trash packs when everyone's taking damage" },
        { spellID = 353937, text = "Essence Font on cooldown for its group-wide heal-and-buff" },
        { spellID = 205406, text = "Sheilun's Gift for a quick top-up on whoever's lowest right after a damage spike" },
        { text = "Spinning Crane Kick's own direct damage was trimmed in 12.1 in favor of this Mastery-driven transfer healing — expect it to heal well, not to hit like it used to" },
    }},
    { title = "Cooldown usage", steps = {
        { spellID = 115310, text = "Revival when damage is stacked and heavy — it's your rawest burst AoE heal" },
        { spellID = 388615, text = "Restoral (talent-exclusive with Revival) trades some raw healing for a group-wide cleanse — take it when the fight has a nasty periodic effect to strip" },
        { spellID = 116680, text = "Thunder Focus Tea to empower your next Enveloping Mist or Essence Font" },
        { spellID = 116849, text = "Life Cocoon on the target about to take heavy predictable damage" },
        { text = "Invoke Yu'lon / Chi-Ji (talent-dependent major cooldown) for sustained raid-damage phases rather than single spike moments" },
        { spellID = 209525, text = "If talented into Vital Expenditure, lean into longer Soothing Mist channels during low-movement phases for its heavily amplified (but mana-hungry) healing" },
        { text = "Pool Thunder Focus Tea charges for high-value moments rather than using them immediately" },
    }},
    { title = "Opener Notes", steps = {
        { text = "Mistweaver's two hero talent trees are Conduit of the Celestials (also Windwalker's) and Master of Harmony (also Brewmaster's) — check which one your loadout uses; SimC does not yet publish a Mistweaver profile to source specific rotation branching from, so this note names the trees without claiming a specific rotation change for either" },
    }},
  },
  cooldowns = {
    { spellID = 115310, text = "Revival — raid-wide heal + cleanse, use for a big incoming damage wave" },
    { spellID = 388615, text = "Restoral — talent-exclusive alternative to Revival, trades some healing for a group-wide poison/disease cleanse" },
    { spellID = 116849, text = "Life Cocoon — single-target damage absorb, save for a tank swap or known burst target" },
    { spellID = 116680, text = "Thunder Focus Tea — empowers the next cast, use on Enveloping Mist or Essence Font for max value" },
    { text = "Invoke Yu'lon / Chi-Ji (talent) — major raid-cooldown, line up with sustained damage phases" },
    { spellID = 1243287, text = "Diffuse Magic — personal defensive against magic damage" },
  },
  consumables = {
    { slot = "Flask", text = "Flask of Tempered Swiftness for pure throughput, or Flask of Saving Graces if you'd rather have the healer-focused option" },
    { slot = "Food", text = "Loa's Gathering or Feast of Knowledge for raid (Stamina + your highest secondary); Hearty Venom-Spiced Cutlets or Puffer Plate for Mythic+/personal (prefer the Hearty version for death persistence)" },
    { slot = "Potion", text = "Tempered Potion or a healing-oriented potion for a big damage phase. Liquid Luster (builds Versatility over 30s) is a strong ramp/M+ alternative, Potion of Unwavering Focus if you want a pure single-target pick instead; always carry Concentrated Silvermoon Health Potions for the emergency heal." },
    { slot = "Weapon", text = "Not applicable" },
    { slot = "Enchants", text = "Max-rank Intellect enchants on cloak and rings" },
    { slot = "Gems", text = "Intellect/secondary stat gems in available sockets" },
    { slot = "Augment Rune", text = "Crystallized Augment Rune (1-hour primary stat) for progression pulls and high keys; the reusable Ethereal Augment Rune the rest of the time" },
  },
  gear = {
    { slot = "Head", text = "One of your tier-set slots — the four-piece bonus adds real throughput to your Renewing Mist/Vivify loop, worth prioritizing" },
    { slot = "Chest", text = "A large stat budget and often your other tier piece — favor Haste, then Mastery" },
    { slot = "Neck", text = "Usually carries a socket — favor Haste or Mastery, then whichever of the two your gear is lighter on" },
    { slot = "Ring", text = "No set bonus attached — use rings to round out Haste and Mastery" },
    { slot = "Trinket", text = "One mana-efficiency or passive-throughput trinket to stretch your healing across a long fight" },
    { slot = "Trinket", text = "A second trinket built around a burst-healing proc or on-use effect you can align with Revival/Thunder Focus Tea" },
    { slot = "Weapon", text = "Monks can dual-wield one-handers or wield a two-hander — take the highest weapon damage option since it feeds both Fistweaving damage and healing" },
    { slot = "Off-hand", text = "If dual-wielding, an off-hand that leans Haste or Mastery keeps your cast-heavy healing loop smooth" },
  },
  -- Live top-players pull (DESIGN.md's v1.4 section), NOT SimC - see this
  -- file's header for the full methodology. The plurality build among the
  -- sample: 3/50 (6%) ran this exact code, since flex-point choices vary - but
  -- the bigger signal is that 50/50 (100%) ran Conduit of the Celestials
  -- overall. Reported honestly rather than dressed up as more decisive than it
  -- is.
  mplusMetaLoadout = {
    string = "C4QAQnG51S19isUJoJoTeJ/IKDAAAAAAAghx2YZYzixMzyyM2wYGmZZZbmxCzoZMDYwgxYmZmhZbMGsYCAAAAgAsYZmlZbmBEAMgBYGwYYsIjZA",
    source = "Blizzard Battle.net API, US region, 2026-08-30: top 50 current-season Mythic+ Mistweaver Monks by best keystone level, sampled across all 83 US connected realms' leaderboards. This exact build was the plurality pick (3/50, 6%); 50/50 (100%) ran Conduit of the Celestials overall.",
    patch = "12.1",
    sampleSize = 50,
  },
  tips = {
    "Keep Renewing Mist bouncing across as many raid members as reasonable — it's efficient passive throughput.",
    "Don't let Renewing Mist charges or Rising Sun Kick sit unused — this is a reactive loop, so hoarding charges is worse than casting on cooldown.",
    "Save Thunder Focus Tea for your highest-value cast rather than spending it on cooldown by default.",
    "If Fistweaving, don't neglect direct healing when damage spikes — melee damage is a bonus, not a replacement for healing; Spinning Crane Kick's own damage was trimmed in 12.1, but it now heals well through Way of the Crane.",
    "Pre-position Life Cocoon or Revival ahead of known scripted damage rather than reacting after the fact.",
  },
})

-- Windwalker ---------------------------------------------------------------
ns.GuideStore:RegisterSpec("MONK", 269, {
  specName = "Windwalker",
  role = "DAMAGER",
  overview = {
    "Windwalker Monk is a fast-paced melee spec built around generating and spending Chi to fuel a combo-point-like system through Rising Sun Kick, Fists of Fury, and the burst window granted by Zenith (which replaced Storm, Earth, and Fire) and Serenity/Invoke Xuen (build-dependent).",
    "The core resource loop is Energy generating Chi via Tiger Palm/Expel Harm-style builders, spent on Chi abilities like Rising Sun Kick and Fists of Fury, with combo strikes (never repeating the same ability twice) triggering Combo Breaker procs that increase damage and enable free casts.",
    "Bring Windwalker when you want a highly mobile, cooldown-driven melee spec with strong burst windows and good cleave through Zenith or Whirling Dragon Punch-style AoE tools.",
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
        { text = "Shado-Pan: race to get Fists of Fury and Rising Sun Kick onto cooldown as fast as possible to kick off the loop" },
        { spellID = 107428, text = "Rising Sun Kick to open with a big hit and debuff" },
        { spellID = 113656, text = "Fists of Fury once Chi is available for a strong channel" },
        { text = "Conduit of the Celestials: open with Touch of Death if it's up, then Strike of the Windlord, then Slicing Winds, then Celestial Conduit, before settling into the shared single-target priority" },
        { text = "Opener Notes: if talented, Zenith and Celestial Conduit's channel jump ahead of your normal single-target flow — fit them into the opener/burst window rather than treating them as regular fillers" },
    }},
    { title = "Single Target", steps = {
        { spellID = 107428, text = "Rising Sun Kick on cooldown — your highest-priority Chi spender" },
        { spellID = 113656, text = "Fists of Fury on cooldown, ideally while stationary" },
        { text = "Strike of the Windlord on cooldown; hold Whirling Dragon Punch instead when Invoke Xuen is more than 10 seconds from coming back up" },
        { spellID = 100784, text = "Blackout Kick when you're short on Chi, or just to avoid overcapping Teachings of the Monastery stacks — it also shaves a second off both Rising Sun Kick and Fists of Fury's cooldowns" },
        { text = "Spinning Crane Kick once you've got 2 stacks of Dance of Chi-Ji, even against a single target" },
        { spellID = 100780, text = "Tiger Palm to generate Chi whenever nothing higher on this list is ready" },
        { text = "Touch of Death whenever it's up" },
        { text = "Maintain 'combo strikes' by never repeating the same ability back-to-back — it's core to Windwalker's damage" },
    }},
    { title = "AoE", steps = {
        { text = "Spinning Crane Kick is weak on its own this patch — most of your AoE comes from Fists of Fury's cleave and Slicing Winds rather than a dedicated AoE spender" },
        { spellID = 113656, text = "Fists of Fury on cooldown — a large share of your AoE damage rides on it" },
        { text = "Slicing Winds (Conduit of the Celestials) on cooldown for its own multi-target hit" },
        { spellID = 107428, text = "Rising Sun Kick to apply its debuff across engaged targets (per talents)" },
        { spellID = 152175, text = "Whirling Dragon Punch (talent) when both Rising Sun Kick and Fists of Fury are ready" },
        { text = "Zenith for your main burst window, spending Chi on Zenith Stomp while it's active" },
        { text = "Keep combo strikes going while prioritizing AoE-focused abilities" },
    }},
    { title = "Opener Notes", steps = {
        { text = "Windwalker's two hero talent trees are Conduit of the Celestials and Shado-Pan — check which one your loadout uses. Shado-Pan plays a very even, consistent single-target loop with no separate sequence; Conduit of the Celestials leans on keeping Heart of the Jade Serpent up and has more of a prescribed opener (Touch of Death into Strike of the Windlord into Slicing Winds into Celestial Conduit) before falling into the shared priority list above. SimC's own action lists are otherwise identical between the two trees, so most of the practical difference is that opener sequencing and upkeep rather than a different ongoing rotation" },
    }},
  },
  cooldowns = {
    { text = "Sync Invoke Xuen, Celestial Conduit, Zenith, and Strike of the Windlord into the same window whenever their cooldowns line up — stack them together, and with external raid cooldowns/stuns, rather than spreading them out" },
    { text = "Invoke Xuen the White Tiger / Invoke Yu'lon (build-dependent) — major burst cooldown, use with your opener or a planned window" },
    { text = "Serenity (talent, mutually exclusive with Xuen build) — short, high-value burst window" },
    { text = "Zenith — main burst-window cooldown (replaced Storm, Earth, and Fire), use aligned with other cooldowns" },
    { text = "Blackout Kick shaves 1 second off both Rising Sun Kick and Fists of Fury's cooldowns each cast — another reason not to skip it when it's available" },
    { spellID = 122470, text = "Touch of Karma — defensive that reflects damage back as healing/damage" },
    { spellID = 1243287, text = "Diffuse Magic — personal defensive against magic damage" },
  },
  consumables = {
    { slot = "Flask", text = "Flask of Tempered Aggression — matches this spec's top secondary; Flask of Alchemical Chaos is the flex pick if your stat weights are close" },
    { slot = "Food", text = "Loa's Gathering or Feast of Knowledge for raid (Stamina + your highest secondary); Hearty Venom-Spiced Cutlets or Puffer Plate for Mythic+/personal (prefer the Hearty version for death persistence)" },
    { slot = "Potion", text = "Tempered Potion, used inside your cooldown window. Liquid Luster (builds Versatility over 30s) is a strong ramp/M+ alternative, Potion of Unwavering Focus if you want a pure single-target pick instead; always carry Concentrated Silvermoon Health Potions for the emergency heal." },
    { slot = "Weapon", text = "Ironclaw Whetstone or the current-tier weapon enchant" },
    { slot = "Enchants", text = "Max-rank Agility enchants on cloak and rings" },
    { slot = "Gems", text = "Agility/secondary stat gems in available sockets" },
    { slot = "Augment Rune", text = "Crystallized Augment Rune (1-hour primary stat) for progression pulls and high keys; the reusable Ethereal Augment Rune the rest of the time" },
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
  -- Live top-players pull (DESIGN.md's v1.4 section), NOT SimC - see this
  -- file's header for the full methodology. The plurality build among the
  -- sample: 2/50 (4%) ran this exact code, since flex-point choices vary - but
  -- the bigger signal is that 29/50 (58%) ran Conduit of the Celestials
  -- overall. Reported honestly rather than dressed up as more decisive than it
  -- is.
  mplusMetaLoadout = {
    string = "C0QAQnG51S19isUJoJoTeJ/IKPzYMgxYZmZ2mBAAAAAAAAAAAYZYmwMMMgZMMzMzwsxMDzyMBAswsxMmZmZgAYxMLz2YCCAYGDgZAGLDgZmZzA",
    source = "Blizzard Battle.net API, US region, 2026-08-30: top 50 current-season Mythic+ Windwalker Monks by best keystone level, sampled across all 83 US connected realms' leaderboards. This exact build was the plurality pick (2/50, 4%); 29/50 (58%) ran Conduit of the Celestials overall.",
    patch = "12.1",
    sampleSize = 50,
  },
  tips = {
    "Never repeat the same ability twice in a row when possible — combo strikes are core to Windwalker's damage and mastery.",
    "Line up Invoke Xuen, Celestial Conduit, Zenith, and Strike of the Windlord together, and with boss burst phases, rather than spreading them out.",
    "Try to channel Fists of Fury while stationary or use its mobility talent — movement during the channel loses ticks.",
    "Use Touch of Karma both as a defensive cooldown and as extra damage when you can afford the self-damage.",
    "Don't let Energy or Chi sit capped — convert Energy into Chi with Tiger Palm as soon as you can afford the global cooldown.",
    "Use Blackout Kick to avoid overcapping Teachings of the Monastery stacks, not only as a Chi-strapped filler.",
  },
})
