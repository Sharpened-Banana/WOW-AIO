local ADDON, ns = ...

-- SpecSage guide data: Death Knight (Blood 250, Frost 251, Unholy 252)
-- Content targets The War Within. This is community-maintained conventional
-- guidance (stat priorities and rotations that match the spec's long-standing
-- design) — not a claim of bleeding-edge sim-perfect optimization.
-- To edit: change the strings/tables below and reload. To add a spec pack,
-- call ns.GuideStore:RegisterSpec(classToken, specID, guideTable) from any
-- addon that loads after SpecSage; see Data/API.lua for validation rules.

if not ns.GuideStore then return end

ns.GuideStore:RegisterSpec("DEATHKNIGHT", 250, {
  specName = "Blood",
  role = "TANK",
  overview = {
    "Blood Death Knight is a self-healing tank that plays around Death Strike, converting Runic Power and recent damage taken into a large heal, while Bone Shield charges provide flat physical damage reduction. It rewards proactive Death Strike timing over purely reactive healing.",
    "The core resources are Runes and Runic Power — Runes are spent on Death Strike and disease application, and Runic Power builds toward Death Strike's healing component. The defining mechanic is Bone Shield, a stacking absorb-adjacent mitigation buff that must be refreshed via Marrowrend before it runs out of charges, alongside pooling Runic Power for a well-timed Death Strike.",
    "Blood brings excellent self-sustain, strong AoE threat through Death and Decay, and solid group utility (Anti-Magic Zone, grip), making it a reliable tank for both progression raiding and Mythic+ where consistent self-healing reduces external healer load.",
  },
  statPriority = {
    { stat = "stamina", note = "for survivability buffer" },
    { stat = "primary", note = "Strength, passive" },
    { stat = "haste" },
    { stat = "mastery", note = "increases blood shield and death strike healing" },
    { stat = "versatility" },
    { stat = "crit" },
  },
  rotation = {
    { title = "Single Target", steps = {
        { spellID = 195182, text = "Marrowrend to keep Bone Shield charges topped up" },
        { spellID = 49998, text = "Death Strike to spend Runic Power for healing and mitigation" },
        { spellID = 206930, text = "Heart Strike as your primary Rune spender and threat generator" },
        { spellID = 43265, text = "Death and Decay kept active under yourself when relevant" },
        { spellID = 61999, text = "Raise Ally or utility abilities as needed" },
        { text = "Don't cast Death Strike below a meaningful Runic Power threshold unless you need the heal now" },
    }},
    { title = "AoE", steps = {
        { spellID = 43265, text = "Death and Decay as the primary AoE threat and damage tool" },
        { spellID = 195182, text = "Marrowrend to maintain Bone Shield while multiple targets attack you" },
        { spellID = 49998, text = "Death Strike on cooldown for healing during heavy incoming damage" },
        { spellID = 47568, text = "Empower Rune Weapon to refill resources during a big pull" },
        { text = "Keep Death and Decay repositioned to cover as many attackers as possible" },
        { text = "Prioritize Bone Shield uptime over pure damage during large trash pulls" },
    }},
    { title = "Mitigation", steps = {
        { spellID = 195181, text = "Bone Shield — never let this fall to zero charges" },
        { spellID = 49998, text = "Death Strike — time it for both healing and mitigation value" },
        { spellID = 48792, text = "Icebound Fortitude for the heaviest predicted damage spikes" },
        { spellID = 55233, text = "Vampiric Blood to amplify healing and effective health during a burst window" },
        { text = "Pool Runic Power slightly before a known damage spike so Death Strike lands at its strongest" },
    }},
  },
  cooldowns = {
    { spellID = 55233, text = "Vampiric Blood — boosts healing received and max health, use for sustained damage" },
    { spellID = 48792, text = "Icebound Fortitude — strong defensive cooldown for burst damage spikes" },
    { spellID = 47568, text = "Empower Rune Weapon — resource refill, use to enable extra Death Strikes" },
    { spellID = 51052, text = "Anti-Magic Zone — raid-wide magic damage reduction utility" },
    { spellID = 61999, text = "Raise Ally — battle-resurrection utility on a personal cooldown" },
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
    "Keep Bone Shield charges above zero at all times — a lapsed Bone Shield is a big mitigation loss.",
    "Time Death Strike for when you actually need the heal, not purely on cooldown, when Runic Power allows pooling.",
    "Death and Decay is both a damage and threat tool — keep it under the pack during AoE pulls.",
    "Save Icebound Fortitude and Vampiric Blood for known heavy-damage phases rather than reacting after the fact.",
  },
})

