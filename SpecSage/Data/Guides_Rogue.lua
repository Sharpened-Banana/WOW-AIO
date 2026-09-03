local ADDON, ns = ...

-- SpecSage guide data: Rogue (Assassination 259, Outlaw 260, Subtlety 261)
-- Content targets Midnight (patch 12.1). Specs below with an `mplusLoadout`
-- field have that talent string (only) cross-checked against
-- SimulationCraft's public profiles (github.com/simulationcraft/simc,
-- GPLv3) as of patch 12.1; specs without one have no such reference.
-- Rotation/overview/tips/gear prose throughout this file is hand-authored
-- and was reviewed for Midnight ability changes, not derived from or
-- checked against SimC's APLs, and was not re-verified against current
-- tuning this pass — EXCEPT Assassination (259), Outlaw (260), and Subtlety (261),
-- which each gained an `mplusMetaLoadout` (DESIGN.md's v1.4 section) this
-- pass: pulled live from Blizzard's own Battle.net Game Data API
-- (client-credentials OAuth, US region) rather than SimC, on 2026-08-30.
-- Methodology: every current-season Mythic+ leaderboard (8-dungeon pool,
-- period 1078) across all 83 US connected realms was scanned (top 20 groups
-- per realm/dungeon) for each spec's group members; the top-observed-keystone
-- characters (up to 50 per spec) had their live `specializations` looked up
-- for their active loadout's `talent_loadout_code`. See each field's own
-- `source` comment for the resulting distribution.
-- Subtlety's overview/rotation/tips were also corrected this pass: Symbols
-- of Death has zero references in SimC's current `midnight` branch
-- profile, confirmed via a Blizzard forum thread on the ability's removal
-- ("It got removed this patch!") — its energy refund and combo-point boost
-- were folded directly into Shadow Dance, which now carries that role
-- alone.
-- A later pass (2026-09-01) enriched all three specs' overview/rotation/
-- cooldowns/tips with opener sequences, single-target-vs-AoE priority
-- nuances, cooldown-syncing notes, and hero-talent-caused differences,
-- drawing on guide sites (Wowhead/Icy Veins/Maxroll/Method/Boostmatch),
-- now a permitted source per repo policy (see
-- .claude/skills/specsage-refresh/SKILL.md). All prose was rewritten in
-- SpecSage's own words rather than copied from any source, and every
-- spellID added was verified against Wowhead rather than guessed. This
-- pass built on top of the already-corrected mechanic names above (no
-- stale Symbols of Death references were reintroduced).
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

ns.GuideStore:RegisterSpec("ROGUE", 259, {
  specName = "Assassination",
  role = "DAMAGER",
  overview = {
    "Assassination Rogue is a poison- and bleed-focused melee spec built around keeping Garrote and Rupture active on the target while spending combo points on Envenom for direct damage. It rewards careful DoT upkeep and combo point discipline over raw button-mashing.",
    "The core resource is Energy, regenerating over time and spent to build combo points with Mutilate/Fan of Knives, which are then spent on finishers like Envenom and Rupture. The defining mechanic is bleed and poison uptime — Garrote, Rupture, and your poisons all need to be refreshed before falling off to avoid a significant damage loss. Deathmark and Kingsbane share the same 1-minute cooldown and are always fired together for the spec's main burst window.",
    "Assassination brings strong sustained single-target damage, solid AoE by opening a pull with Crimson Tempest to spread bleeds before settling into Fan of Knives, and good execute-phase scaling, making it a reliable pick for longer fights where consistent uptime matters more than burst windows.",
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
        { spellID = 2823, text = "Deadly Poison applied to your weapon before you engage" },
        { spellID = 381664, text = "Amplifying Poison applied alongside it — both should already be active when you open" },
        { spellID = 703, text = "Garrote to open from Stealth for its bonus damage" },
        { spellID = 1329, text = "Mutilate to start building combo points" },
        { spellID = 1943, text = "Rupture once you're at 5 or more combo points" },
        { spellID = 360194, text = "Deathmark alongside trinkets, potions, and racials for your first burst window" },
        { spellID = 192759, text = "Kingsbane immediately after Deathmark — the two share a 1-minute cooldown and should always land together" },
        { spellID = 32645, text = "Envenom once you're back at 5+ combo points to close out the opener" },
    }},
    { title = "Single Target", steps = {
        { spellID = 703, text = "Garrote kept up — refresh before it falls off" },
        { spellID = 1943, text = "Rupture kept up at 5+ combo points — refresh before it falls off" },
        { spellID = 360194, text = "Deathmark on cooldown for a burst damage window" },
        { spellID = 192759, text = "Kingsbane on cooldown, synced with Deathmark" },
        { spellID = 32645, text = "Envenom at 5+ combo points (7+ if you're running Darkest Night — see Opener Notes)" },
        { spellID = 5938, text = "Shiv to bump 6 combo points to 7 when Darkest Night wants the extra point" },
        { text = "Thistle Tea inside a Kingsbane window for a burst of Energy to fuel extra actions" },
        { spellID = 1329, text = "Mutilate on cooldown as the primary combo point builder" },
        { text = "Refresh poisons before they expire — lost uptime is a real DPS loss" },
    }},
    { title = "AoE", steps = {
        { text = "Crimson Tempest first to spread your bleeds — it's a combo point builder that also seeds bleed damage across the pull" },
        { spellID = 51723, text = "Fan of Knives as the primary combo point builder against 3+ targets" },
        { spellID = 2823, text = "Deadly Poison spread to all engaged targets" },
        { spellID = 1943, text = "Rupture and Garrote maintained on priority targets once poisons are spread" },
        { spellID = 421975, text = "Caustic Spatter passively cleaves a share of your Envenom/Kingsbane damage to nearby targets — no priority change needed, it just works alongside your normal finishers" },
        { spellID = 32645, text = "Envenom to spend combo points when Rupture upkeep isn't needed" },
    }},
    { title = "Opener Notes", steps = {
        { text = "Open from Stealth with Garrote for its bonus damage, then build toward Rupture" },
        { text = "Line up Deathmark with your first full combo point Envenom for maximum burst" },
        { text = "Deathmark hits hardest once both Garrote and Rupture are already ticking — don't fire it before your bleeds are established" },
        { text = "Your hero talent choice changes the Envenom threshold: Deathstalker holds Envenom to 7 combo points while Darkest Night is active (use Shiv to top off from 6 rather than wasting the point), while Fatebound plays the same builder/finisher loop without that cap change" },
    }},
  },
  cooldowns = {
    { spellID = 360194, text = "Deathmark — core offensive cooldown; always sync it with Kingsbane, since both share a 1-minute timer" },
    { spellID = 192759, text = "Kingsbane — poison burst cooldown on the same 1-minute timer as Deathmark; fire them together every time" },
    { text = "Thistle Tea — burns a charge for a burst of Energy; use it inside the Deathmark/Kingsbane window" },
    { spellID = 31224, text = "Cloak of Shadows — major magic defensive, clears many magic effects" },
    { spellID = 5277, text = "Evasion — physical defensive cooldown" },
    { spellID = 1856, text = "Vanish — reset positioning, re-open with a stealth opener, or drop aggro" },
  },
  consumables = {
    { slot = "Flask", text = "Flask of Tempered Swiftness — matches this spec's top secondary; Flask of Alchemical Chaos is the flex pick if your stat weights are close" },
    { slot = "Food", text = "Loa's Gathering or Feast of Knowledge for raid (Stamina + your highest secondary); Hearty Venom-Spiced Cutlets or Puffer Plate for Mythic+/personal (prefer the Hearty version for death persistence)" },
    { slot = "Potion", text = "Tempered Potion, used inside Deathmark. Liquid Luster (builds Versatility over 30s) is a strong ramp/M+ alternative, Potion of Unwavering Focus if you want a pure single-target pick instead; always carry Concentrated Silvermoon Health Potions for the emergency heal." },
    { slot = "Weapon", text = "Instant Poison and Wound Poison (or current-tier equivalents) on both weapons" },
    { slot = "Enchants", text = "Weapon enchant for Agility/Crit; ring enchants for secondary stats" },
    { slot = "Gems", text = "Agility or Agility/secondary hybrid gems in available sockets" },
    { slot = "Augment Rune", text = "Crystallized Augment Rune (1-hour primary stat) for progression pulls and high keys; the reusable Ethereal Augment Rune the rest of the time" },
  },
  gear = {
    { slot = "Head", text = "Tier set piece — the set bonus usually matters more than a small item-level gap" },
    { slot = "Neck", text = "Favor Haste to speed up combo point generation and DoT ticks" },
    { slot = "Back", text = "Secondary stats matching Haste and Crit outweigh a pure item-level chase" },
    { slot = "Legs", text = "Another tier slot when possible; otherwise the highest item level piece leaning Haste and Crit" },
    { slot = "Ring", text = "Haste or Crit rings depending on your current stat weights" },
    { slot = "Trinket", text = "One on-use Agility or damage trinket lined up with Deathmark" },
    { slot = "Trinket", text = "A passive stat-stick trinket for consistent bleed and poison damage" },
    { slot = "Weapon", text = "Two matched, high item level daggers or one-handers — both weapons carry Assassination's bleed and poison damage equally" },
  },
  mplusLoadout = {
    string = "CMQAAAAAAAAAAAAAAAAAAAAAAYmlxsNDGAAAAAYWGsNDAAAAAIbzMzMzMjxyMzMbzsMzMzYGzYMmZMMAbmlBGwSwywEYYxgZGgxYA",
    source = "SimulationCraft default profile (credit, not endorsement of 'best')",
    patch = "12.1",
  },
  -- Live top-players pull (DESIGN.md's v1.4 section), NOT SimC - see this
  -- file's header for the full methodology. The plurality build among the
  -- sample: 2/50 (4%) ran this exact code, since flex-point choices vary - but
  -- the bigger signal is that 34/50 (68%) ran Deathstalker overall. Reported
  -- honestly rather than dressed up as more decisive than it is.
  mplusMetaLoadout = {
    string = "CMQA5HmDzx68KWyrW/8Y781L7bmlZmFDGAAAAAYWGsNDAAAAAotlZmZmZmxYbmZmtZWmZmHwDMmZMzwMjxAsZWGYALBLDTghFDmZAGMA",
    source = "Blizzard Battle.net API, US region, 2026-08-30: top 50 current-season Mythic+ Assassination Rogues by best keystone level, sampled across all 83 US connected realms' leaderboards. This exact build was the plurality pick (2/50, 4%); 34/50 (68%) ran Deathstalker overall.",
    patch = "12.1",
    sampleSize = 50,
  },
  tips = {
    "Never let Rupture or Garrote fall off a target you'll be attacking for more than a few seconds.",
    "Keep your weapon poisons refreshed — a lapsed poison is a silent DPS loss.",
    "Deathmark and Kingsbane share a cooldown — always fire them together rather than saving one for later.",
    "Pool Energy heading into a Deathmark window so you can chain Mutilate into a full-combo-point Envenom the instant it's up.",
    "Running Darkest Night, hold Envenom to 7 combo points instead of 5, and use Shiv to bump from 6 to 7 rather than capping and wasting a combo point.",
    "Crimson Tempest and Fan of Knives spread your bleeds efficiently — seed DoTs across a pull before settling into single-target finishers.",
  },
})

