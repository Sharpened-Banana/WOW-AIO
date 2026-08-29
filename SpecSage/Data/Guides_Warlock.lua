local ADDON, ns = ...

-- SpecSage guide data: Warlock
-- Content targets The War Within. This is community-maintained, conventional
-- guidance (keep-it-simple stat priorities, long-standing rotation patterns)
-- and is NOT a claim of sim-perfect or bleeding-edge optimal play.
-- To edit: find the RegisterSpec(...) block for the spec you want to change
-- and edit the table in place. To add a new tip/step, insert a new entry in
-- the relevant array. Keep this file data-only — no logic beyond the calls
-- below. See DESIGN.md "Guide data schema" for the full table shape.

if not ns.GuideStore then return end

-- Affliction ---------------------------------------------------------------
ns.GuideStore:RegisterSpec("WARLOCK", 265, {
  specName = "Affliction",
  role = "DAMAGER",
  overview = {
    "Affliction Warlock is a damage-over-time spec that ramps up over the course of a fight, layering Agony, Corruption, Unstable Affliction and Malefic Rapture into a strong sustained-damage profile with periodic burst via Soul Rot and Malefic Rapture dumps.",
    "The core resource is Soul Shards, generated from dots ticking and spent on Malefic Rapture to deal instant damage per active dot on the target, and on Summon Darkglare/Soul Rot for burst windows. Agony's damage scales up the longer it's kept active on a target, rewarding strong dot uptime.",
    "Bring Affliction when a fight rewards consistent damage over time, has multiple targets to dot up, or has a long fight length that lets your damage ramp — it's less ideal for very short burst-only encounters.",
  },
  statPriority = {
    { stat = "primary" },
    { stat = "haste", note = "smooths dot ticks and shard generation" },
    { stat = "mastery" },
    { stat = "crit" },
    { stat = "versatility" },
  },
  rotation = {
    { title = "Opener", steps = {
        { spellID = 980, text = "Agony first to start it ramping as early as possible" },
        { spellID = 172, text = "Corruption to add a second dot" },
        { spellID = 316099, text = "Unstable Affliction for shard generation and damage" },
        { text = "Summon Darkglare / Soul Rot once dots are rolling, for an early burst window" },
    }},
    { title = "Single Target", steps = {
        { spellID = 980, text = "Keep Agony active at all times, refresh before it falls off" },
        { spellID = 172, text = "Keep Corruption active at all times" },
        { spellID = 316099, text = "Unstable Affliction on cooldown for shard generation" },
        { spellID = 324536, text = "Malefic Rapture to spend shards once dots are stacked, avoid overcapping shards" },
        { text = "Use filler (Drain Life/Shadow Bolt) only when no better shard-generating option is available" },
    }},
    { title = "AoE", steps = {
        { spellID = 980, text = "Agony on each target, prioritizing ones that will live longest" },
        { text = "Seed of Corruption (or Corruption per talents) to spread dots across the pack" },
        { spellID = 324536, text = "Malefic Rapture hits all dotted targets — spend shards once several targets are dotted" },
        { text = "Use Phantom Singularity/Vile Taint (talent-dependent) for extra AoE damage over time" },
        { text = "Keep re-dotting targets as they come into range rather than tunneling one target" },
    }},
  },
  cooldowns = {
    { text = "Summon Darkglare — spends dots for instant damage and extends them; use once dots are well-established" },
    { text = "Soul Rot (talent) — burst window, line up with Darkglare and raid cooldowns" },
    { spellID = 108416, text = "Dark Pact — defensive cooldown, absorbs damage using health as a resource" },
    { spellID = 104773, text = "Unending Resolve — major defensive, use against heavy incoming damage" },
    { text = "Mortal Coil / Howl of Terror — utility CC, situational" },
  },
  consumables = {
    { slot = "Flask", text = "Flask of Alchemical Chaos (Intellect)" },
    { slot = "Food", text = "A feast or personal Intellect food for the encounter" },
    { slot = "Potion", text = "Tempered Potion, used during a burst window" },
    { slot = "Weapon", text = "Not applicable" },
    { slot = "Enchants", text = "Max-rank Intellect enchants on cloak and rings" },
    { slot = "Gems", text = "Intellect/secondary stat gems in available sockets" },
  },
  gear = {
    { slot = "Head", text = "One of your tier-set slots — the four-piece bonus is worth chasing since it reinforces your dot-and-Malefic-Rapture damage engine" },
    { slot = "Chest", text = "A large stat budget and often your other tier piece — lean into Haste first to smooth dot ticks and shard generation" },
    { slot = "Neck", text = "Usually has a socket — fill it and prioritize Haste, then Mastery, over Critical Strike" },
    { slot = "Ring", text = "No set bonus tying you down — use rings to round out Haste and Mastery wherever your gear is thin" },
    { slot = "Trinket", text = "One on-use trinket timed with Summon Darkglare/Soul Rot so its burst lands while your dots are fully stacked" },
    { slot = "Trinket", text = "A passive Intellect or secondary-stat trinket to keep sustained dot damage strong the rest of the fight" },
    { slot = "Weapon", text = "Take the highest weapon damage one-hand-plus-off-hand or staff available — type matters far less than item level for a dot-based caster" },
    { slot = "Off-hand", text = "A caster off-hand that adds Haste or Mastery keeps your dot ramp and shard generation smooth" },
  },
  tips = {
    "Never let Agony or Corruption fall off early — dropped dots and re-ramping cost significant damage.",
    "Don't dump Malefic Rapture with only one or two dots active; wait for a fuller board when possible.",
    "Pre-dot targets that are about to become active (adds spawning soon) if you can safely reach them.",
    "Plan Darkglare/Soul Rot around when your dots will be at strong uptime across the most targets.",
  },
})

