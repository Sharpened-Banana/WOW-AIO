local ADDON, ns = ...

-- SpecSage guide data: Paladin (Holy 65, Protection 66, Retribution 70)
-- Content targets The War Within. This is community-maintained conventional
-- guidance (stat priorities and rotations that match the spec's long-standing
-- design) — not a claim of bleeding-edge sim-perfect optimization.
-- To edit: change the strings/tables below and reload. To add a spec pack,
-- call ns.GuideStore:RegisterSpec(classToken, specID, guideTable) from any
-- addon that loads after SpecSage; see Data/API.lua for validation rules.

if not ns.GuideStore then return end

ns.GuideStore:RegisterSpec("PALADIN", 65, {
  specName = "Holy",
  role = "HEALER",
  overview = {
    "Holy Paladin is a hybrid healer that blends direct single-target healing (Holy Shock, Holy Light) with strong smart-heal utility from Beacon of Light/Faith spreading a portion of your healing to bonded targets. It rewards good beacon placement and Holy Power management as much as raw cast timing.",
    "The core resource is Holy Power, generated from Holy Shock and Crusader Strike and spent on Word of Glory / Light of Dawn, alongside mana as the overarching limiting resource across a fight. The defining mechanic is the Beacon system — healing the beacon target's bonded ally also heals them, so positioning beacons on tanks or high-damage targets multiplies your throughput.",
    "Holy Paladin brings strong raid cooldowns (Avenging Wrath, Aura Mastery), solid AoE healing through Light of Dawn and Holy Prism-style tools, and reliable tank healing via beacon uptime — a strong pick whenever consistent, cooldown-supported healing is valued over pure burst throughput.",
  },
  statPriority = {
    { stat = "primary", note = "Intellect, passive" },
    { stat = "crit" },
    { stat = "haste", note = "smooths cast times and Holy Power generation" },
    { stat = "mastery" },
    { stat = "versatility" },
  },
  rotation = {
    { title = "Priorities", steps = {
        { spellID = 20473, text = "Holy Shock on cooldown — efficient direct heal and Holy Power generator" },
        { spellID = 53563, text = "Beacon of Light kept active on the tank or primary damage-taker" },
        { spellID = 85222, text = "Light of Dawn to spend Holy Power on grouped-up allies" },
        { spellID = 82326, text = "Holy Light as a strong single-target heal when mana allows" },
        { spellID = 19750, text = "Flash of Light for fast reactive healing on a spiking target" },
        { text = "Weave Judgment/Crusader Strike when healing demand is low to keep Holy Power flowing" },
    }},
    { title = "Cooldown Usage", steps = {
        { spellID = 31884, text = "Avenging Wrath during heavy incoming damage windows" },
        { spellID = 105809, text = "Holy Avenger to accelerate Holy Power spending during burst phases" },
        { spellID = 31821, text = "Aura Mastery to blanket the raid with your active Aura's benefit during a damage spike" },
        { text = "Pre-position beacons before a pull so tank healing is covered from the first hit" },
        { text = "Stack cooldowns together for predictable heavy-damage phases rather than spreading them thin" },
    }},
  },
  cooldowns = {
    { spellID = 31884, text = "Avenging Wrath — general healing/damage cooldown, use on cooldown during progression" },
    { spellID = 31821, text = "Aura Mastery — raid-wide cooldown, save for known heavy damage windows" },
    { spellID = 105809, text = "Holy Avenger — burst Holy Power generation, pair with heavy Light of Dawn/Word of Glory usage" },
    { spellID = 1022, text = "Blessing of Protection — physical damage immunity for a single ally in danger" },
    { spellID = 6940, text = "Blessing of Sacrifice — redirect damage from an ally to yourself" },
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
    "Keep Beacon of Light on the tank at all times unless you're intentionally repositioning it.",
    "Don't let Holy Power sit capped — spend it on Light of Dawn or Word of Glory before overflow.",
    "Save your strongest cooldowns for known heavy-damage phases rather than reacting after the raid is already low.",
    "Holy Shock's cooldown is short — using it on cooldown even for small top-ups is rarely wrong.",
  },
})

