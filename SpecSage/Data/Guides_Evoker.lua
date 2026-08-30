local ADDON, ns = ...

-- SpecSage guide data: Evoker
-- Content targets Midnight (patch 12.1). Specs below with an `mplusLoadout`
-- field have that talent string (only) cross-checked against
-- SimulationCraft's public profiles (github.com/simulationcraft/simc,
-- GPLv3) as of patch 12.1; specs without one have no such reference.
-- Rotation/overview/tips/gear prose throughout this file is hand-authored
-- and was reviewed for Midnight ability changes, not derived from or
-- checked against SimC's APLs, and was not re-verified against current
-- tuning this pass.
-- This is community-maintained, conventional guidance (keep-it-simple stat
-- priorities, long-standing rotation patterns) and is NOT a claim of
-- sim-perfect or bleeding-edge optimal play.
-- To edit: find the RegisterSpec(...) block for the spec you want to change
-- and edit the table in place. To add a new tip/step, insert a new entry in
-- the relevant array. Keep this file data-only — no logic beyond the calls
-- below. See DESIGN.md "Guide data schema" for the full table shape.

if not ns.GuideStore then return end

-- Devastation ------------------------------------------------------------
ns.GuideStore:RegisterSpec("EVOKER", 1467, {
  specName = "Devastation",
  role = "DAMAGER",
  overview = {
    "Devastation Evoker is a ranged caster spec that blends direct blue-dragonflight spellcasting with red-dragonflight breath attacks, managing Essence as its resource while empowered spells (channel-and-release casts with multiple power levels) add a layer of cast-time tactics.",
    "The core mechanic is Essence, spent on Disintegrate and Pyre and regenerated over time, plus Empower spells (Fire Breath, Eternity Surge) that you can hold longer for a stronger effect at the cost of a longer cast. Dragonrage is the main burst window, dramatically increasing damage and refunding some Essence spending.",
    "Bring Devastation when you want strong ranged burst damage with excellent AoE via Pyre/Fire Breath, good mobility via Hover, and a rotation that rewards judging empower levels correctly for the situation.",
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
        { text = "Living Flame while closing distance to build initial Essence" },
        { text = "Fire Breath (empowered) to apply its damage-over-time before burst" },
        { text = "Dragonrage once dots are applied, to open the main burst window" },
        { text = "Opener Notes: Devastation splits along the Flameshaper and Scalecommander hero trees — Scalecommander turns Disintegrate into a multi-target hit via Mass Disintegrate, Flameshaper keeps closer to the single-target flow above" },
    }},
    { title = "Single Target", steps = {
        { text = "Living Flame as a mobile filler and Essence generator" },
        { spellID = 356995, text = "Disintegrate to spend Essence on strong single-target damage" },
        { text = "Fire Breath on cooldown, empowering to at least level 2-3 depending on the situation" },
        { text = "Eternity Surge on cooldown for additional burst" },
        { text = "Don't let Essence sit capped — spend it before it overflows" },
    }},
    { title = "AoE", steps = {
        { text = "Pyre as your primary AoE Essence spender" },
        { text = "Fire Breath, empowered fully when stationary, to apply damage-over-time across the pack" },
        { text = "Eternity Surge (empowered) to hit multiple targets with strong burst damage" },
        { text = "Living Flame to top up Essence between AoE spenders" },
        { text = "Time Dragonrage for when the full pack is engaged" },
    }},
  },
  cooldowns = {
    { text = "Dragonrage — main burst cooldown, use once dots are applied and align with raid cooldowns" },
    { text = "Fire Breath — empowered breath, hold for a higher empower level when stationary and safe to do so" },
    { text = "Eternity Surge — empowered burst spell, similar empower-level tradeoff as Fire Breath" },
    { spellID = 363916, text = "Obsidian Scales — defensive, reduces damage taken" },
    { text = "Zephyr / Renewing Blaze (talent-dependent) — situational defensive/mobility cooldowns" },
  },
  consumables = {
    { slot = "Flask", text = "Flask of Alchemical Chaos (Intellect)" },
    { slot = "Food", text = "A feast or personal Intellect food for the encounter" },
    { slot = "Potion", text = "Tempered Potion, used during Dragonrage" },
    { slot = "Weapon", text = "Not applicable" },
    { slot = "Enchants", text = "Max-rank Intellect enchants on cloak and rings" },
    { slot = "Gems", text = "Intellect/secondary stat gems in available sockets" },
  },
  gear = {
    { slot = "Head", text = "One of your tier-set slots — the four-piece bonus reinforces your Essence/empower-spell engine, worth prioritizing" },
    { slot = "Chest", text = "A large stat budget and often your other tier piece — push Critical Strike first for Disintegrate/Pyre payoff" },
    { slot = "Neck", text = "Usually carries a socket — favor Critical Strike, then Haste for faster Essence regeneration" },
    { slot = "Ring", text = "No set bonus attached — use rings to round out Critical Strike and Haste" },
    { slot = "Trinket", text = "One on-use trinket timed with Dragonrage so its burst overlaps your main damage window" },
    { slot = "Trinket", text = "A passive secondary-stat trinket to hold sustained damage between Dragonrage windows" },
    { slot = "Weapon", text = "Evokers wield ranged caster weapons — take the highest item level available, since it functions as a stat stick rather than a melee weapon" },
    { slot = "Off-hand", text = "A caster off-hand leaning Critical Strike or Haste keeps your empower spells and Essence spenders hitting hard" },
  },
  -- MID1 fallback: SimC has not yet published a MID2 (12.1) default profile
  -- for Devastation, so this loadout is pulled from the MID1 (12.0) profile
  -- set instead. Swap to a MID2 profile once SimC publishes one.
  mplusLoadout = {
    string = "CsbBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAzMDMDzgBmZGjZaYmpZMWmxMzMz8AzMzAmxMGzMLzMDMwYwCsMGN2GQmBBbYGMzghB",
    source = "SimulationCraft default profile (credit, not endorsement of 'best')",
    patch = "12.0 (MID1, previous tier)",
  },
  tips = {
    "Only hold an empowered cast to a higher level when it's safe to stand still that long — a lower, on-time empower often beats a perfect one that gets interrupted by movement.",
    "Enter Dragonrage with dots already applied so the window isn't spent ramping up.",
    "Don't let Essence sit at cap — Living Flame and Disintegrate exist to keep it flowing.",
    "Use Hover proactively for movement-heavy mechanics rather than eating a cast interruption.",
  },
})

