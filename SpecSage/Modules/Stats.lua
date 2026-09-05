-- Modules/Stats.lua
-- Character stat readout: item level, primary stat, and secondary ratings.

local ADDON, ns = ...

local Stats = ns:NewModule("Stats")

-- These moved into C_SpecializationInfo in modern retail but the globals are
-- still around; prefer the namespaced versions when present.
local GetSpecialization = (C_SpecializationInfo and C_SpecializationInfo.GetSpecialization) or GetSpecialization
local GetSpecializationInfo = (C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo) or GetSpecializationInfo
local GetSpecializationMasterySpells = (C_SpecializationInfo and C_SpecializationInfo.GetSpecializationMasterySpells)
    or GetSpecializationMasterySpells
local GetSpellDescription = (C_Spell and C_Spell.GetSpellDescription) or GetSpellDescription
local RequestLoadSpellData = C_Spell and C_Spell.RequestLoadSpellData

-- Shared guards for expressions that may touch secret values (Core/Init.lua).
-- KnownPast is a comparison that reports false, rather than throwing, on a
-- secret: each tooltipBuilder runs inside a single pcall in TooltipProvider,
-- so one bad comparison would otherwise cost the whole tooltip body.
local SafeCall = ns.SafeCall
local KnownPast = ns.KnownPast

local STAT_STRENGTH, STAT_AGILITY, STAT_STAMINA, STAT_INTELLECT = 1, 2, 3, 4

-- Combat rating indices, with numeric fallbacks in case a global is missing.
local RATING = {
    critMelee = CR_CRIT_MELEE or 9,
    critSpell = CR_CRIT_SPELL or 11,
    hasteMelee = CR_HASTE_MELEE or 18,
    hasteSpell = CR_HASTE_SPELL or 20,
    mastery = CR_MASTERY or 26,
    versDone = CR_VERSATILITY_DAMAGE_DONE or 29,
    versTaken = CR_VERSATILITY_DAMAGE_TAKEN or 31,
    lifesteal = CR_LIFESTEAL or 17,
    avoidance = CR_AVOIDANCE or 21,
    speed = CR_SPEED or 14,
    dodge = CR_DODGE or 12,
    parry = CR_PARRY or 13,
    block = CR_BLOCK or 15,
}

local STAT_NAMES = {
    [STAT_STRENGTH] = "Strength",
    [STAT_AGILITY] = "Agility",
    [STAT_STAMINA] = "Stamina",
    [STAT_INTELLECT] = "Intellect",
}

local UPDATE_EVENTS = {
    "UNIT_STATS",
    "UNIT_AURA",
    "UNIT_MAXHEALTH",
    "UNIT_ATTACK_POWER",
    "COMBAT_RATING_UPDATE",
    "MASTERY_UPDATE",
    "SPEED_UPDATE",
    "LIFESTEAL_UPDATE",
    "AVOIDANCE_UPDATE",
    "PLAYER_EQUIPMENT_CHANGED",
    "PLAYER_AVG_ITEM_LEVEL_UPDATE",
    "PLAYER_SPECIALIZATION_CHANGED",
    "PLAYER_TALENT_UPDATE",
}

-- Data/API.lua (ns.GuideStore) speaks a slightly different stat-key
-- vocabulary than the overlay's internal row keys (statPriority entries use
-- "versatility"/"avoidance"; overlay rows use the shorter "vers"/"avoid" so
-- they line up with SpecSageCharDB.statsShow). This maps the public,
-- guide-facing vocabulary onto the internal reader keys.
local PUBLIC_STAT_ALIASES = {
    versatility = "vers",
    avoidance = "avoid",
}

--------------------------------------------------------------------------------
-- Stat readers
--------------------------------------------------------------------------------

-- Which primary stat this spec actually scales with.
local function GetPrimaryStatIndex()
    local spec = GetSpecialization and GetSpecialization()
    if spec then
        local _, _, _, _, _, primaryStat = GetSpecializationInfo(spec)
        if primaryStat then return primaryStat end
    end

    -- No spec yet (low level characters): fall back to the largest of the three.
    local best, bestValue = STAT_STRENGTH, -1
    for _, index in ipairs({ STAT_STRENGTH, STAT_AGILITY, STAT_INTELLECT }) do
        local _, value = UnitStat("player", index)
        if value > bestValue then
            best, bestValue = index, value
        end
    end
    return best