ns.GuideStore:RegisterSpec("ROGUE", 260, {
  specName = "Outlaw",
  role = "DAMAGER",
  overview = {
    "Outlaw Rogue is a swashbuckling melee spec built around Roll the Bones buffs and Combat Potency-style resource generation from off-hand swings. It plays as a flexible, high-mobility spec with Pistol Shot and Between the Eyes providing ranged options unusual for a Rogue.",
    "The core resource is Energy, spent to build combo points with Sinister Strike and Pistol Shot, which are then spent on Dispatch and Between the Eyes. The defining mechanic is Roll the Bones, a buff roll that grants a randomized set of damage buffs — you re-roll it when few buffs are active and hold it when a strong roll lands. Restless Blades means every combo point you spend also shaves time off Adrenaline Rush, Between the Eyes, Blade Rush, Killing Spree, and Roll the Bones, so spending finishers promptly keeps your own cooldowns cycling faster.",
    "Outlaw brings strong burst through Adrenaline Rush and Blade Flurry cleave, solid mobility via Grappling Hook and Sprint, and simple execute-phase scaling with Between the Eyes, making it a versatile pick for both single-target and cleave-heavy fights.",
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
        { text = "Open from Stealth with your poisons already applied" },
        { spellID = 1214909, text = "Roll the Bones immediately to establish buffs before your first finisher" },
        { spellID = 13750, text = "Adrenaline Rush right after Roll the Bones to start the fight already in your burst window" },
        { spellID = 193315, text = "Sinister Strike (or Ambush from Stealth) to start building combo points" },
        { spellID = 315341, text = "Between the Eyes once you're at 5+ combo points, for its debuff and burst" },
        { spellID = 2098, text = "Dispatch to close out the opener" },
    }},
    { title = "Single Target", steps = {
        { spellID = 51690, text = "Killing Spree on cooldown once you're at 6 or more combo points" },
        { spellID = 315341, text = "Between the Eyes on cooldown to spend combo points and apply its debuff" },
        { spellID = 2098, text = "Dispatch as your main finisher at 5+ combo points" },
        { text = "Pistol Shot once Opportunity is stacked to 6, for its empowered damage" },
        { spellID = 193315, text = "Sinister Strike on cooldown — primary combo point builder" },
        { spellID = 271877, text = "Blade Rush on cooldown for extra damage and Energy" },
        { spellID = 1214909, text = "Roll the Bones to apply buffs, re-roll when few are active" },
        { spellID = 13750, text = "Adrenaline Rush on cooldown for a burst window" },
    }},
    { title = "AoE", steps = {
        { spellID = 13877, text = "Blade Flurry to cleave your attacks across nearby targets" },
        { text = "Otherwise play the near-identical single-target priority — Blade Flurry does the cleaving for you" },
        { spellID = 51690, text = "Killing Spree or equivalent burst tool during add waves" },
        { spellID = 1214909, text = "Roll the Bones for its buffs, especially cleave-relevant ones" },
        { spellID = 2098, text = "Dispatch/finishers to spend combo points across the pull" },
        { text = "Turn on Blade Flurry as soon as 2+ targets are engaged" },
    }},
    { title = "Opener Notes", steps = {
        { text = "Open with Roll the Bones to establish buffs before committing to your main cooldowns" },
        { text = "Line up Adrenaline Rush with a strong Roll the Bones result for maximum burst" },
        { text = "If you're talented into Fan the Hammer, Pistol Shot chains take over as your main combo point builder instead of Sinister Strike — check your build before assuming a fixed generator" },
        { text = "Your hero talent choice also shapes the loop beyond Fan the Hammer: Trickster stacks its own resource on top of your combo points, while Fatebound leans into bigger risk/reward swings from its buff — the Roll the Bones/finisher priority above holds for both" },
    }},
  },
  cooldowns = {
    { spellID = 13750, text = "Adrenaline Rush — core offensive cooldown, use on cooldown" },
    { spellID = 51690, text = "Killing Spree — burst mobility/damage cooldown" },
    { text = "Restless Blades (passive) — spending combo points reduces the cooldown of Adrenaline Rush, Between the Eyes, Blade Rush, Killing Spree, and Roll the Bones, so don't sit on finishers" },
    { spellID = 31224, text = "Cloak of Shadows — major magic defensive, clears many magic effects" },
    { spellID = 5277, text = "Evasion — physical defensive cooldown" },
    { spellID = 1856, text = "Vanish — reset positioning or drop aggro" },
  },
  consumables = {
    { slot = "Flask", text = "Flask of Tempered Swiftness — matches this spec's top secondary; Flask of Alchemical Chaos is the flex pick if your stat weights are close" },
    { slot = "Food", text = "Loa's Gathering or Feast of Knowledge for raid (Stamina + your highest secondary); Hearty Venom-Spiced Cutlets or Puffer Plate for Mythic+/personal (prefer the Hearty version for death persistence)" },
    { slot = "Potion", text = "Tempered Potion, used inside Adrenaline Rush. Liquid Luster (builds Versatility over 30s) is a strong ramp/M+ alternative, Potion of Unwavering Focus if you want a pure single-target pick instead; always carry Concentrated Silvermoon Health Potions for the emergency heal." },
    { slot = "Weapon", text = "Instant Poison or the current-tier weapon buff on both weapons" },
    { slot = "Enchants", text = "Weapon enchant for Agility/Crit; ring enchants for secondary stats" },
    { slot = "Gems", text = "Agility or Agility/secondary hybrid gems in available sockets" },
    { slot = "Augment Rune", text = "Crystallized Augment Rune (1-hour primary stat) for progression pulls and high keys; the reusable Ethereal Augment Rune the rest of the time" },
  },
  gear = {
    { slot = "Head", text = "Tier set piece — the set bonus usually matters more than a small item-level gap" },
    { slot = "Neck", text = "Favor Haste for faster combo point generation and quicker ability weaving" },
    { slot = "Back", text = "Secondary stats matching Haste and Mastery outweigh a pure item-level chase" },
    { slot = "Legs", text = "Another tier slot when possible; otherwise the highest item level piece leaning Haste and Mastery" },
    { slot = "Ring", text = "Haste or Mastery rings depending on your current stat weights" },
    { slot = "Trinket", text = "One on-use Agility or damage trinket lined up with Adrenaline Rush" },
    { slot = "Trinket", text = "A passive stat-stick trinket for consistent damage between cooldowns" },
    { slot = "Weapon", text = "Two matched, high item level one-handers, since Sinister Strike and your finishers scale off both weapons" },
  },
  mplusLoadout = {
    string = "CQQAAAAAAAAAAAAAAAAAAAAAAAgx2MMzMmZmtZmZmZMmF4BmZbaZw2MAAAAAALLzMzwMzMziZmZbAAAAYmBAjZxwQGYWYhWYjBYmBDMA",
    source = "SimulationCraft default profile (credit, not endorsement of 'best')",
    patch = "12.1",
  },
  -- Live top-players pull (DESIGN.md's v1.4 section), NOT SimC - see this
  -- file's header for the full methodology. The plurality build among the
  -- sample: 11/50 (22%) ran this exact code, since flex-point choices vary -
  -- but the bigger signal is that 50/50 (100%) ran Trickster overall. Reported
  -- honestly rather than dressed up as more decisive than it is.
  mplusMetaLoadout = {
    string = "CQQA5HmDzx68KWyrW/8Y781L7Dgx2MMzMjZmtZmZMzMzsAmZbaZw2MAAAAAgZbZmZGmZmZWMzMbDAAAAjBAjZxwQGYWYhWYjBYmBDMA",
    source = "Blizzard Battle.net API, US region, 2026-08-30: top 50 current-season Mythic+ Outlaw Rogues by best keystone level, sampled across all 83 US connected realms' leaderboards. This exact build was the plurality pick (11/50, 22%); 50/50 (100%) ran Trickster overall.",
    patch = "12.1",
    sampleSize = 50,
  },
  tips = {
    "Don't re-roll Roll the Bones just because it feels weak — check whether it's actually below the keep threshold first.",
    "Blade Flurry is worth toggling on immediately when a second target joins the fight.",
    "Line up Adrenaline Rush with your best Roll the Bones roll when timing allows.",
    "Between the Eyes' debuff is valuable raid utility — don't only think of it as a finisher.",
    "Spend combo points promptly rather than hoarding them — Restless Blades only shortens your cooldowns when you actually spend a finisher.",
    "Don't let Opportunity stacks sit unused — cash them in with Pistol Shot once they're capped.",
  },
})