-- Demonology -----------------------------------------------------------
ns.GuideStore:RegisterSpec("WARLOCK", 266, {
  specName = "Demonology",
  role = "DAMAGER",
  overview = {
    "Demonology Warlock is a pet-and-cooldown spec built around summoning waves of demons and popping Demonic Tyrant to empower them all at once for a massive burst window, repeated on cooldown throughout the fight.",
    "The core loop is generating Soul Shards from Demonbolt/Shadow Bolt and spending them on Call Dreadstalkers and Summon Vilefiend to build up a pack of demons, then using Grimoire: Felguard and other summons before popping Summon Demonic Tyrant, which empowers all active demons and extends their duration.",
    "Bring Demonology when you want a highly cooldown-driven, pet-management playstyle with big periodic burst windows and strong pad-the-numbers cleave from empowered demons.",
  },
  statPriority = {
    { stat = "primary" },
    { stat = "haste" },
    { stat = "mastery" },
    { stat = "crit" },
    { stat = "versatility" },
  },
  rotation = {
    { title = "Opener", steps = {
        { text = "Call Dreadstalkers and Summon Vilefiend to build your demon pack" },
        { text = "Grimoire: Felguard (if talented) to add another pet before Tyrant" },
        { text = "Summon Demonic Tyrant once your demons are out, to empower the full pack" },
    }},
    { title = "Single Target", steps = {
        { text = "Call Dreadstalkers on cooldown to generate shards and demons" },
        { text = "Summon Vilefiend on cooldown for additional demon uptime" },
        { spellID = 264178, text = "Demonbolt to generate Soul Shards, use Shadow Bolt only as needed filler" },
        { text = "Hand of Gul'dan to dump excess shards and apply Shadowflame damage" },
        { text = "Pool shards and demon summons for the next Demonic Tyrant window rather than using them piecemeal" },
    }},
    { title = "AoE", steps = {
        { text = "Hand of Gul'dan on cooldown for its AoE Shadowflame damage" },
        { text = "Call Dreadstalkers and Summon Vilefiend as normal — their demons cleave naturally" },
        { text = "Implosion (talent) to detonate Wild Imps into a pack for burst AoE" },
        { text = "Keep pets attacking the highest-priority target so cleave lands on real threats" },
        { text = "Time Demonic Tyrant for when the full pack is engaged on the pull" },
    }},
  },
  cooldowns = {
    { text = "Summon Demonic Tyrant — main burst window, use once your demon pack is built and pool shards for it" },
    { text = "Grimoire: Felguard — extra pet damage, use before or during a Tyrant window per your build" },
    { spellID = 108416, text = "Dark Pact — defensive cooldown, absorbs damage using health as a resource" },
    { spellID = 104773, text = "Unending Resolve — major defensive, use against heavy incoming damage" },
  },
  consumables = {
    { slot = "Flask", text = "Flask of Alchemical Chaos (Intellect)" },
    { slot = "Food", text = "A feast or personal Intellect food for the encounter" },
    { slot = "Potion", text = "Tempered Potion, used during a Demonic Tyrant window" },
    { slot = "Weapon", text = "Not applicable" },
    { slot = "Enchants", text = "Max-rank Intellect enchants on cloak and rings" },
    { slot = "Gems", text = "Intellect/secondary stat gems in available sockets" },
  },
  gear = {
    { slot = "Head", text = "One of your tier-set slots — the four-piece bonus is built around your demon-summon burst, so it's usually worth prioritizing over raw item level" },
    { slot = "Chest", text = "A big stat budget and likely your other tier piece — lean Haste first to shorten the ramp into each Demonic Tyrant window" },
    { slot = "Neck", text = "Usually carries a socket — fill it and favor Haste, then Mastery" },
    { slot = "Ring", text = "No set bonus attached — use rings to top up Haste and Mastery wherever you're light" },
    { slot = "Trinket", text = "One on-use trinket timed to pop with Summon Demonic Tyrant for maximum overlap with your empowered demons" },
    { slot = "Trinket", text = "A passive secondary-stat trinket to hold your damage floor between Tyrant windows" },
    { slot = "Weapon", text = "Take the highest weapon damage staff or one-hand-plus-off-hand you can equip — pet damage scales off your stats, not weapon type" },
    { slot = "Off-hand", text = "A caster off-hand that reinforces Haste helps you rebuild your demon pack faster between cooldowns" },
  },
  tips = {
    "Pool Soul Shards and demon summons before Demonic Tyrant so the empower window has as many demons as possible.",
    "Don't let Wild Imps sit unused if running Implosion — detonate them for burst when the timing calls for it.",
    "Keep track of Dreadstalker and Vilefiend cooldowns so they're ready to refill your pack before each Tyrant.",
    "Reposition pets onto priority adds quickly — cleave damage is wasted on a dead or low-value target.",
  },
})

