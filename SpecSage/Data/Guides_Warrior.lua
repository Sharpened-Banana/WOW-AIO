local ADDON, ns = ...

-- SpecSage guide data: Warrior (Arms 71, Fury 72, Protection 73)
-- Content targets The War Within. This is community-maintained conventional
-- guidance (stat priorities and rotations that match the spec's long-standing
-- design) — not a claim of bleeding-edge sim-perfect optimization.
-- To edit: change the strings/tables below and reload. To add a spec pack,
-- call ns.GuideStore:RegisterSpec(classToken, specID, guideTable) from any
-- addon that loads after SpecSage; see Data/API.lua for validation rules.

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
    { title = "Single Target", steps = {
        { spellID = 167105, text = "Colossus Smash — open burst windows and align cooldowns with it" },
        { spellID = 12294, text = "Mortal Strike on cooldown — top rage priority" },
        { spellID = 772, text = "Rend — keep the bleed active on the target" },
        { spellID = 7384, text = "Overpower when charges are available" },
        { spellID = 845, text = "Cleave / Slam to spend excess rage between cooldowns" },
        { spellID = 163201, text = "Execute once the target drops below execute-range health" },
    }},
    { title = "AoE", steps = {
        { spellID = 227847, text = "Bladestorm to open on 3+ targets" },
        { spellID = 167105, text = "Colossus Smash / Warbreaker before committing cooldowns" },
        { spellID = 845, text = "Cleave as your rage dump against multiple targets" },
        { spellID = 772, text = "Rend on priority targets for extra bleed damage" },
        { spellID = 7384, text = "Overpower to keep charges from capping" },
        { text = "Fill remaining rage with Mortal Strike on the highest-priority target" },
    }},
    { title = "Opener Notes", steps = {
        { text = "Pool rage before pulling, then open with Colossus Smash into Mortal Strike to front-load burst" },
        { text = "Line up trinkets and offensive cooldowns with the first Colossus Smash window" },
    }},
  },
  cooldowns = {
    { spellID = 107574, text = "Avatar — pair with Colossus Smash for maximum burst" },
    { spellID = 167105, text = "Colossus Smash — core damage-amp window, use on cooldown" },
    { spellID = 227847, text = "Bladestorm — strong AoE/cleave cooldown, also usable defensively" },
    { spellID = 118038, text = "Die by the Sword — major defensive, use under heavy melee pressure" },
    { spellID = 97462, text = "Rallying Cry — raid-wide defensive cooldown for group survival checks" },
  },
  consumables = {
    { slot = "Flask", text = "Flask of Alchemical Chaos (Strength)" },
    { slot = "Food", text = "A Strength-focused feast or food buff" },
    { slot = "Potion", text = "Tempered Potion, used inside your Colossus Smash burst window" },
    { slot = "Weapon", text = "Ironclaw Whetstone or the current-tier weapon oil" },
    { slot = "Enchants", text = "Weapon enchant for Strength/Crit; ring enchants for secondary stats" },
    { slot = "Gems", text = "Strength or Strength/secondary hybrid gems in available sockets" },
  },
  tips = {
    "Never let Rend fall off a target you'll be hitting for more than a few seconds.",
    "Save Overpower charges to spend rather than letting them cap and go to waste.",
    "Line up Colossus Smash, trinkets, and Avatar together whenever possible for maximum burst windows.",
    "Watch your rage bar during downtime — starving Mortal Strike of rage is a common DPS loss.",
  },
})

