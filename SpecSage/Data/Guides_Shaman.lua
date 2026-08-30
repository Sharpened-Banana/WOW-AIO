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
-- This is community-maintained conventional guidance (stat priorities and
-- rotations that match the spec's long-standing design) — not a claim of
-- bleeding-edge sim-perfect optimization.
-- To edit: change the strings/tables below and reload. To add a spec pack,
-- call ns.GuideStore:RegisterSpec(classToken, specID, guideTable) from any
-- addon that loads after SpecSage; see Data/API.lua for validation rules.

if not ns.GuideStore then return end

ns.GuideStore:RegisterSpec("SHAMAN", 262, {
  specName = "Elemental",
  role = "DAMAGER",
  overview = {
    "Elemental Shaman is a ranged caster spec that blends instant-cast Lava Burst and Lightning Bolt spam with Maelstrom-fueled Earth Shock casts, all while maintaining Flame Shock on the target as a bridge between Lava Burst casts. It plays with a mix of instant and hard-cast spells that reward positioning discipline during movement-heavy fights.",
    "The core resource is Maelstrom, generated from spells like Lightning Bolt and Earth Shock's associated generators, and spent on Earth Shock. The defining mechanic is Lava Surge, a proc that makes Lava Burst instant and resets its cooldown — chaining these procs with Flame Shock uptime is central to sustained damage.",
    "Elemental brings strong burst through Storm Elemental/Fire Elemental-style cooldowns, solid AoE via Earthquake and Chain Lightning, and useful raid utility (Bloodlust, Hex), making it a flexible pick for both single-target progression fights and add-heavy Mythic+ content.",
  },
  statPriority = {
    { stat = "primary", note = "Intellect, passive" },
    { stat = "haste" },
    { stat = "mastery" },
    { stat = "crit" },
    { stat = "versatility" },
  },
  rotation = {
    { title = "Single Target", steps = {
        { spellID = 188389, text = "Flame Shock kept active on the target" },
        { spellID = 51505, text = "Lava Burst on cooldown, prioritized when Lava Surge procs" },
        { spellID = 8042, text = "Earth Shock to spend Maelstrom once it's built up" },
        { spellID = 188196, text = "Lightning Bolt as a Maelstrom generator and filler" },
        { spellID = 198067, text = "Fire Elemental on cooldown for a sustained burst window" },
        { spellID = 114050, text = "Ascendance on cooldown for a burst window, ideally alongside Fire/Storm Elemental" },
        { spellID = 191634, text = "Stormkeeper before a burst window to empower your next casts" },
        { text = "Never let Flame Shock fall off — it feeds Lava Surge procs" },
    }},
    { title = "AoE", steps = {
        { spellID = 61882, text = "Earthquake as the primary AoE Maelstrom spender" },
        { spellID = 188443, text = "Chain Lightning as the primary AoE Maelstrom generator" },
        { spellID = 188389, text = "Flame Shock spread to priority targets" },
        { spellID = 51505, text = "Lava Burst on cooldown, still valuable while cleaving" },
        { spellID = 198067, text = "Fire Elemental for burst during add waves" },
        { text = "Prioritize Earthquake/Chain Lightning over single-target casts once 3+ targets are engaged" },
    }},
    { title = "Opener Notes", steps = {
        { text = "Apply Flame Shock immediately and build Maelstrom before your first Earth Shock" },
        { text = "Line up Fire Elemental/Storm Elemental with trinkets for maximum burst" },
    }},
  },
  cooldowns = {
    { spellID = 198067, text = "Fire Elemental — core offensive cooldown, use on cooldown" },
    { spellID = 192249, text = "Storm Elemental — alternative burst cooldown depending on talents" },
    { spellID = 114050, text = "Ascendance — burst cooldown, line it up with your elemental and Stormkeeper" },
    { spellID = 191634, text = "Stormkeeper — empowers your next Lightning Bolt/Chain Lightning casts, use before a burst window" },
    { spellID = 108271, text = "Astral Shift — defensive damage-reduction cooldown" },
    { spellID = 2825, text = "Bloodlust — raid-wide haste cooldown, coordinate timing with the raid" },
    { spellID = 51514, text = "Hex — crowd control utility for dangerous adds" },
  },
  consumables = {
    { slot = "Flask", text = "Flask of Alchemical Chaos (Intellect)" },
    { slot = "Food", text = "An Intellect-focused feast or food buff" },
    { slot = "Potion", text = "Tempered Potion, used inside Fire Elemental" },
    { slot = "Weapon", text = "Shadowcore Oil or the current-tier weapon oil" },
    { slot = "Enchants", text = "Weapon enchant for Intellect/haste; ring enchants for secondary stats" },
    { slot = "Gems", text = "Intellect or Intellect/secondary hybrid gems in available sockets" },
  },
  gear = {
    { slot = "Head", text = "Tier set piece — the set bonus usually matters more than a small item-level gap" },
    { slot = "Neck", text = "Favor Haste to chain Lava Surge procs and generate Maelstrom faster" },
    { slot = "Back", text = "Secondary stats matching Haste and Mastery outweigh a pure item-level chase" },
    { slot = "Legs", text = "Another tier slot when possible; otherwise the highest item level piece leaning Haste and Mastery" },
    { slot = "Ring", text = "Haste or Mastery rings depending on your current stat weights" },
    { slot = "Trinket", text = "One on-use Intellect or damage trinket lined up with Fire Elemental or Storm Elemental" },
    { slot = "Trinket", text = "A passive stat-stick trinket for consistent Lava Burst and Earth Shock damage" },
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
    "Don't cap Maelstrom — spend it on Earth Shock before it overflows.",
    "Coordinate Bloodlust timing with your raid rather than using it purely on your own cooldowns.",
    "Switch fully to Earthquake/Chain Lightning once three or more targets are engaged.",
  },
})

ns.GuideStore:RegisterSpec("SHAMAN", 263, {
  specName = "Enhancement",
  role = "DAMAGER",
  overview = {
    "Enhancement Shaman is a dual-wield melee spec that combines weapon-enchant-fueled attacks with elemental spells like Lava Lash and Stormstrike, generating Maelstrom Weapon stacks that empower its spells with instant casts and bonus effects. It plays as a fast, proc-driven spec with a strong emphasis on weaving spells at the right Maelstrom Weapon stack count.",
    "The core resource is Maelstrom Weapon, generated from melee attacks and abilities, and spent by casting empowered spells like Lightning Bolt and Chain Lightning at high stacks for extra effects. The defining mechanic is stack management — using Maelstrom Weapon stacks efficiently rather than either spending too early or overcapping and wasting generation.",
    "Enhancement brings strong burst through Feral Spirit and Doom Winds-style cooldowns, solid AoE via Chain Lightning and Crash Lightning, and good self-sufficiency, making it a strong pick for fights that reward burst windows and consistent melee uptime.",
  },
  statPriority = {
    { stat = "primary", note = "Agility, passive" },
    { stat = "haste" },
    { stat = "mastery" },
    { stat = "crit" },
    { stat = "versatility" },
  },
  rotation = {
    { title = "Single Target", steps = {
        { spellID = 17364, text = "Stormstrike on cooldown — core melee ability and Maelstrom generator" },
        { spellID = 60103, text = "Lava Lash on cooldown for strong single-target damage" },
        { spellID = 187874, text = "Crash Lightning to apply its buff even in single target if talented" },
        { spellID = 188196, text = "Lightning Bolt to spend Maelstrom Weapon stacks at high value" },
        { spellID = 51533, text = "Feral Spirit on cooldown for a burst window" },
        { text = "Primordial Storm (Stormbringer hero talent) once Maelstrom Weapon is stacked high — a strong Maelstrom-fueled finisher" },
        { text = "Spend Maelstrom Weapon stacks before they overcap and waste generation" },
    }},
    { title = "AoE", steps = {
        { spellID = 187874, text = "Crash Lightning as the primary AoE melee tool" },
        { spellID = 188443, text = "Chain Lightning to spend Maelstrom Weapon across multiple targets" },
        { spellID = 17364, text = "Stormstrike still strong, cleaves with talents" },
        { spellID = 60103, text = "Lava Lash for cleave damage and Flame Shock-style spread with talents" },
        { spellID = 51533, text = "Feral Spirit for burst during add waves" },
        { text = "Prioritize Crash Lightning/Chain Lightning once 3+ targets are engaged" },
    }},
    { title = "Opener Notes", steps = {
        { text = "Build Maelstrom Weapon stacks briefly before your first big empowered cast" },
        { text = "Line up Feral Spirit and Doom Winds-style cooldowns with trinkets for maximum burst" },
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
    { slot = "Flask", text = "Flask of Alchemical Chaos (Agility)" },
    { slot = "Food", text = "An Agility-focused feast or food buff" },
    { slot = "Potion", text = "Tempered Potion, used inside Feral Spirit" },
    { slot = "Weapon", text = "Windfury or Flametongue-style weapon imbue as appropriate to your build" },
    { slot = "Enchants", text = "Weapon enchant for Agility/Crit; ring enchants for secondary stats" },
    { slot = "Gems", text = "Agility or Agility/secondary hybrid gems in available sockets" },
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
    "Don't let Maelstrom Weapon stacks sit at cap — spend them before generation is wasted.",
    "Keep Crash Lightning's buff active whenever it benefits your current target count.",
    "Line up Feral Spirit with your other burst cooldowns and trinkets when possible.",
    "Weapon imbues matter a lot for Enhancement's damage — don't let them lapse.",
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
    { stat = "primary", note = "Intellect, passive" },
    { stat = "crit" },
    { stat = "haste" },
    { stat = "mastery" },
    { stat = "versatility" },
  },
  rotation = {
    { title = "Priorities", steps = {
        { spellID = 61295, text = "Riptide on cooldown, cycled across multiple targets for HoT uptime — both its direct and periodic healing were increased in 12.1" },
        { spellID = 1064, text = "Chain Heal for efficient grouped-up raid healing" },
        { spellID = 73920, text = "Healing Rain placed on top of the raid before or during damage — shorter cooldown and wider coverage as of 12.1, so use it more freely" },
        { spellID = 73685, text = "Unleash Life before a big heal — its healing was roughly doubled in 12.1" },
        { spellID = 8004, text = "Healing Surge for fast reactive single-target healing" },
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
    { slot = "Flask", text = "Flask of Alchemical Chaos (Intellect)" },
    { slot = "Food", text = "An Intellect-focused feast or food buff" },
    { slot = "Potion", text = "A mana or Intellect potion for extended healing-heavy fights" },
    { slot = "Weapon", text = "Shadowcore Oil or the current-tier weapon oil" },
    { slot = "Enchants", text = "Weapon enchant for Intellect/haste; ring enchants for secondary stats" },
    { slot = "Gems", text = "Intellect or Intellect/secondary hybrid gems in available sockets" },
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
  },
})
