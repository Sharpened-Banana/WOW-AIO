-- Data/API.lua
-- ns.GuideStore: the registration API guide packs (shipped or third-party)
-- use to publish class/spec guide content.
--
-- Guide data files contain data only, so a typo or a bad third-party guide
-- pack must never be able to take the rest of the addon down. Every entry
-- point here validates its input and skips (with a printed warning) rather
-- than erroring.

local ADDON, ns = ...

local GuideStore = {}
ns.GuideStore = GuideStore

--------------------------------------------------------------------------------
-- The 13 retail classes, in Blizzard's classID order. Listed here (rather
-- than read from the game) so GetClasses() works the same in and out of the
-- client, and so a class with no guides registered yet is still listed.
--------------------------------------------------------------------------------

local CLASSES = {
    { token = "WARRIOR",     name = "Warrior",      classID = 1 },
    { token = "PALADIN",     name = "Paladin",       classID = 2 },
    { token = "HUNTER",      name = "Hunter",        classID = 3 },
    { token = "ROGUE",       name = "Rogue",         classID = 4 },
    { token = "PRIEST",      name = "Priest",        classID = 5 },
    { token = "DEATHKNIGHT", name = "Death Knight",  classID = 6 },
    { token = "SHAMAN",      name = "Shaman",        classID = 7 },
    { token = "MAGE",        name = "Mage",          classID = 8 },
    { token = "WARLOCK",     name = "Warlock",       classID = 9 },
    { token = "MONK",        name = "Monk",          classID = 10 },
    { token = "DRUID",       name = "Druid",         classID = 11 },
    { token = "DEMONHUNTER", name = "Demon Hunter",  classID = 12 },
    { token = "EVOKER",      name = "Evoker",        classID = 13 },
}

local CLASS_BY_TOKEN = {}
for _, entry in ipairs(CLASSES) do
    CLASS_BY_TOKEN[entry.token] = entry
end