ns.GuideStore:RegisterSpec("WARRIOR", 72, {
  specName = "Fury",
  role = "DAMAGER",
  overview = {
    "Fury Warrior is a dual-wield melee spec that plays as a fast, rage-flooded brawler. Its core loop is built around Bloodthirst for rage generation and healing, and Raging Blow for spending the Enrage charges it grants, all while Whirlwind and Rampage fill in the gaps of a high-tempo priority rotation.",
    "The core resource is Rage, generated heavily from Bloodthirst and auto-attacks, and the defining mechanic is the Enrage state — several abilities trigger or require it, so keeping yourself enraged as close to permanently as possible is the throughput backbone of the spec.",
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
    { title = "Single Target", steps = {
        { spellID = 23881, text = "Bloodthirst on cooldown — core rage and Enrage generator" },
        { spellID = 184367, text = "Rampage when you have enough rage banked, to refresh Enrage" },
        { spellID = 85288, text = "Raging Blow to spend Enrage charges before they're wasted" },
        { spellID = 1680, text = "Whirlwind to keep its passive damage buff active" },
        { text = "Fill with Bloodthirst / Raging Blow priority as resources allow" },
    }},
    { title = "AoE", steps = {
        { spellID = 1680, text = "Whirlwind as the primary AoE builder/spender against 3+ targets" },
        { spellID = 23881, text = "Bloodthirst still on cooldown for rage and healing" },
        { spellID = 184367, text = "Rampage to maintain Enrage uptime while cleaving" },
        { spellID = 85288, text = "Raging Blow to dump Enrage charges" },
        { spellID = 46968, text = "Shockwave to stun and cluster adds when available" },
        { text = "Prioritize cleave abilities over single-target fillers while 3+ targets are up" },
    }},
    { title = "Opener Notes", steps = {
        { text = "Open with Bloodthirst to establish Enrage immediately, then weave Rampage as rage allows" },
        { text = "Save Recklessness for a moment you can chain several Enrage-consuming abilities back to back" },
    }},
  },
  cooldowns = {
    { spellID = 1719, text = "Recklessness — pop for a burst window, ideally with trinkets" },
    { spellID = 46924, text = "Bladestorm — strong cleave/AoE cooldown, also a brief defensive tool" },
    { spellID = 184364, text = "Enraged Regeneration — self-healing cooldown for sustain checks" },
    { spellID = 23920, text = "Spell Reflection — reflects the next incoming spell, use against dangerous casts" },
    { spellID = 97462, text = "Rallying Cry — raid-wide defensive utility cooldown" },
  },
  consumables = {
    { slot = "Flask", text = "Flask of Alchemical Chaos (Strength)" },
    { slot = "Food", text = "A Strength-focused feast or food buff" },
    { slot = "Potion", text = "Tempered Potion, used with Recklessness for burst" },
    { slot = "Weapon", text = "Ironclaw Whetstone or the current-tier weapon oil on both weapons" },
    { slot = "Enchants", text = "Weapon enchant for Strength/Crit; ring enchants for secondary stats" },
    { slot = "Gems", text = "Strength or Strength/secondary hybrid gems in available sockets" },
  },
  tips = {
    "Try to stay Enraged as close to 100% of the time as possible — it underpins most of Fury's damage.",
    "Don't let Raging Blow charges cap; spend them before they overflow.",
    "Whirlwind's passive buff is worth maintaining even on single target if it's about to fall off.",
    "Save Recklessness for windows where you can string several abilities together rather than opening cold.",
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
    { title = "Single Target", steps = {
        { spellID = 23922, text = "Shield Slam on cooldown — top rage priority and strong threat" },
        { spellID = 6343, text = "Thunder Clap to keep its debuff active on the target" },
        { spellID = 6572, text = "Revenge when free or off cooldown for rage-efficient damage" },
        { spellID = 190456, text = "Ignore Pain to smooth incoming damage, spending excess rage" },
        { spellID = 1160, text = "Demoralizing Shout for extra mitigation as needed" },
        { text = "Fill with basic attacks between cooldowns" },
    }},
    { title = "AoE", steps = {
        { spellID = 6343, text = "Thunder Clap as the primary AoE threat generator" },
        { spellID = 6572, text = "Revenge cleaves nearby targets — use liberally when free" },
        { spellID = 23922, text = "Shield Slam still on cooldown for single-target priority damage" },
        { spellID = 46968, text = "Shockwave to stun and control add clusters" },
        { spellID = 190456, text = "Ignore Pain to absorb burst damage from multiple attackers" },
        { text = "Rotate cooldowns proactively when pulling large packs" },
    }},
    { title = "Mitigation", steps = {
        { spellID = 2565, text = "Shield Block before predictable physical damage windows" },
        { spellID = 190456, text = "Ignore Pain to convert spare rage into an absorb shield" },
        { spellID = 12975, text = "Last Stand for a big health buffer during dangerous phases" },
        { spellID = 871, text = "Shield Wall as the strongest cooldown for the heaviest damage spikes" },
        { text = "Alternate Shield Block and Ignore Pain uptime so rage isn't wasted overcapping either" },
    }},
  },
  cooldowns = {
    { spellID = 871, text = "Shield Wall — biggest defensive cooldown, save for the most dangerous hits" },
    { spellID = 12975, text = "Last Stand — extra effective health, pair with predictable burst damage" },
    { spellID = 2565, text = "Shield Block — core physical mitigation, keep uptime high" },
    { spellID = 1160, text = "Demoralizing Shout — raid-wide damage reduction utility" },
    { spellID = 97462, text = "Rallying Cry — group-wide defensive cooldown for raid damage checks" },
  },
  consumables = {
    { slot = "Flask", text = "Flask of Alchemical Chaos (Stamina)" },
    { slot = "Food", text = "A Stamina-focused feast or food buff" },
    { slot = "Potion", text = "A Stamina or defensive potion for dangerous pulls/phases" },
    { slot = "Weapon", text = "Ironclaw Whetstone or the current-tier weapon oil" },
    { slot = "Enchants", text = "Weapon enchant for Stamina/mitigation; ring enchants for secondary stats" },
    { slot = "Gems", text = "Stamina or Stamina/secondary hybrid gems in available sockets" },
  },
  tips = {
    "Keep Shield Block active before big physical hits rather than reacting after the fact.",
    "Don't dump all your rage into Ignore Pain at once — spread it to smooth damage over time.",
    "Thunder Clap's debuff is worth refreshing even on single target for the extra mitigation.",
    "Save your strongest defensive cooldown for known burst phases rather than reacting late.",
  },
})