-- Preservation -------------------------------------------------------------
-- Revised against official Blizzard patch notes for 12.1 (Curse of Ula'tek,
-- news.blizzard.com/en-us/article/24293281): no SimC profile exists for this
-- spec, so it is NOT SimC-cross-checked — see the mplusLoadout note in the
-- header above. 12.1 buffs Preservation's single-target/triage kit in PvE:
-- Living Flame healing +20%, Verdant Embrace +25%, Dream Simulacrum's buff
-- to Verdant Embrace up to 40% (was 30%), and Consume Flame (talent) now
-- heals for 240% of the amount consumed (was 200%) with a fix so its heal
-- can crit.
ns.GuideStore:RegisterSpec("EVOKER", 1468, {
  specName = "Preservation",
  role = "HEALER",
  overview = {
    "Preservation Evoker heals through a mix of direct heals, the Echo mechanic (which doubles a future heal on the same target), and strong cooldown-driven raid healing via Dream Breath and Rewind/Time Dilation-style talents.",
    "The core mechanic is Essence for spending on abilities like Living Flame and Dream Breath, plus Echo — placing a marker on a target so your next heal on them heals for extra, rewarding pre-planning rather than purely reactive healing.",
    "Patch 12.1 pushed extra healing into Preservation's single-target/triage tools rather than its group cooldowns: Living Flame and Verdant Embrace both hit noticeably harder, and Consume Flame (if talented) converts more of Fire Breath's damage-over-time into healing. That makes spot-healing between Dream Breath windows meaningfully stronger than in prior tiers.",
    "Bring Preservation when you want a healer with excellent raid cooldown throughput (Dream Breath, Rewind), useful damage-mitigation utility like Blessing of the Bronze and Time Dilation, and a rotation that rewards proactive Echo placement.",
  },
  statPriority = {
    { stat = "primary" },
    { stat = "haste", note = "smooths cast times and HoT ticks" },
    { stat = "mastery" },
    { stat = "crit" },
    { stat = "versatility" },
  },
  rotation = {
    { title = "Priorities", steps = {
        { spellID = 364343, text = "Echo on tanks or high-priority targets ahead of expected damage" },
        { spellID = 355936, text = "Dream Breath (empowered) on cooldown for strong group-wide healing" },
        { spellID = 361469, text = "Living Flame for efficient single-target healing (or damage when topped off) — buffed 20% in 12.1, a stronger filler than before" },
        { spellID = 360995, text = "Verdant Embrace to reposition to and top off an ally at range — buffed 25% in 12.1" },
        { spellID = 367226, text = "Spiritbloom for strong burst healing on a cluster of injured allies" },
        { spellID = 366155, text = "Reversion to maintain a rolling HoT on the tank or a focus target" },
    }},
    { title = "Cooldown usage", steps = {
        { text = "Rewind (talent) to retroactively heal the raid after a damage spike" },
        { text = "Dream Flight / Stasis (talent-dependent) for a big raid-wide cooldown window" },
        { spellID = 357170, text = "Time Dilation to reduce damage taken by an ally proactively" },
        { text = "Emerald Communion for sustained healing and mana regeneration on a long fight" },
        { text = "If talented into Consume Flame, weave it in after Fire Breath's dot has ticked for a while — it now converts a larger share (240%) of the remaining damage into healing" },
        { text = "Pre-place Echo on multiple raid members before a known damage phase" },
    }},
  },
  cooldowns = {
    { text = "Dream Flight — raid-wide healing cooldown, use for a scripted heavy damage phase" },
    { text = "Rewind (talent) — retroactive raid heal, use right after unavoidable burst damage lands" },
    { text = "Emerald Communion — channel for strong sustained self/group healing and mana return" },
    { spellID = 363916, text = "Obsidian Scales — personal defensive, reduces damage taken" },
    { spellID = 357170, text = "Time Dilation — proactive damage reduction for an ally about to take a hit" },
  },
  consumables = {
    { slot = "Flask", text = "Flask of Alchemical Chaos (Intellect)" },
    { slot = "Food", text = "A feast or personal Intellect food for the encounter" },
    { slot = "Potion", text = "Tempered Potion or a healing-oriented potion for a big damage phase" },
    { slot = "Weapon", text = "Not applicable" },
    { slot = "Enchants", text = "Max-rank Intellect enchants on cloak and rings" },
    { slot = "Gems", text = "Intellect/secondary stat gems in available sockets" },
  },
  gear = {
    { slot = "Head", text = "One of your tier-set slots — the four-piece bonus adds real throughput to your Echo/Dream Breath loop, worth prioritizing" },
    { slot = "Chest", text = "A large stat budget and often your other tier piece — lean Haste first to smooth cast times and empowered heal levels" },
    { slot = "Neck", text = "Usually carries a socket — favor Haste, then Mastery" },
    { slot = "Ring", text = "No set bonus attached — use rings to round out Haste and Mastery" },
    { slot = "Trinket", text = "One mana-efficiency or passive-throughput trinket to stretch your healing across a long fight" },
    { slot = "Trinket", text = "A second trinket built around a burst-healing proc you can align with Dream Flight/Rewind" },
    { slot = "Weapon", text = "Evokers wield ranged caster weapons — take the highest item level available as a pure stat stick" },
    { slot = "Off-hand", text = "A caster off-hand leaning Haste keeps your empowered casts and Echo-based healing flowing smoothly" },
  },
  tips = {
    "Place Echo ahead of expected damage rather than reactively — it rewards planning over reacting.",
    "Use empowered Dream Breath at a higher level when it's safe to hold the cast, for stronger group healing.",
    "Save Rewind for right after a big, already-landed damage spike since it heals retroactively.",
    "Blessing of the Bronze and similar buffs are raid utility — keep them refreshed on the group.",
    "Living Flame and Verdant Embrace both got real healing buffs in 12.1 — use them more freely for single-target/triage healing between Dream Breath windows rather than treating them as pure filler.",
  },
})