ns.GuideStore:RegisterSpec("PALADIN", 66, {
  specName = "Protection",
  role = "TANK",
  overview = {
    "Protection Paladin is a shield tank that plays around high, consistent block chance and Word of Glory self-healing fueled by Holy Power. Its rotation blends Judgment/Hammer of the Righteous builders with Shield of the Righteous spenders that both mitigate damage and generate threat.",
    "The core resource is Holy Power, generated from Judgment, Hammer of the Righteous, and Blessed Hammer-style attacks, and spent primarily on Shield of the Righteous, which is the spec's core mitigation cooldown as much as it is a rotational ability. Consecration provides a persistent AoE threat and damage floor under your feet.",
    "Protection Paladin brings smooth, consistent physical mitigation, strong self-healing from Holy Power spenders, and solid AoE threat, making it a reliable tank choice for both sustained raid tanking and Mythic+ pulls where consistent uptime on Shield of the Righteous matters.",
  },
  statPriority = {
    { stat = "stamina", note = "for survivability buffer" },
    { stat = "primary", note = "Strength, passive" },
    { stat = "haste", note = "faster Holy Power generation and Shield of the Righteous uptime" },
    { stat = "mastery" },
    { stat = "versatility" },
    { stat = "crit" },
  },
  rotation = {
    { title = "Single Target", steps = {
        { spellID = 53600, text = "Shield of the Righteous to keep its mitigation buff active — top priority" },
        { spellID = 20271, text = "Judgment on cooldown for Holy Power generation and debuff" },
        { spellID = 53595, text = "Hammer of the Righteous as a builder and to refresh Consecration overlap" },
        { spellID = 26573, text = "Consecration kept active under yourself" },
        { spellID = 85673, text = "Word of Glory when healing is needed and Holy Power is spare" },
        { text = "Fill with basic attacks as builders come off cooldown" },
    }},
    { title = "AoE", steps = {
        { spellID = 53595, text = "Hammer of the Righteous as the primary AoE builder and threat tool" },
        { spellID = 26573, text = "Consecration kept active for passive AoE damage and threat" },
        { spellID = 53600, text = "Shield of the Righteous still prioritized for mitigation uptime" },
        { spellID = 20271, text = "Judgment on cooldown across multiple targets when available" },
        { spellID = 20066, text = "Repentance or crowd control tools to manage dangerous adds" },
        { text = "Keep rotating builders into Shield of the Righteous rather than letting the buff lapse" },
    }},
    { title = "Mitigation", steps = {
        { spellID = 53600, text = "Shield of the Righteous — never let this buff fall off during a pull" },
        { spellID = 86659, text = "Guardian of Ancient Kings for a major defensive cooldown window" },
        { spellID = 31850, text = "Ardent Defender for the heaviest incoming damage spikes" },
        { spellID = 1022, text = "Blessing of Protection on yourself or an ally for a physical-damage emergency" },
        { text = "Bank Holy Power slightly before a known burst window so Shield of the Righteous never lapses" },
    }},
  },
  cooldowns = {
    { spellID = 86659, text = "Guardian of Ancient Kings — strong all-purpose defensive cooldown" },
    { spellID = 31850, text = "Ardent Defender — save for the most dangerous predicted damage spike" },
    { spellID = 1022, text = "Blessing of Protection — physical immunity, use on cooldown for mechanics" },
    { spellID = 6940, text = "Blessing of Sacrifice — soak burst damage meant for an ally" },
    { spellID = 31884, text = "Avenging Wrath — damage and self-healing cooldown, weave in during sustained damage" },
  },
  consumables = {
    { slot = "Flask", text = "Flask of Alchemical Chaos (Stamina)" },
    { slot = "Food", text = "A Stamina-focused feast or food buff" },
    { slot = "Potion", text = "A Stamina or defensive potion for dangerous pulls/phases" },
    { slot = "Weapon", text = "Shadowcore Oil or the current-tier weapon oil" },
    { slot = "Enchants", text = "Weapon enchant for Stamina/mitigation; ring enchants for secondary stats" },
    { slot = "Gems", text = "Stamina or Stamina/secondary hybrid gems in available sockets" },
  },
  tips = {
    "Never let Shield of the Righteous's mitigation buff lapse — it's the spec's core defensive tool.",
    "Keep Consecration active under yourself for free AoE threat and damage.",
    "Bank a small Holy Power buffer before predictable burst damage so you can reapply Shield of the Righteous instantly.",
    "Use Blessing of Protection proactively on known mechanics rather than only as a panic button.",
  },
})