end

-- Casters care about spell crit, everyone else about melee crit. Spell crit is
-- per-school, so take the best school the way the paper doll does.
local function GetBestSpellCrit()
    local best = 0
    for school = 2, 7 do
        local crit = GetSpellCritChance(school) or 0
        if crit > best then best = crit end
    end
    return best
end

local function GetCrit(primaryStat)
    if primaryStat == STAT_INTELLECT then
        return GetBestSpellCrit()
    end
    return GetCritChance() or 0
end

local function GetVersatility()
    local rating = CR_VERSATILITY_DAMAGE_DONE or 29
    return (GetCombatRatingBonus(rating) or 0) + (GetVersatilityBonus(rating) or 0)
end

local readers = {}

readers.ilvl = function()
    local _, equipped = GetAverageItemLevel()
    return "Item Level", format("%.1f", equipped or 0)
end

readers.primary = function(primaryStat)
    local _, value = UnitStat("player", primaryStat)
    return STAT_NAMES[primaryStat] or "Primary", ns.FormatNumber(value)
end

readers.stamina = function()
    local _, value = UnitStat("player", STAT_STAMINA)
    return "Stamina", ns.FormatNumber(value)
end

readers.health = function()
    return "Health", ns.FormatNumber(UnitHealthMax("player"))
end

readers.crit = function(primaryStat)
    return "Crit", ns.FormatPercent(GetCrit(primaryStat))
end

readers.haste = function()
    return "Haste", ns.FormatPercent(GetHaste() or 0)
end

readers.mastery = function()
    return "Mastery", ns.FormatPercent(GetMasteryEffect() or 0)
end

readers.vers = function()
    return "Versatility", ns.FormatPercent(GetVersatility())
end

readers.leech = function()
    local value = GetLifesteal and GetLifesteal() or GetCombatRatingBonus(CR_LIFESTEAL or 17) or 0
    return "Leech", ns.FormatPercent(value)
end

readers.avoid = function()
    local value = GetAvoidance and GetAvoidance() or GetCombatRatingBonus(CR_AVOIDANCE or 21) or 0
    return "Avoidance", ns.FormatPercent(value)
end

readers.speed = function()
    local value = GetSpeed and GetSpeed() or GetCombatRatingBonus(CR_SPEED or 14) or 0
    return "Speed", ns.FormatPercent(value)
end

-- Effective armor has been observed reading as an implausible 0 - below
-- base plus a buff independently known to be positive - for a single read,
-- then reading correctly again moments later; Blizzard's own character
-- panel reads this identical field the identical way, so it is not a
-- misread on our end, just a transient value neither of us protects
-- against. Rather than display or calculate from a number that contradicts
-- its own inputs, fall back to the one figure we can compute ourselves.
-- Every comparison goes through KnownPast/SafeCall because any of the three
-- inputs can be secret in restricted content.
local function SaneEffectiveArmor(base, effective, posBuff)
    if not KnownPast(posBuff, 0, true) then return effective end
    local floor = SafeCall(function() return base + posBuff end)
    if not floor then return effective end
    if KnownPast(effective, floor, false) then
        return floor
    end
    return effective
end

readers.armor = function()
    local base, effectiveArmor, _, posBuff = UnitArmor("player")
    return "Armor", ns.FormatNumber(SaneEffectiveArmor(base, effectiveArmor, posBuff))
end

-- Brewmaster-specific, but shown the same way every other stat is: opt-in via
-- statsShow, with no class gating - a Monk not specced Brewmaster just sees
-- 0%, and the player controls visibility via the Stats options anyway.
-- pcall rather than a plain call: the API is newer than the rest of the
-- paper-doll set and its argument checking has varied between builds.
readers.stagger = function()
    local getStagger = C_PaperDollInfo and C_PaperDollInfo.GetStaggerPercentage
    local stagger = 0
    if getStagger then
        local ok, value = pcall(getStagger, "player")
        if ok then stagger = value or 0 end
    end
    return "Stagger", ns.FormatPercent(stagger)
