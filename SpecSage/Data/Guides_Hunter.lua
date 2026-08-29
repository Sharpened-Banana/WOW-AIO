local ADDON, ns = ...

-- SpecSage guide data: Hunter (Beast Mastery 253, Marksmanship 254, Survival 255)
-- Content targets The War Within. This is community-maintained conventional
-- guidance (stat priorities and rotations that match the spec's long-standing
-- design) — not a claim of bleeding-edge sim-perfect optimization.
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
        { spellID = 120360, text = "Barrage or Multi-Shot to cleave Focus spenders across targets" },
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
    { spellID = 193530, text = "Aspect of the Wild — stack with Bestial Wrath for burst" },
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
    "Survival Hunter is a melee spec (uniquely among Hunter specs) that combines direct weapon attacks with pet support and DoT-style bleeds. It plays as an aggressive, mobility-heavy melee spec that still keeps a pet as a secondary damage source, blending Kill Command with Raptor Strike/Mongoose Bite combos.",
    "The core resource is Focus, generated from auto-attacks and abilities like Raptor Strike, and spent on Kill Command, Wildfire Bomb, and Mongoose Bite. The defining mechanic is stacking Mongoose Bite's Mongoose Fury buff through repeated casts, rewarding sustained uptime on a single target during its window.",
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
        { spellID = 259387, text = "Mongoose Bite repeatedly to stack and maintain Mongoose Fury" },
        { spellID = 186270, text = "Raptor Strike as a Focus-efficient filler and builder" },
        { spellID = 190925, text = "Harpoon to close distance and enable extra melee uptime" },
        { text = "Keep bleeds/DoTs active on the target between cooldown usage" },
    }},
    { title = "AoE", steps = {
        { spellID = 259495, text = "Wildfire Bomb as the primary AoE cooldown, hits and DoTs multiple targets" },
        { text = "Butchery to cleave nearby targets with melee swings" },
        { spellID = 34026, text = "Kill Command on cooldown across the pull" },
        { spellID = 186270, text = "Raptor Strike as filler when other cooldowns are down" },
        { text = "Prioritize Butchery over single-target fillers while 2+ targets are in melee range" },
        { text = "Keep Wildfire Bomb's DoT rolling across as many targets as possible" },
    }},
    { title = "Opener Notes", steps = {
        { text = "Open with Wildfire Bomb and Kill Command to establish damage before committing to Mongoose Bite stacking" },
        { text = "Line up Coordinated Assault (or your burst cooldown) with your first full Mongoose Fury stack window" },
    }},
  },
  cooldowns = {
    { spellID = 360966, text = "Coordinated Assault — core offensive cooldown, use on cooldown" },
    { spellID = 259495, text = "Wildfire Bomb — frequent damage cooldown, weave in on cooldown" },
    { spellID = 186265, text = "Aspect of the Turtle — major defensive, absorbs most damage briefly" },
    { spellID = 109304, text = "Exhilaration — self-healing cooldown for sustain checks" },
    { spellID = 5384, text = "Feign Death — drop threat/aggro or avoid certain mechanics" },
  },
  consumables = {
    { slot = "Flask", text = "Flask of Alchemical Chaos (Agility)" },
    { slot = "Food", text = "An Agility-focused feast or food buff" },
    { slot = "Potion", text = "Tempered Potion, used inside Coordinated Assault" },
    { slot = "Weapon", text = "Ironclaw Whetstone or the current-tier weapon oil" },
    { slot = "Enchants", text = "Weapon enchant for Agility/Crit; ring enchants for secondary stats" },
    { slot = "Gems", text = "Agility or Agility/secondary hybrid gems in available sockets" },
  },
  tips = {
    "Keep Mongoose Fury stacked as high as possible before spending your last Mongoose Bite charge window.",
    "Wildfire Bomb has a short cooldown — don't let it sit unused, especially in AoE.",
    "Butchery is worth prioritizing over single-target fillers as soon as a second target is in melee range.",
    "Muzzle is a strong interrupt — use it proactively on scripted casts rather than saving it indefinitely.",
  },
})
