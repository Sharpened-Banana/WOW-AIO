local ADDON, ns = ...

-- SpecSage guide data: Death Knight (Blood 250, Frost 251, Unholy 252)
-- Content targets Midnight (patch 12.1). Specs below with an `mplusLoadout`
-- field have that talent string (only) cross-checked against
-- SimulationCraft's public profiles (github.com/simulationcraft/simc,
-- GPLv3) as of patch 12.1; specs without one have no such reference.
-- Rotation/overview/tips/gear prose throughout this file is hand-authored
-- and was reviewed for Midnight ability changes, not derived from or
-- checked against SimC's APLs, and was not re-verified against current
-- tuning this pass — EXCEPT Blood (250), Frost (251), and Unholy (252),
-- which each gained an `mplusMetaLoadout` (DESIGN.md's v1.4 section) this
-- pass: pulled live from Blizzard's own Battle.net Game Data API
-- (client-credentials OAuth, US region) rather than SimC, on 2026-08-30.
-- Methodology: every current-season Mythic+ leaderboard (8-dungeon pool,
-- period 1078) across all 83 US connected realms was scanned (top 20 groups
-- per realm/dungeon) for each spec's group members; the top-observed-keystone
-- characters (up to 50 per spec) had their live `specializations` looked up
-- for their active loadout's `talent_loadout_code`. See each field's own
-- `source` comment for the resulting distribution.
-- Unholy's overview/rotation/tips were also corrected this pass: they
-- described the old Festering Wound stacking debuff, which SimC's current
-- `midnight` branch profile and Blizzard's own Midnight Pre-Expansion
-- Content Update Notes both confirm is gone - Festering Strike now sets up
-- a player-side buff that makes the next 2-3 Scourge Strikes each summon a
-- Lesser Ghoul instead (SimC: buff.lesser_ghoul_ready gating Scourge
-- Strike; patch notes: "Festering Strike has been redesigned").
-- This is community-maintained conventional guidance (stat priorities and
-- rotations that match the spec's long-standing design) — not a claim of
-- bleeding-edge sim-perfect optimization.
-- To edit: change the strings/tables below and reload. To add a spec pack,
-- call ns.GuideStore:RegisterSpec(classToken, specID, guideTable) from any
-- addon that loads after SpecSage; see Data/API.lua for validation rules.

-- Consumables/gear pass (2026-09-01, same session as the rotation-guide
-- enrichment above): every spec's Flask/Food/Potion/Augment Rune entries
-- were refreshed to the current Season 2 consumable system (stat-matched
-- "Flask of Tempered <X>" flasks rather than the old generic "Flask of
-- Alchemical Chaos" placeholder used everywhere; current food/potion/
-- augment-rune names), and specs with concrete Season 2 tier-set 2pc/4pc
-- effects (per the same guide-site sources) had that detail appended to
-- their Head gear entry - specs the sources gave no specific tier numbers
-- for were left with their existing generic tier-set mention rather than
-- inventing specifics. statPriority was deliberately NOT touched in this
-- pass either: stat-priority orderings are exactly the kind of contested
-- judgment call (not a mechanically-determined fact) this repo's policy
-- says to flag rather than silently adopt, and neither source gave a
-- confident order clearly better than what already shipped.
if not ns.GuideStore then return end

ns.GuideStore:RegisterSpec("DEATHKNIGHT", 250, {
  specName = "Blood",
  role = "TANK",
  overview = {
    "Blood Death Knight is a self-healing tank that plays around Death Strike, converting Runic Power and recent damage taken into a large heal, while Bone Shield charges provide flat physical damage reduction. It rewards proactive Death Strike timing over purely reactive healing.",
    "The core resources are Runes and Runic Power — Runes are spent on Marrowrend (Bone Shield), Blood Boil, and Heart Strike, while Runic Power builds toward Death Strike's healing component. Blood Boil's Blood Plague also stacks Hemostasis, a Death Strike damage/healing buff, and can proc Crimson Scourge for a free Death and Decay, so Blood Boil and Death Strike timing matter just as much as topping up Bone Shield via Marrowrend.",
    "Blood brings excellent self-sustain, strong AoE threat through Death and Decay, and solid group utility (Anti-Magic Zone, grip), making it a reliable tank for both progression raiding and Mythic+ where consistent self-healing reduces external healer load. Its hero talents diverge more than most tank specs: Deathbringer layers Reaper's Mark's execute-style damage onto the core loop, while San'layn needs Bone Shield charges and its own resource banked before its Vampiric burst window opens.",
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
        { text = "Pre-pull: drop Death and Decay where you'll tank the pack and precast Raise Dead" },
        { spellID = 49576, text = "Death Grip to pull the pack in" },
        { spellID = 195182, text = "Marrowrend to establish roughly 5-6 Bone Shield stacks" },
        { spellID = 50842, text = "Blood Boil to apply Blood Plague and start building Hemostasis" },
        { spellID = 49028, text = "Dancing Rune Weapon together with Reaper's Mark (or your hero talent's own capstone) for your first burst window" },
        { spellID = 49998, text = "Death Strike to kick off the survival loop" },
    }},
    { title = "Single Target", steps = {
        { spellID = 195182, text = "Marrowrend to keep Bone Shield above 5-6 stacks" },
        { spellID = 49998, text = "Death Strike before Hemostasis climbs past 5 stacks, and sooner any time you need the heal or mitigation now" },
        { spellID = 43265, text = "Death and Decay whenever Crimson Scourge procs it for free" },
        { spellID = 50842, text = "Blood Boil when both a Blood and a Frost rune are up, or to keep roughly 2 charges banked" },
        { spellID = 206930, text = "Heart Strike as your default Blood-rune spender and Runic Power generator otherwise" },
        { text = "Don't cast Death Strike below a meaningful Runic Power threshold unless you need the heal now" },
    }},
    { title = "AoE", steps = {
        { spellID = 50842, text = "Blood Boil moves up in priority — spreading Blood Plague and stacking Hemostasis across the pull outweighs its single-target value" },
        { spellID = 43265, text = "Death and Decay is worth dropping proactively at 4+ targets, not just off a Crimson Scourge proc" },
        { spellID = 195182, text = "Marrowrend to maintain Bone Shield while multiple targets attack you" },
        { spellID = 206930, text = "Heart Strike cleaves nearby targets — still your rune-spending filler between Blood Boil and Death and Decay" },
        { spellID = 49998, text = "Death Strike on cooldown for healing during heavy incoming damage" },
        { spellID = 47568, text = "Empower Rune Weapon to refill resources during a big pull" },
        { text = "Prioritize Bone Shield uptime over pure damage during large trash pulls" },
    }},
    { title = "Mitigation", steps = {
        { spellID = 195181, text = "Bone Shield — never let this fall to zero charges" },
        { spellID = 49998, text = "Death Strike — time it for both healing and mitigation value" },
        { spellID = 48792, text = "Icebound Fortitude for the heaviest predicted damage spikes" },
        { spellID = 55233, text = "Vampiric Blood to amplify healing and effective health during a burst window" },
        { text = "Pool Runic Power slightly before a known damage spike so Death Strike lands at its strongest" },
        { text = "Minimize how many Runes go toward Bone Shield upkeep alone — that's the real Blood efficiency question, not maximizing Marrowrend casts" },
        { text = "Keep at least 3 Runes recharging when you can, and don't let Runic Power sit capped — Death Strike is your primary dump" },
    }},
    { title = "Opener Notes", steps = {
        { text = "Your hero talent choice changes what backs up Death Strike, and your opener: Deathbringer opens Dancing Rune Weapon together with Reaper's Mark for execute-style damage layered onto the core loop, while San'layn needs Bone Shield charges (and its own resource) banked before its Vampiric burst window opens — its opener and soul-spending loop diverge from Deathbringer's Reaper's Mark focus, so check your build rather than assuming a fixed extra step" },
    }},
  },
  cooldowns = {
    { spellID = 49028, text = "Dancing Rune Weapon — your core offensive cooldown; keep it and Reaper's Mark (or your hero talent's capstone) as close to lined up as possible so their windows overlap" },
    { spellID = 55233, text = "Vampiric Blood — boosts healing received and max health, use for sustained damage" },
    { spellID = 48792, text = "Icebound Fortitude — strong defensive cooldown for burst damage spikes" },
    { spellID = 47568, text = "Empower Rune Weapon — resource refill, use to enable extra Death Strikes" },
    { spellID = 51052, text = "Anti-Magic Zone — raid-wide magic damage reduction utility" },
    { spellID = 61999, text = "Raise Ally — battle-resurrection utility on a personal cooldown" },
  },
  consumables = {
    { slot = "Flask", text = "Flask of Tempered Swiftness — matches this spec's top secondary; Flask of Alchemical Chaos is the flex pick if your stat weights are close" },
    { slot = "Food", text = "Loa's Gathering or Feast of Knowledge for raid (Stamina + your highest secondary); Hearty Venom-Spiced Cutlets or Puffer Plate for Mythic+/personal (prefer the Hearty version for death persistence)" },
    { slot = "Potion", text = "A Stamina or defensive potion for dangerous pulls/phases. Liquid Luster (builds Versatility over 30s) is a strong ramp/M+ alternative, Potion of Unwavering Focus if you want a pure single-target pick instead; always carry Concentrated Silvermoon Health Potions for the emergency heal." },
    { slot = "Weapon", text = "Ironclaw Whetstone or the current-tier weapon oil" },
    { slot = "Enchants", text = "Weapon enchant for Stamina/mitigation; ring enchants for secondary stats" },
    { slot = "Gems", text = "Stamina or Stamina/secondary hybrid gems in available sockets" },
    { slot = "Augment Rune", text = "Crystallized Augment Rune (1-hour primary stat) for progression pulls and high keys; the reusable Ethereal Augment Rune the rest of the time" },
  },
  gear = {
    { slot = "Head", text = "Tier set piece — the set bonus usually matters more than a small item-level gap for a tank. Season 2's set bonus specifically: Death Strike builds a stacking Strength buff that empowers your next Marrowrend once it's stacked up, and the four-piece extends that same theme further." },
    { slot = "Neck", text = "Balance Stamina for a survivability buffer against Haste for Rune and Runic Power flow" },
    { slot = "Back", text = "Prioritize Stamina and secondary stats over a pure item-level trade" },
    { slot = "Legs", text = "Another tier slot when possible; otherwise the highest item level piece leaning Stamina and Haste" },
    { slot = "Ring", text = "Haste or Mastery rings depending on whether resource flow or Death Strike healing needs more support" },
    { slot = "Trinket", text = "One defensive on-use trinket saved for the fight's heaviest predicted damage window" },
    { slot = "Trinket", text = "One passive Stamina or avoidance trinket for a steady survivability floor" },
    { slot = "Weapon", text = "High item level weapons still carry meaningful damage for Blood — don't sacrifice too much Stamina chasing pure dps stats" },
  },
  mplusLoadout = {
    string = "CoPAAAAAAAAAAAAAAAAAAAAAAwYWmZmxMmZmhZZmZmmZxMjxMAAAAAmZmZGmZGzMjZAgZmZGAAADMwMW0YZDklBsBYGzAAAmZwgB",
    source = "SimulationCraft default profile (credit, not endorsement of 'best')",
    patch = "12.1",
  },
  -- Live top-players pull (DESIGN.md's v1.4 section), NOT SimC - see this
  -- file's header for the full methodology. The plurality build among the
  -- sample: 2/50 (4%) ran this exact code, since flex-point choices vary - but
  -- the bigger signal is that 48/50 (96%) ran San'layn overall. Reported
  -- honestly rather than dressed up as more decisive than it is.
  mplusMetaLoadout = {
    string = "CoPAkXBWxkyfx9CbGaHonEAhLxMzyMzwMmZmhZZMz0MLzYMzMGAAAAwMMzMzMjZGDAYmZmZGAAgZmtxwYGLLNW2WGmsNMsBYGDAAmZmZAjB",
    source = "Blizzard Battle.net API, US region, 2026-08-30: top 50 current-season Mythic+ Blood Death Knights by best keystone level, sampled across all 83 US connected realms' leaderboards. This exact build was the plurality pick (2/50, 4%); 48/50 (96%) ran San'layn overall.",
    patch = "12.1",
    sampleSize = 50,
  },
  tips = {
    "Keep Bone Shield charges above zero at all times — a lapsed Bone Shield is a big mitigation loss.",
    "Time Death Strike for when you actually need the heal, not purely on cooldown, when Runic Power allows pooling.",
    "Death and Decay is both a damage and threat tool — keep it under the pack during AoE pulls.",
    "Save Icebound Fortitude and Vampiric Blood for known heavy-damage phases rather than reacting after the fact.",
    "Don't spend more Runes on Bone Shield upkeep than you need to — minimizing that spend, not maximizing Marrowrend casts, is the actual Blood optimization.",
    "Cast Death Strike before Hemostasis climbs past 5 stacks so you're not leaving free healing and damage on the table.",
    "Line up Dancing Rune Weapon with Reaper's Mark (or your hero talent's own capstone) rather than using either in isolation.",
  },
})

ns.GuideStore:RegisterSpec("DEATHKNIGHT", 251, {
  specName = "Frost",
  role = "DAMAGER",
  overview = {
    "Frost Death Knight is a dual-wield or two-handed melee spec built around Obliterate and Frost Strike, spending Runes and Runic Power while chasing Killing Machine procs that guarantee critical strikes on Frost Strike and Obliterate. It plays as a burst-oriented spec with strong cooldown-driven damage windows.",
    "The core resources are Runes, spent on Obliterate below 3 targets and Frostscythe at 3+, and Runic Power, spent on Frost Strike (Glacial Advance instead in AoE). The defining mechanic is Killing Machine, a proc that guarantees a critical strike on your next Obliterate or Frost Strike, alongside Rime procs that make your next Howling Blast free and instant — spending both promptly, rather than banking them, is central to maximizing damage.",
    "Frost brings strong burst through Pillar of Frost — paired with Reaper's Mark on the Deathbringer hero talent — and, on some builds, a Breath of Sindragosa channel that extends itself the more Killing Machine and Rime procs you spend during it, making it a strong pick for both progression raiding, where Rider of the Apocalypse's straightforward single-target focus shines, and burst-heavy Mythic+, where Deathbringer's AoE tools take over.",
  },
  statPriority = {
    { stat = "primary" },
    { stat = "crit" },
    { stat = "mastery" },
    { stat = "haste" },
    { stat = "versatility" },
  },
  rotation = {
    { title = "Opener", steps = {
        { text = "Close the gap with your pre-cast, then open Pillar of Frost as you engage" },
        { spellID = 51271, text = "Macro Reaper's Mark into Pillar of Frost on the Deathbringer hero talent" },
        { text = "Frostwyrm's Fury for your first burst window: the first charge at the start of Pillar of Frost, the second roughly 12 seconds later within the same window" },
        { spellID = 49020, text = "Obliterate, Frost Strike, Empower Rune Weapon, Obliterate — the standard double-Obliterate opener sequence" },
        { text = "On a Breath of Sindragosa build, ignite the channel once your Runic Power and procs can support it" },
    }},
    { title = "Single Target", steps = {
        { spellID = 49020, text = "Obliterate as the primary Rune spender, especially with Killing Machine active" },
        { spellID = 49143, text = "Frost Strike to spend Runic Power, prioritized under Killing Machine" },
        { spellID = 49184, text = "Consume Rime procs immediately with a free, instant Howling Blast" },
        { spellID = 47568, text = "Empower Rune Weapon on cooldown for extra resources" },
        { spellID = 51271, text = "Pillar of Frost on cooldown for a burst damage window, paired with Reaper's Mark on Deathbringer" },
        { text = "If you're talented into Obliteration, generate and consume Killing Machine even more aggressively during that state — the base priority doesn't change, it just rewards playing it well" },
        { text = "Don't let Killing Machine procs go unused — spend them before they're overwritten" },
    }},
    { title = "AoE", steps = {
        { spellID = 49184, text = "Howling Blast as the primary AoE opener, spreading Frost Fever" },
        { text = "Obliterate at 1-2 targets, switching to Frostscythe at 3+ — this threshold moved up, so don't default to old two-target habits" },
        { spellID = 51271, text = "Pillar of Frost on cooldown during add waves" },
        { text = "Glacial Advance as your Runic Power spender in AoE instead of Frost Strike" },
        { spellID = 196770, text = "Remorseless Winter should already be rolling passively off Pillar of Frost via Frozen Dominion — no need to press it manually when that talent is active" },
        { spellID = 47568, text = "Empower Rune Weapon to sustain resources through a long pull" },
        { text = "Reapply Frost Fever to new adds as they join the pull" },
    }},
    { title = "Opener Notes", steps = {
        { text = "Apply Frost Fever first, then pool for a Pillar of Frost burst window" },
        { text = "Line up Empower Rune Weapon with your main cooldown for maximum resource availability" },
        { text = "Your hero talent changes which build you lean into: Rider of the Apocalypse is the more straightforward single-target/raid pick, while Deathbringer — with Reaper's Mark macroed into Pillar of Frost — is the stronger Mythic+/AoE pick, so check which one your loadout uses" },
    }},
  },
  cooldowns = {
    { spellID = 51271, text = "Pillar of Frost — core offensive cooldown, use on cooldown; Deathbringer players macro Reaper's Mark into it for the biggest combined window" },
    { spellID = 47568, text = "Empower Rune Weapon — resource cooldown, pair with your burst window" },
    { text = "Frostwyrm's Fury — burst cooldown, first charge at the start of Pillar of Frost, second roughly 12 seconds later within the same window" },
    { spellID = 152279, text = "Breath of Sindragosa (talent) — channel every second Pillar of Frost on that build; spending Killing Machine/Rime while it's active extends the duration, so the standard priority holds throughout" },
    { spellID = 48792, text = "Icebound Fortitude — major defensive cooldown for burst damage spikes" },
    { spellID = 49039, text = "Lichborne — self-healing/CC-immunity utility cooldown" },
    { spellID = 61999, text = "Raise Ally — battle-resurrection utility on a personal cooldown" },
  },
  consumables = {
    { slot = "Flask", text = "Flask of Tempered Aggression — matches this spec's top secondary; Flask of Alchemical Chaos is the flex pick if your stat weights are close" },
    { slot = "Food", text = "Loa's Gathering or Feast of Knowledge for raid (Stamina + your highest secondary); Hearty Venom-Spiced Cutlets or Puffer Plate for Mythic+/personal (prefer the Hearty version for death persistence)" },
    { slot = "Potion", text = "Tempered Potion, used inside Pillar of Frost. Liquid Luster (builds Versatility over 30s) is a strong ramp/M+ alternative, Potion of Unwavering Focus if you want a pure single-target pick instead; always carry Concentrated Silvermoon Health Potions for the emergency heal." },
    { slot = "Weapon", text = "Ironclaw Whetstone or the current-tier weapon oil" },
    { slot = "Enchants", text = "Weapon enchant for Strength/Crit; ring enchants for secondary stats" },
    { slot = "Gems", text = "Strength or Strength/secondary hybrid gems in available sockets" },
    { slot = "Augment Rune", text = "Crystallized Augment Rune (1-hour primary stat) for progression pulls and high keys; the reusable Ethereal Augment Rune the rest of the time" },
  },
  gear = {
    { slot = "Head", text = "Tier set piece — the set bonus usually matters more than a small item-level gap. Season 2's set bonus specifically boosts your Shadowfrost/Exterminate damage." },
    { slot = "Neck", text = "Favor Crit and Haste to feed Killing Machine procs" },
    { slot = "Back", text = "Secondary stats matching Crit and Haste outweigh a pure item-level chase" },
    { slot = "Legs", text = "Another tier slot when possible; otherwise the highest item level piece leaning Crit and Haste" },
    { slot = "Ring", text = "Crit or Haste rings depending on your current stat weights" },
    { slot = "Trinket", text = "One on-use Strength or damage trinket lined up with Pillar of Frost" },
    { slot = "Trinket", text = "A passive stat-stick trinket for consistent damage between cooldowns" },
    { slot = "Weapon", text = "Two matched one-handers for dual-wield, or the highest item level two-hander if running that build — check your talents before gearing" },
  },
  mplusLoadout = {
    string = "CsPAAAAAAAAAAAAAAAAAAAAAAMAGAADYYYMiBjhZGDmZmZmZmZmBAAAAAAAAgxYgBAsMMhMWwMjhBGAGmBAwA",
    source = "SimulationCraft default profile (credit, not endorsement of 'best')",
    patch = "12.1",
  },
  -- Live top-players pull (DESIGN.md's v1.4 section), NOT SimC - see this
  -- file's header for the full methodology. The plurality build among the
  -- sample: 2/50 (4%) ran this exact code, since flex-point choices vary - but
  -- the bigger signal is that 50/50 (100%) ran Deathbringer overall. Reported
  -- honestly rather than dressed up as more decisive than it is.
  mplusMetaLoadout = {
    string = "CsPAkXBWxkyfx9CbGaHonEAhLNAzMMjZGDz2MzMzMLmZkZMGDzMGMzMzMzMzMDAAAAAAAAAjZbgBsAWGmQGLYmxMzADADzMAzAD",
    source = "Blizzard Battle.net API, US region, 2026-08-30: top 50 current-season Mythic+ Frost Death Knights by best keystone level, sampled across all 83 US connected realms' leaderboards. This exact build was the plurality pick (2/50, 4%); 50/50 (100%) ran Deathbringer overall.",
    patch = "12.1",
    sampleSize = 50,
  },
  tips = {
    "Spend Killing Machine procs promptly rather than banking multiple and risking an overwrite.",
    "Rime procs make your next Howling Blast free and instant — don't let a Rime proc sit unused.",
    "Keep Frost Fever active on any target you'll be attacking for more than a few seconds.",
    "Line up Empower Rune Weapon and Pillar of Frost together whenever possible.",
    "Howling Blast is a strong AoE opener even on cooldown-limited pulls — don't save it exclusively for big packs.",
    "Switch from Obliterate to Frostscythe once you've got 3+ targets — the AoE swap point moved up from the old two-target rule.",
    "On a Breath of Sindragosa build, keep spending Killing Machine and Rime as normal while it's channeling — that's what extends the Breath, not banking procs.",
    "Deathbringer players get more value macroing Reaper's Mark into Pillar of Frost than casting it on its own.",
  },
})

ns.GuideStore:RegisterSpec("DEATHKNIGHT", 252, {
  specName = "Unholy",
  role = "DAMAGER",
  overview = {
    "Unholy Death Knight is a pet- and disease-focused melee spec built around maintaining Virulent Plague on the target and using Festering Strike to build the Festering Scythe buff, so your next 2-3 Scourge Strikes each summon a Lesser Ghoul, alongside your permanent ghoul pet.",
    "The core resources are Runes, spent on Festering Strike (banking Festering Scythe stacks) and Death and Decay, and Runic Power, spent on Death Coil (free and instant on a Sudden Doom proc) or Epidemic once several targets are up. Festering Strike's Lesser Ghoul setup replaced the older stacking Festering Wound mechanic — this is now a set-up-then-spend loop on your own buff rather than a debuff you build on the target. It's timed around Army of the Dead/Dark Transformation for burst windows: hold banked stacks so Dark Transformation's empowered Scourge Strike, Putrefy, has something to spend rather than firing it on cooldown into an empty buff.",
    "Unholy brings strong burst damage through cooldown windows, excellent sustained AoE via diseases and Death and Decay, and useful pet-based utility, making it a strong pick for fights with add phases or sustained multi-target damage requirements. San'layn needs Festering Scythe/Lesser Ghoul stacks already banked before its Dark Transformation window opens — walking in with 3 or fewer stacks noticeably underperforms — while Rider of the Apocalypse has no such setup requirement, making it the simpler of the two hero trees to pick up.",
  },
  statPriority = {
    { stat = "primary" },
    { stat = "crit" },
    { stat = "mastery" },
    { stat = "haste" },
    { stat = "versatility" },
  },
  rotation = {
    { title = "Opener", steps = {
        { text = "Outbreak to apply Virulent Plague instantly before you engage" },
        { spellID = 85948, text = "Two Festering Strike casts to bank Festering Scythe stacks before your first burst window" },
        { spellID = 42650, text = "Army of the Dead, Dark Transformation, trinket, racial, and potion together for your burst window" },
        { text = "Putrefy x2 to spend your banked stacks while Dark Transformation is active" },
        { spellID = 47541, text = "Death Coil to spend the Runic Power you built up during the burst" },
        { text = "Soul Reaper on your target, then again roughly 6 seconds after Dark Transformation, so its execute bonus lines up with the transformation" },
        { text = "Blightfall just before your Soul Reaper buff expires so its bonus isn't wasted" },
    }},
    { title = "Single Target", steps = {
        { spellID = 191587, text = "Virulent Plague kept active on the target" },
        { spellID = 85948, text = "Maintain the Festering Scythe buff — Festering Strike whenever you have no Lesser Ghoul stacks banked" },
        { text = "Soul Reaper once available, or once the target drops below 35% health" },
        { text = "Putrefy during Dark Transformation, or once you're holding 3 charges — don't oversave stacks past that" },
        { spellID = 55090, text = "Scourge Strike once you're holding at least 1 Lesser Ghoul stack" },
        { spellID = 47541, text = "Death Coil to spend Runic Power (free and instant on a Sudden Doom proc), empowered further while your pet is out" },
        { spellID = 42650, text = "Army of the Dead / Apocalypse-style cooldown on a scheduled burst window" },
        { text = "Don't let a Sudden Doom proc go unused — Death Coil it away before it's overwritten" },
    }},
    { title = "AoE", steps = {
        { spellID = 43265, text = "Death and Decay is worth casting at 2+ targets" },
        { spellID = 85948, text = "Festering Strike to bank Festering Scythe stacks across the pull" },
        { spellID = 55090, text = "Scourge Strike / Clawing Shadows cleaves nearby targets by default once you're spending stacks" },
        { text = "Swap Death Coil for Epidemic at 4+ targets — 6+ if you're inside a Forbidden Knowledge Apex window" },
        { text = "Necrotic Coil works up to about 3 targets; its Apex upgrade, Graveyard, extends that to 5" },
        { spellID = 191587, text = "Virulent Plague spread to as many targets as possible" },
        { spellID = 63560, text = "Dark Transformation to empower your pet during add waves" },
        { text = "Prioritize keeping diseases up across the whole pull over single-target spam" },
    }},
    { title = "Opener Notes", steps = {
        { text = "Apply Virulent Plague immediately, then Festering Strike to bank Festering Scythe stacks before your first burst window" },
        { text = "Time Army of the Dead / Apocalypse-style cooldowns with trinkets for maximum pet burst" },
        { text = "San'layn wants Festering Scythe/Lesser Ghoul stacks already banked before Dark Transformation goes off — walking in with 3 or fewer stacks noticeably underperforms — while Rider of the Apocalypse has no such setup requirement and plays the core loop straight, making it the simpler hero tree to pick up" },
    }},
  },
  cooldowns = {
    { spellID = 63560, text = "Dark Transformation — empowers your pet; try to line its 45-second cooldown up with Army of the Dead's 90-second one so they periodically overlap" },
    { spellID = 42650, text = "Army of the Dead — summons additional ghouls, align with burst windows" },
    { text = "Apply your diseases before Soul Reaper triggers so its disease/minion damage bonus isn't wasted" },
    { spellID = 48792, text = "Icebound Fortitude — major defensive cooldown for burst damage spikes" },
    { spellID = 49039, text = "Lichborne — self-healing/CC-immunity utility cooldown" },
    { spellID = 61999, text = "Raise Ally — battle-resurrection utility on a personal cooldown" },
  },
  consumables = {
    { slot = "Flask", text = "Flask of Tempered Swiftness — matches this spec's top secondary; Flask of Alchemical Chaos is the flex pick if your stat weights are close" },
    { slot = "Food", text = "Loa's Gathering or Feast of Knowledge for raid (Stamina + your highest secondary); Hearty Venom-Spiced Cutlets or Puffer Plate for Mythic+/personal (prefer the Hearty version for death persistence)" },
    { slot = "Potion", text = "Tempered Potion, used inside your main burst window. Liquid Luster (builds Versatility over 30s) is a strong ramp/M+ alternative, Potion of Unwavering Focus if you want a pure single-target pick instead; always carry Concentrated Silvermoon Health Potions for the emergency heal." },
    { slot = "Weapon", text = "Ironclaw Whetstone or the current-tier weapon oil" },
    { slot = "Enchants", text = "Weapon enchant for Strength/Crit; ring enchants for secondary stats" },
    { slot = "Gems", text = "Strength or Strength/secondary hybrid gems in available sockets" },
    { slot = "Augment Rune", text = "Crystallized Augment Rune (1-hour primary stat) for progression pulls and high keys; the reusable Ethereal Augment Rune the rest of the time" },
  },
  gear = {
    { slot = "Head", text = "Tier set piece — the set bonus usually matters more than a small item-level gap" },
    { slot = "Neck", text = "Favor Haste to speed up Rune regeneration and Runic Power flow" },
    { slot = "Back", text = "Secondary stats matching Haste and Mastery outweigh a pure item-level chase" },
    { slot = "Legs", text = "Another tier slot when possible; otherwise the highest item level piece leaning Haste and Mastery" },
    { slot = "Ring", text = "Haste or Mastery rings depending on your current stat weights" },
    { slot = "Trinket", text = "One on-use Strength or damage trinket lined up with Army of the Dead or Apocalypse" },
    { slot = "Trinket", text = "A passive stat-stick trinket, ideally one that also benefits pet damage" },
    { slot = "Weapon", text = "The highest item level two-hander available — weapon damage still matters for Scourge Strike swings" },
  },
  mplusLoadout = {
    string = "CwPAAAAAAAAAAAAAAAAAAAAAAAwMjZMDDz2MzMTzmZmZMjBAAAAAAAgZGmZAwyMmZ2mZGjZAbmFDDZgZjhGLAYGAGzMjZAmZmxYA",
    source = "SimulationCraft default profile (credit, not endorsement of 'best')",
    patch = "12.1",
  },
  -- Live top-players pull (DESIGN.md's v1.4 section), NOT SimC - see this
  -- file's header for the full methodology. The plurality build among the
  -- sample: 2/50 (4%) ran this exact code, since flex-point choices vary - but
  -- the bigger signal is that 38/50 (76%) ran San'layn overall. Reported
  -- honestly rather than dressed up as more decisive than it is.
  mplusMetaLoadout = {
    string = "CwPAkXBWxkyfx9CbGaHonEAhLBYmZMjZMYWGzMTjZmxMzYAAAAAAAAYmxwAglZMzsZmxMzA2MbGGyAzGDNWwAmBgxMzYGgZmxMG",
    source = "Blizzard Battle.net API, US region, 2026-08-30: top 50 current-season Mythic+ Unholy Death Knights by best keystone level, sampled across all 83 US connected realms' leaderboards. This exact build was the plurality pick (2/50, 4%); 38/50 (76%) ran San'layn overall.",
    patch = "12.1",
    sampleSize = 50,
  },
  tips = {
    "Never let Virulent Plague fall off a target you'll keep attacking.",
    "Soul Reaper is worth applying early on a target you expect to kill soon — its bonus damage triggers once that target's health drops low, not on cast.",
    "Spend Lesser Ghoul charges from Festering Strike with Scourge Strike promptly rather than sitting on them.",
    "Dark Transformation is worth using on cooldown rather than saving for a 'perfect' moment in most fights.",
    "Line up your big summon-based cooldown with a known burst or add phase for maximum value.",
    "Spending Runic Power on Death Coil/Epidemic procs Runic Corruption, which speeds up Rune regeneration — don't hoard Runic Power waiting for a 'better' moment.",
    "Don't oversave Putrefy/Festering Scythe stacks past 3 charges outside Dark Transformation.",
    "San'layn wants Festering Scythe stacks already banked before Dark Transformation — walking in empty-handed costs real damage.",
  },
})