end

-- Effective attack power (base plus buffs/debuffs); mirrors StatBreakdown's
-- own summation of UnitAttackPower's three return values.
local function GetAttackPower()
    local base, posBuff, negBuff = UnitAttackPower("player")
    return (base or 0) + (posBuff or 0) + (negBuff or 0), base, posBuff, negBuff
end

-- Casters care about spell power, everyone else about attack power. Best
-- school follows the same pattern as GetBestSpellCrit above.
local function GetBestSpellPower()
    local best = 0
    for school = 2, 7 do
        local power = GetSpellBonusDamage(school) or 0
        if power > best then best = power end
    end
    return best
end

readers.power = function(primaryStat)
    if primaryStat == STAT_INTELLECT then
        return "Spell Power", ns.FormatNumber(GetBestSpellPower())
    end
    return "Attack Power", ns.FormatNumber(GetAttackPower())
end

-- format() on a secret value propagates the secret into a displayable
-- string, but a bad value would otherwise error; same contract as
-- ns.FormatNumber's fallback.
local function SafeFormat(pattern, value)
    local ok, result = pcall(format, pattern, value or 0)
    if ok then return result end
    return "-"
end

-- Main-hand and off-hand swing times, as the character sheet's Attack Speed.
local function GetAttackSpeeds()
    if not UnitAttackSpeed then return nil, nil end
    local main, off = UnitAttackSpeed("player")
    return main, off
end

readers.attackspeed = function()
    local main = GetAttackSpeeds()
    return "Attack Speed", SafeFormat("%.2f", main)
end

readers.dodge = function()
    return "Dodge", ns.FormatPercent(GetDodgeChance() or 0)
end

readers.parry = function()
    return "Parry", ns.FormatPercent(GetParryChance() or 0)
end

-- Only meaningful with a shield equipped, but shown unconditionally like
-- every other stat: 0% for a caster is as informative as the row being
-- absent, and the player controls visibility via the Stats options anyway.
readers.block = function()
    return "Block", ns.FormatPercent(GetBlockChance() or 0)
end

--------------------------------------------------------------------------------
-- Shared computation
--
-- Both the overlay row builder and the public GetStatValue accessor read a
-- stat through this one function, so there is exactly one place that turns a
-- reader key into a label/value pair.
--------------------------------------------------------------------------------

local function ReadStat(key, primaryStat)
    local reader = readers[key]
    if not reader then return nil end

    local ok, label, value = pcall(reader, primaryStat)
    if not ok then return nil end
    return label, value
end

--------------------------------------------------------------------------------
-- Tooltips
--
-- Built on hover rather than on every stat update, which fires often in combat.
--------------------------------------------------------------------------------

local function Rating(index)
    return GetCombatRating and GetCombatRating(index) or 0
end

-- Whether GetArmorEffectiveness reports a 0-1 ratio or an already-scaled
-- percentage, worked out ONCE from a probe made with our own literal numbers
-- and then cached as a multiplier.
--
-- The probe exists because of how secret values behave. Armor is secret in
-- restricted content, a secret argument yields a secret result, and the
-- three rules that follow from Midnight's design are:
--
--   arithmetic on a secret  -> allowed, produces another secret
--   formatting a secret     -> allowed, produces a secret string to display
--   COMPARING a secret      -> errors
--
-- (Displaying is permitted; branching on the value is what Blizzard blocks.)
-- Deciding ratio-vs-percentage per call meant comparing the live value, so
-- the moment a buff made armor secret the comparison threw, the guard
-- returned nil, and the reduction line silently vanished from the tooltip.
-- Probing with constants keeps every comparison on values that can never be
-- secret, leaving the live path to do arithmetic and formatting only.
local armorEffectivenessScale

local function GetArmorEffectivenessScale()
    if armorEffectivenessScale then return armorEffectivenessScale end
    if not (C_PaperDollInfo and C_PaperDollInfo.GetArmorEffectiveness) then return nil end

    -- Literal armor and level: never secret, so this comparison is safe.
    local ok, probe = pcall(C_PaperDollInfo.GetArmorEffectiveness, 1000, 80)
    if not ok or type(probe) ~= "number" then return nil end

    armorEffectivenessScale = (probe <= 1) and 100 or 1
    return armorEffectivenessScale
