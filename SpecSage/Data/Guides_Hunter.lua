local ADDON, ns = ...

-- SpecSage guide data: Hunter (Beast Mastery 253, Marksmanship 254, Survival 255)
-- Content targets Midnight (patch 12.1). Specs below with an `mplusLoadout`
-- field have that talent string (only) cross-checked against
-- SimulationCraft's public profiles (github.com/simulationcraft/simc,
-- GPLv3) as of patch 12.1; specs without one have no such reference.
-- Rotation/overview/tips/gear prose throughout this file is hand-authored
-- and was reviewed for Midnight ability changes, not derived from or
-- checked against SimC's APLs, and was not re-verified against current
-- tuning this pass — EXCEPT Beast Mastery (253), Marksmanship (254), and Survival (255),
-- which each gained an `mplusMetaLoadout` (DESIGN.md's v1.4 section) this
-- pass: pulled live from Blizzard's own Battle.net Game Data API
-- (client-credentials OAuth, US region) rather than SimC, on 2026-08-30.
-- Methodology: every current-season Mythic+ leaderboard (8-dungeon pool,
-- period 1078) across all 83 US connected realms was scanned (top 20 groups
-- per realm/dungeon) for each spec's group members; the top-observed-keystone
-- characters (up to 50 per spec) had their live `specializations` looked up
-- for their active loadout's `talent_loadout_code`. See each field's own
-- `source` comment for the resulting distribution.
-- Survival's overview/rotation/tips were also corrected this pass: they
-- described the old Mongoose Bite/Mongoose Fury stacking mechanic and a
-- separate Coordinated Assault cooldown, both gone. SimC's current
-- `midnight` branch profile has zero references to either (mongoose_bite,
-- coordinated_assault) and is instead built entirely around Tip of the
-- Spear stacks spent on a new Takedown finisher; a Blizzard developer post
-- on the official forums states Takedown "combines aspects of both
-- Coordinated Assault and Flanking Strike."
-- Later pass (2026-09-01): as of this date guide sites (Wowhead, Icy
-- Veins, Maxroll, Method, Boostmatch) are a permitted source for rotation
-- logic, hero-talent recommendations, and stat priorities. All three
-- specs' overview/rotation/cooldowns/tips were rewritten this pass with
-- real opener sequences, single-target/AoE priority splits, and
-- hero-talent-caused differences pulled from those sites, cross-checked
-- against current spell data for the spell IDs added. Survival's AoE
-- section also got a real fix here: it still named Butchery as the AoE
-- tool, but Butchery was removed in Midnight and replaced by Raptor
-- Swipe (every second Raptor Strike auto-converts to hit multiple
-- enemies) - confirmed via direct lookup, not just the compendium.
-- statPriority fields were left untouched throughout, since the sources
-- didn't give a confident order beyond what was already there.
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

ns.GuideStore:RegisterSpec("HUNTER", 253, {
  specName = "Beast Mastery",
  role = "DAMAGER",
  overview = {
    "Beast Mastery Hunter is a pet-focused ranged spec where a large share of the damage comes from your permanent pet, buffed heavily by Bestial Wrath and Kill Command. It plays as a mobile, simple-to-execute spec that stays fully effective while moving, since most casts are instant.",
    "The core resource is Focus, generated passively and from Cobra Shot, and spent on Kill Command and Barbed Shot. The defining mechanic is Barbed Shot's Frenzy stacks on your pet, which increase pet attack speed and must be refreshed regularly to keep pet damage — the spec's main damage source — at its peak. Barbed Shot and Cobra Shot also apply Nature's Ally, a short buff that boosts your next Kill Command, so the rotation is built around weaving a filler between Kill Commands rather than ever casting two in a row.",
    "Beast Mastery's two hero trees are Pack Leader and Dark Ranger. Pack Leader periodically turns a Kill Command into a free extra pet summon via Howl of the Pack Leader; Dark Ranger folds in Black Arrow, timed around its own Withering Fire cooldown. Both still run the same Kill Command/Barbed Shot/Cobra Shot core described above.",
    "Beast Mastery is a strong pick for fights requiring constant movement, cleave-light single target, and simple resource management, making it a common choice for Mythic+ and progression pulls with heavy mechanics.",
  },
  statPriority = {
    { stat = "primary" },
    { stat = "mastery" },
    { stat = "crit" },
    { stat = "haste" },
    { stat = "versatility" },
  },
  rotation = {
    { title = "Single Target", steps = {
        { spellID = 217200, text = "Barbed Shot when Bestial Wrath is about to come off cooldown, or when you're nearing 2 banked charges — don't let charges cap" },
        { spellID = 19574, text = "Bestial Wrath on cooldown" },
        { spellID = 34026, text = "Kill Command — hold a beat for Howl of the Pack Leader if it's about to come up, otherwise fire it with Nature's Ally active for the damage bonus" },
        { spellID = 193455, text = "Cobra Shot at 4 stacks of Cobra Fang" },
        { spellID = 217200, text = "Barbed Shot on cooldown, or once you're below 75 Focus" },
        { spellID = 193455, text = "Cobra Shot as filler" },
        { text = "Never fire two Kill Commands back-to-back on a single target — always weave a Barbed Shot or Cobra Shot between them so Nature's Ally is up for the next one" },
    }},
    { title = "AoE", steps = {
        { spellID = 1264359, text = "Wild Thrash immediately after Bestial Wrath once 2+ targets are up — Beast Cleave now runs a full 10 seconds and can't be cancelled early" },
        { spellID = 217200, text = "Barbed Shot still prioritized to maintain Frenzy" },
        { spellID = 34026, text = "Kill Command on cooldown, cleaving through pet talents; keep Nature's Ally up the same way as single target" },
        { spellID = 193455, text = "Cobra Shot as Focus dump when other cooldowns are down" },
        { text = "Black Arrow during Withering Fire if you're playing Dark Ranger" },
        { text = "Keep pet uptime on the highest-priority target while cleaving" },
    }},
    { title = "Opener Notes", steps = {
        { spellID = 257284, text = "Hunter's Mark and Misdirection pre-pull, then dump any banked Barbed Shot charges before combat starts" },
        { text = "Trinkets, racials, and your potion together, then Bestial Wrath to open the burst window" },
        { spellID = 34026, text = "Kill Command, then Cobra Shot to round out the opener" },
        { text = "Pack Leader and Dark Ranger add different flavor here — Pack Leader weaves in Howl of the Pack Leader's periodic free Kill Command, Dark Ranger works Black Arrow into Withering Fire — but the Barbed Shot/Bestial Wrath/Kill Command opener above holds for both" },
    }},
  },
  cooldowns = {
    { spellID = 19574, text = "Bestial Wrath — core offensive cooldown on a ~30 second timer; dump your Barbed Shot charges right before pressing it rather than banking them through the window" },
    { text = "Aspect of the Wild — stack with Bestial Wrath for burst" },
    { spellID = 186265, text = "Aspect of the Turtle — major defensive, absorbs most damage briefly" },
    { spellID = 109304, text = "Exhilaration — self-healing cooldown for sustain checks" },
    { spellID = 5384, text = "Feign Death — drop threat/aggro or avoid certain mechanics" },
  },
  consumables = {
    { slot = "Flask", text = "Flask of Tempered Aggression — matches this spec's top secondary; Flask of Alchemical Chaos is the flex pick if your stat weights are close" },
    { slot = "Food", text = "Loa's Gathering or Feast of Knowledge for raid (Stamina + your highest secondary); Hearty Venom-Spiced Cutlets or Puffer Plate for Mythic+/personal (prefer the Hearty version for death persistence)" },
    { slot = "Potion", text = "Tempered Potion, used inside Bestial Wrath. Liquid Luster (builds Versatility over 30s) is a strong ramp/M+ alternative, Potion of Unwavering Focus if you want a pure single-target pick instead; always carry Concentrated Silvermoon Health Potions for the emergency heal." },
    { slot = "Weapon", text = "Not typically enchanted — check current-tier weapon oil availability" },
    { slot = "Enchants", text = "Weapon enchant for Agility/Crit; ring enchants for secondary stats" },
    { slot = "Gems", text = "Agility or Agility/secondary hybrid gems in available sockets" },
    { slot = "Augment Rune", text = "Crystallized Augment Rune (1-hour primary stat) for progression pulls and high keys; the reusable Ethereal Augment Rune the rest of the time" },
  },
  gear = {
    { slot = "Head", text = "Tier set piece — the set bonus usually matters more than a small item-level gap. Season 2's set bonus specifically: Barbed Shot makes your pet Stomp an extra time, and the four-piece has that Stomp empower your next Cobra Shot — a bigger boost in AoE, a smaller but still real one on single target." },
    { slot = "Neck", text = "Favor Crit and Mastery, since Mastery boosts pet damage directly for Beast Mastery" },
    { slot = "Back", text = "Secondary stats matching Crit and Mastery outweigh a pure item-level trade" },
    { slot = "Legs", text = "Another tier slot when possible; otherwise the highest item level piece leaning Crit and Mastery" },
    { slot = "Ring", text = "Crit or Mastery rings depending on your current stat weights" },
    { slot = "Trinket", text = "One on-use Agility or damage trinket lined up with Bestial Wrath" },
    { slot = "Trinket", text = "A passive stat-stick trinket for consistent pet and Focus-spender damage" },
    { slot = "Weapon", text = "Mostly a stat stick for Hunters — take the highest item level option since it doesn't gate ability damage directly" },
  },
  mplusLoadout = {
    string = "C0PAAAAAAAAAAAAAAAAAAAAAAAMmxwCsAzwwMsBAgZYMzyMDzYmxMMzYMzwMjZMziZmxMmBjpZAAAAAzAAAwYmZAmZjxGMLgtBgBA",
    source = "SimulationCraft default profile (credit, not endorsement of 'best')",
    patch = "12.1",
  },
  -- Live top-players pull (DESIGN.md's v1.4 section), NOT SimC - see this
  -- file's header for the full methodology. The plurality build among the
  -- sample: 6/50 (12%) ran this exact code, since flex-point choices vary - but
  -- the bigger signal is that 50/50 (100%) ran Pack Leader overall. Reported
  -- honestly rather than dressed up as more decisive than it is.
  mplusMetaLoadout = {
    string = "C0PAD57yiELKEty14ekTDtZEqAMmxwCsAzwQDbAAYGzMzsYGzMzMjZGMzYmhZGzMzYbmZMjZYZMNDAAAAAAAA8AjxAmZjAmFw2AwA",
    source = "Blizzard Battle.net API, US region, 2026-08-30: top 50 current-season Mythic+ Beast Mastery Hunters by best keystone level, sampled across all 83 US connected realms' leaderboards. This exact build was the plurality pick (6/50, 12%); 50/50 (100%) ran Pack Leader overall.",
    patch = "12.1",
    sampleSize = 50,
  },
  tips = {
    "Keep Barbed Shot's Frenzy buff active on your pet at essentially all times — this is the spec's core damage driver.",
    "Line up Bestial Wrath with Aspect of the Wild and trinkets for maximum burst.",
    "Feign Death is useful defensively as well as for threat — it can dodge some mechanics entirely.",
    "Avoid capping Focus; Cobra Shot exists specifically to prevent Focus overflow.",
    "Never let Kill Command or Barbed Shot sit at capped charges — both are core damage, not just maintenance.",
    "Keep a Nature's Ally proc up for every Kill Command by weaving a Barbed Shot or Cobra Shot beforehand — don't cast two Kill Commands back to back.",
  },
})

ns.GuideStore:RegisterSpec("HUNTER", 254, {
  specName = "Marksmanship",
  role = "DAMAGER",
  overview = {
    "Marksmanship Hunter is a precision ranged spec built around hard-hitting cast-time shots, most notably Aimed Shot, amplified by Trueshot and Precise Shots procs. It plays with more positioning and casting discipline than the other Hunter specs — Streamline was removed, so Aimed Shot now has a longer, more deliberate cast time and hits harder for it, rewarding careful use of instant-cast windows while moving.",
    "The core resource is Focus, generated from Steady Shot and passive regeneration, and spent primarily on Aimed Shot and Rapid Fire. The defining mechanic is the Precise Shots buff, generated by Trick Shots/Aimed Shot interactions, which makes your next Arcane Shot or Multi-Shot free and empowered — sequencing around this buff is central to the rotation. Deathblow adds a second layer on top: it flags your next Aimed Shot to grant a free Kill Shot or Black Arrow, so that cast shouldn't get delayed once the proc is up.",
    "Sentinel is Marksmanship's default hero tree, adding Explosive Shot and Volley to the priority list; Dark Ranger instead folds Black Arrow into the same Aimed Shot/Precise Shots core.",
    "Marksmanship brings strong burst windows under Trueshot, good execute-phase damage, and solid ranged utility (traps, Concussive Shot), making it a good pick for fights that reward burst windows and have some downtime to cast in.",
  },
  statPriority = {
    { stat = "primary" },
    { stat = "crit" },
    { stat = "mastery" },
    { stat = "versatility" },
    { stat = "haste" },
  },
  rotation = {
    { title = "Single Target", steps = {
        { spellID = 257044, text = "Rapid Fire on cooldown" },
        { text = "Wailing Arrow on cooldown" },
        { spellID = 185358, text = "Arcane Shot to consume Precise Shots procs" },
        { spellID = 19434, text = "Aimed Shot on cooldown — casts noticeably longer than it used to now that Streamline is gone, so treat it as a deliberate cast rather than something to squeeze in while moving" },
        { text = "Black Arrow if you're playing Dark Ranger" },
        { spellID = 56641, text = "Steady Shot to refill Focus when you're starved for it" },
        { text = "Deathblow flags your next Aimed Shot to grant a free Kill Shot or Black Arrow — don't let that Aimed Shot get delayed" },
    }},
    { title = "AoE", steps = {
        { spellID = 257044, text = "Rapid Fire and Aimed Shot both cleave while Trick Shots is active, so use them the same way as single target" },
        { spellID = 257620, text = "Multi-Shot to apply Trick Shots and spend Precise Shots procs" },
        { text = "Spread Spotter's Mark across multiple targets" },
        { spellID = 56641, text = "Steady Shot as Focus filler between cooldowns" },
        { text = "Keep Trick Shots active whenever 2+ targets are engaged" },
    }},
    { title = "Opener Notes", steps = {
        { spellID = 257284, text = "Mark your target with Hunter's Mark before the pull" },
        { spellID = 288613, text = "Open with Trueshot, then chain Rapid Fire into an Aimed Shot volley while Trick Shots is up" },
        { text = "Weave in Moonlight Chakram and Wailing Arrow as they come off cooldown during the opener" },
        { text = "Sentinel is the default hero tree and adds Explosive Shot/Volley as an extra priority on cooldown; Dark Ranger instead weaves Black Arrow into the same Aimed Shot/Precise Shots core — check which one your loadout uses" },
    }},
  },
  cooldowns = {
    { spellID = 288613, text = "Trueshot — core offensive cooldown, line it up with trinkets, racials, and every other burst cooldown you have, not just Rapid Fire" },
    { spellID = 257044, text = "Rapid Fire — Focus and damage cooldown, use on cooldown" },
    { text = "Lock and Load (talent proc) — grants a free instant Aimed Shot, use it immediately rather than banking it" },
    { spellID = 186265, text = "Aspect of the Turtle — major defensive, absorbs most damage briefly" },
    { spellID = 109304, text = "Exhilaration — self-healing cooldown for sustain checks" },
    { spellID = 5384, text = "Feign Death — drop threat/aggro or avoid certain mechanics" },
  },
  consumables = {
    { slot = "Flask", text = "Flask of Tempered Aggression — matches this spec's top secondary; Flask of Alchemical Chaos is the flex pick if your stat weights are close" },
    { slot = "Food", text = "Loa's Gathering or Feast of Knowledge for raid (Stamina + your highest secondary); Hearty Venom-Spiced Cutlets or Puffer Plate for Mythic+/personal (prefer the Hearty version for death persistence)" },
    { slot = "Potion", text = "Tempered Potion, used inside Trueshot. Liquid Luster (builds Versatility over 30s) is a strong ramp/M+ alternative, Potion of Unwavering Focus if you want a pure single-target pick instead; always carry Concentrated Silvermoon Health Potions for the emergency heal." },
    { slot = "Weapon", text = "Not typically enchanted — check current-tier weapon oil availability" },
    { slot = "Enchants", text = "Weapon enchant for Agility/Crit; ring enchants for secondary stats" },
    { slot = "Gems", text = "Agility or Agility/secondary hybrid gems in available sockets" },
    { slot = "Augment Rune", text = "Crystallized Augment Rune (1-hour primary stat) for progression pulls and high keys; the reusable Ethereal Augment Rune the rest of the time" },
  },
  gear = {
    { slot = "Head", text = "Tier set piece — the set bonus usually outweighs a small item-level gap" },
    { slot = "Neck", text = "Favor Crit and Mastery to match Marksmanship's stat priority" },
    { slot = "Back", text = "Secondary stats matching Crit and Mastery outweigh a pure item-level chase" },
    { slot = "Legs", text = "Another tier slot when possible; otherwise the highest item level piece leaning Crit and Mastery" },
    { slot = "Ring", text = "Crit or Haste rings depending on whether burst or cast-time smoothing is your current bottleneck" },
    { slot = "Trinket", text = "One on-use Agility or damage trinket lined up with Trueshot" },
    { slot = "Trinket", text = "A passive stat-stick trinket for consistent Aimed Shot damage" },
    { slot = "Weapon", text = "Mostly a stat stick — take the highest item level option available" },
  },
  mplusLoadout = {
    string = "C4PAAAAAAAAAAAAAAAAAAAAAAwCMwMGzYZAjZwGAAAAAAAAYGzYmFzYmZMDGTzYwYbZmZmZmZmZWYmlBzAAAGzMjBwM22gBYjZ2mxAA",
    source = "SimulationCraft default profile (credit, not endorsement of 'best')",
    patch = "12.1",
  },
  -- Live top-players pull (DESIGN.md's v1.4 section), NOT SimC - see this
  -- file's header for the full methodology. The plurality build among the
  -- sample: 5/50 (10%) ran this exact code, since flex-point choices vary - but
  -- the bigger signal is that 50/50 (100%) ran Sentinel overall. Reported
  -- honestly rather than dressed up as more decisive than it is.
  mplusMetaLoadout = {
    string = "C4PAD57yiELKEty14ekTDtZEqwGMwMGNWGQmBbAAAAAAAAgZMzMjtZMzMmhlx0MGMLbLzMzMzMzMzCzsMMDAAgHYMGAmxGYA2YmtZMA",
    source = "Blizzard Battle.net API, US region, 2026-08-30: top 50 current-season Mythic+ Marksmanship Hunters by best keystone level, sampled across all 83 US connected realms' leaderboards. This exact build was the plurality pick (5/50, 10%); 50/50 (100%) ran Sentinel overall.",
    patch = "12.1",
    sampleSize = 50,
  },
  tips = {
    "Don't let Precise Shots procs sit unused — they're a meaningful chunk of your damage.",
    "Line up Trueshot with Rapid Fire and trinkets for the biggest burst windows.",
    "Keep Trick Shots active any time you're facing two or more targets.",
    "Position for uninterrupted casting whenever possible — Aimed Shot's cast time is longer than it used to be now that Streamline is gone, so a clean cast matters more than ever.",
    "If you're Focus-starved, Steady Shot exists specifically to refill it — don't stand there with nothing to cast.",
    "Use Lock and Load procs immediately rather than saving them; they don't get better with age.",
  },
})

ns.GuideStore:RegisterSpec("HUNTER", 255, {
  specName = "Survival",
  role = "DAMAGER",
  overview = {
    "Survival Hunter is a melee spec (uniquely among Hunter specs) that combines direct weapon attacks with pet support and DoT-style bleeds. It plays as an aggressive, mobility-heavy melee spec that still keeps a pet as a secondary damage source, blending Kill Command with Raptor Strike and a Takedown-based finisher. You can now dual-wield one-handed weapons instead of a two-hander, and between Aspect of the Eagle and Kill Command/Wildfire Bomb not requiring melee range, a real share of your damage can come from range when a fight demands it — though Raptor Strike and Raptor Swipe still want you in melee.",
    "The core resource is Focus, generated from auto-attacks and abilities like Raptor Strike, and spent on Kill Command and Wildfire Bomb. The defining mechanic is Tip of the Spear: Kill Command grants 2 stacks, and the golden rule of the spec is spending every stack on your highest-priority attack — including Takedown, the hard-hitting finisher that replaced Mongoose Bite/Mongoose Fury (and folded in what used to be the separate Coordinated Assault cooldown) in Midnight — rather than letting stacks go to waste.",
    "Survival's two hero trees, Sentinel and Pack Leader, each run their own distinct priority list on top of the Tip of the Spear loop above rather than being a pure flavor choice.",
    "Survival brings strong sustained single-target damage, useful AoE via Wildfire Bomb, and melee utility (Muzzle interrupt, traps), making it a solid pick for fights where melee positioning is viable and you want pet-assisted burst.",
  },
  statPriority = {
    { stat = "primary" },
    { stat = "mastery" },
    { stat = "crit" },
    { stat = "haste" },
    { stat = "versatility" },
  },
  rotation = {
    { title = "Single Target", steps = {
        { text = "The core loop is Kill Command, then two Tip of the Spear-affected ('Tipped') abilities, then repeat — every Kill Command grants 2 stacks, and the goal is spending every stack on your highest-priority attack rather than letting it fall off unused" },
        { spellID = 34026, text = "Kill Command below 70 Focus, or whenever you're not actively spending Tip of the Spear stacks" },
        { text = "Takedown lined up with your other cooldowns rather than used the instant it's available" },
        { spellID = 259495, text = "Wildfire Bomb on cooldown — strong Focus-free damage and DoT" },
        { spellID = 186270, text = "Raptor Strike as a Focus-efficient filler and builder once the Tip of the Spear priorities above are covered" },
        { spellID = 190925, text = "Harpoon to close distance and enable extra melee uptime" },
        { text = "Keep bleeds/DoTs active on the target between cooldown usage" },
    }},
    { title = "AoE", steps = {
        { spellID = 259495, text = "Wildfire Bomb as the primary AoE cooldown — weight your priority toward it, it hits and DoTs multiple targets" },
        { text = "Raptor Swipe drives your cleave now — every second Raptor Strike auto-converts into a swipe that hits everything in front of you, so just keep using Raptor Strike as normal and let it cleave on its own" },
        { spellID = 34026, text = "Kill Command on cooldown across the pull, same Tip of the Spear loop as single target" },
        { text = "Prioritize Raptor Strike over other fillers while 2+ targets are in melee range" },
        { text = "Keep Wildfire Bomb's DoT rolling across as many targets as possible" },
    }},
    { title = "Opener Notes", steps = {
        { spellID = 257284, text = "Hunter's Mark before the pull" },
        { spellID = 259495, text = "Wildfire Bomb thrown about a second before combat starts so it lands right as the pull happens" },
        { text = "Trinkets, racials, and your potion together with Takedown" },
        { spellID = 34026, text = "Kill Command to start building Tip of the Spear stacks" },
        { text = "Your hero talent choice splits the rotation in two: Pack Leader leans on its pet-summon procs alongside the core builders, while Sentinel runs its own separate priority list — check which one your loadout uses" },
    }},
  },
  cooldowns = {
    { text = "Takedown — core offensive cooldown on a 1:30 baseline (replaced Mongoose Bite and folded in the old Coordinated Assault, adding a dash plus 50 Focus on top of its damage boost), use once Tip of the Spear stacks are up and line it up with Boomstick/Aspect of the Eagle" },
    { spellID = 1261193, text = "Boomstick — 1-minute cooldown that replaced Fury of the Eagle, weave it into the same burst window as Takedown" },
    { spellID = 186289, text = "Aspect of the Eagle — extends your melee abilities' range, useful both for burst windows and for mechanics that push you out of melee" },
    { spellID = 259495, text = "Wildfire Bomb — frequent damage cooldown, weave in on cooldown" },
    { spellID = 186265, text = "Aspect of the Turtle — major defensive, absorbs most damage briefly" },
    { spellID = 109304, text = "Exhilaration — self-healing cooldown for sustain checks" },
    { spellID = 5384, text = "Feign Death — drop threat/aggro or avoid certain mechanics" },
  },
  consumables = {
    { slot = "Flask", text = "Flask of Tempered Swiftness — matches this spec's top secondary; Flask of Alchemical Chaos is the flex pick if your stat weights are close" },
    { slot = "Food", text = "Loa's Gathering or Feast of Knowledge for raid (Stamina + your highest secondary); Hearty Venom-Spiced Cutlets or Puffer Plate for Mythic+/personal (prefer the Hearty version for death persistence)" },
    { slot = "Potion", text = "Tempered Potion, used inside a Takedown window. Liquid Luster (builds Versatility over 30s) is a strong ramp/M+ alternative, Potion of Unwavering Focus if you want a pure single-target pick instead; always carry Concentrated Silvermoon Health Potions for the emergency heal." },
    { slot = "Weapon", text = "Ironclaw Whetstone or the current-tier weapon oil" },
    { slot = "Enchants", text = "Weapon enchant for Agility/Crit; ring enchants for secondary stats" },
    { slot = "Gems", text = "Agility or Agility/secondary hybrid gems in available sockets" },
    { slot = "Augment Rune", text = "Crystallized Augment Rune (1-hour primary stat) for progression pulls and high keys; the reusable Ethereal Augment Rune the rest of the time" },
  },
  gear = {
    { slot = "Head", text = "Tier set piece — the set bonus usually matters more than a small item-level gap" },
    { slot = "Neck", text = "Favor Haste to speed up Focus generation and Tip of the Spear stacking" },
    { slot = "Back", text = "Secondary stats matching Haste and Crit outweigh a pure item-level chase" },
    { slot = "Legs", text = "Another tier slot when possible; otherwise the highest item level piece leaning Haste and Crit" },
    { slot = "Ring", text = "Haste or Crit rings depending on your current stat weights" },
    { slot = "Trinket", text = "One on-use Agility or damage trinket lined up with a Takedown window" },
    { slot = "Trinket", text = "A passive stat-stick trinket for consistent melee and Kill Command damage" },
    { slot = "Weapon", text = "A melee weapon this time, since Survival fights in melee — take the highest item level option with useful secondary stats" },
  },
  mplusLoadout = {
    string = "C8PAAAAAAAAAAAAAAAAAAAAAAMWgBmxoxyAYmgtZMzMGzyAAAAAAwMmxMLmxYGzgx0MAAAADAmxyyMzsYMzMjZmBAzYZDGDjNDAA",
    source = "SimulationCraft default profile (credit, not endorsement of 'best')",
    patch = "12.1",
  },
  -- Live top-players pull (DESIGN.md's v1.4 section), NOT SimC - see this
  -- file's header for the full methodology. The plurality build among the
  -- sample: 5/50 (10%) ran this exact code, since flex-point choices vary - but
  -- the bigger signal is that 30/50 (60%) ran Sentinel overall. Reported
  -- honestly rather than dressed up as more decisive than it is.
  mplusMetaLoadout = {
    string = "C8PAD57yiELKEty14ekTDtZEqMWgBmxoxyAYmgtZmZmZGz28AAAAAAAmxMzM2mxYGzwyYaGAAAgBAGLLzMWwMz4BGjBgZsBGjZmNDA",
    source = "Blizzard Battle.net API, US region, 2026-08-30: top 50 current-season Mythic+ Survival Hunters by best keystone level, sampled across all 83 US connected realms' leaderboards. This exact build was the plurality pick (5/50, 10%); 30/50 (60%) ran Sentinel overall.",
    patch = "12.1",
    sampleSize = 50,
  },
  tips = {
    "Have at least 2 Tip of the Spear stacks up before pressing Takedown, so both your hit and your pet's follow-up hit benefit from the buff.",
    "Wildfire Bomb has a short cooldown — don't let it sit unused, especially in AoE.",
    "Raptor Swipe triggers automatically off every second Raptor Strike now — you don't need a separate AoE button, just keep Raptor Strike in your priority and it cleaves on its own once a second target is up.",
    "Don't let Focus or Wildfire Bomb charges sit capped — both are core damage, not just maintenance.",
    "Muzzle is a strong interrupt — use it proactively on scripted casts rather than saving it indefinitely.",
  },
})