ns.GuideStore:RegisterSpec("PALADIN", 70, {
  specName = "Retribution",
  role = "DAMAGER",
  overview = {
    "Retribution Paladin is a two-handed melee spec that plays around building Holy Power with Blade of Justice and Crusader Strike, then spending it on Templar's Verdict/Final Verdict for burst windows amplified by Wake of Ashes and Crusade/Avenging Wrath-style cooldowns.",
    "The core resource is Holy Power, generated from Blade of Justice, Crusader Strike, and Judgment, and spent on Templar's Verdict and Divine Storm. The defining mechanic is stacking Holy Power generation and burst cooldowns together so several high-value spenders land inside the same damage-amplified window.",
    "Retribution brings strong burst windows, useful raid utility (Blessing of Protection/Sacrifice, Lay on Hands), and solid cleave through Divine Storm, making it a good pick when you want a melee spec with reliable defensive and offensive utility on top of its damage.",
  },
  statPriority = {
    { stat = "primary", note = "Strength, passive" },
    { stat = "haste" },
    { stat = "crit" },
    { stat = "mastery" },
    { stat = "versatility" },
  },
  rotation = {
    { title = "Single Target", steps = {
        { spellID = 85256, text = "Templar's Verdict / Final Verdict to spend Holy Power — top priority" },
        { spellID = 184575, text = "Blade of Justice on cooldown for Holy Power generation" },
        { spellID = 20271, text = "Judgment on cooldown for generation and its debuff" },
        { spellID = 35395, text = "Crusader Strike as a filler builder" },
        { spellID = 231895, text = "Wake of Ashes to refill Holy Power and open burst windows" },
        { text = "Avoid overcapping Holy Power — spend before it caps" },
    }},
    { title = "AoE", steps = {
        { spellID = 53385, text = "Divine Storm as the primary AoE Holy Power spender" },
        { spellID = 231895, text = "Wake of Ashes to generate Holy Power and hit multiple targets" },
        { spellID = 184575, text = "Blade of Justice on cooldown across the pull" },
        { spellID = 20271, text = "Judgment on cooldown for generation" },
        { spellID = 35395, text = "Crusader Strike as filler when builders are down" },
        { text = "Prioritize Divine Storm over Templar's Verdict while 2+ targets are engaged" },
    }},
    { title = "Opener Notes", steps = {
        { text = "Pre-pot and open with Wake of Ashes to establish Holy Power, then chain Holy Power spenders" },
        { text = "Line up Avenging Wrath / Crusade-style cooldowns with your first big burst window" },
    }},
  },
  cooldowns = {
    { spellID = 31884, text = "Avenging Wrath — core offensive cooldown, use on cooldown" },
    { spellID = 231895, text = "Wake of Ashes — Holy Power reset and burst tool, weave into cooldown windows" },
    { text = "A talent-granted burst cooldown (varies by build) — use alongside your main cooldown window" },
    { spellID = 642, text = "Divine Shield — emergency defensive, breaks most damage" },
    { spellID = 1022, text = "Blessing of Protection — utility defensive cooldown for yourself or an ally" },
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
    "Don't let Holy Power sit at cap — spend it before you overflow and waste generation.",
    "Save Wake of Ashes to line up with your other offensive cooldowns when possible.",
    "Divine Storm outperforms Templar's Verdict once two or more targets are in melee range.",
    "Keep Blessing of Protection and Lay on Hands available as raid utility, not just self-preservation.",
  },
})