end

-- A unit's level for the armor curve. UnitEffectiveLevel first: in scaled
-- content (Timewalking, Chromie Time, level-synced zones) it is the level
-- the game actually fights you at, which is the one the armor curve uses,
-- and UnitLevel is only the fallback for a client without it. Read under
-- SafeCall because a unit token that resolves to nothing readable mid-combat
-- can hand back a secret.
local function ReadLevel(unit)
    local level
    if UnitEffectiveLevel then
        level = SafeCall(function() return UnitEffectiveLevel(unit) end)
    end
    if not level and UnitLevel then
        level = SafeCall(function() return UnitLevel(unit) end)
    end
    if type(level) ~= "number" or level <= 0 then return nil end
    return level
end

-- What the armor actually does, the way Blizzard's own character sheet puts
-- it ("Physical damage reduction: 56.62%"), rather than only the rating.
--
-- The number comes from C_PaperDollInfo.GetArmorEffectiveness against an
-- attacker of the player's own level - "an evenly matched enemy" in
-- Blizzard's wording.
--
-- The result may itself be a secret; ns.FormatPercent renders one fine. No
-- clamping is applied, deliberately - clamping means comparing, and the API
-- does not return out-of-range effectiveness anyway.
local function GetArmorReductionPercent(effectiveArmor)
    local scale = GetArmorEffectivenessScale()
    if not scale then return nil end

    -- Re-checked rather than relying on the probe having found it: the scale
    -- is cached for the session, so a client that loses the API afterwards
    -- would otherwise reach the pcall below - where the function is looked up
    -- while building the argument list, i.e. OUTSIDE the pcall, and indexing
    -- a nil C_PaperDollInfo would throw past the guard and cost the whole
    -- tooltip its lines.
    local getEffectiveness = C_PaperDollInfo and C_PaperDollInfo.GetArmorEffectiveness
    if not getEffectiveness then return nil end

    local level = ReadLevel("player")
    if not level then return nil end

    local ok, effectiveness = pcall(getEffectiveness, effectiveArmor, level)
    if not ok then return nil end

    -- Arithmetic only: a secret in yields a secret out, which still displays.
    return SafeCall(function() return effectiveness * scale end)
end

-- Same idea, but against the player's actual current target rather than an
-- assumed same-level enemy - what the character panel shows once you have
-- someone selected. Shares the same scale as GetArmorEffectiveness: they are
-- clearly the same family of API, just against a different attacker. Gated
-- on a hostile target because a friendly one has no attacker level worth
-- reporting, and UnitCanAttack is the one check that survives a secret
-- reaction flag (it returns a boolean, never the underlying value).
local function GetArmorReductionAgainstTarget(effectiveArmor)
    local scale = GetArmorEffectivenessScale()
    if not scale then return nil end

    local againstTarget = C_PaperDollInfo and C_PaperDollInfo.GetArmorEffectivenessAgainstTarget
    if not (againstTarget and UnitExists and UnitCanAttack) then return nil end
    if not (UnitExists("target") and UnitCanAttack("player", "target")) then return nil end

    local ok, effectiveness = pcall(againstTarget, effectiveArmor)
    if not ok or effectiveness == nil then return nil end

    return SafeCall(function() return effectiveness * scale end)
end

--------------------------------------------------------------------------------
-- Manual armor-reduction estimate
--
-- The two functions above go through Blizzard's own curve via
-- C_PaperDollInfo, which is why they are trustworthy - but that call can
-- fail even when the API exists at all: effective armor is a secret value
-- during some combat/content states (see Core/Init.lua), and Blizzard's own
-- internal comparisons against a secret throw, caught above only as "no
-- result." When that happens this manual formula, built from pure
-- arithmetic (division and addition only, never a comparison on the armor
-- value itself), still works on a secret the same way ns.FormatNumber does.
--
-- The formula is Blizzard's published post-squish curve, unchanged since
-- Legion aside from one new linear term added at each later level-cap
-- bump (60, 80, 85); it is used here ONLY as a last resort and is never
-- trusted blindly - see ValidateEstimate below. (An earlier SpecSage build
-- refused any formula because the pre-Shadowlands 85*level+400 form was
-- ~8 points off; the extra terms are what closes that gap.)
--------------------------------------------------------------------------------