-- Valid `stat` keys inside a guide's statPriority list. Matches the overlay's
-- public stat vocabulary (see Modules/Stats.lua's Stats:GetStatValue).
local VALID_STAT_KEYS = {
    primary = true, crit = true, haste = true, mastery = true, versatility = true,
    leech = true, avoidance = true, speed = true, armor = true, stamina = true,
}

local VALID_ROLES = { DAMAGER = true, TANK = true, HEALER = true }

-- Valid `slot` values inside a guide's optional `gear` array (DESIGN.md's
-- "BiS / Gear" section — the same 14-slot vocabulary Modules/BiS.lua's
-- personal checklist entries are validated against, kept as an independent
-- copy there the same way Modules/Loadouts.lua's VALID_CATEGORIES stands on
-- its own rather than reaching into another module's internals).
local VALID_GEAR_SLOTS = {
    Head = true, Neck = true, Shoulder = true, Back = true, Chest = true,
    Wrist = true, Hands = true, Waist = true, Legs = true, Feet = true,
    Ring = true, Trinket = true, Weapon = true, ["Off-hand"] = true,
}

--------------------------------------------------------------------------------
-- Storage
--------------------------------------------------------------------------------

local guides = {}         -- specID -> guide table
local classSpecs = {}      -- classToken -> ordered array of specIDs, registration order
local specClass = {}        -- specID -> classToken, for cross-checking

--------------------------------------------------------------------------------
-- Validation
--
-- Every check returns false plus a human-readable reason on failure, so
-- RegisterSpec can print one useful line and move on.
--------------------------------------------------------------------------------

local function ValidateStatPriority(statPriority)
    if statPriority == nil then return true end
    if type(statPriority) ~= "table" then
        return false, "statPriority must be a table"
    end

    for index, entry in ipairs(statPriority) do
        if type(entry) ~= "table" then
            return false, format("statPriority[%d] must be a table", index)
        end
        if type(entry.stat) ~= "string" or not VALID_STAT_KEYS[entry.stat] then
            return false, format("statPriority[%d] has an invalid stat key '%s'", index, tostring(entry.stat))
        end
    end

    return true
end

-- Optional, per DESIGN.md: shipped guides that predate v1.1 have no `gear`
-- key at all, which must validate the same as an empty one.
local function ValidateGear(gear)
    if gear == nil then return true end
    if type(gear) ~= "table" then
        return false, "gear must be a table"
    end

    for index, entry in ipairs(gear) do
        if type(entry) ~= "table" then
            return false, format("gear[%d] must be a table", index)
        end
        if type(entry.slot) ~= "string" or not VALID_GEAR_SLOTS[entry.slot] then
            return false, format("gear[%d] has an invalid slot '%s'", index, tostring(entry.slot))
        end
        if type(entry.text) ~= "string" or entry.text == "" then
            return false, format("gear[%d] must have non-empty text", index)
        end
        -- Optional (v1.5): a concrete item the Codex renders as a clickable
        -- item link beside the guidance text.
        if entry.itemID ~= nil and type(entry.itemID) ~= "number" then
            return false, format("gear[%d].itemID must be a number when present", index)
        end
    end

    return true
end

-- Trinket tier lists (v1.5, DESIGN.md's "Trinket tier lists" section). A
-- registration is either { unavailable = "<reason>" } (the Codex shows the
-- reason) or { source, patch, lists = { { title, fightStyle, list = { row,
-- ... } }, ... } } where every row is a concrete item: itemID, name, tier
-- (S/A/B/C), gain (percent over baseline), and optional ilvl/source/onUse.
-- D is only ever an editorial (guide-site) tier; the sim buckets stop at C.
local VALID_TIERS = { S = true, A = true, B = true, C = true, D = true, F = true }

local function ValidateTrinkets(data)
    if type(data) ~= "table" then
        return false, "trinkets must be a table"
    end

    if data.unavailable ~= nil then
        if type(data.unavailable) ~= "string" or data.unavailable == "" then
            return false, "trinkets.unavailable must be a non-empty string"
        end
        return true
    end

    if type(data.lists) ~= "table" or #data.lists == 0 then
        return false, "trinkets.lists must be a non-empty array"
    end

    for listIndex, listEntry in ipairs(data.lists) do
        if type(listEntry) ~= "table" or type(listEntry.title) ~= "string" or listEntry.title == "" then
            return false, format("trinkets.lists[%d] must have a title", listIndex)
        end
        if type(listEntry.list) ~= "table" or #listEntry.list == 0 then
            return false, format("trinkets.lists[%d].list must be a non-empty array", listIndex)
        end
        for rowIndex, row in ipairs(listEntry.list) do
            local where = format("trinkets.lists[%d].list[%d]", listIndex, rowIndex)
            if type(row) ~= "table" then
                return false, where .. " must be a table"
            end
            if type(row.itemID) ~= "number" then
                return false, where .. ".itemID must be a number"
            end
            if type(row.name) ~= "string" or row.name == "" then
                return false, where .. ".name must be a non-empty string"
            end
            if type(row.tier) ~= "string" or not VALID_TIERS[row.tier] then
                return false, where .. ".tier must be S, A, B, C, D or F"
            end
            -- gain is a sim number; an editorial (guide-site) list has none.
            if row.gain ~= nil and type(row.gain) ~= "number" then
                return false, where .. ".gain must be a number when present"
            end
            if row.siteTier ~= nil and (type(row.siteTier) ~= "string" or not VALID_TIERS[row.siteTier]) then
                return false, where .. ".siteTier must be a tier letter when present"
            end
            if row.whTier ~= nil and (type(row.whTier) ~= "string" or not VALID_TIERS[row.whTier]) then
                return false, where .. ".whTier must be a tier letter when present"
            end
        end
    end

    if data.note ~= nil and (type(data.note) ~= "string" or data.note == "") then
        return false, "trinkets.note must be a non-empty string when present"
    end

    return true
end

-- Shared shape for `mplusLoadout` (v1.2), `raidLoadout` (v1.3), and
-- `mplusMetaLoadout` (v1.4): most guides have none of these keys at all,
-- which must validate the same as a pre-v1.2 guide. `source` is documentary
-- (credits SimC or Blizzard's API) and is not itself validated - only
-- `string` and `patch` gate acceptance, the two fields the Codex actually
-- reads to render and Add-to-vault a row. `sampleSize`, when present (only
-- mplusMetaLoadout carries one - an empirical aggregate has a sample size,
-- a single curated SimC profile does not), must be a positive number: the
-- Codex renders it directly into the row label ("top 50"), so a bad value
-- there would show garbage to the player rather than merely failing to
-- validate. `fieldName` is only used to word the error.
local function ValidateLoadoutSuggestion(loadout, fieldName)
    if loadout == nil then return true end
    if type(loadout) ~= "table" then
        return false, fieldName .. " must be a table"
    end

    if type(loadout.string) ~= "string" or loadout.string == "" then
        return false, fieldName .. ".string must be a non-empty string"
    end

    if type(loadout.patch) ~= "string" or loadout.patch == "" then
        return false, fieldName .. ".patch must be a non-empty string"
    end

    if loadout.sampleSize ~= nil and (type(loadout.sampleSize) ~= "number" or loadout.sampleSize <= 0) then
        return false, fieldName .. ".sampleSize must be a positive number when present"
    end

    return true
end

local function ValidateGuide(classToken, specID, guide)
    if type(classToken) ~= "string" or not CLASS_BY_TOKEN[classToken] then
        return false, format("unknown class token '%s'", tostring(classToken))
    end

    if type(specID) ~= "number" then
        return false, "specID must be a number"
    end

    if type(guide) ~= "table" then
        return false, "guide must be a table"
    end

    if type(guide.specName) ~= "string" or guide.specName == "" then
        return false, "guide.specName must be a non-empty string"
    end

    if guide.role ~= nil and not VALID_ROLES[guide.role] then
        return false, format("guide.role must be DAMAGER, TANK or HEALER, got '%s'", tostring(guide.role))
    end

    local ok, err = ValidateStatPriority(guide.statPriority)
    if not ok then
        return false, "guide." .. err
    end

    ok, err = ValidateGear(guide.gear)
    if not ok then
        return false, "guide." .. err
    end

    ok, err = ValidateLoadoutSuggestion(guide.mplusLoadout, "mplusLoadout")
    if not ok then
        return false, "guide." .. err
    end

    ok, err = ValidateLoadoutSuggestion(guide.raidLoadout, "raidLoadout")
    if not ok then
        return false, "guide." .. err
    end

    ok, err = ValidateLoadoutSuggestion(guide.mplusMetaLoadout, "mplusMetaLoadout")
    if not ok then
        return false, "guide." .. err
    end

    return true
end

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

-- Registers (or overwrites) the guide for one spec. Returns true on success;
-- on failure it prints a warning and returns false without touching storage.
function GuideStore:RegisterSpec(classToken, specID, guide)
    local ok, err = ValidateGuide(classToken, specID, guide)
    if not ok then
        ns.Print(format("|cffff4444guide rejected|r (class=%s spec=%s): %s",
            tostring(classToken), tostring(specID), err))
        return false
    end

    guides[specID] = guide
    specClass[specID] = classToken

    local specs = classSpecs[classToken]
    if not specs then
        specs = {}
        classSpecs[classToken] = specs
    end

    local alreadyListed = false
    for _, existing in ipairs(specs) do
        if existing == specID then
            alreadyListed = true
            break
        end
    end
    if not alreadyListed then
        specs[#specs + 1] = specID
    end

    return true
end

-- Trinket tier lists (v1.5): kept apart from the guide table so the
-- generated Data/Trinkets.lua can register them without touching the
-- hand-written guide files, and so a third-party pack can ship its own.
local trinkets = {}   -- specID -> trinkets table

-- Registers (or overwrites) a spec's trinket tier lists. Same validate-and-
-- skip contract as RegisterSpec: returns true, or prints one warning and
-- returns false. The spec does not need a guide registered first.
function GuideStore:RegisterTrinkets(specID, data)
    if type(specID) ~= "number" then
        ns.Print(format("|cffff4444trinkets rejected|r (spec=%s): specID must be a number", tostring(specID)))
        return false
    end
    local ok, err = ValidateTrinkets(data)
    if not ok then
        ns.Print(format("|cffff4444trinkets rejected|r (spec=%s): %s", tostring(specID), err))
        return false
    end
    trinkets[specID] = data
    return true
end

-- Returns the trinkets table for a specID (either shape RegisterTrinkets
-- accepts), or nil if none is registered.
function GuideStore:GetTrinkets(specID)
    return trinkets[specID]
end

-- Linked BiS lists (v1.5, generated Data/BiS.lua): { source, patch, lists =
-- { { title, list = { { slot, itemID, name, from }, ... } }, ... } }. Every
-- row is a concrete item in one of the 14 gear slots.
local bisLists = {}

local function ValidateBiS(data)
    if type(data) ~= "table" then return false, "bis must be a table" end
    if type(data.lists) ~= "table" or #data.lists == 0 then
        return false, "bis.lists must be a non-empty array"
    end
    for listIndex, listEntry in ipairs(data.lists) do
        if type(listEntry) ~= "table" or type(listEntry.title) ~= "string" or listEntry.title == "" then
            return false, format("bis.lists[%d] must have a title", listIndex)
        end
        if type(listEntry.list) ~= "table" or #listEntry.list == 0 then
            return false, format("bis.lists[%d].list must be a non-empty array", listIndex)
        end
        for rowIndex, row in ipairs(listEntry.list) do
            local where = format("bis.lists[%d].list[%d]", listIndex, rowIndex)
            if type(row) ~= "table" then return false, where .. " must be a table" end
            if type(row.slot) ~= "string" or not VALID_GEAR_SLOTS[row.slot] then
                return false, where .. " has an invalid slot"
            end
            if type(row.itemID) ~= "number" then return false, where .. ".itemID must be a number" end
            if type(row.name) ~= "string" or row.name == "" then
                return false, where .. ".name must be a non-empty string"
            end
        end
    end
    return true
end

function GuideStore:RegisterBiS(specID, data)
    if type(specID) ~= "number" then
        ns.Print(format("|cffff4444bis rejected|r (spec=%s): specID must be a number", tostring(specID)))
        return false
    end
    local ok, err = ValidateBiS(data)
    if not ok then
        ns.Print(format("|cffff4444bis rejected|r (spec=%s): %s", tostring(specID), err))
        return false
    end
    bisLists[specID] = data
    return true
end

function GuideStore:GetBiS(specID)
    return bisLists[specID]
end

-- Wowhead stat priorities (v1.6, generated Data/StatPriority.lua):
-- { source, url, patch, heroSplit, lists = { { title, note, list = { { stat },
-- ... } }, ... } }. One list per hero talent tree (or, where Wowhead splits on
-- something else, one per split with both hero trees named in the title).
-- Kept apart from the guide's own flat `statPriority` for the same reason the
-- BiS lists are: a regenerated site list never touches a hand-written guide,
-- and Modules/ItemRanks.lua keeps ranking items off the one order the guide
-- itself commits to.
local statPriorities = {}

local function ValidateStatPriorityData(data)
    if type(data) ~= "table" then return false, "statPriority data must be a table" end
    if type(data.lists) ~= "table" or #data.lists == 0 then
        return false, "statPriority.lists must be a non-empty array"
    end
    for listIndex, listEntry in ipairs(data.lists) do
        if type(listEntry) ~= "table" or type(listEntry.title) ~= "string" or listEntry.title == "" then
            return false, format("statPriority.lists[%d] must have a title", listIndex)
        end
        if listEntry.note ~= nil and type(listEntry.note) ~= "string" then
            return false, format("statPriority.lists[%d].note must be a string when present", listIndex)
        end
        if type(listEntry.list) ~= "table" or #listEntry.list == 0 then
            return false, format("statPriority.lists[%d].list must be a non-empty array", listIndex)
        end
        -- Same per-entry check the guides' own flat list goes through, so
        -- the two can never drift into different vocabularies.
        local ok, err = ValidateStatPriority(listEntry.list)
        if not ok then
            return false, format("statPriority.lists[%d]: %s", listIndex, err)
        end
    end
    return true
end

function GuideStore:RegisterStatPriority(specID, data)
    if type(specID) ~= "number" then
        ns.Print(format("|cffff4444stat priority rejected|r (spec=%s): specID must be a number", tostring(specID)))
        return false
    end
    local ok, err = ValidateStatPriorityData(data)
    if not ok then
        ns.Print(format("|cffff4444stat priority rejected|r (spec=%s): %s", tostring(specID), err))
        return false
    end
    statPriorities[specID] = data
    return true
end

function GuideStore:GetStatPriority(specID)
    return statPriorities[specID]
end

-- Guide-site talent builds (v1.5, generated Data/SiteLoadouts.lua):
-- { source, patch, builds = { { label, string }, ... } }, each string an
-- exact Blizzard export string. Kept apart from the guide's own
-- mplusLoadout/raidLoadout/mplusMetaLoadout so a regenerated site list never
-- touches the hand-written guides.
local siteLoadouts = {}

local function ValidateSiteLoadouts(data)
    if type(data) ~= "table" then return false, "siteLoadouts must be a table" end
    if type(data.patch) ~= "string" or data.patch == "" then
        return false, "siteLoadouts.patch must be a non-empty string"
    end
    if type(data.builds) ~= "table" or #data.builds == 0 then
        return false, "siteLoadouts.builds must be a non-empty array"
    end
    for index, build in ipairs(data.builds) do
        if type(build) ~= "table" then return false, format("siteLoadouts.builds[%d] must be a table", index) end
        if type(build.label) ~= "string" or build.label == "" then
            return false, format("siteLoadouts.builds[%d].label must be a non-empty string", index)
        end
        if type(build.string) ~= "string" or build.string == "" then
            return false, format("siteLoadouts.builds[%d].string must be a non-empty string", index)
        end
        if build.site ~= nil and (type(build.site) ~= "string" or build.site == "") then
            return false, format("siteLoadouts.builds[%d].site must be a non-empty string when present", index)
        end
    end
    return true
end

function GuideStore:RegisterSiteLoadouts(specID, data)
    if type(specID) ~= "number" then
        ns.Print(format("|cffff4444site loadouts rejected|r (spec=%s): specID must be a number", tostring(specID)))
        return false
    end
    local ok, err = ValidateSiteLoadouts(data)
    if not ok then
        ns.Print(format("|cffff4444site loadouts rejected|r (spec=%s): %s", tostring(specID), err))
        return false
    end
    siteLoadouts[specID] = data
    return true
end

function GuideStore:GetSiteLoadouts(specID)
    return siteLoadouts[specID]
end

-- Returns the guide table for a specID, or nil if none is registered.
function GuideStore:GetGuide(specID)
    return guides[specID]
end

-- Returns an array of specIDs registered for classToken, in registration
-- order. Always a fresh table, so callers cannot mutate internal state.
function GuideStore:GetClassSpecs(classToken)
    local specs = classSpecs[classToken]
    if not specs then return {} end

    local copy = {}
    for index, specID in ipairs(specs) do
        copy[index] = specID
    end
    return copy
end

-- Returns all 13 retail classes in classID order, each as a fresh
-- { token, name, classID } table. Classes with no guides registered are
-- still listed, so the Codex's class rail is always complete.
function GuideStore:GetClasses()
    local list = {}
    for index, entry in ipairs(CLASSES) do
        list[index] = { token = entry.token, name = entry.name, classID = entry.classID }
    end
    return list
end
