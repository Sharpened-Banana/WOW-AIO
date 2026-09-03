local ADDON, ns = ...

-- SpecSage guide data: Warlock
-- Content targets Midnight (patch 12.1). Specs below with an `mplusLoadout`
-- field have that talent string (only) cross-checked against
-- SimulationCraft's public profiles (github.com/simulationcraft/simc,
-- GPLv3) as of patch 12.1; specs without one have no such reference.
-- Rotation/overview/tips/gear prose throughout this file is hand-authored
-- and was reviewed for Midnight ability changes, not derived from or
-- checked against SimC's APLs, and was not re-verified against current
-- tuning this pass — EXCEPT Affliction (265), Demonology (266), and Destruction (267),
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
-- two hero talent trees, for the one spec that didn't already have one
-- inline (Destruction). Affliction already carried a correct hero-tree
-- note and was left as-is. Demonology's note went through two rounds this
-- session: it originally read Diabolist/Soul Harvester (correct - it was
-- flagged as wrong on the assumption that Hellcaller must fill Demonology's
-- second slot by elimination from Affliction/Destruction's confirmed
-- pairs, and "corrected" to Diabolist/Hellcaller), then a later, more
-- careful audit found Demonology's own SimC profile dispatches to two
-- separate action lists - `diabolist` (talent.diabolic_ritual) and
-- `soulharvest` (talent.demonic_soul) - with zero Hellcaller references
-- anywhere in the file, confirming the original text was right and
-- restoring it. Lesson: check a spec's own file for its real branch names
-- before inferring a pairing from other specs' files.
-- Overview/rotation/tips for Affliction and Demonology were also corrected
-- this pass: Affliction's Malefic Rapture has zero references in SimC's
-- current profile (replaced by Unstable Affliction + the new Dark Harvest
-- as shard spenders, Malefic Grasp as filler); Demonology's Summon
-- Vilefiend is gone as a separate cast (folded into Call Dreadstalkers
-- itself - "Vilefiend added to dog cast" per a Blizzard forum post) and
-- Grimoire: Felguard was replaced by Grimoire: Imp Lord / Grimoire: Fel
-- Ravager.
-- A later pass (2026-09-01) enriched all three specs' overview/rotation/
-- cooldowns/tips with opener sequences, single-target-vs-AoE priority
-- nuances, cooldown-syncing notes, and hero-talent-caused differences,
-- drawing on guide sites (Wowhead/Icy Veins/Maxroll/Method/Boostmatch),
-- now a permitted source per repo policy (see
-- .claude/skills/specsage-refresh/SKILL.md). All prose was rewritten in
-- SpecSage's own words rather than copied from any source, and every
-- spellID added was verified against Wowhead rather than guessed (one
-- casualty of that verification: Vile Taint, which the compendium this
-- pass drew from still listed for Affliction AoE, was confirmed removed
-- in patch 12.0.0 and was NOT added back). This pass built on top of the
-- already-corrected Dark Harvest/Vilefiend/Grimoire mechanics above and
-- did not touch Demonology's verified Diabolist/Soul Harvester pairing.
-- raidLoadout follow-up (2026-09-02): checked SimC's `midnight` branch
-- fresh - still exactly one profile per spec for Demonology and
-- Destruction, no genuinely separate raid build to source a distinct field
-- from. Enriched both specs' hero-talent notes instead with the source
-- material's raid-vs-M+ framing (informational text, no opaque talent
-- string needed or risked).
-- This is community-maintained, conventional guidance (keep-it-simple stat
-- priorities, long-standing rotation patterns) and is NOT a claim of
-- sim-perfect or bleeding-edge optimal play.
-- To edit: find the RegisterSpec(...) block for the spec you want to change
-- and edit the table in place. To add a new tip/step, insert a new entry in
-- the relevant array. Keep this file data-only — no logic beyond the calls
-- below. See DESIGN.md "Guide data schema" for the full table shape.

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

