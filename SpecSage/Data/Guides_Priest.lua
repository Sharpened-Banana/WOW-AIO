local ADDON, ns = ...

-- SpecSage guide data: Priest (Discipline 256, Holy 257, Shadow 258)
-- Content targets The War Within. This is community-maintained conventional
-- guidance (stat priorities and rotations that match the spec's long-standing
-- design) — not a claim of bleeding-edge sim-perfect optimization.
-- To edit: change the strings/tables below and reload. To add a spec pack,
-- call ns.GuideStore:RegisterSpec(classToken, specID, guideTable) from any
-- addon that loads after SpecSage; see Data/API.lua for validation rules.

if not ns.GuideStore then return end

ns.GuideStore:RegisterSpec("PRIEST", 256, {
  specName = "Discipline",
  role = "HEALER",
  overview = {
    "Discipline Priest is a hybrid healer that converts damage into healing through Atonement — a buff applied to allies that turns your damage spells into heals on them. It plays less like a traditional reactive healer and more like a proactive damage-dealer whose output is redirected into the raid's health bars.",
    "The core resource is Mana, spent on both direct heals and the damage spells that trigger Atonement healing, most notably Penance and Smite. The defining mechanic is Atonement uptime — keeping the buff active on as many allies as possible before damage happens, so your damage output translates directly into pre-emptive healing.",
    "Discipline brings strong damage-mitigation-as-healing through Power Word: Shield and Pain Suppression, solid raid cooldowns, and a unique playstyle that rewards good raid-damage prediction, making it a strong pick for progression content with heavy, predictable damage patterns.",
  },
  statPriority = {
    { stat = "primary", note = "Intellect, passive" },
    { stat = "crit" },
    { stat = "haste" },
    { stat = "mastery", note = "increases Atonement healing" },
    { stat = "versatility" },
  },
  rotation = {
    { title = "Priorities", steps = {
        { spellID = 194509, text = "Power Word: Radiance to spread Atonement to the group before damage lands" },
        { spellID = 47540, text = "Penance as a strong Atonement trigger and direct heal/damage" },
        { spellID = 585, text = "Smite to maintain Atonement healing with efficient mana use" },
        { spellID = 17, text = "Power Word: Shield on the target about to take a hit" },
        { spellID = 214621, text = "Schism or a similar damage cooldown to spike Atonement healing" },
        { text = "Keep Atonement active on as many raid members as possible before damage phases" },
    }},
    { title = "Cooldown Usage", steps = {
        { spellID = 33206, text = "Pain Suppression on the tank or target about to take a lethal-range hit" },
        { spellID = 62618, text = "Power Word: Barrier for a raid-wide damage reduction and healing zone" },
        { spellID = 47788, text = "Guardian Spirit as an emergency save on a critical target" },
        { text = "Pre-shield the raid and refresh Atonement right before a known burst damage phase" },
        { text = "Save your strongest cooldown for the highest predicted damage spike rather than reacting late" },
    }},
  },
  cooldowns = {
    { spellID = 62618, text = "Power Word: Barrier — raid-wide cooldown, use for known heavy damage windows" },
    { spellID = 33206, text = "Pain Suppression — strong single-target defensive/healing cooldown" },
    { spellID = 47788, text = "Guardian Spirit — emergency save, prevents a lethal hit" },
    { spellID = 10060, text = "Power Infusion — offensive/support cooldown, use on yourself or a strong DPS ally" },
    { spellID = 47585, text = "Dispersion — personal defensive/mana cooldown for emergencies" },
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
    "Keep Atonement spread across the raid before damage happens, not after.",
    "Power Word: Shield is both mitigation and an Atonement application tool — use it proactively.",
    "Save Power Word: Barrier and Pain Suppression for the fight's known heaviest damage windows.",
    "Smite is mana-efficient Atonement healing — don't neglect it just because it looks like a 'DPS' spell.",
  },
})

ns.GuideStore:RegisterSpec("PRIEST", 257, {
  specName = "Holy",
  role = "HEALER",
  overview = {
    "Holy Priest is a versatile healer that blends strong AoE healing tools (Circle of Healing, Prayer of Healing, Holy Word: Sanctify) with solid single-target throughput from Flash Heal and Heal, all built around the Holy Word cooldown-reduction system.",
    "The core resource is Mana, spent across a wide toolkit of direct and AoE heals. The defining mechanic is the Holy Word system — casting Serenity/Sanctify/Chastise reduces the cooldown of your other Holy Words based on healing/damage done, rewarding a rotation that keeps weaving these together rather than spamming a single spell.",
    "Holy Priest brings excellent raid-wide AoE healing, strong cooldowns (Apotheosis, Divine Hymn), and useful utility (Mass Dispel, Leap of Faith), making it a strong pick for fights with heavy raid-wide damage patterns and a need for flexible throughput.",
  },
  statPriority = {
    { stat = "primary", note = "Intellect, passive" },
    { stat = "crit" },
    { stat = "haste" },
    { stat = "mastery", note = "boosts Echo of Light-style residual healing" },
    { stat = "versatility" },
  },
  rotation = {
    { title = "Priorities", steps = {
        { spellID = 2050, text = "Holy Word: Serenity on cooldown for strong single-target healing" },
        { spellID = 34861, text = "Holy Word: Sanctify on cooldown for AoE healing coverage" },
        { spellID = 596, text = "Prayer of Healing for grouped-up raid healing" },
        { spellID = 2061, text = "Flash Heal for fast reactive single-target healing" },
        { spellID = 139, text = "Renew to keep a low-cost HoT rolling on the tank or a spiking target" },
        { text = "Weave damage spells (Smite/Holy Fire) when healing demand is low to reduce Holy Word cooldowns" },
    }},
    { title = "Cooldown Usage", steps = {
        { spellID = 64843, text = "Divine Hymn during a sustained heavy raid-damage phase" },
        { spellID = 200183, text = "Apotheosis to empower your next Holy Word casts, use with a burst window" },
        { spellID = 47788, text = "Guardian Spirit as an emergency save on a critical target" },
        { text = "Pre-cast Renew or shields before a known damage spike where possible" },
        { text = "Stack Apotheosis with Holy Word: Serenity/Sanctify for the strongest healing windows" },
    }},
  },
  cooldowns = {
    { spellID = 64843, text = "Divine Hymn — sustained raid-wide healing cooldown" },
    { spellID = 47788, text = "Guardian Spirit — emergency save, prevents a lethal hit" },
    { spellID = 200183, text = "Apotheosis — empowers Holy Word casts, use inside a burst window" },
    { spellID = 33076, text = "Prayer of Mending — bounces between allies, refresh it before it runs out of jumps" },
    { spellID = 73325, text = "Leap of Faith — utility cooldown to pull an ally out of danger" },
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
    "Weave in a damage spell when nobody needs healing — it reduces your Holy Word cooldowns.",
    "Use Holy Word: Sanctify and Serenity on cooldown rather than saving them, since usage reduces their own cooldowns.",
    "Save Divine Hymn for sustained damage phases rather than single burst spikes.",
    "Renew is cheap — keep it rolling on the tank between bigger heals.",
  },
})