ns.GuideStore:RegisterSpec("DEATHKNIGHT", 251, {
  specName = "Frost",
  role = "DAMAGER",
  overview = {
    "Frost Death Knight is a dual-wield or two-handed melee spec built around Obliterate and Frost Strike, spending Runes and Runic Power while chasing Killing Machine procs that guarantee critical strikes on Frost Strike and Obliterate. It plays as a burst-oriented spec with strong cooldown-driven damage windows.",
    "The core resources are Runes, spent on Obliterate and Frost Strike-enabling abilities, and Runic Power, spent on Frost Strike and Empower Rune Weapon-style refills. The defining mechanic is Killing Machine, a proc that guarantees a critical strike on your next Obliterate or Frost Strike — playing around these procs efficiently is central to maximizing damage.",
    "Frost brings strong burst through Pillar of Frost and Breath of Sindragosa-style cooldowns, solid cleave via Frostscythe/Frost Strike splash, and reliable execute-phase damage, making it a strong pick for both progression raiding and burst-heavy Mythic+ content.",
  },
  statPriority = {
    { stat = "primary", note = "Strength, passive" },
    { stat = "crit" },
    { stat = "haste" },
    { stat = "mastery", note = "increases Frost damage" },
    { stat = "versatility" },
  },
  rotation = {
    { title = "Single Target", steps = {
        { spellID = 49020, text = "Obliterate as the primary Rune spender, especially with Killing Machine active" },
        { spellID = 49143, text = "Frost Strike to spend Runic Power, prioritized under Killing Machine" },
        { spellID = 47568, text = "Empower Rune Weapon on cooldown for extra resources" },
        { spellID = 51271, text = "Pillar of Frost on cooldown for a burst damage window" },
        { spellID = 49184, text = "Howling Blast to keep its Frost Fever debuff active" },
        { text = "Don't let Killing Machine procs go unused — spend them before they're overwritten" },
    }},
    { title = "AoE", steps = {
        { spellID = 49184, text = "Howling Blast as the primary AoE opener, spreading Frost Fever" },
        { spellID = 49020, text = "Obliterate still strong single-target priority within the pull" },
        { spellID = 51271, text = "Pillar of Frost on cooldown during add waves" },
        { spellID = 49143, text = "Frost Strike to spend Runic Power across the pull" },
        { spellID = 47568, text = "Empower Rune Weapon to sustain resources through a long pull" },
        { text = "Reapply Frost Fever to new adds as they join the pull" },
    }},
    { title = "Opener Notes", steps = {
        { text = "Apply Frost Fever first, then pool for a Pillar of Frost burst window" },
        { text = "Line up Empower Rune Weapon with your main cooldown for maximum resource availability" },
    }},
  },
  cooldowns = {
    { spellID = 51271, text = "Pillar of Frost — core offensive cooldown, use on cooldown" },
    { spellID = 47568, text = "Empower Rune Weapon — resource cooldown, pair with your burst window" },
    { spellID = 48792, text = "Icebound Fortitude — major defensive cooldown for burst damage spikes" },
    { spellID = 49039, text = "Lichborne — self-healing/CC-immunity utility cooldown" },
    { spellID = 61999, text = "Raise Ally — battle-resurrection utility on a personal cooldown" },
  },
  consumables = {
    { slot = "Flask", text = "Flask of Alchemical Chaos (Strength)" },
    { slot = "Food", text = "A Strength-focused feast or food buff" },
    { slot = "Potion", text = "Tempered Potion, used inside Pillar of Frost" },
    { slot = "Weapon", text = "Ironclaw Whetstone or the current-tier weapon oil" },
    { slot = "Enchants", text = "Weapon enchant for Strength/Crit; ring enchants for secondary stats" },
    { slot = "Gems", text = "Strength or Strength/secondary hybrid gems in available sockets" },
  },
  tips = {
    "Spend Killing Machine procs promptly rather than banking multiple and risking an overwrite.",
    "Keep Frost Fever active on any target you'll be attacking for more than a few seconds.",
    "Line up Empower Rune Weapon and Pillar of Frost together whenever possible.",
    "Howling Blast is a strong AoE opener even on cooldown-limited pulls — don't save it exclusively for big packs.",
  },
})