local function EstimateArmorConstant(level)
    local k = 400 + 85 * level
    if level > 59 then k = k + 4.5 * (level - 59) end
    if level > 80 then k = k + 20 * (level - 80) end
    if level > 85 then k = k + 22 * (level - 85) end
    return k
end

-- armor is never tested for truthiness here - it can be the same secret
-- value the live API just failed on, and a plain `if`/`not` on one throws
-- exactly like a comparison does. Only pure arithmetic touches it. The
-- result can end up secret too (division doesn't strip the tag), so success
-- is reported through pcall's own boolean - never by testing the number
-- itself - and callers must do the same rather than write `if estimate`.
local function EstimateArmorReductionPercent(armor, level)
    if not level or level <= 0 then return false, nil end
    local ok, pct = pcall(function()
        local raw = (armor / (armor + EstimateArmorConstant(level))) * 100
        -- Armor's reduction is capped at 75% in the client; only clamp when
        -- the comparison is possible (a secret result is left as-is).
        if KnownPast(raw, 75, true) then return 75 end
        return raw
    end)
    if not ok then return false, nil end
    return true, pct
end

-- A future level squish or curve rework would make the formula above wrong
-- without throwing - it would just quietly compute a different number. So
-- rather than trust it forever, check it against the real API every time
-- that succeeds, using the exact armor/level pair just proven live: one
-- comparison more than about a percentage point off is enough to stop
-- offering the estimate for the rest of the session.
local estimateTrusted = true

local function ValidateEstimate(armor, level, actualPercent)
    if not estimateTrusted then return end

    -- Effective armor has been observed reading as an implausible 0 for a
    -- moment (see SaneEffectiveArmor above) - comparing an estimate against
    -- a live result computed from a momentarily-bad input would read as the
    -- FORMULA being wrong and disable it for the rest of the session over
    -- nothing. Only validate when armor is confirmed to be a real positive
    -- number (a secret one reports false here and is skipped too).
    if not KnownPast(armor, 0, true) then return end

    local haveEstimate, estimate = EstimateArmorReductionPercent(armor, level)
    if not haveEstimate then return end

    local withinTolerance = SafeCall(function()
        return math.abs(estimate - actualPercent) < 1
    end)
    if withinTolerance ~= true then
        estimateTrusted = false
    end
end

local function RatingLines(index, ratingLabel)
    return {
        { left = ratingLabel or "Rating", right = ns.FormatNumber(Rating(index)) },
        { left = "From rating", right = ns.FormatPercent(GetCombatRatingBonus(index) or 0) },
    }
end

local DESCRIPTIONS = {
    ilvl = "The average item level of the gear you are wearing. Overall also counts items in your bags.",
    primary = "Your specialisation's main stat. It increases the damage or healing of most of your abilities.",
    stamina = "Each point of Stamina increases your maximum health.",
    health = "The most damage you can take before dying.",
    crit = "Chance for your attacks and spells to critically strike for extra damage or healing.",
    haste = "Increases attack and casting speed, and the rate of many periodic effects and resource generation.",
    mastery = "Improves a bonus specific to your specialisation.",
    vers = "Increases damage and healing done, and reduces damage taken.",
    leech = "Heals you for a portion of the damage and healing you deal.",
    avoid = "Reduces damage taken from area-of-effect attacks.",
    speed = "Increases your movement speed.",
    armor = "Reduces the physical damage you take.",
    power = "Increases the damage of your attacks or spells, depending on which one your specialisation scales with.",
    attackspeed = "How long each of your weapon swings takes. Haste lowers it.",
    dodge = "Chance to completely avoid a melee or ranged attack.",
    parry = "Chance to deflect a melee attack and reduce the attacker's next swing timer. Requires a melee weapon.",
    block = "Chance for your shield to block part of an incoming melee hit. Requires a shield.",
    stagger = "Brewmaster: the portion of incoming damage held back to be taken over time instead of all at once.",
}

local tooltipBuilders = {}

tooltipBuilders.ilvl = function()
    local overall, equipped = GetAverageItemLevel()
    return {
        lines = {
            { left = "Equipped", right = format("%.1f", equipped or 0) },
            { left = "Overall", right = format("%.1f", overall or 0) },
        },
    }
end

local function StatBreakdown(index)
    local base, total, posBuff, negBuff = UnitStat("player", index)
    local lines = {
        { left = "Base", right = ns.FormatNumber(base) },
    }
    if KnownPast(posBuff, 0, true) then
        lines[#lines + 1] = { left = "From gear and buffs", right = "+" .. ns.FormatNumber(posBuff) }
    end
    if KnownPast(negBuff, 0, false) then
        lines[#lines + 1] = { left = "Reduced by", right = ns.FormatNumber(negBuff) }
    end
    return lines, total
end

tooltipBuilders.primary = function(primaryStat)
    local lines = StatBreakdown(primaryStat)
    return { lines = lines }
end

tooltipBuilders.stamina = function()
    local lines = StatBreakdown(STAT_STAMINA)
    lines[#lines + 1] = { left = "Maximum health", right = ns.FormatNumber(UnitHealthMax("player")) }
    return { lines = lines }
end

tooltipBuilders.health = function()
    return {
        lines = {
            { left = "Current", right = ns.FormatNumber(UnitHealth("player")) },
            { left = "Maximum", right = ns.FormatNumber(UnitHealthMax("player")) },
        },
    }
end

tooltipBuilders.crit = function(primaryStat)
    local index = (primaryStat == STAT_INTELLECT) and RATING.critSpell or RATING.critMelee
    return { lines = RatingLines(index) }
end

tooltipBuilders.haste = function(primaryStat)
    local index = (primaryStat == STAT_INTELLECT) and RATING.hasteSpell or RATING.hasteMelee
    return { lines = RatingLines(index) }
end

-- Mastery is the one secondary stat whose effect is entirely spec-specific
-- ("Frostbolt and Frozen Orb deal more damage", "your shield absorbs more"),
-- so a single fixed description would either be too vague to mean anything
-- or wrong for most specs reading it. The spell description already comes
-- back fully computed with this character's current mastery plugged in, so
-- it doubles as an explanation and a live value.
local function GetMasterySpellDescription()
    if not (GetSpecializationMasterySpells and GetSpecialization and GetSpellDescription) then return nil end

    local spec = GetSpecialization()
    if not spec then return nil end

    local ok, spell1, spell2 = pcall(GetSpecializationMasterySpells, spec)
    if not ok then return nil end

    local lines = {}
    for _, spellID in ipairs({ spell1 or 0, spell2 or 0 }) do
        if spellID > 0 then
            local descOk, desc = pcall(GetSpellDescription, spellID)
            if descOk and desc and desc ~= "" then
                lines[#lines + 1] = desc
            elseif RequestLoadSpellData then
                -- Spell text loads asynchronously; an empty description just
                -- means it hasn't arrived yet (a documented C_Spell quirk,
                -- not a real absence). Kick off the load so a later hover -
                -- there is no event worth waiting on here - gets the real
                -- text instead of the generic fallback forever.
                pcall(RequestLoadSpellData, spellID)
            end
        end
    end

    if #lines == 0 then return nil end
    return table.concat(lines, "\n\n")
end

tooltipBuilders.mastery = function()
    local lines = RatingLines(RATING.mastery)
    if GetMastery then
        lines[#lines + 1] = { left = "Mastery points", right = format("%.2f", GetMastery() or 0) }
    end
    return { lines = lines, description = GetMasterySpellDescription() }
end

tooltipBuilders.vers = function()
    return {
        lines = {
            { left = "Rating", right = ns.FormatNumber(Rating(RATING.versDone)) },
            { left = "Damage and healing done", right = ns.FormatPercent(GetVersatility()) },
            { left = "Damage taken reduced by", right = ns.FormatPercent(
                (GetCombatRatingBonus(RATING.versTaken) or 0) + (GetVersatilityBonus(RATING.versTaken) or 0)) },
        },
    }
end

tooltipBuilders.leech = function() return { lines = RatingLines(RATING.lifesteal) } end
tooltipBuilders.avoid = function() return { lines = RatingLines(RATING.avoidance) } end
tooltipBuilders.speed = function() return { lines = RatingLines(RATING.speed) } end

tooltipBuilders.armor = function()
    local base, effective, _, posBuff = UnitArmor("player")
    effective = SaneEffectiveArmor(base, effective, posBuff)
    local lines = {
        { left = "Base", right = ns.FormatNumber(base) },
        { left = "Effective", right = ns.FormatNumber(effective) },
    }
    if KnownPast(posBuff, 0, true) then
        lines[#lines + 1] = { left = "From buffs", right = "+" .. ns.FormatNumber(posBuff) }
    end

    -- What the armor is actually worth, the way the character sheet shows it.
    -- Recomputed from the current effective armor every call, so a pinned
    -- tooltip's periodic refresh (and a fresh hover) picks up gear, buff,
    -- debuff, or target changes rather than showing a stale reduction.
    local targetReduction = GetArmorReductionAgainstTarget(effective)
    local reduction = not targetReduction and GetArmorReductionPercent(effective) or nil

    if targetReduction then
        ValidateEstimate(effective, ReadLevel("target"), targetReduction)
        lines[#lines + 1] = { left = "Physical damage reduction", right = ns.FormatPercent(targetReduction) }
        lines[#lines + 1] = { left = "|cff808080Against your current target|r", right = "" }
    elseif reduction then
        ValidateEstimate(effective, ReadLevel("player"), reduction)
        lines[#lines + 1] = { left = "Physical damage reduction", right = ns.FormatPercent(reduction) }
        lines[#lines + 1] = { left = "|cff808080Against an evenly matched enemy|r", right = "" }
    else
        -- The live call failed - almost always because effective armor is
        -- unreadable right now, either a Patch 12.0 secret value mid-combat
        -- or this instance restricting addon reads outright (the same
        -- reason Procs/Buffs may be reporting aura tracking as paused).
        -- Fall back to the manual estimate rather than a cached pre-fight
        -- figure, which would be actively misleading during the exact
        -- moment a big armor buff is up.
        --
        -- The fallback note below is shown unconditionally rather than
        -- gated on the API "existing" (formerly checked via the scale
        -- probe): that probe can fail for the exact same live-read reasons
        -- the two calls above just did, which would otherwise go silent
        -- here too rather than say anything at all.
        local haveEstimate, estimate = false, nil
        if estimateTrusted then
            haveEstimate, estimate = EstimateArmorReductionPercent(effective, ReadLevel("player"))
        end

        if haveEstimate then
            lines[#lines + 1] = { left = "Physical damage reduction (estimated)", right = ns.FormatPercent(estimate) }
            lines[#lines + 1] = { left = "|cff808080Live figure unavailable right now|r", right = "" }
        else
            lines[#lines + 1] = { left = "|cff808080Damage reduction unavailable right now|r", right = "" }
        end
    end

    return { lines = lines }
end

tooltipBuilders.attackspeed = function()
    local main, off = GetAttackSpeeds()
    local lines = {
        { left = "Main hand", right = SafeFormat("%.2f sec", main) },
    }
    if off and KnownPast(off, 0, true) then
        lines[#lines + 1] = { left = "Off hand", right = SafeFormat("%.2f sec", off) }
    end

    -- Haste is what moves this number, so name the connection rather than
    -- leaving the player to infer it.
    lines[#lines + 1] = { left = "Haste", right = ns.FormatPercent(GetHaste() or 0) }
    return { lines = lines }
end

tooltipBuilders.power = function(primaryStat)
    if primaryStat == STAT_INTELLECT then
        return { lines = { { left = "Spell power", right = ns.FormatNumber(GetBestSpellPower()) } } }
    end

    local _, base, posBuff, negBuff = GetAttackPower()
    local lines = {
        { left = "Base", right = ns.FormatNumber(base) },
    }
    if KnownPast(posBuff, 0, true) then
        lines[#lines + 1] = { left = "From gear and buffs", right = "+" .. ns.FormatNumber(posBuff) }
    end
    if KnownPast(negBuff, 0, false) then
        lines[#lines + 1] = { left = "Reduced by", right = ns.FormatNumber(negBuff) }
    end
    return { lines = lines }
end

tooltipBuilders.dodge = function() return { lines = RatingLines(RATING.dodge) } end
tooltipBuilders.parry = function() return { lines = RatingLines(RATING.parry) } end
tooltipBuilders.block = function() return { lines = RatingLines(RATING.block) } end

-- GetStaggerPercentage's second return is the stagger against the current
-- target specifically (the character panel's own "vs. target" figure); it
-- is nil with no target, so the line simply does not appear then.
tooltipBuilders.stagger = function()
    local getStagger = C_PaperDollInfo and C_PaperDollInfo.GetStaggerPercentage
    local stagger, staggerAgainstTarget = 0, nil
    if getStagger then
        local ok, value, valueAgainstTarget = pcall(getStagger, "player")
        if ok then
            stagger, staggerAgainstTarget = value or 0, valueAgainstTarget
        end
    end

    local lines = {
        { left = "Of health staggered", right = ns.FormatPercent(stagger or 0) },
    }
    if staggerAgainstTarget then
        lines[#lines + 1] = { left = "From your current target", right = ns.FormatPercent(staggerAgainstTarget) }
    end

    return { lines = lines }
end

-- Called by the UI when the mouse enters a stat row.
local function TooltipProvider(key)
    local entry
    for _, candidate in ipairs(ns.STAT_LIST) do
        if candidate.key == key then
            entry = candidate
            break
        end
    end
    if not entry then return nil end

    local primaryStat = GetPrimaryStatIndex()
    local label, value = ReadStat(key, primaryStat)

    local data = { title = label or entry.label, value = value, description = DESCRIPTIONS[key] }

    local builder = tooltipBuilders[key]
    if builder then
        local ok, built = pcall(builder, primaryStat)
        if ok and built then
            data.lines = built.lines
            -- A builder can supply a live, spec-specific description (see
            -- mastery) that's more useful than the fixed one in DESCRIPTIONS;
            -- falling back to the static text when it can't (e.g. no spec yet).
            if built.description then
                data.description = built.description
            end
        end
    end

    return data
end

--------------------------------------------------------------------------------
-- Module
--------------------------------------------------------------------------------

function Stats:Update()
    if not ns.db.stats.enabled then
        ns.UI:SetSection("stats", nil)
        return
    end

    local shown = ns.StatsShown()
    local primaryStat = GetPrimaryStatIndex()
    local rows = {}

    for _, entry in ipairs(ns.STAT_LIST) do
        if shown[entry.key] then
            local label, value = ReadStat(entry.key, primaryStat)
            if value then
                rows[#rows + 1] = { label = label, value = value, tooltipKey = entry.key }
            end
        end
    end

    ns.UI:SetSection("stats", rows, TooltipProvider)
end

-- Public accessor for other parts of the addon (the Codex's stat-priority
-- page) that want just the formatted display value for a stat, without
-- caring whether the overlay is showing that row right now. Accepts both the
-- overlay's internal keys and the guide-facing vocabulary from
-- Data/API.lua (e.g. "versatility", "avoidance"). Returns nil for a key that
-- does not resolve to a reader, rather than erroring.
function Stats:GetStatValue(statKey)
    if type(statKey) ~= "string" then return nil end

    local key = PUBLIC_STAT_ALIASES[statKey] or statKey
    local _, value = ReadStat(key, GetPrimaryStatIndex())
    return value
end

function Stats:OnEnable()
    local function OnStatEvent(event, unit)
        -- Unit-scoped events fire for every unit in range; only ours matters.
        -- UNIT_AURA's payload is fully secret while auras are secret, and
        -- comparing a secret value errors, so an unreadable unit falls
        -- through to updating rather than taking the handler down.
        local ok, other = pcall(function() return unit and unit ~= "player" end)
        if ok and other then return end
        self:Update()
    end

    for _, event in ipairs(UPDATE_EVENTS) do
        ns:RegisterEvent(event, OnStatEvent)
    end

    self:Update()
end

function Stats:OnConfigChanged()
    self:Update()
end
