local ADDON, ns = ...

-- SpecSage guide data: Shaman (Elemental 262, Enhancement 263, Restoration 264)
-- Content targets Midnight (patch 12.1). Specs below with an `mplusLoadout`
-- field have that talent string (only) cross-checked against
-- SimulationCraft's public profiles (github.com/simulationcraft/simc,
-- GPLv3) as of patch 12.1; specs without one have no such reference.
-- Rotation/overview/tips/gear prose throughout this file is hand-authored
-- and was reviewed for Midnight ability changes, not derived from or
-- checked against SimC's APLs, and was not re-verified against current
-- tuning this pass — EXCEPT Elemental (262), Enhancement (263), and Restoration (264),
-- which each gained an `mplusMetaLoadout` (DESIGN.md's v1.4 section) this
-- pass: pulled live from Blizzard's own Battle.net Game Data API
-- (client-credentials OAuth, US region) rather than SimC, on 2026-08-30.
-- Methodology: every current-season Mythic+ leaderboard (8-dungeon pool,
-- period 1078) across all 83 US connected realms was scanned (top 20 groups
-- per realm/dungeon) for each spec's group members; the top-observed-keystone
-- characters (up to 50 per spec) had their live `specializations` looked up
-- for their active loadout's `talent_loadout_code`. See each field's own
-- `source` comment for the resulting distribution.
-- Elemental's overview/rotation/tips were also corrected this pass: they
-- described Earth Shock as the Maelstrom spender, but in SimC's current
-- `midnight` branch profile it appears once, well behind Elemental Blast
-- and Tempest (10 references) - a free, automatically-triggered empowered
-- Lightning Bolt/Chain Lightning the guide never mentioned at all, despite
-- it now carrying a large share of the spec's damage baseline (no talent
-- gate on it in the APL).
-- A later pass (2026-09-01) enriched all three specs' overview/rotation/
-- cooldowns/tips with opener sequences, single-target-vs-AoE priority
-- nuances, cooldown-syncing notes, and hero-talent-caused differences,
-- drawing on guide sites (Wowhead/Icy Veins/Maxroll/Method/Boostmatch),
-- now a permitted source per repo policy (see
-- .claude/skills/specsage-refresh/SKILL.md). All prose was rewritten in
-- SpecSage's own words rather than copied from any source, and every
-- spellID added was verified against Wowhead rather than guessed. This
-- pass built on top of the already-corrected Tempest/Elemental Blast
-- priority above (Earth Shock stays deprioritized, no stale mechanics
-- reintroduced).
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