-- Augmentation ---------------------------------------------------------
-- Revised against official Blizzard patch notes for 12.1 (Curse of Ula'tek,
-- news.blizzard.com/en-us/article/24293281): no SimC profile exists for this
-- spec, so it is NOT SimC-cross-checked — see the mplusLoadout note in the
-- header above. Augmentation is a support-damage hybrid, not a pure DPS or
-- healer spec — see the overview below for how it actually plays. 12.1's
-- documented Augmentation-specific change is to the Double-time talent: the
-- bonus stats an ally gains when your Ebon Might critically strikes now last
-- a flat 15 seconds (scaled by Mastery: Timewalker) and refresh if you
-- reapply Ebon Might while the buff is still active.
ns.GuideStore:RegisterSpec("EVOKER", 1473, {
  specName = "Augmentation",
  role = "DAMAGER",
  overview = {
    "Augmentation Evoker is a support-damage hybrid, not a conventional DPS spec: most of its value doesn't come from its own damage meter position, it comes from making everyone else's damage bigger. It casts a moderate amount of direct damage itself, but its actual job is buffing allies through Ebon Might and Prescience.",
    "The core mechanic is applying and refreshing Ebon Might — a damage-and-versatility buff shared with you and nearby allies — and placing Prescience — a crit-chance buff — on specific allies, both timed around when those allies' own cooldowns are active so the buff amplifies a bigger number. Direct damage from Living Flame, Upheaval, and Eruption fills the gaps and generates Essence, but it is secondary to buff uptime.",
    "Patch 12.1's one documented change specific to this spec touches the Double-time talent: the bonus stats an ally gains when your Ebon Might crits now last a flat 15 seconds and refresh if you reapply Ebon Might while that buff is still active, so a well-timed refresh keeps the bonus rolling continuously instead of needing to be re-triggered by a fresh crit.",
    "Bring Augmentation when your group wants a force-multiplier spec that boosts the whole raid's damage output, especially in coordinated cooldown-stacking compositions, rather than pure personal damage.",
  },
  statPriority = {
    { stat = "primary" },
    { stat = "crit" },
    { stat = "haste" },
    { stat = "mastery", note = "Mastery: Timewalker extends and retroactively applies your buffs — don't undervalue it versus a DPS spec's usual priorities" },
    { stat = "versatility" },
  },
  rotation = {
    { title = "Priorities", steps = {
        { spellID = 395152, text = "Ebon Might on yourself and key allies, timed to line up with their damage cooldowns" },
        { text = "Prescience on two allies (typically high-damage or cooldown-heavy players), keep it refreshed" },
        { spellID = 361469, text = "Living Flame as filler direct damage and Essence generation" },
        { text = "Upheaval / Eruption on cooldown for direct damage and utility" },
        { text = "Breath of Eons / Black Attunement-style major cooldowns aligned with raid burst windows" },
        { text = "If talented into Double-time, time your Ebon Might refresh to land while the previous crit's stat buff is still active — it extends cleanly instead of resetting" },
    }},
    { title = "AoE / Cooldown usage", steps = {
        { text = "Prioritize applying Ebon Might/Prescience to the group before your own direct damage in AoE" },
        { text = "Time Ebon Might/Prescience with allies' cooldown windows rather than a fixed rotation — this is the spec's actual damage output, not a buff bolted onto a DPS rotation" },
        { text = "Use your empower spells (Upheaval) on cooldown for both damage and utility knockback control" },
        { text = "Coordinate Breath of Eons-style major cooldowns with the raid's planned burst window" },
        { text = "Keep moving to reposition buffs efficiently across a spread-out raid" },
    }},
  },
  cooldowns = {
    { spellID = 395152, text = "Ebon Might — core damage-sharing buff, refresh on cooldown and time with allies' burst windows" },
    { text = "Breath of Eons (talent) — major raid-wide burst cooldown, coordinate with the raid's cooldown plan" },
    { text = "Prescience — crit buff for two allies, prioritize players with strong burst cooldowns of their own" },
    { spellID = 363916, text = "Obsidian Scales — personal defensive, reduces damage taken" },
  },
  consumables = {
    { slot = "Flask", text = "Flask of Alchemical Chaos (Intellect)" },
    { slot = "Food", text = "A feast or personal Intellect food for the encounter" },
    { slot = "Potion", text = "Tempered Potion, used during a coordinated raid burst window" },
    { slot = "Weapon", text = "Not applicable" },
    { slot = "Enchants", text = "Max-rank Intellect enchants on cloak and rings" },
    { slot = "Gems", text = "Intellect/secondary stat gems in available sockets" },
  },
  gear = {
    { slot = "Head", text = "One of your tier-set slots — the four-piece bonus strengthens your Ebon Might/Prescience uptime, worth prioritizing" },
    { slot = "Chest", text = "A large stat budget and often your other tier piece — push Critical Strike first, since your buffs scale partly off your own stats" },
    { slot = "Neck", text = "Usually carries a socket — favor Critical Strike, then Haste for more frequent buff refreshes" },
    { slot = "Ring", text = "No set bonus attached — use rings to round out Critical Strike and Haste" },
    { slot = "Trinket", text = "One on-use trinket timed with Breath of Eons so its burst lines up with the raid's coordinated cooldown window" },
    { slot = "Trinket", text = "A passive secondary-stat trinket to keep your own direct damage relevant between cooldown windows" },
    { slot = "Weapon", text = "Evokers wield ranged caster weapons — take the highest item level available as a stat stick" },
    { slot = "Off-hand", text = "A caster off-hand leaning Critical Strike or Haste supports both your own damage and your buff uptime" },
  },
  tips = {
    "Communicate with the allies you're buffing so Ebon Might and Prescience land while their own cooldowns are active.",
    "Don't treat this as a pure personal-damage spec — your buff uptime on the raid matters more than your own damage meter position.",
    "Reapply Prescience before it expires, and consider swapping targets if a different ally's cooldown window is coming up.",
    "Coordinate your major cooldowns with the raid's overall burst plan rather than using them purely on cooldown.",
    "If you've talented Double-time, refresh Ebon Might while its crit-triggered stat buff is still active rather than letting it lapse — since 12.1 the refresh extends the buff cleanly instead of forcing a new crit to restart it.",
  },
})
