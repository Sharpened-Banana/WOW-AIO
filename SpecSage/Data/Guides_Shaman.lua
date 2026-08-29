local ADDON, ns = ...

-- SpecSage guide data: Shaman (Elemental 262, Enhancement 263, Restoration 264)
-- Content targets The War Within. This is community-maintained conventional
-- guidance (stat priorities and rotations that match the spec's long-standing
-- design) — not a claim of bleeding-edge sim-perfect optimization.
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
  tips = {
    "Don't let Maelstrom Weapon stacks sit at cap — spend them before generation is wasted.",
    "Keep Crash Lightning's buff active whenever it benefits your current target count.",
    "Line up Feral Spirit with your other burst cooldowns and trinkets when possible.",
    "Weapon imbues matter a lot for Enhancement's damage — don't let them lapse.",
  },
})

ns.GuideStore:RegisterSpec("SHAMAN", 264, {
  specName = "Restoration",
  role = "HEALER",
  overview = {
    "Restoration Shaman is a versatile healer that blends strong HoT-based throughput (Riptide, Healing Rain) with impactful burst heals (Healing Surge) and totem-based utility, all supported by the Maelstrom Weapon-adjacent resource flow unique to the spec's healing kit.",
    "The core resource is Mana, spent across a wide toolkit of direct heals, HoTs, and AoE healing zones like Healing Rain and Cloudburst Totem. The defining mechanic is Riptide's HoT-and-heal-reduction interaction with other spells, encouraging efficient weaving of Riptide onto multiple targets to smooth ongoing damage.",
    "Restoration brings strong AoE healing through Healing Rain and Chain Heal, useful raid utility (Bloodlust, Tremor Totem), and solid single-target throughput, making it a strong pick for fights with frequent raid-wide damage and a need for efficient mana management over long encounters.",
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
        { spellID = 61295, text = "Riptide on cooldown, cycled across multiple targets for HoT uptime" },
        { spellID = 1064, text = "Chain Heal for efficient grouped-up raid healing" },
        { spellID = 5394, text = "Healing Rain placed on top of the raid before or during damage" },
        { spellID = 8004, text = "Healing Surge for fast reactive single-target healing" },
        { spellID = 61301, text = "Riptide re-application prioritized over pure direct healing when mana allows" },
        { text = "Pre-position Healing Rain and Riptide before predictable raid damage lands" },
    }},
    { title = "Cooldown Usage", steps = {
        { spellID = 108280, text = "Healing Tide Totem during a sustained heavy raid-damage phase" },
        { spellID = 98008, text = "Spirit Link Totem to redistribute health during a spread-damage burst" },
        { spellID = 16191, text = "Mana Tide Totem to recover mana during a lull in damage" },
        { text = "Stack your strongest raid cooldown with the fight's known heaviest damage window" },
        { text = "Use Ascendance-style cooldowns to extend a heavy sustained healing phase" },
    }},
  },
  cooldowns = {
    { spellID = 108280, text = "Healing Tide Totem — strong raid-wide healing cooldown" },
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
  tips = {
    "Cycle Riptide across the raid rather than only refreshing it on one target — the HoT is efficient healing.",
    "Pre-place Healing Rain ahead of predictable raid-wide damage rather than reacting after it lands.",
    "Save Healing Tide Totem and Spirit Link Totem for the fight's known heaviest damage windows.",
    "Use Mana Tide Totem during lulls to stay ahead of mana problems in longer fights.",
  },
})