-- Destruction ----------------------------------------------------------
ns.GuideStore:RegisterSpec("WARLOCK", 267, {
  specName = "Destruction",
  role = "DAMAGER",
  overview = {
    "Destruction Warlock is a Soul Shard spender spec that alternates between building shards with Incinerate/Conflagrate and unloading them on Chaos Bolt for large single hits, with Immolate providing a steady damage-over-time backbone.",
    "The core resource is Soul Shards (0-5): Incinerate and Conflagrate generate shards (and Conflagrate can also be a free-cast proc via Backdraft), while Chaos Bolt and Rain of Fire spend them. Havoc lets you cleave a second target's worth of single-target damage during execute-style windows.",
    "Bring Destruction when you want a spec with strong scheduled burst via Chaos Bolt during cooldown windows, solid cleave via Havoc/Rain of Fire, and a relatively straightforward shard-management rotation.",
  },
  statPriority = {
    { stat = "primary" },
    { stat = "crit" },
    { stat = "haste" },
    { stat = "mastery" },
    { stat = "versatility" },
  },
  rotation = {
    { title = "Opener", steps = {
        { spellID = 348, text = "Immolate first to start the dot ticking" },
        { spellID = 17962, text = "Conflagrate to generate an early shard" },
        { spellID = 116858, text = "Chaos Bolt once you have shards banked, aligned with cooldowns" },
    }},
    { title = "Single Target", steps = {
        { spellID = 348, text = "Keep Immolate active on the target at all times" },
        { spellID = 17962, text = "Conflagrate on cooldown / on Backdraft proc for shard generation" },
        { spellID = 29722, text = "Incinerate as filler and shard generator" },
        { spellID = 116858, text = "Chaos Bolt to spend shards for big single-target damage" },
        { text = "Use Havoc on a second target during multi-target cleave windows" },
    }},
    { title = "AoE", steps = {
        { spellID = 348, text = "Immolate on primary targets to enable Rain of Fire's bonus damage" },
        { spellID = 5740, text = "Rain of Fire as your primary AoE spender" },
        { spellID = 17962, text = "Conflagrate to generate shards quickly for more Rain of Fire casts" },
        { text = "Use Havoc to cleave Chaos Bolt/Incinerate damage onto a second target when only 2 targets are present" },
        { text = "Channel Demonfire (talent) to spend Immolate uptime into extra AoE damage" },
    }},
  },
  cooldowns = {
    { text = "Summon Infernal — major burst cooldown, use aligned with a strong damage window" },
    { spellID = 116858, text = "Chaos Bolt — spend banked shards during cooldown windows for maximum burst value" },
    { spellID = 108416, text = "Dark Pact — defensive cooldown, absorbs damage using health as a resource" },
    { spellID = 104773, text = "Unending Resolve — major defensive, use against heavy incoming damage" },
  },
  consumables = {
    { slot = "Flask", text = "Flask of Alchemical Chaos (Intellect)" },
    { slot = "Food", text = "A feast or personal Intellect food for the encounter" },
    { slot = "Potion", text = "Tempered Potion, used with Summon Infernal" },
    { slot = "Weapon", text = "Not applicable" },
    { slot = "Enchants", text = "Max-rank Intellect enchants on cloak and rings" },
    { slot = "Gems", text = "Intellect/secondary stat gems in available sockets" },
  },
  gear = {
    { slot = "Head", text = "One of your tier-set slots — the four-piece bonus meaningfully strengthens your Chaos Bolt burst windows, so it's usually worth the set piece" },
    { slot = "Chest", text = "A large stat budget and often your other tier piece — push Critical Strike first since it directly scales your biggest hits" },
    { slot = "Neck", text = "Usually has a socket — prioritize Critical Strike, then Haste for more shard generation" },
    { slot = "Ring", text = "No set bonus tying you down — use rings to round out Critical Strike and Haste" },
    { slot = "Trinket", text = "One on-use trinket timed with Summon Infernal so its burst overlaps your Chaos Bolt spam" },
    { slot = "Trinket", text = "A passive stat-stick trinket to keep Incinerate/Immolate damage solid between cooldown windows" },
    { slot = "Weapon", text = "Take the highest weapon damage staff or one-hand-plus-off-hand — item level matters far more than weapon type here" },
    { slot = "Off-hand", text = "A caster off-hand leaning Critical Strike keeps your burst windows hitting as hard as possible" },
  },
  tips = {
    "Never let Immolate fall off the target — it feeds Rain of Fire and Channel Demonfire damage.",
    "Don't cap Soul Shards; if you're at 5 shards and generating more, spend one before it's wasted.",
    "Save a Backdraft-fueled Conflagrate burst for right before Chaos Bolt spam during a cooldown window.",
    "Use Havoc proactively on cleave/2-target windows rather than only on pure single-target fights.",
  },
})