ns.GuideStore:RegisterSpec("ROGUE", 261, {
  specName = "Subtlety",
  role = "DAMAGER",
  overview = {
    "Subtlety Rogue is a Shadow-infused melee spec built around Shadow Dance windows, spending combo points on Eviscerate while weaving in Shadowstrike from stealth. Symbols of Death was removed and its energy/combo-point boost folded directly into Shadow Dance itself, so Shadow Dance alone now carries that role. It plays as a burst-window spec, dealing much of its damage inside timed cooldown windows rather than a flat sustained rotation.",
    "The core resource is Energy, spent to build combo points with Shadowstrike and Backstab, then spent on Eviscerate and Black Powder — combo points cap at 7 instead of the usual 5, so never sit on a full bar without spending. The defining mechanic is Shadow Dance, which grants stealth-like access to Shadowstrike outside of true stealth, making burst windows repeatable throughout a fight rather than limited to the opener.",
    "Subtlety brings strong burst damage inside cooldown windows, good AoE through Black Powder, and useful utility (Shroud of Concealment, Distract), making it a good pick for fights with clear burst phases or add windows to dump cooldowns into.",
  },
  statPriority = {
    { stat = "primary" },
    { stat = "mastery" },
    { stat = "haste" },
    { stat = "versatility" },
    { stat = "crit" },
  },
  rotation = {
    { title = "Opener", steps = {
        { text = "Open from Stealth with Instant Poison and Atrophic Poison already applied" },
        { spellID = 185313, text = "Shadow Dance immediately, ideally with enough charges banked to chain a second Dance shortly after" },
        { spellID = 185438, text = "Shadowstrike to open, then keep building combo points inside the Dance" },
        { text = "Eviscerate (or Black Powder on an AoE pull) to spend your first full bar of combo points" },
        { spellID = 121471, text = "Shadow Blades lined up with this first Dance — try to land two Shadow Dance windows inside the same Shadow Blades for the biggest burst" },
    }},
    { title = "Single Target", steps = {
        { text = "Shadow Dance on cooldown — it now carries the energy refund and combo-point boost that used to come from the separate Symbols of Death button" },
        { spellID = 1943, text = "Rupture kept active on the target when it's worth the combo points" },
        { spellID = 185313, text = "Shadow Dance to access Shadowstrike outside of stealth" },
        { spellID = 185438, text = "Shadowstrike as your primary combo point builder during Dance windows" },
        { spellID = 53, text = "Backstab to build combo points outside of Dance windows" },
        { text = "Watch the Ancient Arts buff from Shadow Techniques — if you're sitting on 5+ stacks with no finisher window coming up, spend an extra generator rather than letting it go to waste" },
        { spellID = 196819, text = "Eviscerate at 7 combo points — never sit on a full bar without spending" },
    }},
    { title = "AoE", steps = {
        { spellID = 319175, text = "Black Powder as the primary AoE combo point spender" },
        { spellID = 197835, text = "Shuriken Storm as the primary AoE combo point builder" },
        { text = "Shadow Dance on cooldown to buff AoE damage" },
        { spellID = 185313, text = "Shadow Dance for extra Shadowstrike/Black Powder access" },
        { text = "Rupture on priority targets where the uptime is worth the combo points" },
        { text = "Prioritize Black Powder over Eviscerate once 2+ targets are engaged" },
    }},
    { title = "Opener Notes", steps = {
        { text = "Open from Stealth with Shadowstrike, then chain into Shadow Dance" },
        { text = "Save a second Shadow Dance charge if possible to extend your opening burst window" },
        { text = "Shadow Blades lines up with Shadow Dance roughly every 90 seconds — aim to fit two Shadow Dance windows inside each Shadow Blades rather than using them independently" },
        { text = "Your hero talent choice colors the finisher priority — Deathstalker weaves its mark debuff into the builder/finisher cycle, while Trickster stacks its own resource on top of combo points — but the core Shadow Dance cadence stays the same either way" },
    }},
  },
  cooldowns = {
    { spellID = 121471, text = "Shadow Blades — burst cooldown on roughly a 90-second timer; try to land two Shadow Dance windows inside it rather than spending it independently" },
    { spellID = 185313, text = "Shadow Dance — core repeatable burst window, use on cooldown" },
    { spellID = 31224, text = "Cloak of Shadows — major magic defensive, clears many magic effects" },
    { spellID = 5277, text = "Evasion — physical defensive cooldown" },
    { spellID = 1856, text = "Vanish — reopen Shadowstrike from stealth or reposition" },
  },
  consumables = {
    { slot = "Flask", text = "Flask of Tempered Swiftness — matches this spec's top secondary; Flask of Alchemical Chaos is the flex pick if your stat weights are close" },
    { slot = "Food", text = "Loa's Gathering or Feast of Knowledge for raid (Stamina + your highest secondary); Hearty Venom-Spiced Cutlets or Puffer Plate for Mythic+/personal (prefer the Hearty version for death persistence)" },
    { slot = "Potion", text = "Tempered Potion, used inside a Shadow Dance/Shadow Blades window. Liquid Luster (builds Versatility over 30s) is a strong ramp/M+ alternative, Potion of Unwavering Focus if you want a pure single-target pick instead; always carry Concentrated Silvermoon Health Potions for the emergency heal." },
    { slot = "Weapon", text = "Instant Poison or the current-tier weapon buff on both weapons" },
    { slot = "Enchants", text = "Weapon enchant for Agility/Crit; ring enchants for secondary stats" },
    { slot = "Gems", text = "Agility or Agility/secondary hybrid gems in available sockets" },
    { slot = "Augment Rune", text = "Crystallized Augment Rune (1-hour primary stat) for progression pulls and high keys; the reusable Ethereal Augment Rune the rest of the time" },
  },
  gear = {
    { slot = "Head", text = "Tier set piece — the set bonus usually matters more than a small item-level gap. Season 2's four-piece specifically extends Shadow Blades and boosts its Shadow damage." },
    { slot = "Neck", text = "Favor Haste for faster combo point generation and better Shadow Dance uptime" },
    { slot = "Back", text = "Secondary stats matching Haste and Crit outweigh a pure item-level chase" },
    { slot = "Legs", text = "Another tier slot when possible; otherwise the highest item level piece leaning Haste and Crit" },
    { slot = "Ring", text = "Haste or Crit rings depending on your current stat weights" },
    { slot = "Trinket", text = "One on-use Agility or damage trinket lined up with Shadow Dance or Shadow Blades windows" },
    { slot = "Trinket", text = "A passive stat-stick trinket for consistent damage between burst windows" },
    { slot = "Weapon", text = "Two matched, high item level daggers, since Subtlety's damage scales off both weapons" },
  },
  mplusLoadout = {
    string = "CUQAAAAAAAAAAAAAAAAAAAAAAAgx2MAAAAAwsMGLTMbbjxMDDzMzMzw8AbzYGbbzMzMzMjBjZ2GAAAAGMmFzyADYBsMMhMLYGmZAmxA",
    source = "SimulationCraft default profile (credit, not endorsement of 'best')",
    patch = "12.1",
  },
  -- Live top-players pull (DESIGN.md's v1.4 section), NOT SimC - see this
  -- file's header for the full methodology. The plurality build among the
  -- sample: 4/50 (8%) ran this exact code, since flex-point choices vary - but
  -- the bigger signal is that 46/50 (92%) ran Deathstalker overall. Reported
  -- honestly rather than dressed up as more decisive than it is.
  mplusMetaLoadout = {
    string = "CUQA5HmDzx68KWyrW/8Y781L7Dgx2MAAAAAwsMGLTMbbjxMDjZmZmZGGbzYGbLzMzMzMjBjZ2GAAAAGMmNzyADYBsMMhMLYGmZAmxA",
    source = "Blizzard Battle.net API, US region, 2026-08-30: top 50 current-season Mythic+ Subtlety Rogues by best keystone level, sampled across all 83 US connected realms' leaderboards. This exact build was the plurality pick (4/50, 8%); 46/50 (92%) ran Deathstalker overall.",
    patch = "12.1",
    sampleSize = 50,
  },
  tips = {
    "Keep Shadow Dance on cooldown whenever possible for the strongest burst windows.",
    "Don't waste Shadow Dance charges outside of a real damage window if you can help it.",
    "Black Powder overtakes Eviscerate quickly once a second target is in range.",
    "Vanish can be used offensively to re-enter stealth for another Shadowstrike, not just defensively.",
    "Never sit at 7 combo points without spending — Eviscerate or Black Powder before you cap.",
    "Cash in the Ancient Arts buff with an extra builder when it's about to go to waste rather than losing it entirely.",
  },
})
