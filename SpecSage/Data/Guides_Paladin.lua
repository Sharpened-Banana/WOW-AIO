local ADDON, ns = ...

-- SpecSage guide data: Paladin (Holy 65, Protection 66, Retribution 70)
-- Content targets Midnight (patch 12.1). Specs below with an `mplusLoadout`
-- field have that talent string (only) cross-checked against
-- SimulationCraft's public profiles (github.com/simulationcraft/simc,
-- GPLv3) as of patch 12.1; specs without one have no such reference.
-- Rotation/overview/tips/gear prose throughout this file is hand-authored
-- and was reviewed for Midnight ability changes, not derived from or
-- checked against SimC's APLs, and was not re-verified against current
-- tuning this pass — EXCEPT Holy (65), Protection (66), and Retribution (70),
-- which each gained an `mplusMetaLoadout` (DESIGN.md's v1.4 section): pulled
-- live from Blizzard's own Battle.net Game Data API (client-credentials
-- OAuth, US region) rather than SimC (Protection first, on 2026-08-30; Holy
-- and Retribution followed the same day in a second pass). Methodology:
-- every current-season Mythic+ leaderboard (8-dungeon pool, period 1078)
-- across all 83 US connected realms was scanned (top 20 groups per
-- realm/dungeon) for each spec's group members; the 50 distinct characters
-- per spec with the highest observed keystone level had their live
-- `specializations` looked up for their active loadout's
-- `talent_loadout_code` (confirmed to be Blizzard's real export-string
-- format, not structured data needing a custom encoder). See each field's
-- own `source` comment for the resulting distribution.
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

