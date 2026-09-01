local ADDON, ns = ...

-- SpecSage guide data: Rogue (Assassination 259, Outlaw 260, Subtlety 261)
-- Content targets Midnight (patch 12.1). Specs below with an `mplusLoadout`
-- field have that talent string (only) cross-checked against
-- SimulationCraft's public profiles (github.com/simulationcraft/simc,
-- GPLv3) as of patch 12.1; specs without one have no such reference.
-- Rotation/overview/tips/gear prose throughout this file is hand-authored
-- and was reviewed for Midnight ability changes, not derived from or
-- checked against SimC's APLs, and was not re-verified against current
-- tuning this pass — EXCEPT Assassination (259), Outlaw (260), and Subtlety (261),
-- which each gained an `mplusMetaLoadout` (DESIGN.md's v1.4 section) this
-- pass: pulled live from Blizzard's own Battle.net Game Data API
-- (client-credentials OAuth, US region) rather than SimC, on 2026-08-30.
-- Methodology: every current-season Mythic+ leaderboard (8-dungeon pool,
-- period 1078) across all 83 US connected realms was scanned (top 20 groups
-- per realm/dungeon) for each spec's group members; the top-observed-keystone
-- characters (up to 50 per spec) had their live `specializations` looked up
-- for their active loadout's `talent_loadout_code`. See each field's own
-- `source` comment for the resulting distribution.
-- Subtlety's overview/rotation/tips were also corrected this pass: Symbols
-- of Death has zero references in SimC's current `midnight` branch
-- profile, confirmed via a Blizzard forum thread on the ability's removal
-- ("It got removed this patch!") — its energy refund and combo-point boost
-- were folded directly into Shadow Dance, which now carries that role
-- alone.
-- This is community-maintained conventional guidance (stat priorities and
-- rotations that match the spec's long-standing design) — not a claim of
-- bleeding-edge sim-perfect optimization.
-- To edit: change the strings/tables below and reload. To add a spec pack,
-- call ns.GuideStore:RegisterSpec(classToken, specID, guideTable) from any
-- addon that loads after SpecSage; see Data/API.lua for validation rules.

if not ns.GuideStore then return end

ns.GuideStore:RegisterSpec("ROGUE", 259, {
  specName = "Assassination",
  role = "DAMAGER",
  overview = {
    "Assassination Rogue is a poison- and bleed-focused melee spec built around keeping Garrote and Rupture active on the target while spending combo points on Envenom for direct damage. It rewards careful DoT upkeep and combo point discipline over raw button-mashing.",
    "The core resource is Energy, regenerating over time and spent to build combo points with Mutilate/Fan of Knives, which are then spent on finishers like Envenom and Rupture. The defining mechanic is bleed and poison uptime — Garrote, Rupture, and your poisons all need to be refreshed before falling off to avoid a significant damage loss.",
    "Assassination brings strong sustained single-target damage, solid AoE through Fan of Knives spreading DoTs, and good execute-phase scaling, making it a reliable pick for longer fights where consistent uptime matters more than burst windows.",
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
        { spellID = 703, text = "Garrote to open and keep its bleed active on the target" },
        { spellID = 1943, text = "Rupture kept up — refresh before it falls off" },
        { spellID = 32645, text = "Envenom to spend combo points once Rupture is active" },
        { spellID = 1329, text = "Mutilate on cooldown as the primary combo point builder" },
        { spellID = 360194, text = "Deathmark on cooldown for a burst damage window" },
        { text = "Refresh poisons before they expire — lost uptime is a real DPS loss" },
    }},
    { title = "AoE", steps = {
        { spellID = 51723, text = "Fan of Knives as the primary combo point builder against 3+ targets" },
        { text = "Deadly Poison spread to all engaged targets" },
        { spellID = 1943, text = "Rupture on priority targets once poisons are spread" },
        { spellID = 360194, text = "Deathmark on cooldown for burst during add waves" },
        { spellID = 32645, text = "Envenom to spend combo points when Rupture upkeep isn't needed" },
        { text = "Prioritize spreading DoTs over single-target finishers early in an AoE pull" },
    }},
    { title = "Opener Notes", steps = {
        { text = "Open from Stealth with Garrote for its bonus damage, then build toward Rupture" },
        { text = "Line up Deathmark with your first full combo point Envenom for maximum burst" },
        { text = "Deathmark hits hardest once both Garrote and Rupture are already ticking — don't fire it before your bleeds are established" },
    }},
  },
  cooldowns = {
    { spellID = 360194, text = "Deathmark — core offensive cooldown, use on cooldown" },
    { text = "Kingsbane — poison burst cooldown, pair with Deathmark when possible" },
    { spellID = 31224, text = "Cloak of Shadows — major magic defensive, clears many magic effects" },
    { spellID = 5277, text = "Evasion — physical defensive cooldown" },
    { spellID = 1856, text = "Vanish — reset positioning, re-open with a stealth opener, or drop aggro" },
  },
  consumables = {
    { slot = "Flask", text = "Flask of Alchemical Chaos (Agility)" },
    { slot = "Food", text = "An Agility-focused feast or food buff" },
    { slot = "Potion", text = "Tempered Potion, used inside Deathmark" },
    { slot = "Weapon", text = "Instant Poison and Wound Poison (or current-tier equivalents) on both weapons" },
    { slot = "Enchants", text = "Weapon enchant for Agility/Crit; ring enchants for secondary stats" },
    { slot = "Gems", text = "Agility or Agility/secondary hybrid gems in available sockets" },
  },
  gear = {
    { slot = "Head", text = "Tier set piece — the set bonus usually matters more than a small item-level gap" },
    { slot = "Neck", text = "Favor Haste to speed up combo point generation and DoT ticks" },
    { slot = "Back", text = "Secondary stats matching Haste and Crit outweigh a pure item-level chase" },
    { slot = "Legs", text = "Another tier slot when possible; otherwise the highest item level piece leaning Haste and Crit" },
    { slot = "Ring", text = "Haste or Crit rings depending on your current stat weights" },
    { slot = "Trinket", text = "One on-use Agility or damage trinket lined up with Deathmark" },
    { slot = "Trinket", text = "A passive stat-stick trinket for consistent bleed and poison damage" },
    { slot = "Weapon", text = "Two matched, high item level daggers or one-handers — both weapons carry Assassination's bleed and poison damage equally" },
  },
  mplusLoadout = {
    string = "CMQAAAAAAAAAAAAAAAAAAAAAAYmlxsNDGAAAAAYWGsNDAAAAAIbzMzMzMjxyMzMbzsMzMzYGzYMmZMMAbmlBGwSwywEYYxgZGgxYA",
    source = "SimulationCraft default profile (credit, not endorsement of 'best')",
    patch = "12.1",
  },
  -- Live top-players pull (DESIGN.md's v1.4 section), NOT SimC - see this
  -- file's header for the full methodology. The plurality build among the
  -- sample: 2/50 (4%) ran this exact code, since flex-point choices vary - but
  -- the bigger signal is that 34/50 (68%) ran Deathstalker overall. Reported
  -- honestly rather than dressed up as more decisive than it is.
  mplusMetaLoadout = {
    string = "CMQA5HmDzx68KWyrW/8Y781L7bmlZmFDGAAAAAYWGsNDAAAAAotlZmZmZmxYbmZmtZWmZmHwDMmZMzwMjxAsZWGYALBLDTghFDmZAGMA",
    source = "Blizzard Battle.net API, US region, 2026-08-30: top 50 current-season Mythic+ Assassination Rogues by best keystone level, sampled across all 83 US connected realms' leaderboards. This exact build was the plurality pick (2/50, 4%); 34/50 (68%) ran Deathstalker overall.",
    patch = "12.1",
    sampleSize = 50,
  },
  tips = {
    "Never let Rupture or Garrote fall off a target you'll be attacking for more than a few seconds.",
    "Keep your weapon poisons refreshed — a lapsed poison is a silent DPS loss.",
    "Line up Deathmark and Kingsbane together whenever their cooldowns allow.",
    "Fan of Knives spreads your bleeds efficiently — use it to seed DoTs across a pull before single-targeting.",
  },
})

ns.GuideStore:RegisterSpec("ROGUE", 260, {
  specName = "Outlaw",
  role = "DAMAGER",
  overview = {
    "Outlaw Rogue is a swashbuckling melee spec built around Roll the Bones buffs and Combat Potency-style resource generation from off-hand swings. It plays as a flexible, high-mobility spec with Pistol Shot and Between the Eyes providing ranged options unusual for a Rogue.",
    "The core resource is Energy, spent to build combo points with Sinister Strike and Pistol Shot, which are then spent on Dispatch and Between the Eyes. The defining mechanic is Roll the Bones, a buff roll that grants a randomized set of damage buffs — you re-roll it when few buffs are active and hold it when a strong roll lands.",
    "Outlaw brings strong burst through Adrenaline Rush and Blade Flurry cleave, solid mobility via Grappling Hook and Sprint, and simple execute-phase scaling with Between the Eyes, making it a versatile pick for both single-target and cleave-heavy fights.",
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
        { spellID = 193315, text = "Sinister Strike on cooldown — primary combo point builder" },
        { spellID = 1214909, text = "Roll the Bones to apply buffs, re-roll when few are active" },
        { spellID = 2098, text = "Dispatch to spend combo points at low target health" },
        { spellID = 315341, text = "Between the Eyes to spend combo points and apply its debuff" },
        { spellID = 13750, text = "Adrenaline Rush on cooldown for a burst window" },
        { text = "Keep Roll the Bones buffs active — don't let the roll fall off entirely" },
    }},
    { title = "AoE", steps = {
        { spellID = 13877, text = "Blade Flurry to cleave your attacks across nearby targets" },
        { spellID = 193315, text = "Sinister Strike still the primary builder while cleaving" },
        { spellID = 51690, text = "Killing Spree or equivalent burst tool during add waves" },
        { spellID = 1214909, text = "Roll the Bones for its buffs, especially cleave-relevant ones" },
        { spellID = 2098, text = "Dispatch/finishers to spend combo points across the pull" },
        { text = "Turn on Blade Flurry as soon as 2+ targets are engaged" },
    }},
    { title = "Opener Notes", steps = {
        { text = "Open with Roll the Bones to establish buffs before committing to your main cooldowns" },
        { text = "Line up Adrenaline Rush with a strong Roll the Bones result for maximum burst" },
        { text = "If you're talented into Fan the Hammer, Pistol Shot chains take over as your main combo point builder instead of Sinister Strike — check your build before assuming a fixed generator" },
    }},
  },
  cooldowns = {
    { spellID = 13750, text = "Adrenaline Rush — core offensive cooldown, use on cooldown" },
    { spellID = 51690, text = "Killing Spree — burst mobility/damage cooldown" },
    { spellID = 31224, text = "Cloak of Shadows — major magic defensive, clears many magic effects" },
    { spellID = 5277, text = "Evasion — physical defensive cooldown" },
    { spellID = 1856, text = "Vanish — reset positioning or drop aggro" },
  },
  consumables = {
    { slot = "Flask", text = "Flask of Alchemical Chaos (Agility)" },
    { slot = "Food", text = "An Agility-focused feast or food buff" },
    { slot = "Potion", text = "Tempered Potion, used inside Adrenaline Rush" },
    { slot = "Weapon", text = "Instant Poison or the current-tier weapon buff on both weapons" },
    { slot = "Enchants", text = "Weapon enchant for Agility/Crit; ring enchants for secondary stats" },
    { slot = "Gems", text = "Agility or Agility/secondary hybrid gems in available sockets" },
  },
  gear = {
    { slot = "Head", text = "Tier set piece — the set bonus usually matters more than a small item-level gap" },
    { slot = "Neck", text = "Favor Haste for faster combo point generation and quicker ability weaving" },
    { slot = "Back", text = "Secondary stats matching Haste and Mastery outweigh a pure item-level chase" },
    { slot = "Legs", text = "Another tier slot when possible; otherwise the highest item level piece leaning Haste and Mastery" },
    { slot = "Ring", text = "Haste or Mastery rings depending on your current stat weights" },
    { slot = "Trinket", text = "One on-use Agility or damage trinket lined up with Adrenaline Rush" },
    { slot = "Trinket", text = "A passive stat-stick trinket for consistent damage between cooldowns" },
    { slot = "Weapon", text = "Two matched, high item level one-handers, since Sinister Strike and your finishers scale off both weapons" },
  },
  mplusLoadout = {
    string = "CQQAAAAAAAAAAAAAAAAAAAAAAAgx2MMzMmZmtZmZmZMmF4BmZbaZw2MAAAAAALLzMzwMzMziZmZbAAAAYmBAjZxwQGYWYhWYjBYmBDMA",
    source = "SimulationCraft default profile (credit, not endorsement of 'best')",
    patch = "12.1",
  },
  -- Live top-players pull (DESIGN.md's v1.4 section), NOT SimC - see this
  -- file's header for the full methodology. The plurality build among the
  -- sample: 11/50 (22%) ran this exact code, since flex-point choices vary -
  -- but the bigger signal is that 50/50 (100%) ran Trickster overall. Reported
  -- honestly rather than dressed up as more decisive than it is.
  mplusMetaLoadout = {
    string = "CQQA5HmDzx68KWyrW/8Y781L7Dgx2MMzMjZmtZmZMzMzsAmZbaZw2MAAAAAgZbZmZGmZmZWMzMbDAAAAjBAjZxwQGYWYhWYjBYmBDMA",
    source = "Blizzard Battle.net API, US region, 2026-08-30: top 50 current-season Mythic+ Outlaw Rogues by best keystone level, sampled across all 83 US connected realms' leaderboards. This exact build was the plurality pick (11/50, 22%); 50/50 (100%) ran Trickster overall.",
    patch = "12.1",
    sampleSize = 50,
  },
  tips = {
    "Don't re-roll Roll the Bones just because it feels weak — check whether it's actually below the keep threshold first.",
    "Blade Flurry is worth toggling on immediately when a second target joins the fight.",
    "Line up Adrenaline Rush with your best Roll the Bones roll when timing allows.",
    "Between the Eyes' debuff is valuable raid utility — don't only think of it as a finisher.",
  },
})