-- Affliction ---------------------------------------------------------------
ns.GuideStore:RegisterSpec("WARLOCK", 265, {
  specName = "Affliction",
  role = "DAMAGER",
  overview = {
    "Affliction Warlock is a damage-over-time spec that ramps up over the course of a fight, layering Agony, Corruption, and Unstable Affliction into a strong sustained-damage profile, spending shards on Unstable Affliction and the new Dark Harvest for periodic burst.",
    "The core resource is Soul Shards, generated from dots ticking and spent on Unstable Affliction and Dark Harvest — Malefic Rapture no longer exists, replaced by this pair as the shard-spending core. Malefic Grasp is now the channeled filler between spenders. Agony's damage scales up the longer it's kept active on a target, rewarding strong dot uptime.",
    "Bring Affliction when a fight rewards consistent damage over time, has multiple targets to dot up, or has a long fight length that lets your damage ramp — it's less ideal for very short burst-only encounters.",
  },
  statPriority = {
    { stat = "primary" },
    { stat = "haste" },
    { stat = "crit" },
    { stat = "versatility" },
    { stat = "mastery" },
  },
  rotation = {
    { title = "Opener", steps = {
        { spellID = 980, text = "Agony first to start it ramping as early as possible" },
        { text = "Corruption (Wither under Hellcaller) to add a second dot" },
        { spellID = 30108, text = "Unstable Affliction for shard generation and damage" },
        { spellID = 48181, text = "Haunt once your dot board is established" },
        { spellID = 205180, text = "Summon Darkglare (or Soul Rot, talent-dependent) once dots are rolling, together with potions/trinkets/racials for an early burst window" },
        { text = "Dark Harvest right alongside Darkglare to open the burst" },
        { text = "Opener Notes: Affliction splits along the Soul Harvester and Hellcaller hero trees — both keep the dot-then-spend loop above, Hellcaller leans further into Seed of Corruption/Haunt on cleave pulls" },
    }},
    { title = "Single Target", steps = {
        { spellID = 980, text = "Keep Agony active at all times, ramped to its full 6-stack ceiling — refresh before it falls off" },
        { text = "Keep Corruption (or Wither under Hellcaller) active at all times" },
        { spellID = 30108, text = "Unstable Affliction on cooldown for shard generation" },
        { text = "Unstable Affliction and Dark Harvest to spend shards once dots are stacked — spending a shard on Unstable Affliction also shortens Dark Harvest's cooldown, so don't hoard shards past that" },
        { spellID = 235155, text = "Malefic Grasp as your channeled filler between spenders" },
        { spellID = 198590, text = "Drain Soul on a Nightfall proc, or as filler when nothing better is available" },
    }},
    { title = "AoE", steps = {
        { spellID = 980, text = "Agony on each target, prioritizing ones that will live longest" },
        { spellID = 27243, text = "Seed of Corruption (or Corruption/Wither per talents) to spread dots across the pack" },
        { text = "Unstable Affliction and Dark Harvest across dotted targets — spend shards once several targets are dotted" },
        { spellID = 205179, text = "Phantom Singularity (talent) for extra AoE damage over time" },
        { text = "In Mythic+, 'shard snipe' a target that's about to die with Unstable Affliction/Drain Soul to bank a shard before it's lost" },
        { text = "Keep re-dotting targets as they come into range rather than tunneling one target" },
    }},
  },
  cooldowns = {
    { spellID = 205180, text = "Summon Darkglare — spends dots for instant damage and extends them; pool shards and use once dots are well-established" },
    { spellID = 48181, text = "Haunt — short cooldown, weave it in frequently rather than saving it" },
    { text = "Dark Harvest — short, frequent shard spender; keep it cycling rather than holding it for a single big moment" },
    { text = "Soul Rot (talent) — burst window, line up with Darkglare and raid cooldowns" },
    { text = "Malevolence (Hellcaller hero talent) — burst cooldown, line up with Darkglare" },
    { spellID = 108416, text = "Dark Pact — defensive cooldown, absorbs damage using health as a resource" },
    { spellID = 104773, text = "Unending Resolve — major defensive, use against heavy incoming damage" },
    { text = "Mortal Coil / Howl of Terror — utility CC, situational" },
  },
  consumables = {
    { slot = "Flask", text = "Flask of Tempered Swiftness — matches this spec's top secondary; Flask of Alchemical Chaos is the flex pick if your stat weights are close" },
    { slot = "Food", text = "Loa's Gathering or Feast of Knowledge for raid (Stamina + your highest secondary); Hearty Venom-Spiced Cutlets or Puffer Plate for Mythic+/personal (prefer the Hearty version for death persistence)" },
    { slot = "Potion", text = "Tempered Potion, used during a burst window. Liquid Luster (builds Versatility over 30s) is a strong ramp/M+ alternative, Potion of Unwavering Focus if you want a pure single-target pick instead; always carry Concentrated Silvermoon Health Potions for the emergency heal." },
    { slot = "Weapon", text = "Not applicable" },
    { slot = "Enchants", text = "Max-rank Intellect enchants on cloak and rings" },
    { slot = "Gems", text = "Intellect/secondary stat gems in available sockets" },
    { slot = "Augment Rune", text = "Crystallized Augment Rune (1-hour primary stat) for progression pulls and high keys; the reusable Ethereal Augment Rune the rest of the time" },
  },
  gear = {
    { slot = "Head", text = "One of your tier-set slots — the four-piece bonus is worth chasing since it reinforces your dot-and-shard-spender damage engine. Season 2's set bonus boosts Corruption and Agony, and rewards a heavier Unstable Affliction build (each active UA adds a stacking damage bonus, and Seed of Corruption now applies a partial UA too) at four pieces." },
    { slot = "Chest", text = "A large stat budget and often your other tier piece — lean into Haste first to smooth dot ticks and shard generation" },
    { slot = "Neck", text = "Usually has a socket — fill it and prioritize Haste, then Mastery, over Critical Strike" },
    { slot = "Ring", text = "No set bonus tying you down — use rings to round out Haste and Mastery wherever your gear is thin" },
    { slot = "Trinket", text = "One on-use trinket timed with Summon Darkglare/Soul Rot so its burst lands while your dots are fully stacked" },
    { slot = "Trinket", text = "A passive Intellect or secondary-stat trinket to keep sustained dot damage strong the rest of the fight" },
    { slot = "Weapon", text = "Take the highest weapon damage one-hand-plus-off-hand or staff available — type matters far less than item level for a dot-based caster" },
    { slot = "Off-hand", text = "A caster off-hand that adds Haste or Mastery keeps your dot ramp and shard generation smooth" },
  },
  mplusLoadout = {
    string = "CkQAAAAAAAAAAAAAAAAAAAAAAwMzMzoZhhZmZmlBAAYmZZ2mZmFzAAjllBGwEMDbBG2GAAAmBAAwMDzMjBzwMzMzMGMzMzAAGwA",
    source = "SimulationCraft default profile (credit, not endorsement of 'best')",
    patch = "12.1",
  },
  -- Live top-players pull (DESIGN.md's v1.4 section), NOT SimC - see this
  -- file's header for the full methodology. The plurality build among the
  -- sample: 5/50 (10%) ran this exact code, since flex-point choices vary - but
  -- the bigger signal is that 44/50 (88%) ran Soul Harvester overall. Reported
  -- honestly rather than dressed up as more decisive than it is.
  mplusMetaLoadout = {
    string = "CkQAMrNP5kak+EBqLfUa3dMm+yMjZGNbmx2MzYWGAAwMzsMLmZ2GDAM2WGYATwMsFYYbAAAYGAAAzMjZMzsNGzYMzMzYYmZGAgBMA",
    source = "Blizzard Battle.net API, US region, 2026-08-30: top 50 current-season Mythic+ Affliction Warlocks by best keystone level, sampled across all 83 US connected realms' leaderboards. This exact build was the plurality pick (5/50, 10%); 44/50 (88%) ran Soul Harvester overall.",
    patch = "12.1",
    sampleSize = 50,
  },
  tips = {
    "Never let Agony or Corruption fall off early — dropped dots and re-ramping cost significant damage.",
    "Don't dump Unstable Affliction/Dark Harvest with only one or two dots active; wait for a fuller board when possible.",
    "Pre-dot targets that are about to become active (adds spawning soon) if you can safely reach them.",
    "Plan Darkglare/Soul Rot around when your dots will be at strong uptime across the most targets.",
    "Spend shards on Unstable Affliction rather than hoarding them — it also shortens Dark Harvest's cooldown, so it pays for itself twice.",
    "In Mythic+, snipe a dying add with Unstable Affliction or Drain Soul to bank a shard before it's lost for good.",
  },
})

-- Demonology -----------------------------------------------------------
ns.GuideStore:RegisterSpec("WARLOCK", 266, {
  specName = "Demonology",
  role = "DAMAGER",
  overview = {
    "Demonology Warlock is a pet-and-cooldown spec built around summoning waves of demons and popping Demonic Tyrant to empower them all at once for a massive burst window, repeated on cooldown throughout the fight.",
    "The core loop is generating Soul Shards from Demonbolt/Shadow Bolt and spending them on Call Dreadstalkers (which now also summons a Vilefiend as part of the same cast) to build up a pack of demons, then using Grimoire: Imp Lord or Grimoire: Fel Ravager (talent-dependent, replacing the old standalone Grimoire: Felguard) before popping Summon Demonic Tyrant, which empowers all active demons and extends their duration.",
    "Bring Demonology when you want a highly cooldown-driven, pet-management playstyle with big periodic burst windows and strong pad-the-numbers cleave from empowered demons.",
  },
  statPriority = {
    { stat = "primary" },
    { stat = "haste" },
    { stat = "crit" },
    { stat = "mastery" },
    { stat = "versatility" },
  },
  rotation = {
    { title = "Opener", steps = {
        { spellID = 264130, text = "Power Siphon roughly 5 seconds before pulling, if you're talented into Inner Demons" },
        { text = "Pre-cast two Shadow Bolts (or one Demonbolt if you skipped Power Siphon) timed to land right as combat starts" },
        { spellID = 104316, text = "Call Dreadstalkers to build your demon pack — Vilefiend is no longer a separate summon, it's folded into this same cast" },
        { text = "Grimoire: Imp Lord or Grimoire: Fel Ravager (talent-dependent) to add another pet before Tyrant" },
        { spellID = 265187, text = "Summon Demonic Tyrant once your demons are out, to empower and extend the full pack" },
        { text = "Opener Notes: Demonology splits along the Diabolist and Soul Harvester hero trees (not Hellcaller, which pairs with Affliction and Destruction instead) — check which one your loadout uses. SimC's current profile runs a genuinely separate action list for each (gated on talent.diabolic_ritual vs talent.demonic_soul), not just a shared list with a few swapped lines. As a starting point, Diabolist (SimC's default) suits raid single-target/burst better, while Soul Harvester is competitive for pure single-target and sees use in some Mythic+ variants — re-sim if you're unsure" },
    }},
    { title = "Single Target", steps = {
        { spellID = 104316, text = "Call Dreadstalkers on cooldown — its Vilefiend comes along automatically, and you want both up before you pop Tyrant" },
        { spellID = 265187, text = "Summon Demonic Tyrant once Dreadstalkers are active and you're sitting on 5 shards" },
        { text = "Summon Doomguard on cooldown" },
        { spellID = 264130, text = "Power Siphon once you have 2+ Wild Imps and 2 or fewer stacks of Demonic Core" },
        { text = "Hand of Gul'dan (or Ruination, talent-dependent) if you're about to overcap shards" },
        { spellID = 264178, text = "Demonbolt at 2+ stacks of Demonic Core" },
        { spellID = 105174, text = "Hand of Gul'dan at 3 shards to dump excess shards and apply Shadowflame damage" },
        { text = "Shadow Bolt as filler when nothing else applies" },
        { text = "Pool shards and demon summons for the next Demonic Tyrant window rather than using them piecemeal" },
    }},
    { title = "AoE", steps = {
        { spellID = 105174, text = "Hand of Gul'dan on cooldown for its AoE Shadowflame damage" },
        { text = "Call Dreadstalkers as normal — its demons (including the folded-in Vilefiend) cleave naturally" },
        { spellID = 196277, text = "Implosion (talent) at 6 Wild Imps to detonate the pack for burst AoE" },
        { spellID = 267211, text = "Bilescourge Bombers on cooldown" },
        { text = "Keep pets attacking the highest-priority target so cleave lands on real threats" },
        { spellID = 265187, text = "Time Demonic Tyrant for when the full pack is engaged on the pull" },
    }},
  },
  cooldowns = {
    { spellID = 265187, text = "Summon Demonic Tyrant — main burst window (1-minute cooldown), use once your demon pack is built and pool shards for it, always with Dreadstalkers already active" },
    { text = "Grimoire: Imp Lord or Grimoire: Fel Ravager — extra pet damage, use before or during a Tyrant window per your build" },
    { text = "Summon Doomguard — secondary pet cooldown, use on cooldown alongside your other pet summons" },
    { spellID = 108416, text = "Dark Pact — defensive cooldown, absorbs damage using health as a resource" },
    { spellID = 104773, text = "Unending Resolve — major defensive, use against heavy incoming damage" },
  },
  consumables = {
    { slot = "Flask", text = "Flask of Tempered Swiftness — matches this spec's top secondary; Flask of Alchemical Chaos is the flex pick if your stat weights are close" },
    { slot = "Food", text = "Loa's Gathering or Feast of Knowledge for raid (Stamina + your highest secondary); Hearty Venom-Spiced Cutlets or Puffer Plate for Mythic+/personal (prefer the Hearty version for death persistence)" },
    { slot = "Potion", text = "Tempered Potion, used during a Demonic Tyrant window. Liquid Luster (builds Versatility over 30s) is a strong ramp/M+ alternative, Potion of Unwavering Focus if you want a pure single-target pick instead; always carry Concentrated Silvermoon Health Potions for the emergency heal." },
    { slot = "Weapon", text = "Not applicable" },
    { slot = "Enchants", text = "Max-rank Intellect enchants on cloak and rings" },
    { slot = "Gems", text = "Intellect/secondary stat gems in available sockets" },
    { slot = "Augment Rune", text = "Crystallized Augment Rune (1-hour primary stat) for progression pulls and high keys; the reusable Ethereal Augment Rune the rest of the time" },
  },
  gear = {
    { slot = "Head", text = "One of your tier-set slots — the four-piece bonus is built around your demon-summon burst, so it's usually worth prioritizing over raw item level. Season 2's set bonus boosts Wild Imp damage and Implosion, with the four-piece giving depleted Wild Imps a chance to Implode on their own — exact numbers have moved in hotfixes, check your current tooltip." },
    { slot = "Chest", text = "A big stat budget and likely your other tier piece — lean Haste first to shorten the ramp into each Demonic Tyrant window" },
    { slot = "Neck", text = "Usually carries a socket — fill it and favor Haste, then Mastery" },
    { slot = "Ring", text = "No set bonus attached — use rings to top up Haste and Mastery wherever you're light" },
    { slot = "Trinket", text = "One on-use trinket timed to pop with Summon Demonic Tyrant for maximum overlap with your empowered demons" },
    { slot = "Trinket", text = "A passive secondary-stat trinket to hold your damage floor between Tyrant windows" },
    { slot = "Weapon", text = "Take the highest weapon damage staff or one-hand-plus-off-hand you can equip — pet damage scales off your stats, not weapon type" },
    { slot = "Off-hand", text = "A caster off-hand that reinforces Haste helps you rebuild your demon pack faster between cooldowns" },
  },
  mplusLoadout = {
    string = "CoQAAAAAAAAAAAAAAAAAAAAAAwMzMzoZjhZmxsMAAAAAAAjtlBGwAmhtQGbmhZ2mlZmZMDAYMzMzAMzMmxMDAAwMzMzMjZYZAYA",
    source = "SimulationCraft default profile (credit, not endorsement of 'best')",
    patch = "12.1",
  },
  -- Live top-players pull (DESIGN.md's v1.4 section), NOT SimC - see this
  -- file's header for the full methodology. The plurality build among the
  -- sample: 3/50 (6%) ran this exact code, since flex-point choices vary - but
  -- the bigger signal is that 50/50 (100%) ran Diabolist overall. Reported
  -- honestly rather than dressed up as more decisive than it is.
  mplusMetaLoadout = {
    string = "CoQAMrNP5kak+EBqLfUa3dMm+yMmZGNbMz2MzYWGAAAAAAAwYGDLwAbjWohFjZGLz2MzMmBAmZMzMmZAGzYGbAAgxMzMGGWmxAGA",
    source = "Blizzard Battle.net API, US region, 2026-08-30: top 50 current-season Mythic+ Demonology Warlocks by best keystone level, sampled across all 83 US connected realms' leaderboards. This exact build was the plurality pick (3/50, 6%); 50/50 (100%) ran Diabolist overall.",
    patch = "12.1",
    sampleSize = 50,
  },
  tips = {
    "Pool Soul Shards and demon summons before Demonic Tyrant so the empower window has as many demons as possible.",
    "Don't let Wild Imps sit unused if running Implosion — detonate them at 6 stacks for burst rather than banking indefinitely.",
    "Keep track of Call Dreadstalkers' cooldown so it's ready to refill your pack (Dreadstalkers and Vilefiend together) before each Tyrant.",
    "Reposition pets onto priority adds quickly — cleave damage is wasted on a dead or low-value target.",
    "Soul Shards cap at 5 — spend on Hand of Gul'dan (or Ruination) before you're forced to waste shard generation by sitting at the cap.",
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
    { stat = "haste" },
    { stat = "mastery" },
    { stat = "crit" },
    { stat = "versatility" },
  },
  rotation = {
    { title = "Opener", steps = {
        { spellID = 1122, text = "Summon Infernal alongside trinkets and racials to open your first burst window" },
        { spellID = 348, text = "Immolate first to start the dot ticking" },
        { spellID = 17962, text = "Conflagrate to trigger Backdraft and generate an early shard" },
        { spellID = 29722, text = "Incinerate to build toward your first Chaos Bolt" },
        { spellID = 116858, text = "Chaos Bolt once you have shards banked, aligned with Summon Infernal" },
    }},
    { title = "Single Target", steps = {
        { spellID = 1122, text = "Summon Infernal on cooldown" },
        { spellID = 348, text = "Keep Immolate active on the target at all times (Hellcaller's Wither replaces it as the maintained dot on that hero tree)" },
        { spellID = 116858, text = "Chaos Bolt at 5 shards for big single-target damage — this outranks plain Incinerate casts once shards are banked" },
        { spellID = 17962, text = "Conflagrate at 2 charges (or on a Backdraft proc) for shard generation" },
        { spellID = 152108, text = "Cataclysm when available to refresh Immolate" },
        { spellID = 29722, text = "Incinerate as your lowest-priority filler, used only when nothing better is available" },
        { spellID = 80240, text = "Use Havoc on a second target during multi-target cleave windows" },
    }},
    { title = "AoE", steps = {
        { spellID = 80240, text = "Havoc on a second target when exactly 2 are present, to duplicate your single-target damage onto it" },
        { spellID = 152108, text = "Cataclysm to apply Immolate across the pull" },
        { spellID = 205184, text = "Roaring Blaze (talent) alongside Cataclysm to extend Immolate's uptime on every target it hits" },
        { spellID = 348, text = "Immolate on primary targets to enable Rain of Fire's bonus damage" },
        { spellID = 5740, text = "Rain of Fire as your primary AoE spender once 3+ targets are engaged" },
        { spellID = 17962, text = "Conflagrate to generate shards quickly for more Rain of Fire casts" },
        { spellID = 196447, text = "Channel Demonfire (talent) to spend Immolate uptime into extra AoE damage" },
    }},
    { title = "Opener Notes", steps = {
        { text = "Destruction's two hero talent trees are Diabolist (SimC's default; also Demonology's) and Hellcaller (also Affliction's) — check which one your loadout uses. SimC runs the same core Chaos Bolt/Incinerate priority list for both, so the difference shows up in your passive/capstone kit rather than a different sequence to play. As a starting point, Hellcaller (its reworked Wither focuses damage on the priority target) suits raid single-target/2-target/spread fights, while Diabolist's demon-and-cleave kit suits Mythic+ better — re-sim if you're unsure" },
    }},
  },
  cooldowns = {
    { spellID = 1122, text = "Summon Infernal — major burst cooldown, use aligned with a strong damage window" },
    { spellID = 80240, text = "Havoc — short cooldown that duplicates your damage onto a second target; use it proactively rather than saving it for pure single-target fights" },
    { spellID = 116858, text = "Chaos Bolt — spend banked shards during cooldown windows for maximum burst value" },
    { spellID = 108416, text = "Dark Pact — defensive cooldown, absorbs damage using health as a resource" },
    { spellID = 104773, text = "Unending Resolve — major defensive, use against heavy incoming damage" },
  },
  consumables = {
    { slot = "Flask", text = "Flask of Tempered Aggression — matches this spec's top secondary; Flask of Alchemical Chaos is the flex pick if your stat weights are close" },
    { slot = "Food", text = "Loa's Gathering or Feast of Knowledge for raid (Stamina + your highest secondary); Hearty Venom-Spiced Cutlets or Puffer Plate for Mythic+/personal (prefer the Hearty version for death persistence)" },
    { slot = "Potion", text = "Tempered Potion, used with Summon Infernal. Liquid Luster (builds Versatility over 30s) is a strong ramp/M+ alternative, Potion of Unwavering Focus if you want a pure single-target pick instead; always carry Concentrated Silvermoon Health Potions for the emergency heal." },
    { slot = "Weapon", text = "Not applicable" },
    { slot = "Enchants", text = "Max-rank Intellect enchants on cloak and rings" },
    { slot = "Gems", text = "Intellect/secondary stat gems in available sockets" },
    { slot = "Augment Rune", text = "Crystallized Augment Rune (1-hour primary stat) for progression pulls and high keys; the reusable Ethereal Augment Rune the rest of the time" },
  },
  gear = {
    { slot = "Head", text = "One of your tier-set slots — the four-piece bonus meaningfully strengthens your Chaos Bolt burst windows, so it's usually worth the set piece. Season 2's set bonus boosts Incinerate and gives it a chance to evoke Echo of Sargeras, with the four-piece making Echo of Sargeras targets take extra damage from your other spells briefly." },
    { slot = "Chest", text = "A large stat budget and often your other tier piece — push Critical Strike first since it directly scales your biggest hits" },
    { slot = "Neck", text = "Usually has a socket — prioritize Critical Strike, then Haste for more shard generation" },
    { slot = "Ring", text = "No set bonus tying you down — use rings to round out Critical Strike and Haste" },
    { slot = "Trinket", text = "One on-use trinket timed with Summon Infernal so its burst overlaps your Chaos Bolt spam" },
    { slot = "Trinket", text = "A passive stat-stick trinket to keep Incinerate/Immolate damage solid between cooldown windows" },
    { slot = "Weapon", text = "Take the highest weapon damage staff or one-hand-plus-off-hand — item level matters far more than weapon type here" },
    { slot = "Off-hand", text = "A caster off-hand leaning Critical Strike keeps your burst windows hitting as hard as possible" },
  },
  mplusLoadout = {
    string = "CsQAAAAAAAAAAAAAAAAAAAAAAwMmZGNLMzmZmZWmFzMzsYMWMDAAmZGzMziNYgZxoxMAmtYjBAAGDM2AAmZwYGzYDAAwMzMAAMGG",
    source = "SimulationCraft default profile (credit, not endorsement of 'best')",
    patch = "12.1",
  },
  -- Live top-players pull (DESIGN.md's v1.4 section), NOT SimC - see this
  -- file's header for the full methodology. The plurality build among the
  -- sample: 3/50 (6%) ran this exact code, since flex-point choices vary - but
  -- the bigger signal is that 34/50 (68%) ran Diabolist overall. Reported
  -- honestly rather than dressed up as more decisive than it is.
  mplusMetaLoadout = {
    string = "CsQAMrNP5kak+EBqLfUa3dMm+yMMzoZzMz2MzYWmNzMzsYmZZZMAAYGjZmZDMmxwCZgthFaswAAAjBDAwMDwYGzMbAAAmZmBAAzwA",
    source = "Blizzard Battle.net API, US region, 2026-08-30: top 50 current-season Mythic+ Destruction Warlocks by best keystone level, sampled across all 83 US connected realms' leaderboards. This exact build was the plurality pick (3/50, 6%); 34/50 (68%) ran Diabolist overall.",
    patch = "12.1",
    sampleSize = 50,
  },
  tips = {
    "Never let Immolate fall off the target — it feeds Rain of Fire and Channel Demonfire damage.",
    "Don't cap Soul Shards; if you're at 5 shards and generating more, spend one before it's wasted.",
    "Save a Backdraft-fueled Conflagrate burst for right before Chaos Bolt spam during a cooldown window.",
    "Use Havoc proactively on cleave/2-target windows rather than only on pure single-target fights.",
    "Don't let Conflagrate sit at 2 charges — spend one before a third generates and overflows.",
    "On a big pull, use Cataclysm (with Roaring Blaze if talented) to apply Immolate everywhere at once rather than casting it target by target.",
  },
})