-- Holy (65): revised for 12.1 from Blizzard patch-note content reached via
-- search summaries, not from a directly-fetched patch-notes page, and not
-- SimC-cross-checked (no SimC profile exists for this spec — SimC does not
-- publish healer profiles). The specific numbers/mechanics below are
-- UNVERIFIED against a primary source and should be treated as provisional
-- pending direct confirmation. No mplusLoadout is shipped for this spec for
-- the same reason; see the file header and DESIGN.md's "BiS / Gear" section.
ns.GuideStore:RegisterSpec("PALADIN", 65, {
  specName = "Holy",
  role = "HEALER",
  overview = {
    "Holy Paladin is a hybrid healer that blends direct single-target healing (Holy Shock, Holy Light) with strong smart-heal utility from Beacon of Light/Faith spreading a portion of your healing to bonded targets. It rewards good beacon placement and Holy Power management as much as raw cast timing.",
    "The core resource is Holy Power, generated from Holy Shock and Crusader Strike and spent on Word of Glory / Eternal Flame / Light of Dawn, alongside mana as the overarching limiting resource across a fight. The defining mechanic is the Beacon system — healing the beacon target's bonded ally also heals them, so positioning beacons on tanks or high-damage targets multiplies your throughput. Patch 12.1 increased Holy Power spender healing.",
    "Herald of the Sun and Lightsmith are the two hero talent paths. Herald of the Sun boosts Avenging Wrath's healing and adds passive throughput via Dawnlight; Lightsmith's Hammer and Anvil triggers from Judgment. Holy Paladin brings strong raid cooldowns (Avenging Wrath, Aura Mastery), solid AoE healing through Light of Dawn and Holy Prism-style tools, and reliable tank healing via beacon uptime.",
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
        { spellID = 20473, text = "Holy Shock as often as its cooldown allows — it's the core of the whole loop, both a strong heal and your main Holy Power generator" },
        { spellID = 53563, text = "Beacon of Light kept active on the tank or primary damage-taker at all times" },
        { spellID = 82326, text = "Holy Light when an Infusion of Light proc makes it worth casting over Flash of Light" },
        { spellID = 19750, text = "Flash of Light for fast, cheap reactive healing the rest of the time" },
        { spellID = 85222, text = "Light of Dawn or Word of Glory to spend Holy Power — you don't have to dump every point the instant you have one; banking a charge or two is fine when you're unsure whether a bigger heal is about to be needed" },
        { text = "Word of Glory and Eternal Flame both had their healing increased in 12.1" },
        { text = "Weave Judgment/Crusader Strike when healing demand is low to keep Holy Power flowing" },
        { text = "If running Lightsmith, keep Holy Bulwark and Sacred Weapon up on cooldown alongside your normal healing — it's passive value you shouldn't let lapse" },
    }},
    { title = "Cooldown Usage", steps = {
        { spellID = 31884, text = "Avenging Wrath (or Avenging Crusader) during heavy incoming damage windows — stronger self-healing if you're running Herald of the Sun" },
        { spellID = 304971, text = "Divine Toll — it casts five Holy Shocks at once, so use it generously rather than saving it for emergencies, especially into a wave of incoming raid damage" },
        { spellID = 200025, text = "Beacon of Virtue right before a scripted AoE damage spike, to get every beacon target topped off at once" },
        { spellID = 105809, text = "Holy Avenger to accelerate Holy Power spending during burst phases" },
        { spellID = 31821, text = "Aura Mastery to blanket the raid with your active Aura's benefit during a damage spike" },
        { spellID = 633, text = "Lay on Hands as a full-health emergency heal on whoever's about to die" },
        { text = "Pre-position beacons before a pull so tank healing is covered from the first hit" },
        { text = "Stack cooldowns together for predictable heavy-damage phases rather than spreading them thin" },
    }},
  },
  cooldowns = {
    { spellID = 31884, text = "Avenging Wrath — general healing/damage cooldown, use on cooldown during progression" },
    { spellID = 304971, text = "Divine Toll — casts 5 Holy Shocks at once on a fairly short cooldown; use it often rather than hoarding it" },
    { spellID = 31821, text = "Aura Mastery — raid-wide cooldown, save for known heavy damage windows" },
    { spellID = 105809, text = "Holy Avenger — burst Holy Power generation, pair with heavy Light of Dawn/Word of Glory usage" },
    { spellID = 633, text = "Lay on Hands — full-health emergency heal, remember it applies Forbearance to the target" },
    { spellID = 1022, text = "Blessing of Protection — physical damage immunity for a single ally in danger" },
    { spellID = 6940, text = "Blessing of Sacrifice — redirect damage from an ally to yourself" },
  },
  consumables = {
    { slot = "Flask", text = "Flask of Tempered Aggression for pure throughput, or Flask of Saving Graces if you'd rather have the healer-focused option" },
    { slot = "Food", text = "Loa's Gathering or Feast of Knowledge for raid (Stamina + your highest secondary); Hearty Venom-Spiced Cutlets or Puffer Plate for Mythic+/personal (prefer the Hearty version for death persistence)" },
    { slot = "Potion", text = "A mana or Intellect potion for extended healing-heavy fights. Liquid Luster (builds Versatility over 30s) is a strong ramp/M+ alternative, Potion of Unwavering Focus if you want a pure single-target pick instead; always carry Concentrated Silvermoon Health Potions for the emergency heal." },
    { slot = "Weapon", text = "Shadowcore Oil or the current-tier weapon oil" },
    { slot = "Enchants", text = "Weapon enchant for Intellect/haste; ring enchants for secondary stats" },
    { slot = "Gems", text = "Intellect or Intellect/secondary hybrid gems in available sockets" },
    { slot = "Augment Rune", text = "Crystallized Augment Rune (1-hour primary stat) for progression pulls and high keys; the reusable Ethereal Augment Rune the rest of the time" },
  },
  gear = {
    { slot = "Head", text = "Tier set piece — the set bonus usually shapes your Holy Shock/Holy Power cycle more than raw item level. Season 2's set bonus specifically: Infusion of Light adds a large Flash of Light healing boost and a Greater Judgment absorb, with the four-piece adding a chance for Judgment to grant Infusion of Light and a guaranteed (pricier) proc from Holy Light." },
    { slot = "Neck", text = "Favor Crit and Haste to keep Holy Shock cycling and heals landing faster" },
    { slot = "Back", text = "Pick up Intellect and secondary stats over a pure item-level upgrade" },
    { slot = "Legs", text = "Another tier slot when possible; otherwise the highest item level piece leaning Crit and Haste" },
    { slot = "Ring", text = "Crit or Haste rings depending on whether burst healing or cast speed is your current bottleneck" },
    { slot = "Trinket", text = "One mana-efficiency or regen trinket to extend your healing over long fights" },
    { slot = "Trinket", text = "One throughput trinket, on-use or proc, timed with Avenging Wrath or Holy Avenger" },
    { slot = "Weapon", text = "A one-hander with strong Intellect and secondary stats rather than a pure item-level chase" },
    { slot = "Off-hand", text = "An off-hand caster stat stick for extra Intellect and secondary stats" },
  },
  -- Live top-players pull (DESIGN.md's v1.4 section), NOT SimC - see this
  -- file's header for the full methodology. The plurality build among the
  -- sample: 2/50 (4%) ran this exact code, since flex-point choices vary - but
  -- the bigger signal is that 41/50 (82%) ran Herald of the Sun overall.
  -- Reported honestly rather than dressed up as more decisive than it is.
  mplusMetaLoadout = {
    string = "CEEAzbn3egSOtoSwvPw1U1vTLAAAALAwMAAD2mZGmZWmZsAzMsM2MziRTMMmZGGzWGAGA2AbsNzMzysNzMbNAAAALshBbmBzYwMAAmZYGjRDA",
    source = "Blizzard Battle.net API, US region, 2026-08-30: top 50 current-season Mythic+ Holy Paladins by best keystone level, sampled across all 83 US connected realms' leaderboards. This exact build was the plurality pick (2/50, 4%); 41/50 (82%) ran Herald of the Sun overall.",
    patch = "12.1",
    sampleSize = 50,
  },
  tips = {
    "Keep Beacon of Light on the tank at all times unless you're intentionally repositioning it.",
    "Don't let Holy Power sit at the cap, but banking a point or two while you wait to see if a bigger heal is coming is completely fine — Holy doesn't have to dump on cooldown the way a DPS spec does.",
    "Save your strongest cooldowns for known heavy-damage phases rather than reacting after the raid is already low.",
    "Holy Shock's cooldown is short — using it on cooldown even for small top-ups is rarely wrong.",
    "Divine Toll is short enough on cooldown that you should be casting it often, not hoarding it for emergencies.",
    "Patch 12.1 buffed talents that support Beacon of Virtue.",
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
    { title = "Opener", steps = {
        { spellID = 31935, text = "Avenger's Shield to pull" },
        { spellID = 20271, text = "Judgment" },
        { text = "Blessed Hammer or Hammer of the Righteous, whichever your build runs" },
        { spellID = 26573, text = "Get Consecration down and keep it there" },
        { spellID = 53600, text = "Shield of the Righteous once you've got Holy Power to spend" },
    }},
    { title = "Single Target", steps = {
        { spellID = 26573, text = "Keep Consecration down under yourself near-permanently — it's a real damage and threat floor, not just filler" },
        { spellID = 53600, text = "Shield of the Righteous to keep its mitigation buff at (or close to) 100% uptime — it's off the global cooldown, so this should rarely cost you a generator" },
        { spellID = 31935, text = "Avenger's Shield on cooldown — ranged pull tool, interrupt, and real Holy Power/damage contributor, not just an opener button" },
        { spellID = 20271, text = "Judgment on cooldown for Holy Power generation and debuff" },
        { spellID = 24275, text = "Hammer of Wrath on cooldown once it's available as another generator" },
        { spellID = 53595, text = "Hammer of the Righteous (or Blessed Hammer, choice-node dependent) as a builder and to refresh Consecration overlap" },
        { text = "Templar: press Hammer of Light every time Divine Toll makes it available — don't sit on it" },
        { spellID = 304971, text = "Divine Toll on cooldown to dump a burst of extra Holy Power (line it up with Avenging Wrath when both are up)" },
        { spellID = 85673, text = "Word of Glory when healing is needed and Holy Power is spare" },
        { text = "Fill with basic attacks as builders come off cooldown" },
    }},
    { title = "AoE", steps = {
        { spellID = 26573, text = "Consecration kept active — between it and Avenger's Shield's multi-target hit, these two carry most of your AoE" },
        { spellID = 31935, text = "Avenger's Shield on cooldown — it hits multiple targets and is a big share of your AoE threat and damage" },
        { spellID = 53595, text = "Hammer of the Righteous (or Blessed Hammer) as the primary AoE builder" },
        { spellID = 53600, text = "Shield of the Righteous still prioritized for mitigation uptime" },
        { spellID = 20271, text = "Judgment on cooldown across multiple targets when available" },
        { spellID = 20066, text = "Repentance or crowd control tools to manage dangerous adds" },
        { text = "Otherwise the single-target priority carries over — keep Consecration down and your generators on cooldown rather than switching to a separate AoE-only rotation" },
    }},
    { title = "Mitigation", steps = {
        { spellID = 53600, text = "Shield of the Righteous — off the global cooldown, so keeping its buff up basically never costs you a GCD; never let it fall off during a pull" },
        { spellID = 85673, text = "Word of Glory when you'd rather spend Holy Power on healing than mitigation — it's the one Holy Power spender here that does cost a GCD" },
        { spellID = 86659, text = "Guardian of Ancient Kings for a major defensive cooldown window — it has 2 charges on a 3-minute recharge, so don't be shy about using the first one" },
        { spellID = 31850, text = "Ardent Defender for the heaviest incoming damage spikes" },
        { spellID = 642, text = "Divine Shield as a full damage-immunity panic button when nothing else will save you" },
        { spellID = 1022, text = "Blessing of Protection on yourself or an ally for a physical-damage emergency" },
        { text = "Bank Holy Power slightly before a known burst window so Shield of the Righteous never lapses" },
    }},
    { title = "Opener Notes", steps = {
        { text = "Templar's capstone finisher, Hammer of Light, becomes available every time Divine Toll enables it — spend it promptly rather than continuing to bank Shield of the Righteous stacks" },
        { text = "Templar and Lightsmith are Protection's two hero trees: Templar trades a little consistency for Hammer of Light's periodic burst, while Lightsmith is simpler and layers group-wide absorbs on top of your normal kit. The current Mythic+ meta leans heavily toward Lightsmith (94% of the top-keystone Protection Paladins in this guide's own live-meta sample), for whatever that's worth beyond raw power level" },
    }},
  },
  cooldowns = {
    { spellID = 86659, text = "Guardian of Ancient Kings — strong all-purpose defensive cooldown, 2 charges on a 3-minute recharge" },
    { spellID = 31850, text = "Ardent Defender — save for the most dangerous predicted damage spike" },
    { spellID = 642, text = "Divine Shield — full damage immunity, use when nothing else will keep you standing" },
    { spellID = 1022, text = "Blessing of Protection — physical immunity, use on cooldown for mechanics" },
    { spellID = 6940, text = "Blessing of Sacrifice — soak burst damage meant for an ally" },
    { spellID = 31884, text = "Avenging Wrath — damage and self-healing cooldown, weave in during sustained damage" },
  },
  consumables = {
    { slot = "Flask", text = "Flask of Tempered Swiftness — matches this spec's top secondary; Flask of Alchemical Chaos is the flex pick if your stat weights are close" },
    { slot = "Food", text = "Loa's Gathering or Feast of Knowledge for raid (Stamina + your highest secondary); Hearty Venom-Spiced Cutlets or Puffer Plate for Mythic+/personal (prefer the Hearty version for death persistence)" },
    { slot = "Potion", text = "A Stamina or defensive potion for dangerous pulls/phases. Liquid Luster (builds Versatility over 30s) is a strong ramp/M+ alternative, Potion of Unwavering Focus if you want a pure single-target pick instead; always carry Concentrated Silvermoon Health Potions for the emergency heal." },
    { slot = "Weapon", text = "Shadowcore Oil or the current-tier weapon oil" },
    { slot = "Enchants", text = "Weapon enchant for Stamina/mitigation; ring enchants for secondary stats" },
    { slot = "Gems", text = "Stamina or Stamina/secondary hybrid gems in available sockets" },
    { slot = "Augment Rune", text = "Crystallized Augment Rune (1-hour primary stat) for progression pulls and high keys; the reusable Ethereal Augment Rune the rest of the time" },
  },
  gear = {
    { slot = "Head", text = "Tier set piece — Shield of the Righteous uptime and Holy Power flow usually benefit more than a small item-level gap. Season 2's set bonus specifically: Consecration grows and grants bonus crit chance against enemies standing in it, with the four-piece adding bonus Holy damage to Judgment/Blessed Hammer that doubles on a crit." },
    { slot = "Neck", text = "Balance Stamina for survivability with Haste for faster Holy Power generation" },
    { slot = "Back", text = "Prioritize Stamina and secondary stats over a pure item-level trade" },
    { slot = "Legs", text = "Another tier slot when possible; otherwise the highest item level piece leaning Haste and Mastery" },
    { slot = "Ring", text = "Haste or Mastery rings depending on whether Shield of the Righteous uptime or block chance needs more support" },
    { slot = "Trinket", text = "One defensive on-use trinket saved for the fight's heaviest predicted damage window" },
    { slot = "Trinket", text = "One passive Stamina or avoidance trinket for a steady mitigation floor" },
    { slot = "Weapon", text = "A solid one-hander — abilities carry the damage, so mitigation and Holy Power stats matter more than weapon dps" },
    { slot = "Off-hand", text = "The highest-armor shield available, since it directly backs Shield of the Righteous's mitigation value" },
  },
  mplusLoadout = {
    string = "CIEAAAAAAAAAAAAAAAAAAAAAAsNzYWmZMzYmxyyALzCDDAwAAAAAAg0MDzYmZMzs1GAGYGYGsNAAwMTbzMLzAEYzyGGAGmhxAAsNDwMAjN",
    source = "SimulationCraft default profile (credit, not endorsement of 'best')",
    patch = "12.1",
  },
  -- Live top-players pull (DESIGN.md's v1.4 section), NOT SimC - see this
  -- file's header for the full methodology. The plurality build among the
  -- sample: only 4/50 (8%) ran this exact code, since flex-point choices
  -- vary - but the bigger signal is the hero talent behind it: 47/50 (94%)
  -- of the sample chose Lightsmith over Templar, a real, strong consensus
  -- this loadout reflects even though the literal byte-for-byte string does
  -- not command anything close to majority agreement on its own. Reported
  -- honestly rather than dressed up as more decisive than it is.
  mplusMetaLoadout = {
    string = "CIEAzbn3egSOtoSwvPw1U1vTLsZYWGzYmZmZW2GjZZWmlZMAADAAAAAAaamZZmxMDDbtBgBGwMYDAAgAMzsst0yMjFLLMDgBzshBAzMAYmBMWA",
    source = "Blizzard Battle.net API, US region, 2026-08-30: top 50 current-season Mythic+ Protection Paladins by best keystone level, sampled across all 83 US connected realms' leaderboards. This exact build was the plurality pick (4/50, 8%); 94% of the sample (47/50) ran the Lightsmith hero talent overall.",
    patch = "12.1",
    sampleSize = 50,
  },
  tips = {
    "Never let Shield of the Righteous's mitigation buff lapse — it's the spec's core defensive tool.",
    "Keep Consecration active under yourself for free AoE threat and damage.",
    "Default to spending Holy Power on Shield of the Righteous — only divert it to Word of Glory when you actually need the heal, since SotR is free on the GCD and WoG isn't.",
    "Bank a small Holy Power buffer before predictable burst damage so you can reapply Shield of the Righteous instantly.",
    "Guardian of Ancient Kings has two charges — use the first one without hesitation instead of hoarding both.",
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
        { spellID = 31884, text = "Avenging Wrath on cooldown — your core burst window; everything below is sequenced to land inside it" },
        { text = "Execution Sentence on cooldown, timed for that same window" },
        { text = "Hammer of Light the moment Wake of Ashes makes it available, and again immediately on a Light's Deliverance proc" },
        { spellID = 53385, text = "Divine Storm over Final Verdict whenever a Divine Arbiter proc is up, even against a single target" },
        { spellID = 337247, text = "Final Verdict at 5 Holy Power once the above are on cooldown or unavailable" },
        { spellID = 184575, text = "Blade of Justice, Judgment, and Hammer of Wrath to keep generating Holy Power between spenders" },
        { spellID = 255937, text = "Wake of Ashes (30s) on cooldown to refill Holy Power" },
        { spellID = 304971, text = "Divine Toll on cooldown for the same reason" },
        { spellID = 35395, text = "Crusader Strike as a filler builder" },
        { text = "Avoid overcapping Holy Power — spend before it caps" },
    }},
    { title = "AoE", steps = {
        { spellID = 304971, text = "Divine Toll on cooldown — it hits multiple targets and refills Holy Power for your next Divine Storm" },
        { spellID = 53385, text = "Divine Storm as the primary AoE Holy Power spender" },
        { spellID = 255937, text = "Wake of Ashes to generate Holy Power and hit multiple targets" },
        { spellID = 184575, text = "Blade of Justice on cooldown across the pull" },
        { spellID = 20271, text = "Judgment on cooldown for generation" },
        { spellID = 35395, text = "Crusader Strike as filler when builders are down" },
        { text = "Prioritize Divine Storm over Final Verdict while 2+ targets are engaged" },
    }},
    { title = "Opener Notes", steps = {
        { text = "Open with Blade of Justice into Avenging Wrath, popping your potion and on-use trinkets alongside it, and keep building Holy Power rather than dumping it immediately — the goal is landing your first big spender dump fully inside the Avenging Wrath window" },
        { text = "Talent picks like Radiant Glory and Execution Sentence meaningfully reshape when your burst cooldowns line up — don't assume a fixed cadence without checking your own build" },
        { text = "Templar and Herald of the Sun are Retribution's two hero trees. Templar swaps some of your Holy Power flow toward Templar Strikes for more manual control and adds the Hammer of Light finisher; Herald of the Sun instead leans on Crusading Strikes' passive Holy Power generation — check which one your loadout uses" },
    }},
  },
  cooldowns = {
    { spellID = 31884, text = "Avenging Wrath — core offensive cooldown, the whole rotation is sequenced around this window" },
    { spellID = 304971, text = "Divine Toll — extra Holy Power and multi-target damage, use it often rather than saving it" },
    { text = "Execution Sentence — a slow-hitting burst DoT; cast it early in your cooldown window so its damage lands while everything else is also amplified" },
    { spellID = 255937, text = "Wake of Ashes — Holy Power reset and burst tool, weave into cooldown windows" },
    { text = "Hammer of Light — a Templar capstone finisher that becomes available from Wake of Ashes and certain procs; spend it as soon as it's up" },
    { spellID = 642, text = "Divine Shield — emergency defensive, breaks most damage" },
    { spellID = 1022, text = "Blessing of Protection — utility defensive cooldown for yourself or an ally" },
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
    { slot = "Head", text = "Tier set piece — the set bonus usually reshapes Holy Power flow more than a small item-level gap. Season 2's set bonus increases your Divine Purpose proc rate and boosts whichever Holy Power spender follows a proc — weave Divine Storm on single target or Final Verdict in AoE right after one." },
    { slot = "Neck", text = "Favor Haste to keep Holy Power generators and Templar's Verdict casts flowing" },
    { slot = "Back", text = "Secondary stats matching Haste and Crit outweigh a pure item-level chase" },
    { slot = "Legs", text = "Another tier slot when possible; otherwise the highest item level piece leaning Haste and Crit" },
    { slot = "Ring", text = "Haste or Crit rings depending on your current stat weights" },
    { slot = "Trinket", text = "One on-use Strength or damage trinket lined up with Avenging Wrath or Wake of Ashes" },
    { slot = "Trinket", text = "A passive stat-stick trinket for consistent damage between cooldowns" },
    { slot = "Weapon", text = "The highest item level two-hander available — weapon damage is a large share of Retribution's output" },
  },
  -- MID1 fallback: SimC has not yet published a MID2 (12.1) default profile
  -- for Retribution, so this loadout is pulled from the MID1 (12.0) profile
  -- set instead. Swap to a MID2 profile once SimC publishes one.
  mplusLoadout = {
    string = "CYEAAAAAAAAAAAAAAAAAAAAAAAAAAAAQz22MzsMMzAAAAAAwoMmhZGbDz2wMbzYMmZYGbsNMAAkZm2mZ2mBAsBYAwYGmBzYMbYZGMMmxgB",
    source = "SimulationCraft default profile (credit, not endorsement of 'best')",
    patch = "12.0 (MID1, previous tier)",
  },
  -- Live top-players pull (DESIGN.md's v1.4 section), NOT SimC - see this
  -- file's header for the full methodology. The plurality build among the
  -- sample: 6/50 (12%) ran this exact code, since flex-point choices vary - but
  -- the bigger signal is that 49/50 (98%) ran Herald of the Sun overall.
  -- Reported honestly rather than dressed up as more decisive than it is.
  mplusMetaLoadout = {
    string = "CYEAzbn3egSOtoSwvPw1U1vTLAAAAAwoZbbmZWGzMzAAAAAAYmyYGmZsNmthZ2mxYMGmxCbAYWmtZmZrBBAAsAYAwYGGYGzMbAzMDjZMYA",
    source = "Blizzard Battle.net API, US region, 2026-08-30: top 50 current-season Mythic+ Retribution Paladins by best keystone level, sampled across all 83 US connected realms' leaderboards. This exact build was the plurality pick (6/50, 12%); 49/50 (98%) ran Herald of the Sun overall.",
    patch = "12.1",
    sampleSize = 50,
  },
  tips = {
    "Don't let Holy Power sit at cap — spend it before you overflow and waste generation.",
    "Save Wake of Ashes to line up with your other offensive cooldowns when possible.",
    "Divine Storm outperforms Final Verdict once two or more targets are in melee range.",
    "Divine Toll is worth using on cooldown rather than hoarding — it both refills Holy Power and hits multiple targets.",
    "Keep Blessing of Protection and Lay on Hands available as raid utility, not just self-preservation.",
  },
})
