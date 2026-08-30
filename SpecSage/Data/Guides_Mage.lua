local ADDON, ns = ...

-- SpecSage guide data: Mage
-- Content targets Midnight (patch 12.1). Specs below with an `mplusLoadout`
-- field have that talent string (only) cross-checked against
-- SimulationCraft's public profiles (github.com/simulationcraft/simc,
-- GPLv3) as of patch 12.1; specs without one have no such reference.
-- Rotation/overview/tips/gear prose throughout this file is hand-authored
-- and was reviewed for Midnight ability changes, not derived from or
-- checked against SimC's APLs, and was not re-verified against current
-- tuning this pass — EXCEPT Arcane (62), Fire (63), and Frost (64),
-- which each gained an `mplusMetaLoadout` (DESIGN.md's v1.4 section) this
-- pass: pulled live from Blizzard's own Battle.net Game Data API
-- (client-credentials OAuth, US region) rather than SimC, on 2026-08-30.
-- Methodology: every current-season Mythic+ leaderboard (8-dungeon pool,
-- period 1078) across all 83 US connected realms was scanned (top 20 groups
-- per realm/dungeon) for each spec's group members; the top-observed-keystone
-- characters (up to 50 per spec) had their live `specializations` looked up
-- for their active loadout's `talent_loadout_code`. See each field's own
-- `source` comment for the resulting distribution.
-- This is community-maintained, conventional guidance (keep-it-simple stat
-- priorities, long-standing rotation patterns) and is NOT a claim of
-- sim-perfect or bleeding-edge optimal play.
-- To edit: find the RegisterSpec(...) block for the spec you want to change
-- and edit the table in place. To add a new tip/step, insert a new entry in
-- the relevant array. Keep this file data-only — no logic beyond the calls
-- below. See DESIGN.md "Guide data schema" for the full table shape.

if not ns.GuideStore then return end

-- Arcane -----------------------------------------------------------------
ns.GuideStore:RegisterSpec("MAGE", 62, {
  specName = "Arcane",
  role = "DAMAGER",
  overview = {
    "Arcane Mage is a burst-window spec built around managing the Arcane Charges resource and the mana tied to it. You alternate between a mana-conserving 'Arcane Blast/Barrage' setup phase and short, extremely high-damage burn windows fueled by Arcane Surge and trinkets/cooldowns.",
    "The core mechanic is Arcane Charges (0-4, stacking from Arcane Blast and Arcane Barrage): each charge increases Arcane Blast damage and mana cost while also increasing Arcane Barrage's damage when you dump them. Clearcasting procs from Arcane Barrage let you cast free, no-mana spells to extend burn windows.",
    "Bring Arcane when you want strong burst damage aligned to boss windows (bloodlust, execute phases, add spawns) and are comfortable with a rotation that rewards careful cooldown and mana planning over simple button-pressing.",
  },
  statPriority = {
    { stat = "primary" },
    { stat = "crit" },
    { stat = "mastery" },
    { stat = "haste", note = "to a comfortable breakpoint, then re-evaluate" },
    { stat = "versatility" },
  },
  rotation = {
    { title = "Opener", steps = {
        { text = "Pre-cast Arcane Blast to land as combat starts" },
        { spellID = 365350, text = "Arcane Surge to open the burn phase" },
        { spellID = 44425, text = "Arcane Barrage at 4 charges to dump and reset" },
        { text = "Opener Notes: your rotation splits along the Sunfury and Spellslinger hero trees — both still center on the Blast/Barrage/Surge loop above, just with different burst-window shaping" },
    }},
    { title = "Single Target", steps = {
        { spellID = 30451, text = "Arcane Blast to build Arcane Charges" },
        { text = "Use Clearcasting procs on free Arcane Missiles/Blast before they expire" },
        { spellID = 44425, text = "Arcane Barrage at 4 charges or when mana is low" },
        { text = "Weave in Arcane Orb / Touch of the Magi per talent build for extra charges and burst" },
        { text = "Save Arcane Surge and trinkets for your next planned burn window" },
    }},
    { title = "AoE", steps = {
        { text = "Arcane Explosion to build charges while enemies are stacked" },
        { spellID = 44425, text = "Arcane Barrage to spread damage and reset charges" },
        { text = "Use Nether Tempest / Arcane Orb (if talented) to cleave charge generation" },
        { text = "Prioritize Clearcasting procs into AoE spenders" },
        { text = "Line up burn cooldowns with add waves for maximum value" },
    }},
  },
  cooldowns = {
    { spellID = 365350, text = "Arcane Surge — opens your main burn window, use on cooldown around boss burst phases" },
    { text = "Touch of the Magi (talent) — line up before dumping Arcane Barrage for extra damage" },
    { spellID = 45438, text = "Ice Block — defensive, use to survive unavoidable burst damage" },
    { spellID = 55342, text = "Mirror Image — minor defensive/utility cooldown, use when threat or a small buffer helps" },
  },
  consumables = {
    { slot = "Flask", text = "Flask of Alchemical Chaos (Intellect)" },
    { slot = "Food", text = "A feast or personal Intellect food for the encounter" },
    { slot = "Potion", text = "Tempered Potion, used during a burn window" },
    { slot = "Weapon", text = "Not applicable (Mage uses no weapon enchant beyond ring/cloak enchants)" },
    { slot = "Enchants", text = "Max-rank Intellect enchants on cloak and rings" },
    { slot = "Gems", text = "Intellect/secondary stat gems in available sockets" },
  },
  gear = {
    { slot = "Head", text = "One of your tier-set slots — the four-piece bonus adds enough burn-window damage that it usually beats a higher item-level non-set piece" },
    { slot = "Chest", text = "A big stat budget slot and often your other tier piece — lean into Critical Strike and Mastery here, your top two secondaries" },
    { slot = "Neck", text = "Usually carries a socket — fill it and favor Critical Strike/Mastery rolls over Haste once you're past a comfortable cast-speed breakpoint" },
    { slot = "Ring", text = "Pure secondary-stat real estate with no set bonus attached — take whichever ring pushes Critical Strike and Mastery hardest" },
    { slot = "Trinket", text = "One on-use Intellect or damage trinket you can pop alongside Arcane Surge so its burst lands inside your burn window" },
    { slot = "Trinket", text = "A second, passive trinket that simply adds secondary stats so you're not dead weight between burn windows" },
    { slot = "Weapon", text = "A one-hand weapon and off-hand or a two-hand staff both work — take whichever has the higher weapon damage" },
    { slot = "Off-hand", text = "If you're wielding a one-hander, match its off-hand's secondary stats to the same Critical Strike/Mastery lean" },
  },
  mplusLoadout = {
    string = "C4DAAAAAAAAAAAAAAAAAAAAAAYGGLzMzswMDamZGAAAGAAEwMzMLLzMxCAAwMzMjNLzMzsMjxYmZwCzYmZGAgBAAYmZBAMDAGmZG",
    source = "SimulationCraft default profile (credit, not endorsement of 'best')",
    patch = "12.1",
  },
  -- Live top-players pull (DESIGN.md's v1.4 section), NOT SimC - see this
  -- file's header for the full methodology. The plurality build among the
  -- sample: 11/50 (22%) ran this exact code, since flex-point choices vary -
  -- but the bigger signal is that 50/50 (100%) ran Sunfury overall. Reported
  -- honestly rather than dressed up as more decisive than it is.
  mplusMetaLoadout = {
    string = "C4DAche08tHz49KSVf7iKFnyuNzwYZmZmFMzQzMGAAAGAwMz0sssMDAEbAAsBzMDbWmxMLzYMzMzMswMzMzMAADAAwAMzAMAYYmZA",
    source = "Blizzard Battle.net API, US region, 2026-08-30: top 50 current-season Mythic+ Arcane Mages by best keystone level, sampled across all 83 US connected realms' leaderboards. This exact build was the plurality pick (11/50, 22%); 50/50 (100%) ran Sunfury overall.",
    patch = "12.1",
    sampleSize = 50,
  },
  tips = {
    "Track your mana closely — running out mid-burn wastes the window; running out too early forces a weak conserve phase.",
    "Pre-cast your first Arcane Blast before the pull timer hits zero for a free head start.",
    "Never let a Clearcasting proc expire unused — it's free damage.",
    "Plan burn windows around raid cooldowns and boss vulnerability phases rather than using them purely on cooldown.",
  },
})

-- Fire ---------------------------------------------------------------------
ns.GuideStore:RegisterSpec("MAGE", 63, {
  specName = "Fire",
  role = "DAMAGER",
  overview = {
    "Fire Mage is a crit-and-execute spec centered on stacking Heating Up and Hot Streak procs to fire off instant, guaranteed-crit Pyroblasts. Damage is spiky, with big cooldown-aligned burst windows via Combustion.",
    "The core loop is: Fire Blast and Fireball/Scorch build Heating Up, two crits in a row (or a Fire Blast consuming Heating Up) grant Hot Streak, and Hot Streak is spent on a free, instant Pyroblast. Ignite (a damage-over-time spread from crits) rewards keeping crit up and hitting multiple targets.",
    "Bring Fire when you want a spec that shines in short, well-timed burst windows and cleave/AoE fights, and you're willing to manage Fire Blast/Phoenix Flames charges tightly around Combustion.",
  },
  statPriority = {
    { stat = "crit" },
    { stat = "primary" },
    { stat = "mastery" },
    { stat = "haste" },
    { stat = "versatility" },
  },
  rotation = {
    { title = "Opener", steps = {
        { text = "Pre-cast Pyroblast (or Scorch while moving) to enter combat with a head start" },
        { spellID = 190319, text = "Combustion once you have Heating Up or Hot Streak banked, aligned with damage cooldowns" },
        { spellID = 108853, text = "Fire Blast to convert Heating Up into Hot Streak during Combustion" },
        { text = "Opener Notes: Fire splits along the Frostfire and Sunfury hero trees — Frostfire folds in Frostfire Bolt casts, Sunfury leans harder on Meteor-timed Combustion windows, but the Heating Up/Hot Streak loop above holds either way" },
    }},
    { title = "Single Target", steps = {
        { spellID = 133, text = "Fireball as your default filler to build Heating Up" },
        { spellID = 108853, text = "Fire Blast to convert Heating Up into Hot Streak" },
        { spellID = 194466, text = "Phoenix Flames as an additional Heating Up/Hot Streak generator" },
        { spellID = 11366, text = "Pyroblast whenever Hot Streak is active" },
        { text = "Never cap Fire Blast or Phoenix Flames charges — spend before overflowing" },
    }},
    { title = "AoE", steps = {
        { spellID = 2120, text = "Flamestrike (with Hot Streak) as your primary AoE spender" },
        { text = "Fire Blast / Phoenix Flames to generate Hot Streak procs quickly" },
        { spellID = 31661, text = "Dragon's Breath to group and daze adds when appropriate" },
        { text = "Let Ignite spread damage across the pack rather than single-target dumping" },
        { text = "Time Combustion for when the full pack is engaged" },
    }},
  },
  cooldowns = {
    { spellID = 190319, text = "Combustion — main burst window, line up with Hot Streak/Heating Up banked and other raid cooldowns" },
    { spellID = 194466, text = "Phoenix Flames — extra proc generation, spend charges rather than hoarding" },
    { spellID = 108853, text = "Fire Blast — instant proc conversion, weave throughout and especially during Combustion" },
    { spellID = 45438, text = "Ice Block — defensive, negates incoming damage entirely" },
    { spellID = 80353, text = "Time Warp/Bloodlust — raid utility cooldown, coordinate with your raid's lust plan" },
  },
  consumables = {
    { slot = "Flask", text = "Flask of Alchemical Chaos (Intellect)" },
    { slot = "Food", text = "A feast or personal Intellect food for the encounter" },
    { slot = "Potion", text = "Tempered Potion, used to align with Combustion" },
    { slot = "Weapon", text = "Not applicable" },
    { slot = "Enchants", text = "Max-rank Intellect enchants on cloak and rings" },
    { slot = "Gems", text = "Intellect/secondary stat gems in available sockets" },
  },
  gear = {
    { slot = "Head", text = "One of your tier-set slots — the four-piece bonus meaningfully boosts your Hot Streak/Combustion damage, so favor the set piece over a small item-level edge elsewhere" },
    { slot = "Chest", text = "A large stat budget and often your second tier piece — push Critical Strike here first since crits are the entire engine of this spec" },
    { slot = "Neck", text = "Usually has a socket — prioritize Critical Strike, with Mastery as your next fill for Ignite scaling" },
    { slot = "Ring", text = "No set bonus tying you down, so chase Critical Strike hard on both rings before rounding out Mastery" },
    { slot = "Trinket", text = "One on-use trinket timed to pop with Combustion for maximum burst overlap" },
    { slot = "Trinket", text = "A second trinket with a strong passive Intellect or Critical Strike stat stick to carry outside cooldown windows" },
    { slot = "Weapon", text = "Staff or one-hand-plus-off-hand both work fine — weapon damage and item level matter far more than the weapon type" },
    { slot = "Off-hand", text = "Match a one-hander's off-hand to your Critical Strike lean rather than treating it as an afterthought slot" },
  },
  mplusLoadout = {
    string = "C8DAAAAAAAAAAAAAAAAAAAAAAYGGLzMzswMzIzMGAAAGAwMz0sstMDAwmZmx2MzMzYBAAAAALmZmZAAgZMmZmZMzsMAMzQGjBMDjB",
    source = "SimulationCraft default profile (credit, not endorsement of 'best')",
    patch = "12.1",
  },
  -- Live top-players pull (DESIGN.md's v1.4 section), NOT SimC - see this
  -- file's header for the full methodology. The plurality build among the
  -- sample: 1/22 (5%) ran this exact code, since flex-point choices vary - but
  -- the bigger signal is that 22/22 (100%) ran Sunfury overall. Reported
  -- honestly rather than dressed up as more decisive than it is.
  mplusMetaLoadout = {
    string = "C8DAche08tHz49KSVf7iKFnyuNmtlZWmZmZBzMYGmBAAwAAmZGzyyyMAAbmZmZbGjZmFAAAAAsYmZmBAAmxYGmhZWmBwMDMGAzwA",
    source = "Blizzard Battle.net API, US region, 2026-08-30: top 22 current-season Mythic+ Fire Mages by best keystone level, sampled across all 83 US connected realms' leaderboards. This exact build was the plurality pick (1/22, 5%); 22/22 (100%) ran Sunfury overall.",
    patch = "12.1",
    sampleSize = 22,
  },
  tips = {
    "Enter Combustion with Heating Up or Hot Streak already active so the window starts strong.",
    "Never overcap Fire Blast or Phoenix Flames charges — that's wasted proc generation.",
    "Use Scorch while moving to keep building toward Heating Up instead of standing still doing nothing.",
    "Watch Ignite uptime on multi-target fights; spreading it well is a large chunk of your AoE damage.",
  },
})

-- Frost ----------------------------------------------------------------
ns.GuideStore:RegisterSpec("MAGE", 64, {
  specName = "Frost",
  role = "DAMAGER",
  overview = {
    "Frost Mage combines a steady Icicle/Frostbolt builder rotation with burst windows from Icy Veins and shatter combos (Frost Nova/Freeze into a guaranteed crit on Frostbolt/Ice Lance). Brain Freeze procs let you weave in free, empowered Flurry casts.",
    "The core mechanic is generating Fingers of Frost and Brain Freeze procs: Fingers of Frost grants guaranteed-crit Ice Lances, and Brain Freeze grants a free, instant Flurry that also applies Winter's Chill for a shatter follow-up. Icicles stack from Frostbolt and launch automatically or on Ice Lance.",
    "Bring Frost when you want a spec with strong burst windows, good cleave via Glacial Spike/Comet Storm-style talents, and reliable ranged utility (roots/slows) for mechanics-heavy fights.",
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
        { text = "Pre-cast Frostbolt to enter combat with an Icicle already building" },
        { spellID = 12472, text = "Icy Veins aligned with your first burst window" },
        { text = "Use a shatter combo (Freeze/Nova) into Ice Lance on your first Fingers of Frost proc" },
        { text = "Opener Notes: Frost splits along the Frostfire and Spellslinger hero trees — Frostfire weaves in Frostfire Bolt casts on top of the usual Frostbolt/Ice Lance/Flurry loop, Spellslinger keeps the loop closer to the description above" },
    }},
    { title = "Single Target", steps = {
        { spellID = 116, text = "Frostbolt as your default filler and Icicle builder" },
        { spellID = 30455, text = "Ice Lance on Fingers of Frost procs for guaranteed crits" },
        { spellID = 44614, text = "Flurry on Brain Freeze procs, followed by Ice Lance for the shatter" },
        { text = "Glacial Spike (if talented) once you have 5 Icicles banked" },
        { text = "Weave Frozen Orb/Comet Storm per talents to refresh Fingers of Frost" },
    }},
    { title = "AoE", steps = {
        { spellID = 84714, text = "Frozen Orb to generate procs and cleave damage" },
        { text = "Blizzard to apply consistent AoE damage and chill" },
        { spellID = 30455, text = "Ice Lance to spend Fingers of Frost across the pack" },
        { text = "Comet Storm (if talented) for burst AoE" },
        { text = "Use Ice Nova/Frost Nova to group and root adds before AoE lands" },
    }},
  },
  cooldowns = {
    { spellID = 12472, text = "Icy Veins — main burst window, line up with procs banked and other cooldowns" },
    { spellID = 84714, text = "Frozen Orb — proc generation and cleave, use on cooldown outside of burst planning" },
    { text = "Comet Storm / Ray of Frost (talent-dependent) — burst cooldowns, use inside Icy Veins" },
    { spellID = 45438, text = "Ice Block — defensive, negates incoming damage entirely" },
    { spellID = 80353, text = "Time Warp/Bloodlust — raid utility cooldown, coordinate with your raid's lust plan" },
  },
  consumables = {
    { slot = "Flask", text = "Flask of Alchemical Chaos (Intellect)" },
    { slot = "Food", text = "A feast or personal Intellect food for the encounter" },
    { slot = "Potion", text = "Tempered Potion, used to align with Icy Veins" },
    { slot = "Weapon", text = "Not applicable" },
    { slot = "Enchants", text = "Max-rank Intellect enchants on cloak and rings" },
    { slot = "Gems", text = "Intellect/secondary stat gems in available sockets" },
  },
  gear = {
    { slot = "Head", text = "One of your tier-set slots — the four-piece bonus is worth prioritizing since it strengthens your Fingers of Frost/Brain Freeze proc engine" },
    { slot = "Chest", text = "A big stat budget and often your other tier piece — split it between Critical Strike (for shatter payoff) and Mastery (for Icicle damage)" },
    { slot = "Neck", text = "Usually carries a socket — fill it and lean Critical Strike/Mastery over Haste past your casting comfort point" },
    { slot = "Ring", text = "No set bonus attached, so use rings to fill whichever of Critical Strike or Mastery your gear is currently light on" },
    { slot = "Trinket", text = "One on-use trinket timed to pop with Icy Veins for a stacked burst window" },
    { slot = "Trinket", text = "A passive secondary-stat trinket to keep your damage strong between Icy Veins windows" },
    { slot = "Weapon", text = "Staff or one-hand-plus-off-hand both work — prioritize the higher weapon damage/item level over the type" },
    { slot = "Off-hand", text = "If dual-wielding a caster off-hand, favor one that reinforces your Critical Strike/Mastery split" },
  },
  mplusLoadout = {
    string = "CAEAAAAAAAAAAAAAAAAAAAAAAYGGLzMzsMmZmYmZGjZMziZmZmZMDEAAYmZmllZm2AAAAAAgNA2WGzMzAbzYmZYBAAgZ2AmBGwADD",
    source = "SimulationCraft default profile (credit, not endorsement of 'best')",
    patch = "12.1",
  },
  -- Live top-players pull (DESIGN.md's v1.4 section), NOT SimC - see this
  -- file's header for the full methodology. The plurality build among the
  -- sample: 2/28 (7%) ran this exact code, since flex-point choices vary - but
  -- the bigger signal is that 19/28 (68%) ran Spellslinger overall. Reported
  -- honestly rather than dressed up as more decisive than it is.
  mplusMetaLoadout = {
    string = "CAEAche08tHz49KSVf7iKFnyuNzwYZmZmFMzEzMmZmZmZWMzMzMzMzsMTzMbzCAAAaBAAWAAAAAYbZMzMDmtZMzM2WAAAAzMYGGDYAMA",
    source = "Blizzard Battle.net API, US region, 2026-08-30: top 28 current-season Mythic+ Frost Mages by best keystone level, sampled across all 83 US connected realms' leaderboards. This exact build was the plurality pick (2/28, 7%); 19/28 (68%) ran Spellslinger overall.",
    patch = "12.1",
    sampleSize = 28,
  },
  tips = {
    "Shatter your burst spells (Ice Lance, Frostbolt vs a rooted/frozen target) whenever a root or Freeze is available for guaranteed crits.",
    "Don't let Icicles overflow past 5 stacks if running Glacial Spike — spend before you waste generation.",
    "Save Fingers of Frost procs for a shatter setup when practical, rather than dumping them the instant they appear.",
    "Use your root/slow kit (Frost Nova, Ice Nova, Cone of Cold) proactively for movement-heavy mechanics, not just for damage.",
  },
})