ns.GuideStore:RegisterSpec("PRIEST", 258, {
  specName = "Shadow",
  role = "DAMAGER",
  overview = {
    "Shadow Priest is a DoT-focused caster spec built around maintaining Shadow Word: Pain and Vampiric Touch on the target while spending Insanity on Mind Blast and Void Eruption/Void Bolt-style casts. It plays as a sustained-pressure spec with an escape-into-Voidform rhythm that rewards good DoT and Insanity management.",
    "The core resource is Insanity, generated from Mind Blast, Mind Flay/Mind Spike, and DoT ticks, and spent on Void Bolt and Void Eruption-related abilities. The defining mechanic is DoT uptime combined with the Insanity-fueled Voidform-style burst window, where damage output is meaningfully higher and must be timed with cooldowns and add windows.",
    "Shadow Priest brings strong DoT-based cleave and AoE through Shadow Crash and Mind Sear, useful raid utility (Mass Dispel, Fade), and solid execute-independent scaling, making it a good pick for fights with multiple DoT-friendly targets or sustained add phases.",
  },
  statPriority = {
    { stat = "primary", note = "Intellect, passive" },
    { stat = "haste", note = "faster DoT ticks and Insanity generation" },
    { stat = "mastery" },
    { stat = "crit" },
    { stat = "versatility" },
  },
  rotation = {
    { title = "Single Target", steps = {
        { spellID = 589, text = "Shadow Word: Pain kept active on the target" },
        { spellID = 34914, text = "Vampiric Touch kept active on the target" },
        { spellID = 8092, text = "Mind Blast on cooldown — strong Insanity generator" },
        { spellID = 15407, text = "Mind Flay as your primary Insanity-neutral filler" },
        { spellID = 205448, text = "Void Bolt on cooldown once available for burst damage" },
        { text = "Refresh DoTs before they fall off rather than letting them lapse" },
    }},
    { title = "AoE", steps = {
        { spellID = 205385, text = "Shadow Crash to spread DoTs to multiple targets at once" },
        { spellID = 48045, text = "Mind Sear as an AoE Insanity-neutral filler across grouped targets" },
        { spellID = 589, text = "Shadow Word: Pain maintained on priority targets" },
        { spellID = 8092, text = "Mind Blast on cooldown, still strong even while cleaving" },
        { spellID = 205448, text = "Void Bolt on cooldown for burst during add waves" },
        { text = "Keep DoTs rolling on as many targets as your Insanity budget allows" },
    }},
    { title = "Opener Notes", steps = {
        { text = "Apply Shadow Word: Pain and Vampiric Touch immediately, then build toward your burst window" },
        { text = "Line up your Insanity-spending burst cooldown with trinkets and other offensive cooldowns" },
    }},
  },
  cooldowns = {
    { spellID = 228260, text = "Void Eruption or your spec's burst-window cooldown — use on cooldown" },
    { spellID = 47585, text = "Dispersion — damage reduction and mana/Insanity recovery cooldown" },
    { spellID = 586, text = "Fade to drop threat or avoid certain mechanics" },
    { spellID = 15487, text = "Silence — interrupt/utility cooldown, use on dangerous casts" },
  },
  consumables = {
    { slot = "Flask", text = "Flask of Alchemical Chaos (Intellect)" },
    { slot = "Food", text = "An Intellect-focused feast or food buff" },
    { slot = "Potion", text = "Tempered Potion, used inside your burst window" },
    { slot = "Weapon", text = "Shadowcore Oil or the current-tier weapon oil" },
    { slot = "Enchants", text = "Weapon enchant for Intellect/haste; ring enchants for secondary stats" },
    { slot = "Gems", text = "Intellect or Intellect/secondary hybrid gems in available sockets" },
  },
  tips = {
    "Never let Shadow Word: Pain or Vampiric Touch fall off a target you'll keep attacking.",
    "Shadow Crash is a strong opener tool for seeding DoTs across a whole pull.",
    "Don't dump Insanity haphazardly — plan your burst window around your strongest cooldowns.",
    "Fade is useful for both threat management and dodging certain mechanics — don't save it purely for emergencies.",
  },
})
