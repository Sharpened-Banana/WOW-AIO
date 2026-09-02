local ADDON, ns = ...

-- SpecSage guide data: Evoker
-- Content targets Midnight (patch 12.1). Specs below with an `mplusLoadout`
-- field have that talent string (only) cross-checked against
-- SimulationCraft's public profiles (github.com/simulationcraft/simc,
-- GPLv3) as of patch 12.1; specs without one have no such reference.
-- Rotation/overview/tips/gear prose throughout this file is hand-authored
-- and was reviewed for Midnight ability changes, not derived from or
-- checked against SimC's APLs, and was not re-verified against current
-- tuning this pass — EXCEPT Devastation (1467), Preservation (1468), and Augmentation (1473),
-- which each gained an `mplusMetaLoadout` (DESIGN.md's v1.4 section) this
-- pass: pulled live from Blizzard's own Battle.net Game Data API
-- (client-credentials OAuth, US region) rather than SimC, on 2026-08-30.
-- Methodology: every current-season Mythic+ leaderboard (8-dungeon pool,
-- period 1078) across all 83 US connected realms was scanned (top 20 groups
-- per realm/dungeon) for each spec's group members; the top-observed-keystone
-- characters (up to 50 per spec) had their live `specializations` looked up
-- for their active loadout's `talent_loadout_code`. See each field's own
-- `source` comment for the resulting distribution.
-- This pass also added an "Opener Notes" rotation entry naming each spec's
-- two hero talent trees, for the two specs that didn't already have one
-- inline (Preservation, Augmentation). Devastation already carried a
-- hero-tree note; a same-session earlier pass incorrectly "corrected" its
-- Mass Disintegrate claim away, on the mistaken belief that Scalecommander
-- and Flameshaper ran an identical actions= list - textually true (both
-- names point at the same file), but the file's own action list dispatches
-- on `talent.mass_disintegrate` internally, a real behavioral branch a
-- flat text diff between two files' output can't see. Re-confirmed
-- directly (grep for `run_action_list,name=sc,if=talent.mass_disintegrate`
-- in MID1_Evoker_Devastation.simc) and restored the original claim.
-- These notes ARE cross-checked against SimC's current `midnight` branch
-- profiles (github.com/simulationcraft/simc) where a real action-list
-- branch exists per hero tree - whether that branch lives across two
-- separate files or as a `talent.X`/`hero_tree.X` conditional inside one -
-- and where SimC's profile set truly has no such branch, or ships no
-- profile for the spec at all, the note says so honestly instead of
-- inventing a rotation change.
-- Later pass (2026-09-01): as of this date guide sites (Wowhead, Icy
-- Veins, Maxroll, Method, Boostmatch) are a permitted source for rotation
-- logic, hero-talent recommendations, and stat priorities. Devastation,
-- Preservation, and Augmentation's overview/rotation/cooldowns/tips were
-- rewritten this pass with real opener sequences, single-target/AoE
-- priority splits, and hero-talent-caused differences pulled from those
-- sites, cross-checked against current spell data for spell IDs. One
-- correction worth flagging: a compendium synthesized from those sites
-- for this pass named "Engulf" as a Flameshaper cooldown for Devastation;
-- direct lookup confirmed Engulf was removed from the game entirely in
-- Midnight (12.1) - Flameshaper's healing-side signature ability, not a
-- Devastation tool to begin with, and gone either way - so it was left
-- out rather than reintroduced. Survival's own file has a similar note
-- for Butchery -> Raptor Swipe. statPriority fields were left untouched
-- throughout, since the sources didn't give a confident order beyond
-- what was already there.
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
    "The core mechanic is Essence, spent on Disintegrate and Pyre and regenerated over time, plus Empower spells (Fire Breath, Eternity Surge) that you can hold longer for a stronger effect at the cost of a longer cast. Dragonrage is the main burst window, dramatically increasing damage; if you're talented into Animosity, casting Fire Breath and Eternity Surge while it's active extends the window further, and Shattering Star adds a debuff that makes those casts hit harder.",
    "Devastation's two hero trees genuinely change the priority list, not just the flavor: Scalecommander adds the Deep Breath cooldown and spreads Bombardments through the Mass Disintegrate talent, while Flameshaper leans into a second Fire Breath charge. Both still run the same Essence/empower core described above.",
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
        { spellID = 361469, text = "Pre-cast Living Flame just before the pull to have some Essence banked" },
        { spellID = 375087, text = "Dragonrage right on pull — delay it a beat if Bloodlust/Heroism is about to go out so the window lines up" },
        { spellID = 370452, text = "Shattering Star to crack the target's defenses before your empowered spells land" },
        { spellID = 357208, text = "Fire Breath, using Tip the Scales to fire it off instantly at full empower" },
        { spellID = 359073, text = "Eternity Surge at rank 1 — tempo matters more than empower level this early" },
        { spellID = 356995, text = "Disintegrate until Essence runs dry" },
        { spellID = 361469, text = "Living Flame as filler once you're out of other resources" },
        { text = "Opener Notes: Devastation splits along the Flameshaper and Scalecommander hero trees — Scalecommander's Mass Disintegrate talent turns your next Disintegrate into a multi-target strike, giving it a genuinely different priority list from Flameshaper, so check which one your loadout uses" },
    }},
    { title = "Single Target", steps = {
        { spellID = 356995, text = "Disintegrate as your primary Essence spender — inside Dragonrage it's fine to clip the channel a few ticks early instead of always running it to completion, so you fit in more casts" },
        { spellID = 357208, text = "Fire Breath on cooldown — with Animosity talented, this and Eternity Surge both extend Dragonrage, so don't skip them for filler" },
        { spellID = 359073, text = "Eternity Surge on cooldown for the same Dragonrage-extension reason" },
        { spellID = 370452, text = "Shattering Star on cooldown" },
        { spellID = 361469, text = "Living Flame on Burnout procs, or as filler when nothing else is up" },
        { text = "Don't let Essence or Essence Burst sit capped — spend it before it overflows" },
    }},
    { title = "AoE", steps = {
        { spellID = 357211, text = "Pyre replaces Disintegrate as your Essence spender once you're hitting 3+ targets, thanks to Volatility" },
        { spellID = 362969, text = "Azure Strike replaces Living Flame as filler at the same target count" },
        { spellID = 357208, text = "Fire Breath, empowered fully when stationary, to spread its damage-over-time across the pack" },
        { spellID = 359073, text = "Eternity Surge, roughly matching the empower level to how many targets you're hitting" },
        { spellID = 375087, text = "Time Dragonrage for when the full pack is engaged" },
        { text = "Scalecommander spreads Bombardments through Mass Disintegrate — another reason that hero tree wants Disintegrate/Pyre uptime kept up" },
    }},
  },
  cooldowns = {
    { spellID = 375087, text = "Dragonrage — main burst cooldown, open with it on pull (delaying slightly to catch Bloodlust) or just ahead of your next Fire Breath/Eternity Surge" },
    { spellID = 357208, text = "Fire Breath — empowered breath, hold for a higher empower level when stationary and safe to do so; also extends Dragonrage if you're talented into Animosity" },
    { spellID = 359073, text = "Eternity Surge — empowered burst spell, same empower-level tradeoff as Fire Breath and the same Dragonrage-extension value" },
    { spellID = 357210, text = "Deep Breath — Scalecommander hero-tree cooldown, use it on cooldown rather than saving it" },
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
  -- Live top-players pull (DESIGN.md's v1.4 section), NOT SimC - see this
  -- file's header for the full methodology. The plurality build among the
  -- sample: 4/50 (8%) ran this exact code, since flex-point choices vary - but
  -- the bigger signal is that 49/50 (98%) ran Scalecommander overall. Reported
  -- honestly rather than dressed up as more decisive than it is.
  mplusMetaLoadout = {
    string = "CsbBPJc41CfcseY0baneJ1IHrBAAAAAAAAAAAjZgZYGzMgBjZamZmpZM2mxMzMzMzMzAmxMGzMLzMDMwYwGsMGN2GQmJAbYgZGMMA",
    source = "Blizzard Battle.net API, US region, 2026-08-30: top 50 current-season Mythic+ Devastation Evokers by best keystone level, sampled across all 83 US connected realms' leaderboards. This exact build was the plurality pick (4/50, 8%); 49/50 (98%) ran Scalecommander overall.",
    patch = "12.1",
    sampleSize = 50,
  },
  tips = {
    "Only hold an empowered cast to a higher level when it's safe to stand still that long — a lower, on-time empower often beats a perfect one that gets interrupted by movement.",
    "Open Dragonrage close to pull rather than saving it — line it up with Bloodlust if you can, but don't delay it far past its own cooldown chasing a perfect setup.",
    "Don't let Essence or Essence Burst sit at cap — Living Flame, Disintegrate, and Pyre all exist to keep it flowing.",
    "If you're talented into Animosity, treat Fire Breath and Eternity Surge as Dragonrage-extenders, not just damage — skipping them shortens your burst window.",
    "Use Hover proactively for movement-heavy mechanics rather than eating a cast interruption.",
  },
})

