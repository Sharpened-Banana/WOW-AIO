local ADDON, ns = ...

-- SpecSage guide data: Rogue (Assassination 259, Outlaw 260, Subtlety 261)
-- Content targets The War Within. This is community-maintained conventional
-- guidance (stat priorities and rotations that match the spec's long-standing
-- design) — not a claim of bleeding-edge sim-perfect optimization.
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
        { spellID = 1830, text = "Fan of Knives as the primary combo point builder against 3+ targets" },
        { text = "Deadly Poison spread to all engaged targets" },
        { spellID = 1943, text = "Rupture on priority targets once poisons are spread" },
        { spellID = 360194, text = "Deathmark on cooldown for burst during add waves" },
        { spellID = 32645, text = "Envenom to spend combo points when Rupture upkeep isn't needed" },
        { text = "Prioritize spreading DoTs over single-target finishers early in an AoE pull" },
    }},
    { title = "Opener Notes", steps = {
        { text = "Open from Stealth with Garrote for its bonus damage, then build toward Rupture" },
        { text = "Line up Deathmark with your first full combo point Envenom for maximum burst" },
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
        { spellID = 315508, text = "Roll the Bones to apply buffs, re-roll when few are active" },
        { spellID = 2098, text = "Dispatch to spend combo points at low target health" },
        { spellID = 315341, text = "Between the Eyes to spend combo points and apply its debuff" },
        { spellID = 13750, text = "Adrenaline Rush on cooldown for a burst window" },
        { text = "Keep Roll the Bones buffs active — don't let the roll fall off entirely" },
    }},
    { title = "AoE", steps = {
        { spellID = 13877, text = "Blade Flurry to cleave your attacks across nearby targets" },
        { spellID = 193315, text = "Sinister Strike still the primary builder while cleaving" },
        { spellID = 51690, text = "Killing Spree or equivalent burst tool during add waves" },
        { spellID = 315508, text = "Roll the Bones for its buffs, especially cleave-relevant ones" },
        { spellID = 2098, text = "Dispatch/finishers to spend combo points across the pull" },
        { text = "Turn on Blade Flurry as soon as 2+ targets are engaged" },
    }},
    { title = "Opener Notes", steps = {
        { text = "Open with Roll the Bones to establish buffs before committing to your main cooldowns" },
        { text = "Line up Adrenaline Rush with a strong Roll the Bones result for maximum burst" },
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
    "Subtlety Rogue is a Shadow-infused melee spec built around Shadow Dance windows and Symbols of Death, spending combo points on Eviscerate while weaving in Shadowstrike from stealth. It plays as a burst-window spec, dealing much of its damage inside timed cooldown windows rather than a flat sustained rotation.",
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
        { spellID = 212283, text = "Symbols of Death on cooldown to buff damage and enable Shadow Dance uptime" },
        { spellID = 185313, text = "Shadow Dance to access Shadowstrike outside of stealth" },
        { spellID = 185438, text = "Shadowstrike as your primary combo point builder during Dance windows" },
        { spellID = 53, text = "Backstab to build combo points outside of Dance windows" },
        { spellID = 196819, text = "Eviscerate to spend combo points" },
        { text = "Keep Symbols of Death and Shadow Dance windows synced for maximum burst" },
    }},
    { title = "AoE", steps = {
        { spellID = 199603, text = "Black Powder as the primary AoE combo point spender" },
        { spellID = 212283, text = "Symbols of Death on cooldown to buff AoE damage" },
        { spellID = 185313, text = "Shadow Dance for extra Shadowstrike/Black Powder access" },
        { spellID = 185438, text = "Shadowstrike still a strong builder, hits the primary target" },
        { spellID = 53, text = "Backstab as filler builder when Dance is down" },
        { text = "Prioritize Black Powder over Eviscerate once 2+ targets are engaged" },
    }},
    { title = "Opener Notes", steps = {
        { text = "Open from Stealth with Shadowstrike, then use Symbols of Death to chain into Shadow Dance" },
        { text = "Save a second Shadow Dance charge if possible to extend your opening burst window" },
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
  tips = {
    "Sync Symbols of Death with Shadow Dance whenever possible for the strongest burst windows.",
    "Don't waste Shadow Dance charges outside of a real damage window if you can help it.",
    "Black Powder overtakes Eviscerate quickly once a second target is in range.",
    "Vanish can be used offensively to re-enter stealth for another Shadowstrike, not just defensively.",
  },
})