ns.GuideStore:RegisterSpec("DEATHKNIGHT", 252, {
  specName = "Unholy",
  role = "DAMAGER",
  overview = {
    "Unholy Death Knight is a pet- and disease-focused melee spec built around maintaining Virulent Plague on the target and spending Runes on Festering Strike to build Festering Wounds, which are then burst open with Scourge Strike/Death Coil-fueled cooldowns alongside your permanent ghoul pet.",
    "The core resources are Runes, spent on Festering Strike and Death and Decay, and Runic Power, spent on Death Coil. The defining mechanic is Festering Wounds — stacking them on the target with Festering Strike, then bursting them open with Scourge Strike or Clawing Shadows for damage and Runic Power, timed around Army of the Dead/Apocalypse-style cooldowns for burst windows.",
    "Unholy brings strong burst damage through cooldown windows, excellent sustained AoE via diseases and Death and Decay, and useful pet-based utility, making it a strong pick for fights with add phases or sustained multi-target damage requirements.",
  },
  statPriority = {
    { stat = "primary", note = "Strength, passive" },
    { stat = "haste" },
    { stat = "mastery", note = "increases pet and disease damage" },
    { stat = "crit" },
    { stat = "versatility" },
  },
  rotation = {
    { title = "Single Target", steps = {
        { spellID = 191587, text = "Virulent Plague kept active on the target" },
        { spellID = 85948, text = "Festering Strike to build Festering Wounds" },
        { spellID = 55090, text = "Scourge Strike to burst open Festering Wounds" },
        { spellID = 47541, text = "Death Coil to spend Runic Power, empowered further while your pet is out" },
        { spellID = 42650, text = "Army of the Dead / Apocalypse-style cooldown on a scheduled burst window" },
        { text = "Don't let Festering Wounds overcap — burst them open before they stack too high" },
    }},
    { title = "AoE", steps = {
        { spellID = 43265, text = "Death and Decay as a core AoE damage and Rune-efficiency tool" },
        { spellID = 85948, text = "Festering Strike to seed Festering Wounds across the pull" },
        { spellID = 55090, text = "Scourge Strike / Clawing Shadows to burst wounds across multiple targets" },
        { spellID = 191587, text = "Virulent Plague spread to as many targets as possible" },
        { spellID = 63560, text = "Dark Transformation to empower your pet during add waves" },
        { text = "Prioritize keeping diseases up across the whole pull over single-target spam" },
    }},
    { title = "Opener Notes", steps = {
        { text = "Apply Virulent Plague immediately, then build Festering Wounds before your first burst window" },
        { text = "Time Army of the Dead / Apocalypse-style cooldowns with trinkets for maximum pet-and-wound burst" },
    }},
  },
  cooldowns = {
    { spellID = 63560, text = "Dark Transformation — empowers your pet, use on cooldown" },
    { spellID = 42650, text = "Army of the Dead — summons additional ghouls, align with burst windows" },
    { spellID = 48792, text = "Icebound Fortitude — major defensive cooldown for burst damage spikes" },
    { spellID = 49039, text = "Lichborne — self-healing/CC-immunity utility cooldown" },
    { spellID = 61999, text = "Raise Ally — battle-resurrection utility on a personal cooldown" },
  },
  consumables = {
    { slot = "Flask", text = "Flask of Alchemical Chaos (Strength)" },
    { slot = "Food", text = "A Strength-focused feast or food buff" },
    { slot = "Potion", text = "Tempered Potion, used inside your main burst window" },
    { slot = "Weapon", text = "Ironclaw Whetstone or the current-tier weapon oil" },
    { slot = "Enchants", text = "Weapon enchant for Strength/Crit; ring enchants for secondary stats" },
    { slot = "Gems", text = "Strength or Strength/secondary hybrid gems in available sockets" },
  },
  tips = {
    "Never let Virulent Plague fall off a target you'll keep attacking.",
    "Don't overcap Festering Wounds — burst them before you lose value from excess stacks.",
    "Dark Transformation is worth using on cooldown rather than saving for a 'perfect' moment in most fights.",
    "Line up your big summon-based cooldown with a known burst or add phase for maximum value.",
  },
})