ns.GuideStore:RegisterSpec("ROGUE", 261, {
  specName = "Subtlety",
  role = "DAMAGER",
  overview = {
    "Subtlety Rogue is a Shadow-infused melee spec built around Shadow Dance windows, spending combo points on Eviscerate while weaving in Shadowstrike from stealth. Symbols of Death was removed and its energy/combo-point boost folded directly into Shadow Dance itself, so Shadow Dance alone now carries that role. It plays as a burst-window spec, dealing much of its damage inside timed cooldown windows rather than a flat sustained rotation.",
    "The core resource is Energy, spent to build combo points with Shadowstrike and Backstab, then spent on Eviscerate and Black Powder. The defining mechanic is Shadow Dance, which grants stealth-like access to Shadowstrike outside of true stealth, making burst windows repeatable throughout a fight rather than limited to the opener.",
    "Subtlety brings strong burst damage inside cooldown windows, good AoE through Black Powder, and useful utility (Shroud of Concealment, Distract), making it a good pick for fights with clear burst phases or add windows to dump cooldowns into.",
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
        { text = "Shadow Dance on cooldown — it now carries the energy refund and combo-point boost that used to come from the separate Symbols of Death button" },
        { spellID = 185313, text = "Shadow Dance to access Shadowstrike outside of stealth" },
        { spellID = 185438, text = "Shadowstrike as your primary combo point builder during Dance windows" },
        { spellID = 53, text = "Backstab to build combo points outside of Dance windows" },
        { spellID = 196819, text = "Eviscerate to spend combo points" },
        { text = "Keep Shadow Dance on cooldown for maximum burst" },
    }},
    { title = "AoE", steps = {
        { spellID = 319175, text = "Black Powder as the primary AoE combo point spender" },
        { text = "Shadow Dance on cooldown to buff AoE damage" },
        { spellID = 185313, text = "Shadow Dance for extra Shadowstrike/Black Powder access" },
        { spellID = 185438, text = "Shadowstrike still a strong builder, hits the primary target" },
        { spellID = 53, text = "Backstab as filler builder when Dance is down" },
        { text = "Prioritize Black Powder over Eviscerate once 2+ targets are engaged" },
    }},
    { title = "Opener Notes", steps = {
        { text = "Open from Stealth with Shadowstrike, then chain into Shadow Dance" },
        { text = "Save a second Shadow Dance charge if possible to extend your opening burst window" },
        { text = "Your hero talent choice colors the finisher priority — Deathstalker weaves its mark debuff into the builder/finisher cycle, while Trickster stacks its own resource on top of combo points — but the core Shadow Dance cadence stays the same either way" },
    }},
  },
  cooldowns = {
    { spellID = 121471, text = "Shadow Blades — burst cooldown, use alongside Shadow Dance" },
    { spellID = 185313, text = "Shadow Dance — core repeatable burst window, use on cooldown" },
    { spellID = 31224, text = "Cloak of Shadows — major magic defensive, clears many magic effects" },
    { spellID = 5277, text = "Evasion — physical defensive cooldown" },
    { spellID = 1856, text = "Vanish — reopen Shadowstrike from stealth or reposition" },
  },
  consumables = {
    { slot = "Flask", text = "Flask of Alchemical Chaos (Agility)" },
    { slot = "Food", text = "An Agility-focused feast or food buff" },
    { slot = "Potion", text = "Tempered Potion, used inside a Shadow Dance/Shadow Blades window" },
    { slot = "Weapon", text = "Instant Poison or the current-tier weapon buff on both weapons" },
    { slot = "Enchants", text = "Weapon enchant for Agility/Crit; ring enchants for secondary stats" },
    { slot = "Gems", text = "Agility or Agility/secondary hybrid gems in available sockets" },
  },
  gear = {
    { slot = "Head", text = "Tier set piece — the set bonus usually matters more than a small item-level gap" },
    { slot = "Neck", text = "Favor Haste for faster combo point generation and better Shadow Dance uptime" },
    { slot = "Back", text = "Secondary stats matching Haste and Crit outweigh a pure item-level chase" },
    { slot = "Legs", text = "Another tier slot when possible; otherwise the highest item level piece leaning Haste and Crit" },
    { slot = "Ring", text = "Haste or Crit rings depending on your current stat weights" },
    { slot = "Trinket", text = "One on-use Agility or damage trinket lined up with Shadow Dance or Shadow Blades windows" },
    { slot = "Trinket", text = "A passive stat-stick trinket for consistent damage between burst windows" },
    { slot = "Weapon", text = "Two matched, high item level daggers, since Subtlety's damage scales off both weapons" },
  },
  mplusLoadout = {
    string = "CUQAAAAAAAAAAAAAAAAAAAAAAAgx2MAAAAAwsMGLTMbbjxMDDzMzMzw8AbzYGbbzMzMzMjBjZ2GAAAAGMmFzyADYBsMMhMLYGmZAmxA",
    source = "SimulationCraft default profile (credit, not endorsement of 'best')",
    patch = "12.1",
  },
  -- Live top-players pull (DESIGN.md's v1.4 section), NOT SimC - see this
  -- file's header for the full methodology. The plurality build among the
  -- sample: 4/50 (8%) ran this exact code, since flex-point choices vary - but
  -- the bigger signal is that 46/50 (92%) ran Deathstalker overall. Reported
  -- honestly rather than dressed up as more decisive than it is.
  mplusMetaLoadout = {
    string = "CUQA5HmDzx68KWyrW/8Y781L7Dgx2MAAAAAwsMGLTMbbjxMDjZmZmZGGbzYGbLzMzMzMjBjZ2GAAAAGMmNzyADYBsMMhMLYGmZAmxA",
    source = "Blizzard Battle.net API, US region, 2026-08-30: top 50 current-season Mythic+ Subtlety Rogues by best keystone level, sampled across all 83 US connected realms' leaderboards. This exact build was the plurality pick (4/50, 8%); 46/50 (92%) ran Deathstalker overall.",
    patch = "12.1",
    sampleSize = 50,
  },
  tips = {
    "Keep Shadow Dance on cooldown whenever possible for the strongest burst windows.",
    "Don't waste Shadow Dance charges outside of a real damage window if you can help it.",
    "Black Powder overtakes Eviscerate quickly once a second target is in range.",
    "Vanish can be used offensively to re-enter stealth for another Shadowstrike, not just defensively.",
  },
})
