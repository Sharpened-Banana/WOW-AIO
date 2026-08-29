-- luacheck configuration for SpecSage.
-- WoW runs Lua 5.1 and exposes a large set of globals.

std = "lua51"
max_line_length = 120

exclude_files = { "tests/" }

-- Addon saved variables and slash command globals are written by us.
globals = {
    "SpecSageDB",
    "SpecSageCharDB",
    "SpecSageOverlayFrame",
    "SpecSageCodexFrame",
    "SLASH_SPECSAGE1",
    "SLASH_SPECSAGE2",
    "SlashCmdList",
    "SpecSage_PinHoveredTooltip",
    "BINDING_HEADER_SPECSAGE",
    "BINDING_NAME_SPECSAGE_PIN_TOOLTIP",
    "UISpecialFrames",
}

-- Everything the client provides, read-only from our point of view.
read_globals = {
    -- Namespaces
    "C_AddOns", "C_Spell", "C_SpecializationInfo", "C_Timer", "C_UnitAuras",
    "C_ClassTalents", "C_Traits",
    "AuraUtil", "Settings", "MinimalSliderWithSteppersMixin",

    -- Frames and widgets
    "CreateFrame", "UIParent", "GameFontNormal", "GameFontNormalSmall",
    "GameFontHighlightSmall", "BackdropTemplateMixin", "GameTooltip",

    -- Settings API helpers
    "CreateSettingsListSectionHeaderInitializer", "CreateSettingsButtonInitializer",

    -- Unit and character info
    "UnitGUID", "UnitStat", "UnitArmor", "UnitHealth", "UnitHealthMax", "UnitClass", "InCombatLockdown",
    "GetAverageItemLevel", "GetCritChance", "GetSpellCritChance", "GetRangedCritChance",
    "GetHaste", "GetMasteryEffect", "GetMastery",
    "GetCombatRating", "GetCombatRatingBonus", "GetVersatilityBonus",
    "GetLifesteal", "GetAvoidance", "GetSpeed",
    "GetSpecialization", "GetSpecializationInfo", "GetSpecializationInfoByID",
    "GetSpellInfo", "GetSpellCooldown", "GetAddOnMetadata",
    "GetNumClasses", "GetClassInfo",

    -- Combat log
    "CombatLogGetCurrentEventInfo",
    "COMBATLOG_OBJECT_AFFILIATION_MINE",
    "COMBATLOG_OBJECT_TYPE_PET",
    "COMBATLOG_OBJECT_TYPE_GUARDIAN",
    "CR_VERSATILITY_DAMAGE_DONE", "CR_VERSATILITY_DAMAGE_TAKEN",
    "CR_LIFESTEAL", "CR_AVOIDANCE", "CR_SPEED",
    "CR_CRIT_MELEE", "CR_CRIT_SPELL", "CR_HASTE_MELEE", "CR_HASTE_SPELL", "CR_MASTERY",

    -- Misc
    "GetTime", "format", "strjoin", "tostringall", "bit", "tinsert", "tremove",

    -- Codex: class rail colours/icons, and the talent-loadout export surface.
    "RAID_CLASS_COLORS", "CLASS_ICON_TCOORDS",
}