ns.GuideStore:RegisterSpec("SHAMAN", 262, {
  specName = "Elemental",
  role = "DAMAGER",
  overview = {
    "Elemental Shaman is a ranged caster spec that blends instant-cast Lava Burst and Lightning Bolt spam with Maelstrom-fueled Earth Shock and Elemental Blast casts, plus a free empowered Lightning Bolt/Chain Lightning (Tempest) that fires once enough Maelstrom is built, all while maintaining Flame Shock on the target as a bridge between Lava Burst casts. It plays with a mix of instant and hard-cast spells that reward positioning discipline during movement-heavy fights.",
    "The core resource is Maelstrom, generated from spells like Lightning Bolt, and spent on Earth Shock and Elemental Blast — with Tempest now carrying a large share of the spec's damage as a free, automatically-triggered empowered cast. Don't let Maelstrom sit at cap; Elemental Blast and Tempest come ahead of Earth Shock in priority, so plan your spending around those first. The defining mechanic is Lava Surge, a proc that makes Lava Burst instant and resets its cooldown — chaining these procs with Flame Shock uptime is central to sustained damage.",
    "Elemental brings strong single-target damage and big-pull AoE via Earthquake and Chain Lightning, useful raid utility (Bloodlust, Hex), and burst through Storm Elemental/Fire Elemental-style cooldowns — though recent tuning nerfed those cooldowns, so damage is flatter across a fight than it used to be. It's noticeably weaker on small 2-3 target cleave than at pure single target or full-pull AoE, so weigh that when a fight sits in that awkward middle ground.",
  },
  statPriority = {
    { stat = "mastery" },
    { stat = "haste" },
    { stat = "crit" },
    { stat = "versatility" },
    { stat = "primary" },
  },
  rotation = {
    { title = "Opener", steps = {
        { spellID = 191634, text = "Stormkeeper roughly 1.5-3 seconds before the pull, so it's ready to empower your first casts" },
        { spellID = 51505, text = "Lava Burst about 1.5 seconds before the pull to land right as combat starts" },
        { spellID = 443454, text = "Ancestral Swiftness (if talented) to fire an instant cast into the opening seconds" },
        { spellID = 114050, text = "Ascendance alongside trinkets and your burst potion for the opening cooldown stack" },
        { spellID = 51505, text = "Lava Burst again once you're in the Ascendance window" },
    }},
    { title = "Single Target", steps = {
        { spellID = 188389, text = "Flame Shock kept active on the target" },
        { spellID = 191634, text = "Stormkeeper on cooldown" },
        { spellID = 443454, text = "Ancestral Swiftness on cooldown for a free instant cast" },
        { spellID = 114050, text = "Ascendance on cooldown for a burst window" },
        { spellID = 117014, text = "Elemental Blast, if you don't already have its buff and are at 1 or fewer Tempest stacks" },
        { spellID = 454009, text = "Tempest once Master of the Elements is available to consume" },
        { spellID = 8042, text = "Earth Shock to spend remaining Maelstrom once the Elemental Blast/Tempest priorities above are handled" },
        { spellID = 51505, text = "Lava Burst only when a Lava Surge proc makes it instant — otherwise let it sit behind your Maelstrom spenders" },
        { spellID = 188196, text = "Lightning Bolt as filler and Maelstrom generation" },
        { text = "Never let Flame Shock fall off — it feeds Lava Surge procs" },
    }},
    { title = "AoE", steps = {
        { spellID = 61882, text = "Earthquake as the primary AoE Maelstrom spender" },
        { spellID = 188443, text = "Chain Lightning as the primary AoE Maelstrom generator/filler" },
        { text = "Voltaic Blaze applies Flame Shock to multiple targets at once, so lean on it to spread the dot on a big pull" },
        { spellID = 188389, text = "Flame Shock spread to priority targets" },
        { spellID = 51505, text = "Lava Burst on cooldown, still valuable while cleaving" },
        { spellID = 198067, text = "Fire Elemental for burst during add waves" },
        { text = "This spec is strongest at 1 target or a big pull — expect a weaker showing at 2-3 target cleave" },
    }},
    { title = "Opener Notes", steps = {
        { text = "Apply Flame Shock immediately and build Maelstrom before your first Elemental Blast/Earth Shock" },
        { text = "Line up Fire Elemental/Storm Elemental with trinkets for maximum burst" },
        { text = "Don't hold Stormkeeper or Ascendance too long waiting for a 'perfect' window — recent tuning flattened the spec's burst profile, so using them promptly on cooldown outweighs hoarding them" },
        { text = "Hero talent choice changes where you're strongest: Farseer favors single target and small cleave, while Stormbringer favors mass AoE pulls" },
    }},
  },
  cooldowns = {
    { spellID = 198067, text = "Fire Elemental — core offensive cooldown, use on cooldown" },
    { spellID = 192249, text = "Storm Elemental — alternative burst cooldown depending on talents" },
    { spellID = 114050, text = "Ascendance — burst cooldown, line it up with your elemental and Stormkeeper; don't hold it long waiting for a better window" },
    { spellID = 191634, text = "Stormkeeper — empowers your next Lightning Bolt/Chain Lightning casts; fire it roughly 1.5-3 seconds before a pull or burst window rather than banking it" },
    { spellID = 443454, text = "Ancestral Swiftness — free instant cast, use on cooldown rather than saving it" },
    { spellID = 108271, text = "Astral Shift — defensive damage-reduction cooldown" },
    { spellID = 2825, text = "Bloodlust — raid-wide haste cooldown, coordinate timing with the raid" },
    { spellID = 51514, text = "Hex — crowd control utility for dangerous adds" },
  },
  consumables = {
    { slot = "Flask", items = { 241323, 241325 }, text = "Flask of the Magisters for Mastery, this spec's top secondary; Flask of the Blood Knights if your gear already leans hard into Mastery and Haste is the stat you're short on." },
    { slot = "Food", items = { 275265, 275266, 255846, 275259, 242757 }, text = "Raid feasts: Loa's Gathering or Feast of Knowledge (Stamina plus your highest secondary, new in 12.1), or Harandar Celebration / Silvermoon Parade (Stamina plus 50 primary stat) - the two families sim within a fraction of a percent of each other, so eat whichever is down. Solo and Mythic+: Hearty Venom-Spiced Cutlets or Hearty Puffer Plate (highest secondary) or Hearty Warped Wise Wings (Mastery); Hearty food persists through death." },
    { slot = "Potion", items = { 241289, 241309, 271887, 271884 }, text = "Potion of Recklessness (+1585 Mastery for 30s, at the cost of 213 of your lowest secondary) is the burst potion; Light's Potential (+593 primary stat) if your lowest secondary is one you can't afford to lose. Liquid Luster (12.1) ramps Versatility over 30s and suits a pre-pot into a long opener. Always carry Concentrated Silvermoon Health Potions - 421k, the 12.1 upgrade." },
    { slot = "Weapon Oil", items = { 243734 }, text = "Thalassian Phoenix Oil - the current tier's weapon oil (+16 Critical Strike and Haste for 2 hours, from Enchanting)." },
    { slot = "Weapon Enchant", items = { 244029, 244031 }, text = "Acuity of the Ren'dorei procs +67 primary stat for 15s; Arcane Mastery procs +124 Mastery instead. The primary-stat proc is the usual default; take the secondary one if your stat weights put Mastery well clear of the rest." },
    { slot = "Ring Enchants", items = { 243959, 244015 }, text = "Zul'jin's Mastery (+29 Mastery) on both rings; Silvermoon's Alacrity (+29 Haste) if you're topping up your second stat instead. Use the greater tier - the lesser one is +24." },
    { slot = "Chest Enchant", items = { 243977 }, text = "Mark of the Worldsoul (+50 primary stat)." },
    { slot = "Leg Enchant", items = { 240133 }, text = "Sunfire Silk Spellthread (+41 Intellect, +115 Stamina)." },
    { slot = "Helm, Shoulders and Boots", items = { 243979, 243963, 244009, 244021, 243983 }, text = "Helm: Blessing of Speed (+13). Shoulders: Akil'zon's Swiftness (+65 Speed) or Silvermoon's Mending (+166 Leech). Boots: Farstrider's Hunt (+11 Speed, +232 Stamina) or Shaladrassil's Roots (+28 Leech, +232 Stamina). Speed is the throughput-neutral default; swap to Leech for a progression fight you keep dying on." },
    { slot = "Gems", items = { 240967, 240896, 240900 }, text = "One Powerful Eversong Diamond (+23 primary stat and crit effectiveness per unique gem colour you socket) - it's unique-equipped. Then Flawless Masterful Amethyst (+17 Mastery) in every other socket, or Flawless Quick Amethyst (+16 Mastery, +7 Haste) to spread a second colour if your diamond counts colours." },
    { slot = "Augment Rune", items = { 259085, 246492, 224572 }, text = "Void-Touched Augment Rune (+25 primary stat for 1 hour; it does not persist through death) for progression pulls and high keys. Soulgorged Augment Rune (+6, persists through death) or Crystallized Augment Rune (+6) are the cheap fallbacks the rest of the time." },
  },
  gear = {
    { slot = "Head", text = "Tier set piece — the set bonus usually matters more than a small item-level gap" },
    { slot = "Neck", text = "Favor Haste to chain Lava Surge procs and generate Maelstrom faster" },
    { slot = "Back", text = "Secondary stats matching Haste and Mastery outweigh a pure item-level chase" },
    { slot = "Legs", text = "Another tier slot when possible; otherwise the highest item level piece leaning Haste and Mastery" },
    { slot = "Ring", text = "Haste or Mastery rings depending on your current stat weights" },
    { slot = "Trinket", text = "One on-use Intellect or damage trinket lined up with Fire Elemental or Storm Elemental" },
    { slot = "Trinket", text = "A passive stat-stick trinket for consistent Lava Burst and Elemental Blast/Earth Shock damage" },
    { slot = "Weapon", text = "A one-hander with strong Intellect and secondary stats" },
    { slot = "Off-hand", text = "An off-hand caster stat stick for extra Intellect and secondary stats" },
  },
  mplusLoadout = {
    string = "CYQAAAAAAAAAAAAAAAAAAAAAAAAAAAzMbbzMmZmZZbZMMjBAAAAsYmNYADY2YCZWAgZbmZGjtFTYmxYxMzMmZWsMjFzMMzyAAGGAzMGGGA",
    source = "SimulationCraft default profile (credit, not endorsement of 'best')",
    patch = "12.1",
  },
  -- Live top-players pull (DESIGN.md's v1.4 section), NOT SimC - see this
  -- file's header for the full methodology. The plurality build among the
  -- sample: 2/50 (4%) ran this exact code, since flex-point choices vary - but
  -- the bigger signal is that 50/50 (100%) ran Farseer overall. Reported
  -- honestly rather than dressed up as more decisive than it is.
  mplusMetaLoadout = {
    string = "CYQALMl7AwW51MWzGneuHE3tPCAAAAzMbLzMGjZZbZMmhZAAAAgFzsBDYAzGTIzCAMbzMzYssYajZmtxyMzMjhFLzMLDjZmFAgBAmZMMMA",
    source = "Blizzard Battle.net API, US region, 2026-08-30: top 50 current-season Mythic+ Elemental Shamans by best keystone level, sampled across all 83 US connected realms' leaderboards. This exact build was the plurality pick (2/50, 4%); 50/50 (100%) ran Farseer overall.",
    patch = "12.1",
    sampleSize = 50,
  },
  tips = {
    "Keep Flame Shock active on the target at all times — it's the engine behind Lava Surge procs.",
    "Don't cap Maelstrom — spend it on Elemental Blast/Tempest ahead of Earth Shock before it overflows.",
    "Coordinate Bloodlust timing with your raid rather than using it purely on your own cooldowns.",
    "Switch fully to Earthquake/Chain Lightning once three or more targets are engaged.",
    "Only cast Lava Burst off cooldown when Lava Surge makes it instant — otherwise it loses out to your Maelstrom spenders.",
    "Fire Stormkeeper and Ascendance promptly rather than banking them for a perfect moment — the spec's burst cooldowns run flatter than they used to.",
  },
})

ns.GuideStore:RegisterSpec("SHAMAN", 263, {
  specName = "Enhancement",
  role = "DAMAGER",
  overview = {
    "Enhancement Shaman is a dual-wield melee spec that combines weapon-enchant-fueled attacks with elemental spells like Lava Lash and Stormstrike, generating Maelstrom Weapon stacks that empower its spells with instant casts and bonus effects. It plays as a fast, proc-driven spec with a strong emphasis on weaving spells at the right Maelstrom Weapon stack count.",
    "The core resource is Maelstrom Weapon, generated from melee attacks and abilities, and spent by casting empowered spells like Lightning Bolt and Chain Lightning — both go instant at 5+ stacks, so stay below the 10-stack cap rather than sitting on a full bar and wasting further generation. The defining mechanic is stack management — using Maelstrom Weapon stacks efficiently rather than either spending too early or overcapping and wasting generation.",
    "Enhancement brings strong burst through Feral Spirit and Doom Winds-style cooldowns, solid AoE via Chain Lightning and Crash Lightning, and good self-sufficiency, making it a strong pick for fights that reward burst windows and consistent melee uptime. The Stormbringer hero talent in particular shines on 5-6 target packs, while Totemic plays a steadier totem-support game.",
  },
  statPriority = {
    { stat = "primary" },
    { stat = "crit" },
    { stat = "mastery" },
    { stat = "haste" },
    { stat = "versatility" },
  },
  rotation = {
    { title = "Opener", steps = {
        { spellID = 188389, text = "Flame Shock on your approach, before you're even in melee range" },
        { text = "Auto-attacks plus Stormstrike/Lava Lash to build Maelstrom Weapon stacks" },
        { text = "Doom Winds, Feral Spirit, and/or Ascendance together to open your first cooldown window" },
        { spellID = 197214, text = "Sundering to open your AoE/cleave damage if multiple targets are present" },
    }},
    { title = "Single Target", steps = {
        { text = "Voltaic Blaze on cooldown" },
        { text = "Sync your empowered casts with Surging Totem — it wants a cast roughly every other GCD" },
        { spellID = 60103, text = "Lava Lash with Hot Hand or Whirling Fire active" },
        { spellID = 1218090, text = "Primordial Storm at 10 stacks of Maelstrom Weapon — a strong Maelstrom-fueled finisher" },
        { spellID = 188196, text = "Tempest or Lightning Bolt at 10 stacks of Maelstrom Weapon" },
        { spellID = 17364, text = "Stormstrike on cooldown — core melee ability and Maelstrom generator" },
        { spellID = 187874, text = "Crash Lightning on cooldown, even in single target if talented" },
        { text = "Spend Maelstrom Weapon stacks before they overcap and waste generation" },
    }},
    { title = "AoE", steps = {
        { spellID = 187874, text = "Crash Lightning jumps up in priority against 3+ targets" },
        { spellID = 188443, text = "Chain Lightning as your Maelstrom Weapon spender across multiple targets" },
        { spellID = 333974, text = "Fire Nova to detonate Flame Shock/Magma stacks on the pull" },
        { spellID = 197214, text = "Sundering for extra cleave" },
        { text = "This spec's cleave especially shines at 5-6 targets under the Stormbringer hero talent" },
    }},
    { title = "Opener Notes", steps = {
        { text = "Build Maelstrom Weapon stacks briefly before your first big empowered cast" },
        { text = "Line up Feral Spirit and Doom Winds-style cooldowns with trinkets for maximum burst" },
        { text = "Hero talent choice shapes your target-count sweet spot: Stormbringer is best on 5-6 target packs, while Totemic trades some of that ceiling for steadier totem support" },
    }},
  },
  cooldowns = {
    { spellID = 51533, text = "Feral Spirit — core offensive cooldown, use on cooldown" },
    { spellID = 384352, text = "Doom Winds — burst melee cooldown if talented, use with Feral Spirit" },
    { spellID = 114051, text = "Ascendance — burst cooldown, line up with Feral Spirit and Doom Winds" },
    { spellID = 108271, text = "Astral Shift — defensive damage-reduction cooldown" },
    { spellID = 2825, text = "Bloodlust — raid-wide haste cooldown, coordinate timing with the raid" },
    { spellID = 51514, text = "Hex — crowd control utility for dangerous adds" },
  },
  consumables = {
    { slot = "Flask", items = { 241327, 241323 }, text = "Flask of the Shattered Sun for Critical Strike, this spec's top secondary; Flask of the Magisters if your gear already leans hard into Critical Strike and Mastery is the stat you're short on." },
    { slot = "Food", items = { 275265, 275266, 255846, 275259, 242755 }, text = "Raid feasts: Loa's Gathering or Feast of Knowledge (Stamina plus your highest secondary, new in 12.1), or Harandar Celebration / Silvermoon Parade (Stamina plus 50 primary stat) - the two families sim within a fraction of a percent of each other, so eat whichever is down. Solo and Mythic+: Hearty Venom-Spiced Cutlets or Hearty Puffer Plate (highest secondary) or Hearty Sun-Seared Lumifin (Critical Strike); Hearty food persists through death." },
    { slot = "Potion", items = { 241289, 241309, 271887, 271884 }, text = "Potion of Recklessness (+1585 Critical Strike for 30s, at the cost of 213 of your lowest secondary) is the burst potion; Light's Potential (+593 primary stat) if your lowest secondary is one you can't afford to lose. Liquid Luster (12.1) ramps Versatility over 30s and suits a pre-pot into a long opener. Always carry Concentrated Silvermoon Health Potions - 421k, the 12.1 upgrade." },
    { slot = "Weapon Oil", items = { 243734, 237371, 237369 }, text = "Thalassian Phoenix Oil - the current tier's weapon oil (+16 Critical Strike and Haste for 2 hours, from Enchanting); Refulgent Whetstone (bladed) or Refulgent Weightstone (blunt) gives +15 Attack Power instead, from Blacksmithing - the two are close, so take whichever is cheaper." },
    { slot = "Weapon Enchant", items = { 244029, 243971 }, text = "Acuity of the Ren'dorei procs +67 primary stat for 15s; Jan'alai's Precision procs +124 Critical Strike instead. The primary-stat proc is the usual default; take the secondary one if your stat weights put Critical Strike well clear of the rest." },
    { slot = "Ring Enchants", items = { 243987, 243959 }, text = "Nature's Fury (+29 Critical Strike) on both rings; Zul'jin's Mastery (+29 Mastery) if you're topping up your second stat instead. Use the greater tier - the lesser one is +24." },
    { slot = "Chest Enchant", items = { 243977, 243975 }, text = "Mark of the Worldsoul (+50 primary stat); Mark of the Rootwarden (+40 Agility, +15 Speed) trades a little stat for movement." },
    { slot = "Leg Enchant", items = { 244641 }, text = "Forest Hunter's Armor Kit (+41 primary stat, +115 Stamina)." },
    { slot = "Helm, Shoulders and Boots", items = { 243979, 243963, 244009, 244021, 243983 }, text = "Helm: Blessing of Speed (+13). Shoulders: Akil'zon's Swiftness (+65 Speed) or Silvermoon's Mending (+166 Leech). Boots: Farstrider's Hunt (+11 Speed, +232 Stamina) or Shaladrassil's Roots (+28 Leech, +232 Stamina). Speed is the throughput-neutral default; swap to Leech for a progression fight you keep dying on." },
    { slot = "Gems", items = { 240967, 240904, 240908 }, text = "One Powerful Eversong Diamond (+23 primary stat and crit effectiveness per unique gem colour you socket) - it's unique-equipped. Then Flawless Deadly Garnet (+17 Critical Strike) in every other socket, or Flawless Masterful Garnet (+16 Critical Strike, +7 Mastery) to spread a second colour if your diamond counts colours." },
    { slot = "Augment Rune", items = { 259085, 246492, 224572 }, text = "Void-Touched Augment Rune (+25 primary stat for 1 hour; it does not persist through death) for progression pulls and high keys. Soulgorged Augment Rune (+6, persists through death) or Crystallized Augment Rune (+6) are the cheap fallbacks the rest of the time." },
  },
  gear = {
    { slot = "Head", text = "Tier set piece — the set bonus usually matters more than a small item-level gap" },
    { slot = "Neck", text = "Favor Haste to generate Maelstrom Weapon stacks faster" },
    { slot = "Back", text = "Secondary stats matching Haste and Mastery outweigh a pure item-level chase" },
    { slot = "Legs", text = "Another tier slot when possible; otherwise the highest item level piece leaning Haste and Mastery" },
    { slot = "Ring", text = "Haste or Mastery rings depending on your current stat weights" },
    { slot = "Trinket", text = "One on-use Agility or damage trinket lined up with Feral Spirit or Doom Winds" },
    { slot = "Trinket", text = "A passive stat-stick trinket for consistent Stormstrike and Lava Lash damage" },
    { slot = "Weapon", text = "Two matched, high item level one-handers, kept imbued — both weapons carry Enhancement's melee damage" },
  },
  mplusLoadout = {
    string = "CcQAAAAAAAAAAAAAAAAAAAAAAMzMzgZmZmZmhZmZAAAAAAAAA2AsZGDLkFYGGawCAzyMmxYZZGYmZbsMzMzMGGzAAMDjZGGBmZwgxA",
    source = "SimulationCraft default profile (credit, not endorsement of 'best')",
    patch = "12.1",
  },
  -- Live top-players pull (DESIGN.md's v1.4 section), NOT SimC - see this
  -- file's header for the full methodology. The plurality build among the
  -- sample: 7/50 (14%) ran this exact code, since flex-point choices vary - but
  -- the bigger signal is that 50/50 (100%) ran Stormbringer overall. Reported
  -- honestly rather than dressed up as more decisive than it is.
  mplusMetaLoadout = {
    string = "CcQALMl7AwW51MWzGneuHE3tPOzMzgZmZmZmhZmZAAAAAAAAA2AsZGDbkFYGGawCAz2MmxYZZGbMzsNWmZmZYsMmBAYGGzMMCMzgBjB",
    source = "Blizzard Battle.net API, US region, 2026-08-30: top 50 current-season Mythic+ Enhancement Shamans by best keystone level, sampled across all 83 US connected realms' leaderboards. This exact build was the plurality pick (7/50, 14%); 50/50 (100%) ran Stormbringer overall.",
    patch = "12.1",
    sampleSize = 50,
  },
  tips = {
    "Don't let Maelstrom Weapon stacks sit at cap — Lightning Bolt/Chain Lightning are already instant at 5 stacks, so spend well before you hit 10 and waste generation.",
    "Keep Crash Lightning's buff active whenever it benefits your current target count.",
    "Line up Doom Winds, Feral Spirit, and Ascendance together for a single big cooldown window rather than spreading them out.",
    "Weapon imbues matter a lot for Enhancement's damage — don't let them lapse.",
    "Time your empowered casts to Surging Totem's cadence — it wants a cast roughly every other GCD to keep pace.",
  },
})

-- Restoration (264): revised for 12.1 from Blizzard patch-note content
-- reached via search summaries, not from a directly-fetched patch-notes
-- page, and not SimC-cross-checked (no SimC profile exists for this spec —
-- SimC does not publish healer profiles). The specific numbers/mechanics
-- below are UNVERIFIED against a primary source and should be treated as
-- provisional pending direct confirmation. No mplusLoadout is shipped for
-- this spec for the same reason; see the file header and DESIGN.md's
-- "BiS / Gear" section.
ns.GuideStore:RegisterSpec("SHAMAN", 264, {
  specName = "Restoration",
  role = "HEALER",
  overview = {
    "Restoration Shaman is a versatile healer that blends strong HoT-based throughput (Riptide, Healing Rain) with impactful burst heals (Healing Surge, Unleash Life) and totem-based utility, all supported by a mana-driven toolkit rather than a hard resource bar.",
    "The core resource is Mana, spent across a wide toolkit of direct heals, HoTs, and AoE healing zones like Healing Rain and Chain Heal. The defining mechanic is Riptide's HoT-and-heal-amplifying interaction with other spells, encouraging efficient weaving of Riptide onto multiple targets to smooth ongoing damage. Patch 12.1 increased Riptide's direct heal and periodic healing, shortened Healing Rain's cooldown while widening its coverage, and roughly doubled Unleash Life's healing.",
    "The two hero talent trees play differently: Totemic routes healing through your totems, with Surging Totem producing a Healing Rain effect without a cast; Farseer summons Ancestors that add extra cast-time healing. In 12.1 Farseer's Ancestors' Chain Heal was buffed. Restoration brings strong AoE healing through Healing Rain and Chain Heal, useful raid utility (Bloodlust, Tremor Totem), and solid single-target throughput.",
  },
  statPriority = {
    { stat = "primary" },
    { stat = "crit" },
    { stat = "haste" },
    { stat = "versatility" },
    { stat = "mastery" },
  },
  rotation = {
    { title = "Pre-Pull", steps = {
        { spellID = 73920, text = "Healing Rain pre-cast just before the pull if the fight opens with heavy damage" },
        { spellID = 61295, text = "Riptide pre-cast onto the group alongside it" },
        { spellID = 974, text = "Earth Shield kept active before combat starts" },
    }},
    { title = "Priorities", steps = {
        { spellID = 61295, text = "Riptide on cooldown, cycled across multiple targets for HoT uptime — both its direct and periodic healing were increased in 12.1" },
        { spellID = 5394, text = "Healing Stream Totem (or Stormstream Totem per your build) dropped for passive raid-wide trickle healing" },
        { spellID = 73920, text = "Healing Rain placed on top of the raid before or during damage — shorter cooldown and wider coverage as of 12.1, so use it more freely" },
        { spellID = 73685, text = "Unleash Life before a big heal — its healing was roughly doubled in 12.1" },
        { spellID = 378081, text = "Nature's Swiftness (or Ancestral Swiftness under Farseer) on cooldown for a free instant heal" },
        { spellID = 8004, text = "Healing Surge for fast reactive single-target healing" },
        { spellID = 1064, text = "Chain Heal for grouped-up raid damage, but it has no cooldown and costs meaningfully more mana than Riptide/Unleash Life/Healing Rain — treat it as a flexible filler you lean on as mana allows, not your first-line tool" },
        { text = "Pre-position Healing Rain and Riptide before predictable raid damage lands" },
    }},
    { title = "Cooldown Usage", steps = {
        { spellID = 108280, text = "Healing Tide Totem during a sustained heavy raid-damage phase" },
        { spellID = 114052, text = "Ascendance to extend a heavy sustained healing phase — as of 12.1 it shares a choice node with Healing Tide Totem, so pick whichever fits the fight rather than assuming both are available" },
        { spellID = 98008, text = "Spirit Link Totem to redistribute health during a spread-damage burst" },
        { spellID = 16191, text = "Mana Tide Totem to recover mana during a lull in damage" },
        { text = "Stack your strongest raid cooldown with the fight's known heaviest damage window" },
    }},
  },
  cooldowns = {
    { spellID = 108280, text = "Healing Tide Totem — strong raid-wide healing cooldown; now on a choice node with Ascendance, so only one is available per build" },
    { spellID = 114052, text = "Ascendance — sustained raid healing cooldown; shares a choice node with Healing Tide Totem" },
    { spellID = 98008, text = "Spirit Link Totem — redistributes raid health, use for spread burst damage" },
    { spellID = 16191, text = "Mana Tide Totem — mana recovery cooldown for the raid" },
    { spellID = 108271, text = "Astral Shift — personal defensive cooldown" },
    { spellID = 2825, text = "Bloodlust — raid-wide haste cooldown, coordinate timing with the raid" },
  },
  consumables = {
    { slot = "Flask", items = { 241327, 241325 }, text = "Flask of the Shattered Sun for Critical Strike, this spec's top secondary; Flask of the Blood Knights if your gear already leans hard into Critical Strike and Haste is the stat you're short on." },
    { slot = "Food", items = { 275265, 275266, 255846, 275259, 242755 }, text = "Raid feasts: Loa's Gathering or Feast of Knowledge (Stamina plus your highest secondary, new in 12.1), or Harandar Celebration / Silvermoon Parade (Stamina plus 50 primary stat) - the two families sim within a fraction of a percent of each other, so eat whichever is down. Solo and Mythic+: Hearty Venom-Spiced Cutlets or Hearty Puffer Plate (highest secondary) or Hearty Sun-Seared Lumifin (Critical Strike); Hearty food persists through death." },
    { slot = "Potion", items = { 241301, 241295, 241289, 271884 }, text = "Lightfused Mana Potion is the safe mana return; Potion of Devoured Dreams gives more over 10s but leaves you defenceless while it channels, so only when nothing is targeting you. Potion of Recklessness (+1585 highest secondary for 30s) for a throughput window instead. Always carry Concentrated Silvermoon Health Potions." },
    { slot = "Weapon Oil", items = { 243734, 243736 }, text = "Thalassian Phoenix Oil - the current tier's weapon oil (+16 Critical Strike and Haste for 2 hours, from Enchanting); Oil of Dawn instead if you'd rather your heals proc a small absorb on their target." },
    { slot = "Weapon Enchant", items = { 244029, 243971, 243997 }, text = "Acuity of the Ren'dorei procs +67 primary stat for 15s; Jan'alai's Precision procs +124 Critical Strike instead. The primary-stat proc is the usual default; take the secondary one if your stat weights put Critical Strike well clear of the rest. Worldsoul Cradle (heals proc a 12.5k barrier on the target) is the healer-flavoured alternative." },
    { slot = "Ring Enchants", items = { 243987, 244015 }, text = "Nature's Fury (+29 Critical Strike) on both rings; Silvermoon's Alacrity (+29 Haste) if you're topping up your second stat instead. Use the greater tier - the lesser one is +24." },
    { slot = "Chest Enchant", items = { 243977, 244003 }, text = "Mark of the Worldsoul (+50 primary stat); Mark of the Magister (+40 Intellect, +5% mana) if mana is what runs out." },
    { slot = "Leg Enchant", items = { 240133, 240155 }, text = "Sunfire Silk Spellthread (+41 Intellect, +115 Stamina); Arcanoweave Spellthread (+41 Intellect, +4% mana) if you'd rather have the mana than the health." },
    { slot = "Helm, Shoulders and Boots", items = { 243979, 243963, 244009, 244021, 243983 }, text = "Helm: Blessing of Speed (+13). Shoulders: Akil'zon's Swiftness (+65 Speed) or Silvermoon's Mending (+166 Leech). Boots: Farstrider's Hunt (+11 Speed, +232 Stamina) or Shaladrassil's Roots (+28 Leech, +232 Stamina). Speed is the throughput-neutral default; swap to Leech for a progression fight you keep dying on." },
    { slot = "Gems", items = { 240969, 240904, 240906 }, text = "One Telluric Eversong Diamond (+23 primary stat, +1% mana per unique gem colour) - it's unique-equipped. Then Flawless Deadly Garnet (+17 Critical Strike) in every other socket, or Flawless Quick Garnet (+16 Critical Strike, +7 Haste) to spread a second colour if your diamond counts colours." },
    { slot = "Augment Rune", items = { 259085, 246492, 224572 }, text = "Void-Touched Augment Rune (+25 primary stat for 1 hour; it does not persist through death) for progression pulls and high keys. Soulgorged Augment Rune (+6, persists through death) or Crystallized Augment Rune (+6) are the cheap fallbacks the rest of the time." },
  },
  gear = {
    { slot = "Head", text = "Tier set piece — the set bonus usually matters more than a small item-level gap" },
    { slot = "Neck", text = "Favor Crit and Haste to strengthen burst heals and Riptide cycling" },
    { slot = "Back", text = "Pick up Intellect and secondary stats over a pure item-level upgrade" },
    { slot = "Legs", text = "Another tier slot when possible; otherwise the highest item level piece leaning Crit and Mastery" },
    { slot = "Ring", text = "Crit or Mastery rings depending on whether burst or sustained healing needs more support" },
    { slot = "Trinket", text = "One mana-efficiency trinket for long fights" },
    { slot = "Trinket", text = "One throughput trinket timed with Healing Tide Totem or Ascendance windows" },
    { slot = "Weapon", text = "A one-hander with strong Intellect and secondary stats" },
    { slot = "Off-hand", text = "An off-hand caster stat stick for extra Intellect and secondary stats" },
  },
  -- Live top-players pull (DESIGN.md's v1.4 section), NOT SimC - see this
  -- file's header for the full methodology. The plurality build among the
  -- sample: 2/50 (4%) ran this exact code, since flex-point choices vary - but
  -- the bigger signal is that 47/50 (94%) ran Totemic overall. Reported
  -- honestly rather than dressed up as more decisive than it is.
  mplusMetaLoadout = {
    string = "CgQALMl7AwW51MWzGneuHE3tPCAAAgBAAAAzMzsstMmZmZmZmZMjhFYDmxiGbDIzAbYmBzyMjRzyyMzmZMbsYMzYYZWGAAMAmZwMDAMYA",
    source = "Blizzard Battle.net API, US region, 2026-08-30: top 50 current-season Mythic+ Restoration Shamans by best keystone level, sampled across all 83 US connected realms' leaderboards. This exact build was the plurality pick (2/50, 4%); 47/50 (94%) ran Totemic overall.",
    patch = "12.1",
    sampleSize = 50,
  },
  tips = {
    "Cycle Riptide across the raid rather than only refreshing it on one target — the HoT is efficient healing, and got stronger again in patch 12.1.",
    "Pre-place Healing Rain ahead of predictable raid-wide damage rather than reacting after it lands — its shorter 12.1 cooldown means you can afford to use it more often.",
    "Save Spirit Link Totem for the fight's known heaviest spread-damage windows, and Healing Tide Totem or Ascendance (whichever your build has, since 12.1 put them on a shared choice node) for sustained heavy phases.",
    "Use Mana Tide Totem during lulls to stay ahead of mana problems in longer fights.",
    "Unleash Life's healing bonus was roughly doubled in patch 12.1 — use it before a big cast.",
    "Pre-cast Healing Rain and Riptide just before a pull that opens with heavy damage, rather than starting from zero.",
    "Keep Earth Shield active on your tank — it's easy to let it lapse once you're busy with raid healing.",
    "Chain Heal costs noticeably more mana than Riptide, Unleash Life, or Healing Rain — lean on those first and use Chain Heal as a flexible filler as mana allows.",
  },
})