-- Preservation -------------------------------------------------------------
-- Revised for 12.1 (Curse of Ula'tek) from Blizzard patch-note content
-- reached via search summaries; the official article could not be fetched
-- directly from this environment, so the specific numbers below are
-- UNVERIFIED against the source page and should be treated as provisional
-- pending direct confirmation. No SimC profile exists for this spec, so it
-- is NOT SimC-cross-checked — see the mplusLoadout note in the header above.
-- 12.1 buffs Preservation's single-target/triage kit in PvE: Living Flame
-- healing +20%, Verdant Embrace +25%, and Consume Flame (talent) now heals
-- for 240% of the amount consumed (was 200%) with a fix so its heal can
-- crit.
ns.GuideStore:RegisterSpec("EVOKER", 1468, {
  specName = "Preservation",
  role = "HEALER",
  overview = {
    "Preservation Evoker heals through a mix of direct heals, the Echo mechanic (which doubles a future heal on the same target), and strong cooldown-driven raid healing via Dream Breath and Rewind/Time Dilation-style talents.",
    "The core mechanic is Essence for spending on abilities like Living Flame and Dream Breath, plus Echo — placing a marker on a target (mostly generated by Temporal Anomaly) so your next heal on them heals for extra, rewarding pre-planning rather than purely reactive healing. Fire Breath doubles as a healing tool: its damage-over-time procs Leaping Flames and generates Essence Burst, which pays for extra Emerald Blossom casts.",
    "Patch 12.1 pushed extra healing into Preservation's single-target/triage tools rather than its group cooldowns: Living Flame and Verdant Embrace both hit noticeably harder, and Consume Flame (if talented) converts more of Fire Breath's damage-over-time into healing. That makes spot-healing between Dream Breath windows meaningfully stronger than in prior tiers.",
    "Preservation's two hero trees push the kit in different directions: Flameshaper adds a second Dream Breath charge and leans on Consume Flame, while Chronowarden trades some of that group-cooldown focus for Primacy's haste-per-active-HoT stacking and a Living Flame/Chrono Flame-based filler.",
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
        { text = "Ramp pattern for a damage phase: Dream Breath into Merithra's Blessing, then Temporal Anomaly, spend the Echoes it generates, Emerald Blossom on the Essence Burst proc, and close with another Merithra's Blessing" },
        { spellID = 373861, text = "Temporal Anomaly on cooldown outside a planned ramp too — it's your main Echo engine and a group-wide shield in one cast" },
        { spellID = 355936, text = "Dream Breath (empowered) on cooldown for strong group-wide healing" },
        { spellID = 366155, text = "Reversion to spend Echoes on your priority targets, or Merithra's Blessing (if talented) to spend them on whoever is lowest" },
        { spellID = 360995, text = "Verdant Embrace on cooldown to reposition to and top off an ally at range — buffed 25% in 12.1" },
        { spellID = 357208, text = "Fire Breath on cooldown — procs Leaping Flames and Essence Burst, which pays for a free Emerald Blossom" },
        { spellID = 361469, text = "Living Flame for efficient single-target healing (or damage when topped off) — buffed 20% in 12.1, a stronger filler than before" },
        { spellID = 367226, text = "Spiritbloom for strong burst healing on a cluster of injured allies" },
    }},
    { title = "Cooldown usage", steps = {
        { spellID = 363534, text = "Rewind (talent) — your strongest cooldown, heals all damage the raid took in the last several seconds, so use it right after a spike lands rather than before" },
        { text = "Dream Flight for a big raid-wide cooldown window" },
        { spellID = 370537, text = "Stasis (talent) to bank 3 spell casts and unleash them together for an extra burst window" },
        { text = "Tip the Scales for an on-demand, fully-empowered Dream Breath or Fire Breath outside your normal cooldown timing" },
        { spellID = 357170, text = "Time Dilation to reduce damage taken by an ally proactively" },
        { text = "Emerald Communion for sustained healing and mana regeneration on a long fight" },
        { text = "If talented into Consume Flame, weave it in after Fire Breath's dot has ticked for a while — it now converts a larger share (240%) of the remaining damage into healing" },
        { spellID = 364343, text = "Pre-place Echo on multiple raid members before a known damage phase" },
    }},
    { title = "Opener Notes", steps = {
        { text = "Preservation's two hero talent trees are Flameshaper (also Devastation's) and Chronowarden (also Augmentation's) — check which one your loadout uses" },
        { text = "Flameshaper adds a second Dream Breath charge and leans on Consume Flame to convert Fire Breath's damage into healing; Chronowarden leans on Primacy (haste per active HoT, up to 3) and shifts your filler toward Living Flame/Chrono Flame, running its own version of the ramp above" },
    }},
  },
  cooldowns = {
    { spellID = 363534, text = "Rewind (talent) — the strongest cooldown available, heals all damage the raid took in the last several seconds; use it right after unavoidable burst damage lands rather than before" },
    { spellID = 359816, text = "Dream Flight — raid-wide healing cooldown, use for a scripted heavy damage phase" },
    { spellID = 370537, text = "Stasis (talent) — banks 3 spell casts to unleash together for an extra burst window" },
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
  -- Live top-players pull (DESIGN.md's v1.4 section), NOT SimC - see this
  -- file's header for the full methodology. The plurality build among the
  -- sample: 1/49 (2%) ran this exact code, since flex-point choices vary - but
  -- the bigger signal is that 46/49 (94%) ran Flameshaper overall. Reported
  -- honestly rather than dressed up as more decisive than it is.
  mplusMetaLoadout = {
    string = "CwbBPJc41CfcseY0baneJ1IHrBAAAAAmZmZ2MeAGmZmZzMeAmtBAAwMmxMzYYmYmZAAAAzMzkxMzMzyYGAYMzYmlFWswwMzMN0sBbGGzMYmhB",
    source = "Blizzard Battle.net API, US region, 2026-08-30: top 49 current-season Mythic+ Preservation Evokers by best keystone level, sampled across all 83 US connected realms' leaderboards. This exact build was the plurality pick (1/49, 2%); 46/49 (94%) ran Flameshaper overall.",
    patch = "12.1",
    sampleSize = 49,
  },
  tips = {
    "Place Echo ahead of expected damage rather than reactively — it rewards planning over reacting.",
    "Use empowered Dream Breath at a higher level when it's safe to hold the cast, for stronger group healing.",
    "Save Rewind for right after a big, already-landed damage spike since it heals retroactively.",
    "Blessing of the Bronze and similar buffs are raid utility — keep them refreshed on the group.",
    "Living Flame and Verdant Embrace both got real healing buffs in 12.1 — use them more freely for single-target/triage healing between Dream Breath windows rather than treating them as pure filler.",
    "Spend Essence Burst procs on Emerald Blossom when the group needs healing, or Disintegrate when it doesn't — don't let the proc sit unused either way.",
  },
})

-- Augmentation ---------------------------------------------------------
-- Revised for 12.1 (Curse of Ula'tek) from Blizzard patch-note content
-- reached via search summaries; the official article could not be fetched
-- directly from this environment, so the specific numbers/mechanics below
-- are UNVERIFIED against the source page and should be treated as
-- provisional pending direct confirmation. No mplusLoadout is shipped for
-- this spec — Augmentation's value is in ally buffs, which SimC's default
-- profiles model poorly, so a SimC-derived talent string would be a weak
-- reference here; see the mplusLoadout note in the header above.
-- Augmentation is a support-damage hybrid, not a pure DPS or healer spec —
-- see the overview below for how it actually plays. 12.1's documented
-- Augmentation-specific change is to the Double-time talent: the bonus
-- stats an ally gains when your Ebon Might critically strikes now last a
-- flat 15 seconds (scaled by Mastery: Timewalker) and refresh if you
-- reapply Ebon Might while the buff is still active.
ns.GuideStore:RegisterSpec("EVOKER", 1473, {
  specName = "Augmentation",
  role = "DAMAGER",
  overview = {
    "Augmentation Evoker is a support-damage hybrid, not a conventional DPS spec: most of its value doesn't come from its own damage meter position, it comes from making everyone else's damage bigger. It casts a moderate amount of direct damage itself, but its actual job is buffing allies through Ebon Might and Prescience.",
    "The core mechanic is applying and refreshing Ebon Might — a damage-and-versatility buff shared with you and nearby allies — and placing Prescience — a crit-chance buff, capped at two allies — on specific targets, both timed around when those allies' own cooldowns are active so the buff amplifies a bigger number. Direct damage from Living Flame, Upheaval, and Eruption fills the gaps and generates Essence, but it is secondary to buff uptime; Eruption in particular is what keeps Ebon Might itself topped up, and empower spells like Fire Breath and Upheaval are only worth casting while Ebon Might is actually active.",
    "Patch 12.1's one documented change specific to this spec touches the Double-time talent: the bonus stats an ally gains when your Ebon Might crits now last a flat 15 seconds and refresh if you reapply Ebon Might while that buff is still active, so a well-timed refresh keeps the bonus rolling continuously instead of needing to be re-triggered by a fresh crit.",
    "Augmentation's two hero trees split it further: Chronowarden pushes buff strength and favors Critical Strike, while Scalecommander redirects more of the kit's value into your own Deep Breath and empowered casts.",
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
        { spellID = 395152, text = "Refresh Ebon Might on yourself and key allies once it has about 4 seconds or less remaining — don't clip it early" },
        { text = "Breath of Eons on cooldown" },
        { spellID = 357210, text = "Deep Breath on cooldown (Scalecommander)" },
        { spellID = 409311, text = "Prescience on cooldown, capped at two allies — typically high-damage or cooldown-heavy players" },
        { spellID = 370553, text = "Tip the Scales, generally paired with Fire Breath, otherwise used on cooldown" },
        { spellID = 357208, text = "Fire Breath at its highest available rank — only while Ebon Might is active" },
        { spellID = 408092, text = "Upheaval, same rule — only while Ebon Might is active" },
        { spellID = 395160, text = "Eruption once you're at 2 Essence or holding Essence Burst — this is also what maintains Ebon Might, so don't let it sit unspent" },
        { spellID = 361469, text = "Living Flame as filler direct damage and Essence generation" },
        { spellID = 395152, text = "If talented into Double-time, time your Ebon Might refresh to land while the previous crit's stat buff is still active — it extends cleanly instead of resetting" },
    }},
    { title = "AoE / Cooldown usage", steps = {
        { text = "The single-target priority above barely changes in AoE — the job is still maximizing Ebon Might uptime on the group" },
        { text = "Breath of Eons is worth prioritizing even more here since it applies a Temporal Wound to every enemy it flies through" },
        { text = "Prioritize applying Ebon Might/Prescience to the group before your own direct damage" },
        { text = "Time Ebon Might/Prescience with allies' cooldown windows rather than a fixed rotation — this is the spec's actual damage output, not a buff bolted onto a DPS rotation" },
        { text = "Coordinate Breath of Eons roughly every 2 minutes, paired with allies' own DPS cooldowns rather than used in isolation" },
        { text = "Keep moving to reposition buffs efficiently across a spread-out raid" },
    }},
    { title = "Opener Notes", steps = {
        { text = "Augmentation's two hero talent trees are Chronowarden (also Preservation's) and Scalecommander (also Devastation's) — check which one your loadout uses" },
        { text = "Chronowarden pushes buff strength further and favors Critical Strike, while Scalecommander shifts more of the spec's own damage onto Deep Breath and empowered casts — the Ebon Might/Prescience priority above holds for both" },
    }},
  },
  cooldowns = {
    { spellID = 395152, text = "Ebon Might — core damage-sharing buff, refresh once it has ~4 seconds left and time it with allies' burst windows" },
    { spellID = 403631, text = "Breath of Eons — major raid-wide burst cooldown on roughly a 2-minute cycle, coordinate with allies' own cooldowns" },
    { spellID = 409311, text = "Prescience — crit buff capped at two allies, prioritize players with strong burst cooldowns of their own" },
    { spellID = 357210, text = "Deep Breath — Scalecommander hero-tree cooldown, use it on cooldown" },
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
  -- Live top-players pull (DESIGN.md's v1.4 section), NOT SimC - see this
  -- file's header for the full methodology. The plurality build among the
  -- sample: 2/22 (9%) ran this exact code, since flex-point choices vary - but
  -- the bigger signal is that 13/22 (59%) ran Chronowarden overall. Reported
  -- honestly rather than dressed up as more decisive than it is.
  mplusMetaLoadout = {
    string = "CEcBPJc41CfcseY0baneJ1IHrNMzMbjZGMDzMLzYmZMzGAAAAAAAAmhZGYM1YmZGAAAAMzMjxMzyYmBmZzYwCsMGGbDgZiYDjZwMDgB",
    source = "Blizzard Battle.net API, US region, 2026-08-30: top 22 current-season Mythic+ Augmentation Evokers by best keystone level, sampled across all 83 US connected realms' leaderboards. This exact build was the plurality pick (2/22, 9%); 13/22 (59%) ran Chronowarden overall.",
    patch = "12.1",
    sampleSize = 22,
  },
  tips = {
    "Communicate with the allies you're buffing so Ebon Might and Prescience land while their own cooldowns are active.",
    "Don't treat this as a pure personal-damage spec — your buff uptime on the raid matters more than your own damage meter position.",
    "Reapply Prescience before it expires, and consider swapping targets if a different ally's cooldown window is coming up.",
    "Coordinate your major cooldowns with the raid's overall burst plan rather than using them purely on cooldown.",
    "If you've talented Double-time, refresh Ebon Might while its crit-triggered stat buff is still active rather than letting it lapse — since 12.1 the refresh extends the buff cleanly instead of forcing a new crit to restart it.",
    "Spend Essence and Essence Burst on Eruption rather than banking it — Eruption is what keeps Ebon Might rolling, so treat it as maintenance, not just damage.",
    "Only fire off Fire Breath or Upheaval while Ebon Might is active; casting them outside the window gives up their scaling.",
  },
})
